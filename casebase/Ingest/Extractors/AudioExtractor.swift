import AVFoundation
import Foundation

final class AudioExtractor: Extractor {
    let supportedSourceKinds: Set<ImportSourceKind> = [.audio]

    private let fileManager: FileManager
    private let transcriber: AudioTranscriber

    init(
        configuration: CasebaseConfiguration,
        fileManager: FileManager = .default,
        transcriber: AudioTranscriber? = nil,
        session: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.transcriber = transcriber ?? OpenAIAudioTranscriber(
            configuration: configuration.ai,
            session: session
        )
    }

    func canExtract(_ payload: ImportPayload) -> Bool {
        FileTypeResolver.resolve(payload).sourceKind == .audio
    }

    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent {
        guard case let .file(filePayload) = payload else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.audioExtractionRequiresFileBackedPayload
            )
        }

        let resolution = FileTypeResolver.resolve(payload)
        guard resolution.sourceKind == .audio else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.payloadIsNotASupportedAudioFile
            )
        }

        var metadata = FileMetadataReader.basicMetadata(
            for: filePayload.fileURL,
            mimeType: resolution.mimeType,
            utType: resolution.utType,
            fileManager: fileManager
        )
        metadata.merge(filePayload.contextMetadata) { _, new in new }
        if let durationSeconds = await durationSeconds(for: filePayload.fileURL) {
            metadata["durationSeconds"] = format(seconds: durationSeconds)
        }

        let attachment = NormalizedAttachment(
            kind: .audioSource,
            path: filePayload.fileURL.path,
            mimeType: resolution.mimeType
        )

        do {
            let transcription = try await transcriber.transcribe(
                fileURL: filePayload.fileURL,
                mimeType: resolution.mimeType
            )
            let normalizedTranscript = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata["transcriptionSucceeded"] = String(!normalizedTranscript.isEmpty)
            if let language = transcription.language, !language.isEmpty {
                metadata["transcriptionLanguage"] = language
            }

            return NormalizedContent(
                sourceKind: .audio,
                rawText: normalizedTranscript.isEmpty ? nil : normalizedTranscript,
                attachments: [attachment],
                fallbackMetadata: metadata
            )
        } catch {
            metadata["transcriptionSucceeded"] = "false"
            metadata["transcriptionError"] = String(describing: error.localizedDescription)
            return NormalizedContent(
                sourceKind: .audio,
                rawText: nil,
                attachments: [attachment],
                fallbackMetadata: metadata
            )
        }
    }

    private func durationSeconds(for fileURL: URL) async -> Double? {
        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds
            guard seconds.isFinite, seconds > 0 else { return nil }
            return seconds
        } catch {
            return nil
        }
    }

    private func format(seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}
