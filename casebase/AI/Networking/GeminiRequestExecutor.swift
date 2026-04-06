import Foundation

typealias GeminiJSONObject = [String: Any]

enum GeminiTransportError: Error {
    case invalidRequestBody
    case invalidResponse
    case transport(Error)
    case server(statusCode: Int, message: String, retryable: Bool)
    case decodingFailed(String)
}

actor GeminiRequestExecutor {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let requestTimeout: TimeInterval
    private let maxAttempts = 3

    init(
        baseURL: URL,
        apiKey: String,
        requestTimeout: TimeInterval,
        session: URLSession? = nil
    ) {
        self.baseURL = GeminiRequestExecutor.normalizedBaseURL(baseURL)
        self.apiKey = apiKey
        self.requestTimeout = requestTimeout

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = requestTimeout
            configuration.timeoutIntervalForResource = requestTimeout
            self.session = URLSession(configuration: configuration)
        }
    }

    func postJSON<Response: Decodable>(
        path: String,
        body: GeminiJSONObject,
        decode responseType: Response.Type
    ) async throws -> Response {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw GeminiTransportError.invalidRequestBody
        }

        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        let requestURL = baseURL.appending(path: path)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = payload

        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiTransportError.invalidResponse
                }

                if (200 ..< 300).contains(httpResponse.statusCode) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .useDefaultKeys
                    do {
                        return try decoder.decode(responseType, from: data)
                    } catch {
                        throw GeminiTransportError.decodingFailed(Self.decodePreview(from: data))
                    }
                }

                let message = Self.extractServerMessage(from: data)
                let retryable = httpResponse.statusCode == 429 || (500 ... 599).contains(httpResponse.statusCode)
                let error = GeminiTransportError.server(
                    statusCode: httpResponse.statusCode,
                    message: message,
                    retryable: retryable
                )

                if retryable, attempt < maxAttempts {
                    try await Self.sleepBeforeRetry(attempt: attempt)
                    lastError = error
                    continue
                }

                throw error
            } catch {
                if Self.isRetryableTransportError(error), attempt < maxAttempts {
                    try await Self.sleepBeforeRetry(attempt: attempt)
                    lastError = error
                    continue
                }

                if let transportError = error as? GeminiTransportError {
                    throw transportError
                }
                throw GeminiTransportError.transport(error)
            }
        }

        throw lastError ?? GeminiTransportError.invalidResponse
    }

    private static func normalizedBaseURL(_ url: URL) -> URL {
        let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed) ?? url
    }

    private static func sleepBeforeRetry(attempt: Int) async throws {
        let delay = UInt64(Double(250_000_000) * pow(2.0, Double(max(0, attempt - 1))))
        try await Task.sleep(nanoseconds: delay)
    }

    private static func isRetryableTransportError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .resourceUnavailable:
                return true
            default:
                return false
            }
        }
        if let transportError = error as? GeminiTransportError,
           case let .server(_, _, retryable) = transportError
        {
            return retryable
        }
        return false
    }

    private static func extractServerMessage(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data) {
            return envelope.error.message
        }
        return decodePreview(from: data)
    }

    private static func decodePreview(from data: Data) -> String {
        String(decoding: data.prefix(512), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GeminiErrorEnvelope: Decodable {
    let error: GeminiErrorPayload
}

private struct GeminiErrorPayload: Decodable {
    let code: Int?
    let message: String
    let status: String?
}
