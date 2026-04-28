import Foundation
import UniformTypeIdentifiers

enum GeminiAnswerContentEncoder {
    private static let maxPreviewBytesPerAttachment = 4_000_000
    private static let maxTotalPreviewBytes = 12_000_000
    private static let maxInlinePDFBytes = 8_000_000

    static func encodeAnswerContents(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy
    ) throws -> [GeminiJSONObject] {
        var parts: [GeminiJSONObject] = [[
            "text": CasebasePromptCatalog.ai.answerPrompt(
                question: question,
                sources: sources,
                policy: policy
            ),
        ]]
        parts.append(contentsOf: try attachmentParts(from: sources))
        return [["parts": parts]]
    }

    static func encodeAttributionContents(
        question: String,
        answerText: String,
        sources: [AnswerEvidencePacket]
    ) throws -> [GeminiJSONObject] {
        var parts: [GeminiJSONObject] = [[
            "text": CasebasePromptCatalog.ai.attributionPrompt(
                question: question,
                answerText: answerText,
                sources: sources
            ),
        ]]
        parts.append(contentsOf: try attachmentParts(from: sources))
        return [["parts": parts]]
    }

    private static func attachmentParts(from sources: [AnswerEvidencePacket]) throws -> [GeminiJSONObject] {
        var parts: [GeminiJSONObject] = []
        var consumedPreviewBytes = 0

        for (offset, source) in sources.enumerated() {
            let sourceIndex = offset + 1
            for attachment in source.attachments {
                let fileURL = URL(fileURLWithPath: attachment.path)
                let mimeType = resolvedMimeType(for: attachment, fileURL: fileURL)

                if attachment.kind == .originalAsset, mimeType == "application/pdf" {
                    let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    guard data.count <= maxInlinePDFBytes else { continue }

                    parts.append([
                        "text": "Source \(sourceIndex) attached PDF document.",
                    ])
                    parts.append([
                        "inline_data": [
                            "mime_type": mimeType,
                            "data": data.base64EncodedString(),
                        ],
                    ])
                    continue
                }

                guard attachment.kind == .imagePreview || attachment.kind == .pagePreview else {
                    continue
                }

                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                guard data.count <= maxPreviewBytesPerAttachment else { continue }

                let nextConsumedBytes = consumedPreviewBytes + data.count
                guard nextConsumedBytes <= maxTotalPreviewBytes else { continue }

                parts.append([
                    "text": "Source \(sourceIndex) visual preview.",
                ])
                parts.append([
                    "inline_data": [
                        "mime_type": mimeType,
                        "data": data.base64EncodedString(),
                    ],
                ])
                consumedPreviewBytes = nextConsumedBytes
            }
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
