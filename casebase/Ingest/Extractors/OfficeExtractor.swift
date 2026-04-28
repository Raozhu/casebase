import Foundation

final class OfficeExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.binary]

    private let fileManager: FileManager
    private let previewRenderer: QuickLookPreviewRenderer
    private let ocrService: ImageOCRService

    init(
        fileManager: FileManager = .default,
        previewRenderer: QuickLookPreviewRenderer,
        ocrService: ImageOCRService = ImageOCRService()
    ) {
        self.fileManager = fileManager
        self.previewRenderer = previewRenderer
        self.ocrService = ocrService
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        guard case let .file(filePayload) = payload else { return false }
        return Self.supportedExtensions.contains(filePayload.fileURL.pathExtension.lowercased())
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.officeExtractionRequiresFileBackedPayload
            )
        }

        guard canExtract(payload) else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.payloadIsNotASupportedOfficeFile
            )
        }

        let resolution = FileTypeResolver.resolve(payload)
        let originalAttachment = NormalizedAttachment(
            kind: .originalAsset,
            path: filePayload.fileURL.path,
            mimeType: resolution.mimeType
        )

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: resolution.mimeType,
            utType: resolution.utType,
            fileManager: fileManager
        )
        metadata["analysisInputMode"] = "office-document"
        metadata["officeExtension"] = filePayload.fileURL.pathExtension.lowercased()
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        var attachments = [originalAttachment]
        let previewStartedAt = Date()
        CasebaseDebugLogger.log(
            "office extractor preview started file=\"\(filePayload.fileURL.lastPathComponent)\""
        )
        if let preview = await previewRenderer.renderPreviewAttachment(
            for: filePayload.fileURL,
            prefix: filePayload.fileURL.deletingPathExtension().lastPathComponent
        ) {
            attachments.append(preview)
            metadata["generatedPreviewCount"] = "1"
            CasebaseDebugLogger.log(
                "office extractor preview finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: previewStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" generatedPreviewCount=1"
            )
        } else {
            metadata["generatedPreviewCount"] = "0"
            CasebaseDebugLogger.log(
                "office extractor preview finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: previewStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" generatedPreviewCount=0"
            )
        }

        let textExtractionStartedAt = Date()
        CasebaseDebugLogger.log(
            "office extractor text extraction started file=\"\(filePayload.fileURL.lastPathComponent)\""
        )
        let extraction = try extractedText(for: filePayload.fileURL)
        CasebaseDebugLogger.log(
            "office extractor text extraction finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: textExtractionStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" extractedChars=\(extraction.text?.count ?? 0)"
        )
        var rawText = extraction.text
        for (key, value) in extraction.metadata {
            metadata[key] = value
        }

        if let previewAttachment = attachments.first(where: { $0.kind == .pagePreview }) {
            let ocrStartedAt = Date()
            CasebaseDebugLogger.log(
                "office extractor preview OCR started file=\"\(filePayload.fileURL.lastPathComponent)\""
            )
            let previewOCR = try? ocrService.recognizeText(from: URL(fileURLWithPath: previewAttachment.path))
            CasebaseDebugLogger.log(
                "office extractor preview OCR finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: ocrStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" ocrChars=\(previewOCR?.count ?? 0)"
            )
            if let previewOCR,
               !previewOCR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                metadata["previewOCRCharacterCount"] = String(previewOCR.count)
                if let currentText = rawText {
                    if shouldAppendOCR(previewOCR, to: currentText) {
                        rawText = currentText + "\n\n" + previewOCR
                        metadata["officeExtractionSource"] = [metadata["officeExtractionSource"], "preview-ocr"]
                            .compactMap { $0 }
                            .joined(separator: "+")
                    }
                } else {
                    rawText = previewOCR
                    metadata["officeExtractionSource"] = "preview-ocr"
                }
            }
        }

        if let rawText {
            metadata["characterCount"] = String(rawText.count)
            metadata["lineCount"] = String(rawText.split(whereSeparator: \.isNewline).count)
        }

        return NormalizedContent(
            sourceKind: .binary,
            rawText: rawText,
            attachments: attachments,
            fallbackMetadata: metadata
        )
    }

    private func extractedText(for fileURL: URL) throws -> (text: String?, metadata: [String: String]) {
        let fileExtension = fileURL.pathExtension.lowercased()
        var candidates: [(source: String, text: String)] = []
        var metadata: [String: String] = [:]
        let fileName = fileURL.lastPathComponent

        let openXMLStartedAt = Date()
        CasebaseDebugLogger.log("office extractor ooxml started file=\"\(fileName)\"")
        if let openXML = try OfficeOpenXMLReader.extractText(from: fileURL) {
            let trimmed = normalizeCandidateText(openXML.text)
            if !trimmed.isEmpty {
                candidates.append(("ooxml", trimmed))
                for (key, value) in openXML.metadata {
                    metadata[key] = value
                }
            }
        }
        let hasOpenXMLCandidate = candidates.contains(where: { $0.source == "ooxml" })
        CasebaseDebugLogger.log(
            "office extractor ooxml finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: openXMLStartedAt)) file=\"\(fileName)\" candidates=\(hasOpenXMLCandidate ? 1 : 0)"
        )

        if Self.textUtilExtensions.contains(fileExtension) {
            let textUtilStartedAt = Date()
            CasebaseDebugLogger.log("office extractor textutil started file=\"\(fileName)\"")
            let text = extractTextWithTextUtil(from: fileURL)
            CasebaseDebugLogger.log(
                "office extractor textutil finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: textUtilStartedAt)) file=\"\(fileName)\" chars=\(text?.count ?? 0)"
            )
            if let text {
                candidates.append(("textutil", text))
            }
        }

        let spotlightStartedAt = Date()
        CasebaseDebugLogger.log("office extractor spotlight started file=\"\(fileName)\"")
        if let spotlightText = extractTextWithSpotlight(from: fileURL) {
            candidates.append(("spotlight", spotlightText))
        }
        let spotlightCharacterCount = candidates.first(where: { $0.source == "spotlight" })?.text.count ?? 0
        CasebaseDebugLogger.log(
            "office extractor spotlight finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: spotlightStartedAt)) file=\"\(fileName)\" chars=\(spotlightCharacterCount)"
        )

        let best = bestCandidate(in: candidates)
        metadata["officeExtractionSource"] = best?.source ?? "none"
        metadata["officeTextCandidateCount"] = String(candidates.count)
        return (best?.text, metadata)
    }

    private func extractTextWithTextUtil(from fileURL: URL) -> String? {
        do {
            let result = try SystemCommandRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/textutil"),
                arguments: ["-convert", "txt", "-stdout", "--", fileURL.path]
            )
            let text = String(decoding: result.standardOutput, as: UTF8.self)
            let normalized = normalizeCandidateText(text)
            return normalized.isEmpty ? nil : normalized
        } catch {
            return nil
        }
    }

    private func extractTextWithSpotlight(from fileURL: URL) -> String? {
        do {
            let result = try SystemCommandRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/mdls"),
                arguments: ["-raw", "-name", "kMDItemTextContent", fileURL.path]
            )
            var text = String(decoding: result.standardOutput, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text != "(null)" else { return nil }

            if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
                text = String(text.dropFirst().dropLast())
            }

            text = text
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\t", with: "\t")
            let normalized = normalizeCandidateText(text)
            return normalized.isEmpty ? nil : normalized
        } catch {
            return nil
        }
    }

    private func bestCandidate(in candidates: [(source: String, text: String)]) -> (source: String, text: String)? {
        candidates.max { lhs, rhs in
            score(for: lhs.text) < score(for: rhs.text)
        }
    }

    private func score(for text: String) -> Int {
        let lineCount = text.split(whereSeparator: \.isNewline).count
        let uniqueCharacters = Set(text).count
        return text.count + lineCount * 24 + uniqueCharacters
    }

    private func normalizeCandidateText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldAppendOCR(_ ocrText: String, to currentText: String) -> Bool {
        let normalizedOCR = ocrText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let normalizedCurrent = currentText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")

        guard normalizedOCR.count >= 24 else { return false }
        return !normalizedCurrent.contains(normalizedOCR)
    }

    private static let supportedExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx"
    ]

    private static let textUtilExtensions: Set<String> = [
        "doc", "docx"
    ]
}
