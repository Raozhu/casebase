import Foundation

final class OMLXAudioTranscriber: AudioTranscriber {
    private let endpoint: URL
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(
        endpoint: URL? = nil,
        apiKey: String? = nil,
        model: String = "VibeVoice-ASR-4bit",
        settingsFileURL: URL? = nil,
        fileManager: FileManager = .default,
        session: URLSession? = nil,
        timeout: TimeInterval = 1_800
    ) throws {
        let settings = try Settings.load(from: settingsFileURL, fileManager: fileManager)
        self.endpoint = endpoint ?? settings.baseURL.appendingPathComponent("v1/audio/transcriptions", isDirectory: false)
        self.apiKey = apiKey ?? settings.apiKey
        self.model = model

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: configuration)
        }
    }

    func transcribe(fileURL: URL, mimeType: String?) async throws -> AudioTranscription {
        var builder = MultipartFormDataBuilder()
        builder.addField(named: "model", value: model)
        builder.addField(named: "response_format", value: "json")
        try builder.addFile(
            named: "file",
            fileURL: fileURL,
            mimeType: mimeType ?? "application/octet-stream"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(builder.contentTypeHeader, forHTTPHeaderField: "Content-Type")
        request.httpBody = builder.build()

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let responseText = String(data: data, encoding: .utf8) ?? "Unknown transcription error."
            throw CasebaseError.normalizationFailed(
                CasebasePromptCatalog.errors.audioTranscriptionRequestFailed(responseText)
            )
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        let resolvedSegments: [AudioTranscriptionSegment] = decoded.segments?.compactMap { segment in
            let trimmedText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return nil
            }
            return AudioTranscriptionSegment(
                start: segment.start,
                end: segment.end,
                speakerID: segment.speakerID,
                text: trimmedText
            )
        } ?? []

        let derivedText = Self.resolveTranscriptText(
            rawText: decoded.text,
            segments: resolvedSegments
        )
        let trimmedText = derivedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw CasebaseError.emptyResponse
        }

        return AudioTranscription(
            text: trimmedText,
            language: decoded.language,
            segments: resolvedSegments
        )
    }

    private static func resolveTranscriptText(
        rawText: String,
        segments: [AudioTranscriptionSegment]
    ) -> String {
        if !segments.isEmpty {
            return segments
                .map(\.text)
                .joined(separator: "\n")
        }

        let trimmedRawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRawText.hasPrefix("[") else {
            return trimmedRawText
        }

        guard
            let data = trimmedRawText.data(using: .utf8),
            let parsed = try? JSONDecoder().decode([LegacySegment].self, from: data)
        else {
            return trimmedRawText
        }

        let lines = parsed
            .map(\.content)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? trimmedRawText : lines.joined(separator: "\n")
    }
}

private extension OMLXAudioTranscriber {
    struct Settings {
        let baseURL: URL
        let apiKey: String

        static func load(from overrideURL: URL?, fileManager: FileManager) throws -> Settings {
            let fileURL: URL
            if let overrideURL {
                fileURL = overrideURL
            } else {
                fileURL = fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent(".omlx", isDirectory: true)
                    .appendingPathComponent("settings.json", isDirectory: false)
            }

            guard let data = try? Data(contentsOf: fileURL) else {
                throw CasebaseError.missingConfiguration(fileURL.path)
            }

            let decoded = try JSONDecoder().decode(SettingsFile.self, from: data)
            guard
                let baseURL = URL(
                    string: "http://\(decoded.server.host):\(decoded.server.port)"
                )
            else {
                throw CasebaseError.missingConfiguration("oMLX server URL")
            }
            guard !decoded.auth.apiKey.isEmpty else {
                throw CasebaseError.missingConfiguration("oMLX API key")
            }

            return Settings(
                baseURL: baseURL,
                apiKey: decoded.auth.apiKey
            )
        }
    }

    struct SettingsFile: Decodable {
        let server: Server
        let auth: Auth

        struct Server: Decodable {
            let host: String
            let port: Int
        }

        struct Auth: Decodable {
            let apiKey: String

            private enum CodingKeys: String, CodingKey {
                case apiKey = "api_key"
            }
        }
    }

    struct TranscriptionResponse: Decodable {
        let text: String
        let language: String?
        let segments: [ResponseSegment]?
    }

    struct ResponseSegment: Decodable {
        let start: Double?
        let end: Double?
        let speakerID: Int?
        let text: String

        private enum CodingKeys: String, CodingKey {
            case start
            case end
            case speakerID = "speaker_id"
            case text
        }
    }

    struct LegacySegment: Decodable {
        let content: String

        private enum CodingKeys: String, CodingKey {
            case content = "Content"
        }
    }
}
