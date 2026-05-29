import AppKit
import Foundation
import ImageIO

final class ImageExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.image]

    private let fileManager: FileManager
    private let previewWriter: TemporaryPreviewWriter
    private let ocrService: ImageOCRService

    init(
        fileManager: FileManager = .default,
        previewWriter: TemporaryPreviewWriter,
        ocrService: ImageOCRService = ImageOCRService()
    ) {
        self.fileManager = fileManager
        self.previewWriter = previewWriter
        self.ocrService = ocrService
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        FileTypeResolver.resolve(payload).sourceKind == .image
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.imageExtractionRequiresFileBackedPayload
            )
        }

        let resolution = FileTypeResolver.resolve(payload)
        guard resolution.sourceKind == .image else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.payloadIsNotASupportedImageFile
            )
        }

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: resolution.mimeType,
            utType: resolution.utType,
            fileManager: fileManager
        )
        metadata["analysisInputMode"] = "direct-image"

        if let pixelSize = pixelSize(for: filePayload.fileURL) {
            metadata["pixelWidth"] = String(Int(pixelSize.width.rounded()))
            metadata["pixelHeight"] = String(Int(pixelSize.height.rounded()))
        }
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        let originalAttachment = NormalizedAttachment(
            kind: .originalAsset,
            path: filePayload.fileURL.path,
            mimeType: resolution.mimeType
        )

        let previewStartedAt = Date()
        CasebaseDebugLogger.log(
            "image extractor preview started file=\"\(filePayload.fileURL.lastPathComponent)\""
        )
        let preview = try previewWriter.writeCompressedImagePreview(
            from: filePayload.fileURL,
            prefix: filePayload.fileURL.deletingPathExtension().lastPathComponent
        )
        CasebaseDebugLogger.log(
            "image extractor preview finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: previewStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" previewBytes=\(preview.byteCount) previewSize=\(preview.pixelWidth)x\(preview.pixelHeight)"
        )
        metadata["aiPreviewMimeType"] = "image/jpeg"
        metadata["aiPreviewPixelWidth"] = String(preview.pixelWidth)
        metadata["aiPreviewPixelHeight"] = String(preview.pixelHeight)
        metadata["aiPreviewByteCount"] = String(preview.byteCount)
        let previewURL = preview.fileURL
        let ocrStartedAt = Date()
        CasebaseDebugLogger.log(
            "image extractor preview OCR started file=\"\(filePayload.fileURL.lastPathComponent)\""
        )
        let previewOCR = try? ocrService.recognizeText(from: previewURL)
        let normalizedOCR = previewOCR?.trimmingCharacters(in: .whitespacesAndNewlines)
        CasebaseDebugLogger.log(
            "image extractor preview OCR finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: ocrStartedAt)) file=\"\(filePayload.fileURL.lastPathComponent)\" ocrChars=\(normalizedOCR?.count ?? 0)"
        )
        metadata["localOCRCharacterCount"] = String(normalizedOCR?.count ?? 0)

        return NormalizedContent(
            sourceKind: .image,
            rawText: normalizedOCR?.isEmpty == false ? normalizedOCR : nil,
            attachments: [
                originalAttachment,
                NormalizedAttachment(
                    kind: .imagePreview,
                    path: previewURL.path,
                    mimeType: "image/jpeg"
                )
            ],
            fallbackMetadata: metadata
        )
    }

    private func pixelSize(for fileURL: URL) -> CGSize? {
        guard
            let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            if
                let data = try? Data(contentsOf: fileURL),
                let bitmapRepresentation = NSBitmapImageRep(data: data)
            {
                return CGSize(width: bitmapRepresentation.pixelsWide, height: bitmapRepresentation.pixelsHigh)
            }
            return nil
        }

        return CGSize(width: pixelWidth, height: pixelHeight)
    }
}
