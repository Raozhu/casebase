import Foundation
import UniformTypeIdentifiers

enum GeminiContentEncoder {
    private static let previewKinds: Set<NormalizedAttachmentKind> = [.imagePreview, .pagePreview]
    private static let maxPreviewAttachments = 4
    private static let maxPreviewBytes = 4_000_000

    static func encodeAnalysisContents(_ content: NormalizedContent) throws -> [GeminiJSONObject] {
        let rawText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userSupplementKey = CasebasePromptCatalog.ai.userSupplementMetadataKey
        let userSupplement = content.fallbackMetadata[userSupplementKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previewParts = try makePreviewParts(from: content.attachments)
        guard !(rawText?.isEmpty ?? true) || !previewParts.isEmpty || !(userSupplement?.isEmpty ?? true) else {
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

        parts.append(contentsOf: previewParts)
        return [["parts": parts]]
    }

    private static func makePreviewParts(from attachments: [NormalizedAttachment]) throws -> [GeminiJSONObject] {
        var parts: [GeminiJSONObject] = []

        for attachment in attachments where previewKinds.contains(attachment.kind) {
            guard parts.count < maxPreviewAttachments else {
                break
            }

            let fileURL = URL(fileURLWithPath: attachment.path)
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            guard data.count <= maxPreviewBytes else {
                continue
            }

            let mimeType = resolvedMimeType(for: attachment, fileURL: fileURL)
            parts.append([
                "inline_data": [
                    "mime_type": mimeType,
                    "data": data.base64EncodedString(),
                ],
            ])
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
}
