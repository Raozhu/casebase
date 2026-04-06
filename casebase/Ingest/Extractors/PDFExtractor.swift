import Foundation
import PDFKit

final class PDFExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.pdf]

    private let fileManager: FileManager
    private let previewRenderer: PDFPreviewRenderer
    private let minimumMeaningfulTextLength = 80

    init(
        fileManager: FileManager = .default,
        previewRenderer: PDFPreviewRenderer
    ) {
        self.fileManager = fileManager
        self.previewRenderer = previewRenderer
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        FileTypeResolver.resolve(payload).sourceKind == .pdf
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.pdfExtractionRequiresFileBackedPayload
            )
        }

        let resolution = FileTypeResolver.resolve(payload)
        guard resolution.sourceKind == .pdf else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.payloadIsNotASupportedPDFFile
            )
        }

        guard let document = PDFDocument(url: filePayload.fileURL) else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.unableToOpenPDF(filePayload.fileURL.lastPathComponent)
            )
        }

        let extractedText = extractText(from: document)
        let normalizedText = extractedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldRenderExtendedPreview = (normalizedText?.count ?? 0) < minimumMeaningfulTextLength
        let requestedPreviewCount = shouldRenderExtendedPreview ? min(3, document.pageCount) : min(1, document.pageCount)

        var attachments: [NormalizedAttachment] = [
            NormalizedAttachment(
                kind: .originalAsset,
                path: filePayload.fileURL.path,
                mimeType: resolution.mimeType ?? "application/pdf"
            )
        ]

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: resolution.mimeType ?? "application/pdf",
            utType: resolution.utType,
            fileManager: fileManager
        )
        metadata["pageCount"] = String(document.pageCount)
        metadata["extractedCharacterCount"] = String(normalizedText?.count ?? 0)
        metadata["isTextBased"] = String((normalizedText?.isEmpty == false))
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        do {
            let previewAttachments = try previewRenderer.renderPreviewAttachments(
                for: document,
                sourceURL: filePayload.fileURL,
                previewCount: requestedPreviewCount
            )
            attachments.append(contentsOf: previewAttachments)
            metadata["generatedPreviewCount"] = String(previewAttachments.count)
        } catch {
            metadata["generatedPreviewCount"] = "0"
            metadata["previewGenerationError"] = String(describing: error.localizedDescription)
        }

        return NormalizedContent(
            sourceKind: .pdf,
            rawText: normalizedText?.isEmpty == false ? extractedText : nil,
            attachments: attachments,
            fallbackMetadata: metadata
        )
    }

    private func extractText(from document: PDFDocument) -> String? {
        let pageStrings = (0..<document.pageCount).compactMap { pageIndex -> String? in
            document.page(at: pageIndex)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !pageStrings.isEmpty else { return nil }
        return pageStrings.joined(separator: "\n\n")
    }
}
