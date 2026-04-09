import AppKit
import Foundation
import QuickLookThumbnailing

final class QuickLookPreviewRenderer {
    private let previewWriter: TemporaryPreviewWriter

    init(previewWriter: TemporaryPreviewWriter) {
        self.previewWriter = previewWriter
    }

    func renderPreviewAttachment(
        for sourceURL: URL,
        prefix: String,
        size: CGSize = CGSize(width: 1600, height: 1600)
    ) async -> NormalizedAttachment? {
        let request = QLThumbnailGenerator.Request(
            fileAt: sourceURL,
            size: size,
            scale: 2,
            representationTypes: .all
        )

        do {
            let representation = try await bestRepresentation(for: request)
            let previewURL = try previewWriter.writePNG(
                image: representation.nsImage,
                prefix: prefix
            )
            return NormalizedAttachment(
                kind: .pagePreview,
                path: previewURL.path,
                mimeType: "image/png"
            )
        } catch {
            return nil
        }
    }

    private func bestRepresentation(
        for request: QLThumbnailGenerator.Request
    ) async throws -> QLThumbnailRepresentation {
        try await withCheckedThrowingContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                if let thumbnail {
                    continuation.resume(returning: thumbnail)
                    return
                }

                continuation.resume(
                    throwing: error ?? CasebaseError.normalizationFailed(
                        CasebasePromptCatalog.errors.failedToGenerateDocumentPreview
                    )
                )
            }
        }
    }
}
