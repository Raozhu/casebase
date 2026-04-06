import Foundation

final class TextExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.text]
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        switch payload {
        case .text:
            return true
        case .file:
            return FileTypeResolver.resolve(payload).sourceKind == .text
        }
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        switch payload {
        case let .text(textPayload):
            let text = textPayload.text
            return NormalizedContent(
                sourceKind: .text,
                rawText: text,
                fallbackMetadata: inlineTextMetadata(for: text, payload: textPayload)
            )

        case let .file(filePayload):
            let resolution = FileTypeResolver.resolve(payload)
            guard resolution.sourceKind == .text else {
                throw CasebaseError.invalidPayload(
                    CasebasePromptCatalog.errors.payloadIsNotASupportedTextFile
                )
            }

            let readResult = try TextFileReader.readText(from: filePayload.fileURL)
            var metadata = FileMetadataReader.basicMetadata(
                for: filePayload.fileURL,
                mimeType: resolution.mimeType,
                utType: resolution.utType,
                fileManager: fileManager
            )
            metadata["characterCount"] = String(readResult.text.count)
            metadata["lineCount"] = String(lineCount(for: readResult.text))
            metadata["encoding"] = readResult.encodingName
            metadata.merge(filePayload.contextMetadata) { _, new in new }

            return NormalizedContent(
                sourceKind: .text,
                rawText: readResult.text,
                fallbackMetadata: metadata
            )
        }
    }

    private func inlineTextMetadata(
        for text: String,
        payload: TextImportPayload
    ) -> [String: String] {
        var metadata: [String: String] = [
            "fileName": payload.suggestedFileName ?? "Dragged Text",
            "characterCount": String(text.count),
            "lineCount": String(lineCount(for: text)),
            "encoding": "inline-text"
        ]
        if let mimeType = payload.mimeType {
            metadata["mimeType"] = mimeType
        }
        metadata.merge(payload.contextMetadata) { _, new in new }
        return metadata
    }

    private func lineCount(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.split(whereSeparator: \.isNewline).count
    }
}
