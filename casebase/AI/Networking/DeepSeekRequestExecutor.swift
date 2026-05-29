import Foundation

typealias DeepSeekJSONObject = [String: Any]

enum DeepSeekTransportError: Error {
    case invalidRequestBody
    case invalidResponse
    case transport(Error)
    case server(statusCode: Int, message: String, retryable: Bool)
    case decodingFailed(String)
}

actor DeepSeekRequestExecutor {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let requestTimeout: TimeInterval
    private let proxySummary: String
    private let maxAttempts = 3

    init(
        baseURL: URL,
        apiKey: String,
        requestTimeout: TimeInterval,
        proxyURLString: String? = nil,
        session: URLSession? = nil
    ) {
        self.baseURL = Self.normalizedBaseURL(baseURL)
        self.apiKey = apiKey
        self.requestTimeout = requestTimeout
        proxySummary = Self.proxySummary(from: proxyURLString)

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = requestTimeout
            configuration.timeoutIntervalForResource = requestTimeout
            CasebaseNetworkProxy.applyProxy(from: proxyURLString, to: configuration)
            self.session = URLSession(configuration: configuration)
        }
    }

    func postJSON<Response: Decodable>(
        path: String,
        body: DeepSeekJSONObject,
        decode responseType: Response.Type
    ) async throws -> Response {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw DeepSeekTransportError.invalidRequestBody
        }

        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        let requestURL = Self.requestURL(for: path, relativeTo: baseURL)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload

        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DeepSeekTransportError.invalidResponse
                }

                if (200 ..< 300).contains(httpResponse.statusCode) {
                    do {
                        return try JSONDecoder().decode(responseType, from: data)
                    } catch {
                        throw DeepSeekTransportError.decodingFailed(Self.decodePreview(from: data))
                    }
                }

                let message = Self.extractServerMessage(from: data)
                let retryable = httpResponse.statusCode == 429 || (500 ... 599).contains(httpResponse.statusCode)
                let error = DeepSeekTransportError.server(
                    statusCode: httpResponse.statusCode,
                    message: message,
                    retryable: retryable
                )

                if retryable, attempt < maxAttempts {
                    try await Self.sleepBeforeRetry(attempt: attempt)
                    lastError = error
                    continue
                }

                logFailure(
                    path: path,
                    message: "status=\(httpResponse.statusCode) retryable=\(retryable) message=\(message)"
                )
                throw error
            } catch {
                if Self.isRetryableTransportError(error), attempt < maxAttempts {
                    try await Self.sleepBeforeRetry(attempt: attempt)
                    lastError = error
                    continue
                }

                if let transportError = error as? DeepSeekTransportError {
                    logFailure(path: path, message: "transport=\(String(describing: transportError)) attempt=\(attempt)")
                    throw transportError
                }
                logFailure(path: path, message: "transport=\(String(describing: error)) attempt=\(attempt)")
                throw DeepSeekTransportError.transport(error)
            }
        }

        if let lastError {
            logFailure(path: path, message: "exhausted_retries error=\(String(describing: lastError))")
        }
        throw lastError ?? DeepSeekTransportError.invalidResponse
    }

    func streamJSON<Response: Decodable>(
        path: String,
        body: DeepSeekJSONObject,
        decode responseType: Response.Type,
        onEvent: @Sendable @escaping (Response) async throws -> Void
    ) async throws {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw DeepSeekTransportError.invalidRequestBody
        }

        let payload = try JSONSerialization.data(withJSONObject: body, options: [])
        let requestURL = Self.requestURL(for: path, relativeTo: baseURL)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload

        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let (bytes, response) = try await session.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DeepSeekTransportError.invalidResponse
                }

                guard (200 ..< 300).contains(httpResponse.statusCode) else {
                    let collected = try await Self.collectData(from: bytes)
                    let message = Self.extractServerMessage(from: collected)
                    let retryable = httpResponse.statusCode == 429 || (500 ... 599).contains(httpResponse.statusCode)
                    let error = DeepSeekTransportError.server(
                        statusCode: httpResponse.statusCode,
                        message: message,
                        retryable: retryable
                    )

                    if retryable, attempt < maxAttempts {
                        try await Self.sleepBeforeRetry(attempt: attempt)
                        lastError = error
                        continue
                    }

                    logFailure(path: path, message: "status=\(httpResponse.statusCode) retryable=\(retryable) message=\(message)")
                    throw error
                }

                let decoder = JSONDecoder()
                var eventDataLines: [String] = []
                var trailingJSONLines: [String] = []
                var currentLine = Data()

                for try await byte in bytes {
                    if byte == 0x0A {
                        try await Self.processSSELine(
                            from: currentLine,
                            eventDataLines: &eventDataLines,
                            trailingJSONLines: &trailingJSONLines,
                            decoder: decoder,
                            responseType: responseType,
                            onEvent: onEvent
                        )
                        currentLine.removeAll(keepingCapacity: true)
                    } else {
                        currentLine.append(byte)
                    }
                }

                if !currentLine.isEmpty {
                    try await Self.processSSELine(
                        from: currentLine,
                        eventDataLines: &eventDataLines,
                        trailingJSONLines: &trailingJSONLines,
                        decoder: decoder,
                        responseType: responseType,
                        onEvent: onEvent
                    )
                }

                if !eventDataLines.isEmpty {
                    try await Self.emitSSEEvent(
                        from: eventDataLines,
                        decoder: decoder,
                        responseType: responseType,
                        onEvent: onEvent
                    )
                }

                try Self.throwIfTrailingServerError(lines: trailingJSONLines)
                return
            } catch {
                if Self.isRetryableTransportError(error), attempt < maxAttempts {
                    try await Self.sleepBeforeRetry(attempt: attempt)
                    lastError = error
                    continue
                }

                if let transportError = error as? DeepSeekTransportError {
                    logFailure(path: path, message: "transport=\(String(describing: transportError)) attempt=\(attempt)")
                    throw transportError
                }
                logFailure(path: path, message: "transport=\(String(describing: error)) attempt=\(attempt)")
                throw DeepSeekTransportError.transport(error)
            }
        }

        if let lastError {
            logFailure(path: path, message: "exhausted_retries error=\(String(describing: lastError))")
        }
        throw lastError ?? DeepSeekTransportError.invalidResponse
    }

    private static func normalizedBaseURL(_ url: URL) -> URL {
        if url.host?.localizedCaseInsensitiveContains("deepseek") != true {
            return URL(string: "https://api.deepseek.com")!
        }
        let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed) ?? url
    }

    private static func proxySummary(from proxyURLString: String?) -> String {
        guard
            let proxyURLString,
            let proxyURL = URL(string: proxyURLString),
            let host = proxyURL.host
        else {
            return "none"
        }

        let scheme = proxyURL.scheme?.lowercased() ?? "unknown"
        let port = proxyURL.port.map(String.init) ?? "-"
        return "\(scheme)://\(host):\(port)"
    }

    private static func requestURL(for path: String, relativeTo baseURL: URL) -> URL {
        let base = baseURL.absoluteString.hasSuffix("/") ? baseURL.absoluteString : baseURL.absoluteString + "/"
        return URL(string: base + path) ?? baseURL.appending(path: path)
    }

    private func logFailure(path: String, message: String) {
        let host = baseURL.host ?? "unknown"
        CasebaseDebugLogger.log("DeepSeek request failed host=\(host) proxy=\(proxySummary) path=\(path) \(message)")
    }

    private static func emitSSEEvent<Response: Decodable>(
        from lines: [String],
        decoder: JSONDecoder,
        responseType: Response.Type,
        onEvent: @Sendable (Response) async throws -> Void
    ) async throws {
        guard !lines.isEmpty else { return }
        let payload = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty, payload != "[DONE]" else { return }
        guard let data = payload.data(using: .utf8) else {
            throw DeepSeekTransportError.decodingFailed(payload)
        }

        do {
            let response = try decoder.decode(responseType, from: data)
            try await onEvent(response)
        } catch {
            throw DeepSeekTransportError.decodingFailed(payload)
        }
    }

    private static func processSSELine<Response: Decodable>(
        from rawLine: Data,
        eventDataLines: inout [String],
        trailingJSONLines: inout [String],
        decoder: JSONDecoder,
        responseType: Response.Type,
        onEvent: @Sendable (Response) async throws -> Void
    ) async throws {
        let lineData = rawLine.last == 0x0D ? rawLine.dropLast() : rawLine
        guard let line = String(data: lineData, encoding: .utf8) else {
            throw DeepSeekTransportError.decodingFailed(String(decoding: lineData, as: UTF8.self))
        }

        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await emitSSEEvent(
                from: eventDataLines,
                decoder: decoder,
                responseType: responseType,
                onEvent: onEvent
            )
            eventDataLines.removeAll(keepingCapacity: true)
            return
        }

        if line.hasPrefix("data:") {
            let value = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            eventDataLines.append(String(value))
            return
        }

        if line.hasPrefix(":") || line.hasPrefix("event:") || line.hasPrefix("id:") || line.hasPrefix("retry:") {
            return
        }

        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.hasPrefix("\"") {
            trailingJSONLines.append(trimmed)
        }
    }

    private static func throwIfTrailingServerError(lines: [String]) throws {
        guard !lines.isEmpty else { return }
        let payload = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty, let data = payload.data(using: .utf8) else { return }
        if let envelope = try? JSONDecoder().decode(DeepSeekErrorEnvelope.self, from: data) {
            throw DeepSeekTransportError.server(
                statusCode: -1,
                message: envelope.error.message,
                retryable: true
            )
        }
        throw DeepSeekTransportError.decodingFailed(payload)
    }

    private static func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
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
        if let transportError = error as? DeepSeekTransportError,
           case let .server(_, _, retryable) = transportError {
            return retryable
        }
        return false
    }

    private static func extractServerMessage(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(DeepSeekErrorEnvelope.self, from: data) {
            return envelope.error.message
        }
        return decodePreview(from: data)
    }

    private static func decodePreview(from data: Data) -> String {
        String(decoding: data.prefix(512), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DeepSeekErrorEnvelope: Decodable {
    let error: DeepSeekErrorPayload
}

private struct DeepSeekErrorPayload: Decodable {
    let message: String
    let type: String?
    let code: String?
}
