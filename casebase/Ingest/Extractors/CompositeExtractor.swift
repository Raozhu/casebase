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
        return try await extractor.normalize(payload)
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
}
