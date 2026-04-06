import Foundation

final class FallbackExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.binary]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        if case .file = payload {
            return true
        }
        return false
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.fallbackExtractionOnlyAcceptsFileBackedPayloads
            )
        }

        let resolution = FileTypeResolver.resolve(payload)
        let attachment = NormalizedAttachment(
            kind: .originalAsset,
            path: filePayload.fileURL.path,
            mimeType: resolution.mimeType
        )

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: resolution.mimeType,
            utType: resolution.utType,
            fileManager: fileManager
        )
        metadata.merge(filePayload.contextMetadata) { _, new in new }

        return NormalizedContent(
            sourceKind: .binary,
            rawText: nil,
            attachments: [attachment],
            fallbackMetadata: metadata
        )
    }
}
