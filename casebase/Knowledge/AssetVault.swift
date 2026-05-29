import CryptoKit
import Foundation

actor AssetVault {
    private let configuration: StorageConfiguration
    private let fileManager: FileManager
    private let illegalFolderCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
    private let illegalFileNameCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")

    init(configuration: StorageConfiguration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    func prepareDirectories() throws {
        try fileManager.createDirectory(at: configuration.rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.assetsDirectory, withIntermediateDirectories: true)
    }

    func store(_ payload: ImportPayload) throws -> StoredAsset {
        try prepareDirectories()

        switch payload {
        case let .file(filePayload):
            return try storeFilePayload(filePayload)
        case let .text(textPayload):
            return try storeTextPayload(textPayload)
        }
    }

    func url(for assetPath: String) -> URL {
        configuration.rootDirectory.appendingPathComponent(assetPath, isDirectory: false)
    }

    func assetExists(at assetPath: String) -> Bool {
        fileManager.fileExists(atPath: url(for: assetPath).path)
    }

    func discardTemporaryAsset(_ storedAsset: StoredAsset, preservingAssetPath preservedAssetPath: String) throws {
        guard storedAsset.assetPath != preservedAssetPath else { return }

        let assetURL = url(for: storedAsset.assetPath)
        guard fileManager.fileExists(atPath: assetURL.path) else { return }

        try fileManager.removeItem(at: assetURL)
        try removeParentFolderIfEmpty(forAssetAt: assetURL)
    }

    func purposeFolderNames() throws -> [String] {
        try prepareDirectories()

        let assetURLs = try fileManager.contentsOfDirectory(
            at: configuration.assetsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return assetURLs.compactMap { assetURL in
            guard
                let values = try? assetURL.resourceValues(forKeys: [.isDirectoryKey]),
                values.isDirectory == true
            else {
                return nil
            }

            let folderName = assetURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            return folderName.isEmpty ? nil : folderName
        }
        .sorted()
    }

    func relocate(
        _ storedAsset: StoredAsset,
        intoPurposeFolder folderName: String,
        preferredDisplayName: String? = nil
    ) throws -> StoredAsset {
        try prepareDirectories()

        let normalizedFolderName = sanitizedPurposeFolderName(folderName)
        let folderURL = try ensuredPurposeFolderURL(named: normalizedFolderName)
        let destinationFileName = storedAsset.sourceKind == .folder
            ? readableFolderName(preferredName: storedAsset.fileName)
            : readableFileName(
                preferredName: storedAsset.fileName,
                displayName: preferredDisplayName
            )
        let sourceURL = url(for: storedAsset.assetPath)
        let destinationURL = availableDestinationURL(
            forFileName: destinationFileName,
            in: folderURL,
            sourceURL: sourceURL
        )
        let destinationRelativePath = "assets/\(normalizedFolderName)/\(destinationURL.lastPathComponent)"

        if sourceURL.path != destinationURL.path {
            if fileManager.fileExists(atPath: destinationURL.path) {
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.removeItem(at: sourceURL)
                }
            } else if fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
            }

            try removeParentFolderIfEmpty(forAssetAt: sourceURL)
        }

        return StoredAsset(
            assetPath: destinationRelativePath,
            assetHash: storedAsset.assetHash,
            fileName: storedAsset.fileName,
            mimeType: storedAsset.mimeType,
            sourceKind: storedAsset.sourceKind,
            fileSize: storedAsset.fileSize,
            contextMetadata: storedAsset.contextMetadata
        )
    }

    func removeParentFolderIfEmpty(forAssetAt assetURL: URL) throws {
        let parentURL = assetURL.deletingLastPathComponent()
        guard parentURL.path != configuration.assetsDirectory.path else { return }
        guard parentURL.path.hasPrefix(configuration.assetsDirectory.path) else { return }

        let contents = try fileManager.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        guard contents.isEmpty else { return }
        try fileManager.removeItem(at: parentURL)
    }

    func deleteAllStoredAssets() throws {
        if fileManager.fileExists(atPath: configuration.assetsDirectory.path) {
            let assetURLs = try fileManager.contentsOfDirectory(
                at: configuration.assetsDirectory,
                includingPropertiesForKeys: nil
            )
            for assetURL in assetURLs {
                try fileManager.removeItem(at: assetURL)
            }
        }

        try prepareDirectories()
    }

    private func storeFilePayload(_ payload: FileImportPayload) throws -> StoredAsset {
        let sourceURL = payload.fileURL
        if FileMetadataReader.isDirectory(sourceURL, fileManager: fileManager) {
            return try storeFolderPayload(payload)
        }

        let data = try Data(contentsOf: sourceURL)
        let assetHash = sha256Hex(for: data)
        let fileName = payload.suggestedFileName ?? sourceURL.lastPathComponent
        let destinationFileName = hashedFileName(hash: assetHash, preferredName: fileName)
        let relativePath = "assets/\(destinationFileName)"
        let destinationURL = configuration.rootDirectory.appendingPathComponent(relativePath, isDirectory: false)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        return StoredAsset(
            assetPath: relativePath,
            assetHash: assetHash,
            fileName: fileName,
            mimeType: payload.mimeType,
            sourceKind: inferSourceKind(from: payload.sourceKindHint, fileName: fileName, mimeType: payload.mimeType),
            fileSize: Int64(data.count),
            contextMetadata: payload.contextMetadata
        )
    }

    private func storeFolderPayload(_ payload: FileImportPayload) throws -> StoredAsset {
        let sourceURL = payload.fileURL
        let fileName = payload.suggestedFileName ?? sourceURL.lastPathComponent
        let assetHash = try folderHash(for: sourceURL, displayName: fileName)
        let destinationFileName = hashedFolderName(hash: assetHash, preferredName: fileName)
        let relativePath = "assets/\(destinationFileName)"
        let destinationURL = configuration.rootDirectory.appendingPathComponent(relativePath, isDirectory: true)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        return StoredAsset(
            assetPath: relativePath,
            assetHash: assetHash,
            fileName: fileName,
            mimeType: payload.mimeType ?? "inode/directory",
            sourceKind: .folder,
            fileSize: FileMetadataReader.directorySizeBytes(for: sourceURL, fileManager: fileManager),
            contextMetadata: payload.contextMetadata
        )
    }

    private func storeTextPayload(_ payload: TextImportPayload) throws -> StoredAsset {
        guard let data = payload.text.data(using: .utf8) else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.draggedTextCouldNotBeEncodedAsUTF8
            )
        }

        let assetHash = sha256Hex(for: data)
        let preferredName = payload.suggestedFileName ?? "Dragged Text.txt"
        let normalizedName = preferredName.contains(".") ? preferredName : preferredName + ".txt"
        let destinationFileName = hashedFileName(hash: assetHash, preferredName: normalizedName)
        let relativePath = "assets/\(destinationFileName)"
        let destinationURL = configuration.rootDirectory.appendingPathComponent(relativePath, isDirectory: false)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        return StoredAsset(
            assetPath: relativePath,
            assetHash: assetHash,
            fileName: normalizedName,
            mimeType: payload.mimeType,
            sourceKind: .text,
            fileSize: Int64(data.count),
            contextMetadata: payload.contextMetadata
        )
    }

    private func inferSourceKind(
        from hint: ImportSourceKind?,
        fileName: String,
        mimeType: String?
    ) -> ImportSourceKind {
        if let hint {
            return hint
        }

        if mimeType?.lowercased() == "inode/directory" {
            return .folder
        }

        let loweredMime = mimeType?.lowercased() ?? ""
        if loweredMime.hasPrefix("image/") {
            return .image
        }
        if loweredMime == "application/pdf" {
            return .pdf
        }
        if loweredMime.hasPrefix("audio/") {
            return .audio
        }
        if loweredMime.hasPrefix("text/") {
            return .text
        }

        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "webp", "heic", "gif", "tiff", "bmp":
            return .image
        case "pdf":
            return .pdf
        case "txt", "md", "json", "csv", "xml", "yaml", "yml", "rtf":
            return .text
        case "wav", "mp3", "m4a", "aac", "flac":
            return .audio
        default:
            return .binary
        }
    }

    private func hashedFileName(hash: String, preferredName: String) -> String {
        let pathExtension = URL(fileURLWithPath: preferredName).pathExtension
        guard !pathExtension.isEmpty else {
            return hash
        }
        return "\(hash).\(pathExtension.lowercased())"
    }

    private func hashedFolderName(hash: String, preferredName: String) -> String {
        let folderName = sanitizedReadableBaseName(preferredName)
            ?? (CasebasePromptCatalog.language == .simplifiedChinese ? "资料文件夹" : "Folder")
        return "\(hash)-\(folderName)"
    }

    private func readableFileName(
        preferredName: String,
        displayName: String?
    ) -> String {
        let pathExtension = URL(fileURLWithPath: preferredName).pathExtension.lowercased()
        let fallbackBaseName = URL(fileURLWithPath: preferredName)
            .deletingPathExtension()
            .lastPathComponent
        let candidateBaseName = sanitizedReadableBaseName(displayName) ?? sanitizedReadableBaseName(fallbackBaseName)
        let baseName = candidateBaseName
            ?? (CasebasePromptCatalog.language == .simplifiedChinese ? "资料" : "Document")

        guard !pathExtension.isEmpty else {
            return baseName
        }
        return "\(baseName).\(pathExtension)"
    }

    private func readableFolderName(preferredName: String) -> String {
        sanitizedReadableBaseName(preferredName)
            ?? (CasebasePromptCatalog.language == .simplifiedChinese ? "资料文件夹" : "Folder")
    }

    private func sanitizedReadableBaseName(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let cleaned = rawValue
            .components(separatedBy: illegalFileNameCharacters)
            .joined(separator: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !cleaned.isEmpty else {
            return nil
        }

        let clipped = String(cleaned.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped.isEmpty ? nil : clipped
    }

    private func availableDestinationURL(
        forFileName fileName: String,
        in folderURL: URL,
        sourceURL: URL
    ) -> URL {
        let baseURL = folderURL.appendingPathComponent(fileName, isDirectory: false)
        if !fileManager.fileExists(atPath: baseURL.path) || baseURL.path == sourceURL.path {
            return baseURL
        }

        let pathExtension = baseURL.pathExtension
        let baseName = baseURL.deletingPathExtension().lastPathComponent

        var suffix = 2
        while true {
            let candidateName: String
            if pathExtension.isEmpty {
                candidateName = "\(baseName) \(suffix)"
            } else {
                candidateName = "\(baseName) \(suffix).\(pathExtension)"
            }

            let candidateURL = folderURL.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidateURL.path) || candidateURL.path == sourceURL.path {
                return candidateURL
            }

            suffix += 1
        }
    }

    private func ensuredPurposeFolderURL(named folderName: String) throws -> URL {
        var candidateURL = configuration.assetsDirectory.appendingPathComponent(folderName, isDirectory: true)
        var suffix = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                return candidateURL
            }

            suffix += 1
            candidateURL = configuration.assetsDirectory.appendingPathComponent("\(folderName)-\(suffix)", isDirectory: true)
        }

        try fileManager.createDirectory(at: candidateURL, withIntermediateDirectories: true)
        return candidateURL
    }

    private func sanitizedPurposeFolderName(_ folderName: String) -> String {
        let cleaned = folderName
            .components(separatedBy: illegalFolderCharacters)
            .joined(separator: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            return CasebasePromptCatalog.language == .simplifiedChinese ? "通用资料" : "General"
        }

        let clipped = String(cleaned.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped.isEmpty
            ? (CasebasePromptCatalog.language == .simplifiedChinese ? "通用资料" : "General")
            : clipped
    }

    private func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func folderHash(for folderURL: URL, displayName: String) throws -> String {
        var hasher = SHA256()
        updateHash(&hasher, string: "casebase-folder-v1\n")
        updateHash(&hasher, string: "name:\(displayName)\n")

        let entries = try folderHashEntries(for: folderURL)
        for entryURL in entries {
            let relativePath = relativePath(from: folderURL, to: entryURL)
            let values = try entryURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ])

            if values.isDirectory == true {
                updateHash(&hasher, string: "dir:\(relativePath)\n")
            } else if values.isSymbolicLink == true {
                let destination = (try? fileManager.destinationOfSymbolicLink(atPath: entryURL.path)) ?? ""
                updateHash(&hasher, string: "symlink:\(relativePath):\(destination)\n")
            } else if values.isRegularFile == true {
                updateHash(&hasher, string: "file:\(relativePath)\n")
                let data = try Data(contentsOf: entryURL, options: .mappedIfSafe)
                hasher.update(data: data)
                updateHash(&hasher, string: "\n")
            } else {
                updateHash(&hasher, string: "other:\(relativePath)\n")
            }
        }

        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }

    private func folderHashEntries(for folderURL: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return []
        }

        var entries: [URL] = []
        for case let url as URL in enumerator {
            entries.append(url)
        }

        return entries.sorted {
            relativePath(from: folderURL, to: $0) < relativePath(from: folderURL, to: $1)
        }
    }

    private func updateHash(_ hasher: inout SHA256, string: String) {
        hasher.update(data: Data(string.utf8))
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
}
