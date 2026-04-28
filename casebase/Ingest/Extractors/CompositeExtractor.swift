import Foundation

final class CompositeExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [
        .image,
        .text,
        .pdf,
        .audio,
        .binary
    ]

    private let textExtractor: TextExtractor
    private let imageExtractor: ImageExtractor
    private let pdfExtractor: PDFExtractor
    private let audioExtractor: AudioExtractor
    private let officeExtractor: OfficeExtractor
    private let fallbackExtractor: FallbackExtractor

    init(
        configuration: CasebaseConfiguration,
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        transcriber: AudioTranscriber? = nil
    ) {
        let previewWriter = TemporaryPreviewWriter(fileManager: fileManager)
        let quickLookPreviewRenderer = QuickLookPreviewRenderer(previewWriter: previewWriter)
        textExtractor = TextExtractor(fileManager: fileManager)
        imageExtractor = ImageExtractor(
            fileManager: fileManager,
            previewWriter: previewWriter
        )
        pdfExtractor = PDFExtractor(
            fileManager: fileManager,
            previewRenderer: PDFPreviewRenderer(previewWriter: previewWriter)
        )
        audioExtractor = AudioExtractor(
            configuration: configuration,
            fileManager: fileManager,
            transcriber: transcriber,
            session: session
        )
        officeExtractor = OfficeExtractor(
            fileManager: fileManager,
            previewRenderer: quickLookPreviewRenderer
        )
        fallbackExtractor = FallbackExtractor(fileManager: fileManager)
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        switch payload {
        case .text:
            return textExtractor.canExtract(payload)
        case .file:
            return true
        }
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        let extractor = extractorForPayload(payload)
        let startedAt = Date()
        let extractorName = String(describing: type(of: extractor))
        let payloadSummary = payloadSummary(payload)
        CasebaseDebugLogger.log(
            "extractor dispatch started extractor=\(extractorName) \(payloadSummary)"
        )

        do {
            let normalizedContent = try await extractor.normalize(payload)
            CasebaseDebugLogger.log(
                "extractor dispatch finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: startedAt)) extractor=\(extractorName) \(payloadSummary) attachments=\(normalizedContent.attachments.count) rawTextChars=\(normalizedContent.rawText?.count ?? 0)"
            )
            return normalizedContent
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            CasebaseDebugLogger.log(
                "extractor dispatch failed elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: startedAt)) extractor=\(extractorName) \(payloadSummary) error=\(message)"
            )
            throw error
        }
    }

    private func extractorForPayload(_ payload: ImportPayload) -> Extractor {
        if officeExtractor.canExtract(payload) {
            return officeExtractor
        }

        let resolution = FileTypeResolver.resolve(payload)

        switch resolution.sourceKind {
        case .text:
            return textExtractor
        case .image:
            return imageExtractor
        case .pdf:
            return pdfExtractor
        case .audio:
            return audioExtractor
        case .binary, .none:
            return fallbackExtractor
        }
    }

    private func payloadSummary(_ payload: ImportPayload) -> String {
        switch payload {
        case let .text(textPayload):
            return "file=\"\(payload.displayName)\" sourceKind=text textChars=\(textPayload.text.count)"
        case let .file(filePayload):
            let fileSize = FileMetadataReader.fileSizeBytes(for: filePayload.fileURL) ?? 0
            return "file=\"\(payload.displayName)\" sourceKind=\(payload.sourceKindHint?.rawValue ?? "unknown") path=\"\(filePayload.fileURL.lastPathComponent)\" bytes=\(fileSize)"
        }
    }
}
