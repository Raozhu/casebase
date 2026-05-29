import Foundation
import PDFKit

final class PDFExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.pdf]

    private let fileManager: FileManager
    private let previewRenderer: PDFPreviewRenderer
    private let ocrService: ImageOCRService
    private let minimumMeaningfulTextLength = 80
    private let richTextThreshold = 240
    private let aggressivePreviewFileSizeBytes: Int64 = 8_000_000
    private let moderatePreviewFileSizeBytes: Int64 = 16_000_000

    init(
        fileManager: FileManager = .default,
        previewRenderer: PDFPreviewRenderer,
        ocrService: ImageOCRService = ImageOCRService()
    ) {
        self.fileManager = fileManager
        self.previewRenderer = previewRenderer
        self.ocrService = ocrService
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
        var normalizedText = extractedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileSizeBytes = FileMetadataReader.fileSizeBytes(for: filePayload.fileURL, fileManager: fileManager) ?? 0
        let requestedPreviewCount = preferredPreviewCount(
            pageCount: document.pageCount,
            extractedCharacterCount: normalizedText?.count ?? 0,
            fileSizeBytes: fileSizeBytes
        )

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
        metadata["requestedPreviewCount"] = String(requestedPreviewCount)
        metadata["extractedCharacterCount"] = String(normalizedText?.count ?? 0)
        metadata["isTextBased"] = String((normalizedText?.isEmpty == false))
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        let previewStartedAt = Date()
        CasebaseDebugLogger.log(
            "pdf extractor preview started file=\"\(filePayload.fileURL.lastPathComponent)\" pageCount=\(document.pageCount) requestedPreviewCount=\(requestedPreviewCount)"
        )
        do {
            let previewAttachments = try previewRenderer.renderPreviewAttachments(
                for: document,
                sourceURL: filePayload.fileURL,
                previewCount: requestedPreviewCount
            )
            attachments.append(contentsOf: previewAttachments)
            metadata["generatedPreviewCount"] = String(previewAttachments.count)
            CasebaseDebugLogger.log(
                "pdf extractor preview finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: previewStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" generatedPreviewCount=\(previewAttachments.count)"
            )
        } catch {
            metadata["generatedPreviewCount"] = "0"
            metadata["previewGenerationError"] = String(describing: error.localizedDescription)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            CasebaseDebugLogger.log(
                "pdf extractor preview failed elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: previewStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" error=\(message)"
            )
        }

        if (normalizedText?.count ?? 0) < minimumMeaningfulTextLength {
            let ocrStartedAt = Date()
            CasebaseDebugLogger.log(
                "pdf extractor preview OCR started file=\"\(filePayload.fileURL.lastPathComponent)\" previewCount=\(attachments.filter { $0.kind == .pagePreview }.count)"
            )
            let ocrText = attachments
                .filter { $0.kind == .pagePreview }
                .compactMap { attachment in
                    try? ocrService.recognizeText(from: URL(fileURLWithPath: attachment.path))
                }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            CasebaseDebugLogger.log(
                "pdf extractor preview OCR finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: ocrStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" ocrChars=\(ocrText.count)"
            )
            metadata["previewOCRCharacterCount"] = String(ocrText.count)
            if !ocrText.isEmpty {
                if let currentText = normalizedText, !currentText.isEmpty {
                    if !currentText.localizedCaseInsensitiveContains(ocrText) {
                        normalizedText = currentText + "\n\n" + ocrText
                    }
                } else {
                    normalizedText = ocrText
                }
            }
        }

        return NormalizedContent(
            sourceKind: .pdf,
            rawText: normalizedText?.isEmpty == false ? normalizedText : nil,
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

    private func preferredPreviewCount(
        pageCount: Int,
        extractedCharacterCount: Int,
        fileSizeBytes: Int64
    ) -> Int {
        guard pageCount > 0 else { return 0 }

        if extractedCharacterCount >= richTextThreshold {
            return min(2, pageCount)
        }

        if extractedCharacterCount >= minimumMeaningfulTextLength {
            return min(4, pageCount)
        }

        if fileSizeBytes > 0, fileSizeBytes <= aggressivePreviewFileSizeBytes {
            return min(10, pageCount)
        }

        if fileSizeBytes > 0, fileSizeBytes <= moderatePreviewFileSizeBytes {
            return min(6, pageCount)
        }

        return min(4, pageCount)
    }
}
