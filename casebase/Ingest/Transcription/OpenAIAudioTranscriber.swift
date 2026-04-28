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

private struct MultipartFormDataBuilder {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var data = Data()

    var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(named name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(named name: String, fileURL: URL, mimeType: String) throws {
        let fileData = try Data(contentsOf: fileURL)
        append("--\(boundary)\r\n")
        append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
        )
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    func build() -> Data {
        var finalData = data
        finalData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalData
    }

    private mutating func append(_ string: String) {
        data.append(string.data(using: .utf8)!)
    }
}
