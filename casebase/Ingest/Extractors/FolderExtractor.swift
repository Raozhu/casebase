import Foundation
import PDFKit
import UniformTypeIdentifiers

final class FolderExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.folder]

    private struct FolderEntry {
        let url: URL
        let relativePath: String
        let isDirectory: Bool
        let isRegularFile: Bool
        let byteCount: Int64
        let fileExtension: String
    }

    private let fileManager: FileManager
    private let maxTreeEntries = 180
    private let maxMediaEntries = 40
    private let maxSampleFiles = 12
    private let maxSampleCharactersPerFile = 800
    private let maxSummaryCharacters = 16_000

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        FileTypeResolver.resolve(payload).sourceKind == .folder
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.fallbackExtractionOnlyAcceptsFileBackedPayloads
            )
        }

        guard FileTypeResolver.resolve(payload).sourceKind == .folder else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.fallbackExtractionOnlyAcceptsFileBackedPayloads
            )
        }

        let entries = folderEntries(in: filePayload.fileURL)
        let fileEntries = entries.filter(\.isRegularFile)
        let directoryEntries = entries.filter(\.isDirectory)
        let totalBytes = fileEntries.reduce(Int64(0)) { $0 + $1.byteCount }
        let summary = folderSummary(
            rootURL: filePayload.fileURL,
            entries: entries,
            fileEntries: fileEntries,
            directoryEntries: directoryEntries,
            totalBytes: totalBytes
        )

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: filePayload.mimeType ?? "inode/directory",
            utType: .directory,
            fileManager: fileManager
        )
        metadata["folderName"] = filePayload.fileURL.lastPathComponent
        metadata["folderFileCount"] = String(fileEntries.count)
        metadata["folderDirectoryCount"] = String(directoryEntries.count)
        metadata["folderTotalSizeBytes"] = String(totalBytes)
        metadata["folderSummaryMode"] = "structure-and-sampled-text"
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        return NormalizedContent(
            sourceKind: .folder,
            rawText: summary,
            fallbackMetadata: metadata
        )
    }

    private func folderEntries(in rootURL: URL) -> [FolderEntry] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
            ],
            options: []
        ) else {
            return []
        }

        var entries: [FolderEntry] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if shouldSkipSummaryEntry(name: name) {
                if isDirectory(url) {
                    enumerator.skipDescendants()
                }
                continue
            }

            let values = try? url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
            ])
            let isDirectory = values?.isDirectory == true
            let isRegularFile = values?.isRegularFile == true
            let byteCount = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            entries.append(FolderEntry(
                url: url,
                relativePath: relativePath(from: rootURL, to: url),
                isDirectory: isDirectory,
                isRegularFile: isRegularFile,
                byteCount: byteCount,
                fileExtension: url.pathExtension.lowercased()
            ))
        }

        return entries.sorted { $0.relativePath < $1.relativePath }
    }

    private func folderSummary(
        rootURL: URL,
        entries: [FolderEntry],
        fileEntries: [FolderEntry],
        directoryEntries: [FolderEntry],
        totalBytes: Int64
    ) -> String {
        var sections: [String] = []
        sections.append("""
        文件夹入库摘要（本地抽样生成，不是全文读取）
        请根据目录结构、文件名、文件类型统计和少量关键文本片段判断这个文件夹的内容、用途和检索标签；不要声称已经完整阅读所有文件。
        根目录：\(rootURL.lastPathComponent)
        文件数：\(fileEntries.count)
        子目录数：\(directoryEntries.count)
        总大小：\(formattedByteCount(totalBytes))
        """)

        let extensionStats = extensionStatistics(from: fileEntries)
        if !extensionStats.isEmpty {
            sections.append("文件类型统计：\n\(extensionStats)")
        }

        let keyFiles = keyFileList(from: fileEntries)
        if !keyFiles.isEmpty {
            sections.append("关键文件名（按信号排序）：\n\(keyFiles)")
        }

        let tree = directoryTree(from: entries)
        if !tree.isEmpty {
            sections.append("目录结构（截断）：\n\(tree)")
        }

        let samples = sampledTextBlocks(from: fileEntries)
        if !samples.isEmpty {
            sections.append("关键文本片段（抽样）：\n\(samples)")
        }

        let media = mediaMetadata(from: fileEntries)
        if !media.isEmpty {
            sections.append("多媒体/二进制文件线索（仅元数据）：\n\(media)")
        }

        let summary = sections.joined(separator: "\n\n")
        if summary.count <= maxSummaryCharacters {
            return summary
        }

        let endIndex = summary.index(summary.startIndex, offsetBy: maxSummaryCharacters)
        return String(summary[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "\n…（摘要已截断）"
    }

    private func extensionStatistics(from files: [FolderEntry]) -> String {
        let counts = Dictionary(grouping: files) { entry in
            entry.fileExtension.isEmpty ? "no-extension" : entry.fileExtension
        }
        return counts
            .map { (key: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.key < rhs.key }
                return lhs.count > rhs.count
            }
            .prefix(20)
            .map { "\($0.key): \($0.count)" }
            .joined(separator: "\n")
    }

    private func directoryTree(from entries: [FolderEntry]) -> String {
        entries
            .prefix(maxTreeEntries)
            .map { entry in
                let depth = entry.relativePath.split(separator: "/").count - 1
                let indent = String(repeating: "  ", count: max(0, depth))
                let marker = entry.isDirectory ? "[D]" : "[F]"
                return "\(indent)\(marker) \(URL(fileURLWithPath: entry.relativePath).lastPathComponent)"
            }
            .joined(separator: "\n")
    }

    private func sampledTextBlocks(from files: [FolderEntry]) -> String {
        scoredTextCandidates(from: files)
            .prefix(maxSampleFiles)
            .compactMap { entry -> String? in
                guard let excerpt = textExcerpt(from: entry.url), !excerpt.isEmpty else {
                    return nil
                }
                return "### \(entry.relativePath)\n\(excerpt)"
            }
            .joined(separator: "\n\n")
    }

    private func keyFileList(from files: [FolderEntry]) -> String {
        files
            .sorted { lhs, rhs in
                let lhsScore = sampleScore(for: lhs)
                let rhsScore = sampleScore(for: rhs)
                if lhsScore == rhsScore { return lhs.relativePath < rhs.relativePath }
                return lhsScore > rhsScore
            }
            .prefix(24)
            .map { "\($0.relativePath) (\($0.fileExtension.isEmpty ? "unknown" : $0.fileExtension), \(formattedByteCount($0.byteCount)))" }
            .joined(separator: "\n")
    }

    private func scoredTextCandidates(from files: [FolderEntry]) -> [FolderEntry] {
        files
            .filter { canSampleText(from: $0) }
            .sorted { lhs, rhs in
                let lhsScore = sampleScore(for: lhs)
                let rhsScore = sampleScore(for: rhs)
                if lhsScore == rhsScore { return lhs.relativePath < rhs.relativePath }
                return lhsScore > rhsScore
            }
    }

    private func canSampleText(from entry: FolderEntry) -> Bool {
        textExtensions.contains(entry.fileExtension)
            || officeExtensions.contains(entry.fileExtension)
            || entry.fileExtension == "pdf"
    }

    private func sampleScore(for entry: FolderEntry) -> Int {
        let normalizedPath = entry.relativePath.lowercased()
        var score = max(0, 20 - normalizedPath.split(separator: "/").count)

        for keyword in highSignalKeywords where normalizedPath.contains(keyword) {
            score += 20
        }

        if ["md", "txt", "docx", "pdf"].contains(entry.fileExtension) {
            score += 8
        }
        if entry.byteCount > 0 && entry.byteCount < 500_000 {
            score += 4
        }
        return score
    }

    private func textExcerpt(from url: URL) -> String? {
        let fileExtension = url.pathExtension.lowercased()
        let rawText: String?

        if textExtensions.contains(fileExtension) {
            rawText = try? TextFileReader.readText(from: url).text
        } else if officeExtensions.contains(fileExtension) {
            rawText = try? OfficeOpenXMLReader.extractText(from: url)?.text
        } else if fileExtension == "pdf" {
            rawText = pdfTextExcerpt(from: url)
        } else {
            rawText = nil
        }

        guard let rawText else { return nil }
        let normalized = normalizeWhitespace(in: rawText)
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(maxSampleCharactersPerFile))
    }

    private func pdfTextExcerpt(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var sections: [String] = []
        for pageIndex in 0 ..< min(document.pageCount, 2) {
            guard let text = document.page(at: pageIndex)?.string else { continue }
            let normalized = normalizeWhitespace(in: text)
            if !normalized.isEmpty {
                sections.append(normalized)
            }
        }
        return sections.joined(separator: "\n")
    }

    private func mediaMetadata(from files: [FolderEntry]) -> String {
        files
            .filter { mediaExtensions.contains($0.fileExtension) || !canSampleText(from: $0) }
            .prefix(maxMediaEntries)
            .map { "\($0.relativePath) (\($0.fileExtension.isEmpty ? "unknown" : $0.fileExtension), \(formattedByteCount($0.byteCount)))" }
            .joined(separator: "\n")
    }

    private func shouldSkipSummaryEntry(name: String) -> Bool {
        let lowered = name.lowercased()
        return skippedSummaryNames.contains(lowered)
            || lowered.hasSuffix(".tmp")
            || lowered.hasSuffix(".lock")
    }

    private func isDirectory(_ url: URL) -> Bool {
        FileMetadataReader.isDirectory(url, fileManager: fileManager)
    }

    private func relativePath(from rootURL: URL, to childURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let childPath = childURL.standardizedFileURL.path
        guard childPath.hasPrefix(rootPath) else {
            return childURL.lastPathComponent
        }

        var relative = String(childPath.dropFirst(rootPath.count))
        while relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative
    }

    private func normalizeWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedByteCount(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: byteCount)
    }

    private let highSignalKeywords = [
        "readme", "prd", "需求", "方案", "总结", "复盘", "prompt", "提示词",
        "规则", "index", "package", "计划", "设计", "文档", "spec", "brief",
        "meeting", "会议", "report", "报告",
    ]

    private let skippedSummaryNames: Set<String> = [
        ".ds_store", "__macosx", ".git", "node_modules", ".build", ".cache",
        "__pycache__", "deriveddata", ".swiftpm", ".venv", "tmp", "temp",
    ]

    private let textExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "jsonl", "xml", "yaml", "yml",
        "csv", "tsv", "log", "rtf", "html", "htm", "css", "js", "ts",
        "swift", "py", "rb", "go", "java", "c", "cc", "cpp", "h", "hpp",
        "m", "mm", "sh", "zsh", "bash", "toml",
    ]

    private let officeExtensions: Set<String> = ["docx", "xlsx", "pptx"]

    private let mediaExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "webp", "gif", "tif", "tiff", "bmp",
        "mp4", "mov", "m4v", "avi", "mkv", "webm",
        "m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "flac",
    ]
}
