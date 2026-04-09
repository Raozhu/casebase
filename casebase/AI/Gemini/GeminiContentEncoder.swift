import Foundation
import UniformTypeIdentifiers

enum GeminiContentEncoder {
    private static let previewKinds: Set<NormalizedAttachmentKind> = [.imagePreview, .pagePreview]
    private static let maxPreviewAttachments = 8
    private static let maxPreviewBytesPerAttachment = 4_000_000
    private static let maxTotalPreviewBytes = 12_000_000
    private static let maxInlinePDFBytes = 8_000_000
    private static let maxURLContextURLs = 6

    static func encodeAnalysisContents(_ content: NormalizedContent) throws -> [GeminiJSONObject] {
        let rawText = analysisRawText(for: content)
        let userSupplementKey = CasebasePromptCatalog.ai.userSupplementMetadataKey
        let userSupplement = content.fallbackMetadata[userSupplementKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysisURLs = extractAnalysisURLs(from: content)
        let inlineDocumentParts = try makeInlineDocumentParts(from: content.attachments)
        let previewParts = try makePreviewParts(
            from: content.attachments,
            sourceKind: content.sourceKind,
            allowsExtendedBudget: inlineDocumentParts.isEmpty
        )
        guard !(rawText?.isEmpty ?? true)
            || !inlineDocumentParts.isEmpty
            || !previewParts.isEmpty
            || !(userSupplement?.isEmpty ?? true)
        else {
            throw CasebaseError.analysisFailed(
                CasebasePromptCatalog.errors.noRawTextOrPreviewAttachmentsAvailableForAnalysis
            )
        }

        var parts: [GeminiJSONObject] = []
        parts.append(["text": GeminiAnalysisPromptBuilder.instructions])

        if let userSupplement, !userSupplement.isEmpty {
            parts.append(["text": "\(CasebasePromptCatalog.ai.userSupplementLabel):\n\(userSupplement)"])
        }

        if let rawText, !rawText.isEmpty {
            parts.append(["text": "\(CasebasePromptCatalog.ai.normalizedTextLabel):\n\(rawText)"])
        }

        let visibleMetadata = content.fallbackMetadata.filter { $0.key != userSupplementKey }
        if !visibleMetadata.isEmpty {
            let metadataBlock = visibleMetadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            parts.append(["text": "\(CasebasePromptCatalog.ai.fallbackMetadataLabel):\n\(metadataBlock)"])
        }

        if !analysisURLs.isEmpty {
            let urlBlock = analysisURLs
                .map(\.absoluteString)
                .joined(separator: "\n")
            parts.append([
                "text": """
                \(CasebasePromptCatalog.ai.urlContextLabel):
                \(urlBlock)

                \(CasebasePromptCatalog.ai.urlContextInstruction)
                """,
            ])
        }

        parts.append(contentsOf: inlineDocumentParts)
        parts.append(contentsOf: previewParts)
        return [["parts": parts]]
    }

    static func extractAnalysisURLs(from content: NormalizedContent) -> [URL] {
        let candidateTexts = [
            analysisRawText(for: content),
            content.fallbackMetadata[CasebasePromptCatalog.ai.userSupplementMetadataKey]?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
        ]
        let texts = candidateTexts.compactMap { $0 }.filter { !$0.isEmpty }

        guard !texts.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return []
        }

        var urls: [URL] = []
        var seen: Set<String> = []

        for text in texts {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                guard let url = match.url,
                      let normalizedURL = normalizedPublicHTTPURL(from: url)
                else {
                    continue
                }

                let dedupeKey = normalizedURL.absoluteString.lowercased()
                guard seen.insert(dedupeKey).inserted else {
                    continue
                }

                urls.append(normalizedURL)
                if urls.count >= maxURLContextURLs {
                    return urls
                }
            }
        }

        return urls
    }

    private static func makeInlineDocumentParts(from attachments: [NormalizedAttachment]) throws -> [GeminiJSONObject] {
        for attachment in attachments where attachment.kind == .originalAsset {
            let fileURL = URL(fileURLWithPath: attachment.path)
            let mimeType = resolvedMimeType(for: attachment, fileURL: fileURL)
            guard mimeType == "application/pdf" else { continue }

            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            guard data.count <= maxInlinePDFBytes else { continue }

            return [[
                "inline_data": [
                    "mime_type": mimeType,
                    "data": data.base64EncodedString(),
                ],
            ]]
        }

        return []
    }

    private static func analysisRawText(for content: NormalizedContent) -> String? {
        guard content.sourceKind != .pdf else {
            return nil
        }
        return content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makePreviewParts(
        from attachments: [NormalizedAttachment],
        sourceKind: ImportSourceKind,
        allowsExtendedBudget: Bool
    ) throws -> [GeminiJSONObject] {
        guard sourceKind == .image else {
            return []
        }

        var parts: [GeminiJSONObject] = []
        var consumedBytes = 0

        for attachment in attachments where previewKinds.contains(attachment.kind) {
            guard parts.count < maxPreviewAttachments else {
                break
            }

            let fileURL = URL(fileURLWithPath: attachment.path)
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            guard data.count <= maxPreviewBytesPerAttachment else {
                continue
            }
            let nextConsumedBytes = consumedBytes + data.count
            guard nextConsumedBytes <= (allowsExtendedBudget ? maxTotalPreviewBytes : maxPreviewBytesPerAttachment) else {
                continue
            }

            let mimeType = resolvedMimeType(for: attachment, fileURL: fileURL)
            parts.append([
                "inline_data": [
                    "mime_type": mimeType,
                    "data": data.base64EncodedString(),
                ],
            ])
            consumedBytes = nextConsumedBytes
        }

        return parts
    }

    private static func resolvedMimeType(for attachment: NormalizedAttachment, fileURL: URL) -> String {
        if let mimeType = attachment.mimeType, !mimeType.isEmpty {
            return mimeType
        }
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           let mimeType = type.preferredMIMEType
        {
            return mimeType
        }
        return "application/octet-stream"
    }

    private static func normalizedPublicHTTPURL(from url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              isPublicHost(host)
        else {
            return nil
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.fragment = nil
        return components.url
    }

    private static func isPublicHost(_ host: String) -> Bool {
        guard !host.isEmpty,
              host != "localhost",
              !host.hasSuffix(".local")
        else {
            return false
        }

        if host.contains(":") {
            let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
            if normalized == "::1" || normalized.hasPrefix("fc") || normalized.hasPrefix("fd") || normalized.hasPrefix("fe80:") {
                return false
            }
            return true
        }

        let octets = host.split(separator: ".")
        if octets.count == 4, let first = Int(octets[0]), let second = Int(octets[1]) {
            if first == 10 || first == 127 || (first == 169 && second == 254) || (first == 192 && second == 168) {
                return false
            }
            if first == 172 && (16 ... 31).contains(second) {
                return false
            }
        }

        return host.contains(".")
    }
}
