import AppKit
import Foundation
import PDFKit

final class PDFPreviewRenderer {
    private let previewWriter: TemporaryPreviewWriter

    init(previewWriter: TemporaryPreviewWriter) {
        self.previewWriter = previewWriter
    }

    func renderPreviewAttachments(
        for document: PDFDocument,
        sourceURL: URL,
        previewCount: Int
    ) throws -> [NormalizedAttachment] {
        guard previewCount > 0 else { return [] }

        var attachments: [NormalizedAttachment] = []
        let maxPageCount = min(previewCount, document.pageCount)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        for pageIndex in 0..<maxPageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let previewImage = page.thumbnail(of: CGSize(width: 1200, height: 1600), for: .mediaBox)
            let previewURL = try previewWriter.writePNG(
                image: previewImage,
                prefix: "\(baseName)-page-\(pageIndex + 1)"
            )
            attachments.append(
                NormalizedAttachment(
                    kind: .pagePreview,
                    path: previewURL.path,
                    mimeType: "image/png"
                )
            )
        }

        return attachments
    }
}
