import Foundation

final class OpenAIAudioTranscriber: AudioTranscriber {
    private let configuration: AIServiceConfiguration
    private let session: URLSession

    init(configuration: AIServiceConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
            sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout
            CasebaseNetworkProxy.applyProxy(from: configuration.proxyURLString, to: sessionConfiguration)
            self.session = URLSession(configuration: sessionConfiguration)
        }
    }

    func transcribe(fileURL: URL, mimeType: String?) async throws -> AudioTranscription {
        let endpoint = configuration.baseURL.appendingPathComponent("audio/transcriptions", isDirectory: false)

        var builder = MultipartFormDataBuilder()
        builder.addField(named: "model", value: configuration.transcriptionModel)
        builder.addField(named: "response_format", value: "json")
        try builder.addFile(
            named: "file",
            fileURL: fileURL,
            mimeType: mimeType ?? "application/octet-stream"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
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
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw CasebaseError.emptyResponse
        }

        return AudioTranscription(text: text, language: decoded.language)
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
    let language: String?
}
