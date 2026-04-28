import Foundation

private struct GeminiGenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent?
    let finishReason: String?
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]?
}

private struct GeminiResponsePart: Decodable {
    let text: String?
    let thought: Bool?
}

private struct GeminiEmbedContentResponse: Decodable {
    let embedding: GeminiEmbedding?
}

private struct GeminiEmbedding: Decodable {
    let values: [Float]
}

private struct GeminiAnalysisPayload: Decodable {
    let contentType: String
    let scene: String
    let purpose: String
    let title: String
    let shortSummary: String
    let tags: [String]
    let usefulSnippets: [String]
    let structuredData: [String: StructuredFieldValue]
    let searchText: String
    let needsReview: Bool
    let clarification: GeminiClarificationPayload
}

private struct GeminiClarificationPayload: Decodable {
    let uncertaintySummary: String
    let impactExplanation: String
    let questions: [GeminiClarificationQuestionPayload]
}

private struct GeminiClarificationQuestionPayload: Decodable {
    let title: String
    let reason: String
    let suggestedOptions: [String]
}

private struct GeminiAttributionCitationPayload: Decodable {
    let index: Int
    let supportNote: String
}

private struct GeminiAttributionPayload: Decodable {
    let citations: [GeminiAttributionCitationPayload]
    let usedModelSupplement: Bool
}

final class GeminiAIClient: AIClient, GeminiEmbeddingModeProviding {
    private let executor: GeminiRequestExecutor
    private let analysisModels: [String]
    private let answerModel: String
    private let embeddingModel: String
    private let attributionResolver = AnswerAttributionResolver()

    init(
        configuration: CasebaseConfiguration,
        session: URLSession? = nil
    ) {
        let resolvedBaseURL = GeminiRuntimeDefaults.resolvedBaseURL(from: configuration.ai.baseURL)
        executor = GeminiRequestExecutor(
            baseURL: resolvedBaseURL,
            apiKey: configuration.ai.apiKey,
            requestTimeout: configuration.ai.requestTimeout,
            proxyURLString: configuration.ai.proxyURLString,
            session: session
        )
        analysisModels = GeminiRuntimeDefaults.resolvedAnalysisModels(from: configuration.ai.analysisModel)
        answerModel = GeminiRuntimeDefaults.resolvedAnswerModel(from: configuration.ai.answerModel)
        embeddingModel = GeminiRuntimeDefaults.resolvedEmbeddingModel(from: configuration.ai.embeddingModel)
    }

    func analyze(content: NormalizedContent, thoughtHandler: AIThoughtHandler?) async throws -> AnalysisResult {
        do {
            let contents = try GeminiContentEncoder.encodeAnalysisContents(content)
            let analysisURLs = GeminiContentEncoder.extractAnalysisURLs(from: content)
            let initial = try await analyzeOnce(
                contents: contents,
                urlContextURLs: analysisURLs,
                thoughtHandler: thoughtHandler,
                requiresExplicitClarificationQuestions: false
            )

            if Self.requiresClarificationRepair(initial.payload) {
                let repaired = try await analyzeOnce(
                    contents: contents,
                    urlContextURLs: analysisURLs,
                    thoughtHandler: thoughtHandler,
                    requiresExplicitClarificationQuestions: true
                )
                return try validate(payload: repaired.payload, thoughtSummary: repaired.thoughtSummary)
            }

            return try validate(payload: initial.payload, thoughtSummary: initial.thoughtSummary)
        } catch let error as CasebaseError {
            throw error
        } catch let error as GeminiTransportError {
            throw CasebaseError.analysisFailed(Self.describeTransportError(error))
        } catch {
            throw CasebaseError.analysisFailed(error.localizedDescription)
        }
    }

    func embed(text: String) async throws -> [Float] {
        try await embedDocument(text, title: nil)
    }

    func embedQuery(_ text: String) async throws -> [Float] {
        try await embed(text: text, taskType: "RETRIEVAL_QUERY", title: nil)
    }

    func answer(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw CasebaseError.emptyQuery
        }

        guard !sources.isEmpty else {
            return AnswerResult(
                answerText: CasebasePromptCatalog.ui.answerNoEvidenceMessage,
                citedRecordIDs: [],
                citations: [],
                usedModelSupplement: false
            )
        }

        do {
            return try await answer(
                question: trimmedQuestion,
                sources: sources,
                policy: policy,
                model: answerModel,
                streamHandler: streamHandler,
                thoughtHandler: thoughtHandler
            )
        } catch let error as GeminiTransportError {
            throw CasebaseError.answerFailed(Self.describeTransportError(error))
        } catch let error as CasebaseError {
            throw error
        } catch {
            throw CasebaseError.answerFailed(error.localizedDescription)
        }
    }

    private func embedDocument(_ text: String, title: String?) async throws -> [Float] {
        try await embed(text: text, taskType: "RETRIEVAL_DOCUMENT", title: title)
    }

    private func embed(text: String, taskType: String, title: String?) async throws -> [Float] {
        let preparedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preparedText.isEmpty else {
            throw CasebaseError.answerFailed(CasebasePromptCatalog.errors.cannotEmbedEmptyText)
        }

        let truncated = String(preparedText.prefix(8_000))
        var body: GeminiJSONObject = [
            "model": "models/\(embeddingModel)",
            "content": [
                "parts": [
                    [
                        "text": truncated,
                    ],
                ],
            ],
            "taskType": taskType,
        ]

        if let title, !title.isEmpty, taskType == "RETRIEVAL_DOCUMENT" {
            body["title"] = title
        }

        do {
            let response: GeminiEmbedContentResponse = try await executor.postJSON(
                path: "models/\(embeddingModel):embedContent",
                body: body,
                decode: GeminiEmbedContentResponse.self
            )
            guard let values = response.embedding?.values, !values.isEmpty else {
                throw CasebaseError.emptyResponse
            }
            return values
        } catch let error as CasebaseError {
            throw CasebaseError.answerFailed(error.localizedDescription)
        } catch let error as GeminiTransportError {
            throw CasebaseError.answerFailed(Self.describeTransportError(error))
        } catch {
            throw CasebaseError.answerFailed(error.localizedDescription)
        }
    }

    private func validate(
        payload: GeminiAnalysisPayload,
        thoughtSummary: String?
    ) throws -> AnalysisResult {
        let contentType = payload.contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        let scene = payload.scene.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = payload.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortSummary = payload.shortSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchText = payload.searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !contentType.isEmpty,
            !scene.isEmpty,
            !purpose.isEmpty,
            !title.isEmpty,
            !shortSummary.isEmpty,
            !searchText.isEmpty
        else {
            throw CasebaseError.analysisFailed(
                CasebasePromptCatalog.errors.geminiReturnedEmptyRequiredFields
            )
        }

        let usefulSnippets = payload.usefulSnippets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tags = payload.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let clarification = sanitizeClarification(payload.clarification)

        return AnalysisResult(
            contentType: contentType,
            scene: scene,
            purpose: purpose,
            title: title,
            shortSummary: shortSummary,
            aiThoughtSummary: thoughtSummary,
            usefulSnippets: Array(usefulSnippets.prefix(12)),
            tags: Array(tags.prefix(12)),
            structuredData: payload.structuredData,
            searchText: searchText,
            clarificationRequest: clarification,
            needsReview: payload.needsReview
        )
    }

    private func sanitizeClarification(_ payload: GeminiClarificationPayload) -> ClarificationRequest? {
        let uncertaintySummary = payload.uncertaintySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let impactExplanation = payload.impactExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let questions = payload.questions
            .prefix(3)
            .enumerated()
            .compactMap { offset, questionPayload -> ClarificationQuestion? in
                let title = questionPayload.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let reason = questionPayload.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !reason.isEmpty else {
                    return nil
                }

                let options = questionPayload.suggestedOptions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .prefix(3)

                return ClarificationQuestion(
                    id: "q\(offset + 1)",
                    title: title,
                    reason: reason,
                    suggestedOptions: Array(options)
                )
            }

        guard !questions.isEmpty else {
            return nil
        }

        return ClarificationRequest(
            uncertaintySummary: uncertaintySummary,
            impactExplanation: impactExplanation,
            questions: questions
        )
    }

    private func extractPrimaryText(from response: GeminiGenerateContentResponse) throws -> String {
        let text = Self.extractText(from: response, thought: false)

        guard let text, !text.isEmpty else {
            throw CasebaseError.emptyResponse
        }
        return text
    }

    private func extractThoughtSummary(from response: GeminiGenerateContentResponse) -> String? {
        let thoughtSummary = Self.extractText(from: response, thought: true)

        guard let thoughtSummary, !thoughtSummary.isEmpty else {
            return nil
        }
        return thoughtSummary
    }

    private func decodeJSONPayload<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let data = text.data(using: .utf8) else {
            throw CasebaseError.emptyResponse
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private func answer(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        model: String,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult {
        let answerRequest: GeminiJSONObject = [
            "contents": try GeminiAnswerPromptBuilder.answerContents(
                question: question,
                sources: sources,
                policy: policy
            ),
            "generationConfig": Self.answerGenerationConfig(
                for: model,
                includeThoughts: true
            ),
        ]

        let answerText = try await streamAnswerResponse(
            requestBody: answerRequest,
            model: model,
            streamHandler: streamHandler,
            thoughtHandler: thoughtHandler
        )

        do {
            let attributionRequest: GeminiJSONObject = [
                "contents": try GeminiAnswerPromptBuilder.attributionContents(
                    question: question,
                    answerText: answerText,
                    sources: sources
                ),
                "generationConfig": Self.answerGenerationConfig(
                    for: model,
                    includeThoughts: false,
                    responseMimeType: "application/json",
                    responseJsonSchema: GeminiAnswerPromptBuilder.attributionJSONSchema
                ),
            ]

            let attributionResponse: GeminiGenerateContentResponse = try await executor.postJSON(
                path: "models/\(model):generateContent",
                body: attributionRequest,
                decode: GeminiGenerateContentResponse.self
            )
            let attributionText = try extractPrimaryText(from: attributionResponse)
            let attribution = try decodeJSONPayload(GeminiAttributionPayload.self, from: attributionText)
            let (recordIDs, citations) = attributionResolver.resolveCitations(
                from: sources,
                citedSources: attribution.citations.map { payload in
                    AnswerAttributionResolver.CitationSupport(
                        index: payload.index,
                        supportNote: payload.supportNote
                    )
                }
            )

            return AnswerResult(
                answerText: answerText,
                citedRecordIDs: recordIDs,
                citations: citations,
                usedModelSupplement: attribution.usedModelSupplement
            )
        } catch {
            let (recordIDs, citations) = attributionResolver.fallbackCitations(from: sources)
            return AnswerResult(
                answerText: answerText,
                citedRecordIDs: recordIDs,
                citations: citations,
                usedModelSupplement: true
            )
        }
    }

    private func streamAnswerResponse(
        requestBody: GeminiJSONObject,
        model: String,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> String {
        let accumulator = GeminiStreamingAccumulator()
        do {
            try await executor.streamJSON(
                path: "models/\(model):streamGenerateContent?alt=sse",
                body: requestBody,
                decode: GeminiGenerateContentResponse.self
            ) { response in
                if let thoughtChunk = Self.extractText(from: response, thought: true, trimsWhitespace: false) {
                    let visibleThought = accumulator.appendThought(thoughtChunk)
                    thoughtHandler?(visibleThought)
                }

                if let primaryChunk = Self.extractText(from: response, thought: false, trimsWhitespace: false) {
                    let visibleText = accumulator.appendPrimary(primaryChunk)
                    streamHandler?(visibleText)
                }
            }
        } catch {
            let fallbackText = try await fetchAnswerNonStreaming(
                requestBody: requestBody,
                model: model
            )
            streamHandler?(fallbackText)
            return fallbackText
        }

        let primaryText = accumulator.primaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryText.isEmpty else {
            throw GeminiTransportError.server(
                statusCode: 503,
                message: CasebasePromptCatalog.language == .simplifiedChinese
                    ? "流式回答在生成正文前结束，请重试。"
                    : "The streamed answer ended before any visible response was produced.",
                retryable: true
            )
        }
        return primaryText
    }

    private func fetchAnswerNonStreaming(
        requestBody: GeminiJSONObject,
        model: String
    ) async throws -> String {
        let response: GeminiGenerateContentResponse = try await executor.postJSON(
            path: "models/\(model):generateContent",
            body: requestBody,
            decode: GeminiGenerateContentResponse.self
        )
        return try extractPrimaryText(from: response)
    }

    private func analyzeOnce(
        contents: [GeminiJSONObject],
        urlContextURLs: [URL],
        thoughtHandler: AIThoughtHandler?,
        requiresExplicitClarificationQuestions: Bool
    ) async throws -> (payload: GeminiAnalysisPayload, thoughtSummary: String?) {
        for index in analysisModels.indices {
            let model = analysisModels[index]
            let requestBody = Self.analysisRequestBody(
                contents: contents,
                urlContextURLs: urlContextURLs,
                requiresExplicitClarificationQuestions: requiresExplicitClarificationQuestions,
                model: model
            )

            do {
                let streamed = try await streamAnalysisResponse(
                    requestBody: requestBody,
                    model: model,
                    thoughtHandler: thoughtHandler
                )
                let payload = try decodeJSONPayload(GeminiAnalysisPayload.self, from: streamed.primaryText)
                return (payload, streamed.thoughtSummary)
            } catch let error as GeminiTransportError where Self.shouldTryNextAnalysisModel(after: error) && index < analysisModels.index(before: analysisModels.endIndex) {
                let nextModel = analysisModels[analysisModels.index(after: index)]
                CasebaseDebugLogger.log(
                    "AI analysis model fallback from=\(model) to=\(nextModel) reason=\"\(Self.describeTransportError(error))\""
                )
                continue
            }
        }

        throw CasebaseError.emptyResponse
    }

    private func streamAnalysisResponse(
        requestBody: GeminiJSONObject,
        model: String,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> (primaryText: String, thoughtSummary: String?) {
        let accumulator = GeminiStreamingAccumulator()

        try await executor.streamJSON(
            path: "models/\(model):streamGenerateContent?alt=sse",
            body: requestBody,
            decode: GeminiGenerateContentResponse.self
        ) { response in
            if let thoughtChunk = Self.extractText(from: response, thought: true) {
                let visibleThought = accumulator.appendThought(thoughtChunk)
                thoughtHandler?(visibleThought)
            }

            if let primaryChunk = Self.extractText(from: response, thought: false) {
                _ = accumulator.appendPrimary(primaryChunk)
            }
        }

        let primaryText = accumulator.primaryText
        guard !primaryText.isEmpty else {
            throw CasebaseError.emptyResponse
        }

        return (
            primaryText: primaryText,
            thoughtSummary: accumulator.thoughtText.isEmpty ? nil : accumulator.thoughtText
        )
    }

    private static func extractText(
        from response: GeminiGenerateContentResponse,
        thought: Bool,
        trimsWhitespace: Bool = true
    ) -> String? {
        let text = response.candidates?
            .compactMap(\.content?.parts)
            .flatMap { $0 }
            .filter { ($0.thought ?? false) == thought }
            .compactMap(\.text)
            .joined()

        let preparedText = trimsWhitespace
            ? text?.trimmingCharacters(in: .whitespacesAndNewlines)
            : text

        guard let preparedText, !preparedText.isEmpty else {
            return nil
        }
        return preparedText
    }

    private static func analysisRequestBody(
        contents: [GeminiJSONObject],
        urlContextURLs: [URL],
        requiresExplicitClarificationQuestions: Bool,
        model: String
    ) -> GeminiJSONObject {
        var body: GeminiJSONObject = [
            "contents": adjustedAnalysisContents(
                from: contents,
                requiresExplicitClarificationQuestions: requiresExplicitClarificationQuestions
            ),
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseJsonSchema": GeminiAnalysisPromptBuilder.responseJSONSchema,
                "thinkingConfig": analysisThinkingConfig(for: model),
            ],
        ]

        if !urlContextURLs.isEmpty {
            body["tools"] = [[
                "url_context": [:],
            ]]
        }

        return body
    }

    private static func adjustedAnalysisContents(
        from contents: [GeminiJSONObject],
        requiresExplicitClarificationQuestions: Bool
    ) -> [GeminiJSONObject] {
        guard requiresExplicitClarificationQuestions,
              var firstContent = contents.first,
              var parts = firstContent["parts"] as? [GeminiJSONObject]
        else {
            return contents
        }

        parts.append(["text": CasebasePromptCatalog.ai.clarificationRepairInstruction])
        firstContent["parts"] = parts

        var adjusted = contents
        adjusted[0] = firstContent
        return adjusted
    }

    private static func requiresClarificationRepair(_ payload: GeminiAnalysisPayload) -> Bool {
        guard payload.needsReview else { return false }
        let questions = payload.clarification.questions.compactMap { question -> ClarificationQuestion? in
            let title = question.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = question.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !reason.isEmpty else { return nil }
            return ClarificationQuestion(id: "probe", title: title, reason: reason, suggestedOptions: [])
        }
        return questions.isEmpty
    }

    private static func shouldTryNextAnalysisModel(after error: GeminiTransportError) -> Bool {
        if case let .server(_, _, retryable) = error {
            return retryable
        }
        return false
    }

    private static func analysisThinkingConfig(for model: String) -> GeminiJSONObject {
        if model.hasPrefix("gemini-2.5-") {
            return [
                "includeThoughts": true,
                "thinkingBudget": 0,
            ]
        }

        return [
            "includeThoughts": true,
            "thinkingLevel": "low",
        ]
    }

    private static func answerGenerationConfig(
        for model: String,
        includeThoughts: Bool,
        responseMimeType: String? = nil,
        responseJsonSchema: GeminiJSONObject? = nil
    ) -> GeminiJSONObject {
        var config: GeminiJSONObject = [:]
        if let responseMimeType {
            config["responseMimeType"] = responseMimeType
        }
        if let responseJsonSchema {
            config["responseJsonSchema"] = responseJsonSchema
        }
        if let thinkingConfig = answerThinkingConfig(for: model, includeThoughts: includeThoughts) {
            config["thinkingConfig"] = thinkingConfig
        }
        return config
    }

    private static func answerThinkingConfig(for model: String, includeThoughts: Bool) -> GeminiJSONObject? {
        if model.hasPrefix("gemini-2.5-") {
            return includeThoughts ? ["includeThoughts": true] : nil
        }

        var config: GeminiJSONObject = [
            "thinkingLevel": "MEDIUM",
        ]
        if includeThoughts {
            config["includeThoughts"] = true
        }
        return config
    }

    private static func describeTransportError(_ error: GeminiTransportError) -> String {
        switch error {
        case .invalidRequestBody:
            return CasebasePromptCatalog.errors.invalidAIRequestBody
        case .invalidResponse:
            return CasebasePromptCatalog.errors.invalidAIResponse
        case let .transport(underlying):
            let nsError = underlying as NSError
            if nsError.domain == kCFErrorDomainCFNetwork as String, nsError.code == 310 {
                return CasebasePromptCatalog.language == .simplifiedChinese
                    ? "网络代理链路异常（CFNetwork 310）。请确认代理可用后重试。"
                    : "Proxy/network chain error (CFNetwork 310). Please verify proxy connectivity and retry."
            }
            if let transportMessage = transportFailureMessage(for: underlying) {
                return transportMessage
            }
            return underlying.localizedDescription
        case let .server(statusCode, message, _):
            if let authenticationMessage = authenticationFailureMessage(
                statusCode: statusCode,
                message: message
            ) {
                return authenticationMessage
            }
            return CasebasePromptCatalog.errors.httpStatus(statusCode, message: message)
        case let .decodingFailed(preview):
            return CasebasePromptCatalog.errors.failedToDecodeAIResponse(preview)
        }
    }

    private static func transportFailureMessage(for error: Error) -> String? {
        guard let urlError = error as? URLError else {
            return nil
        }

        switch urlError.code {
        case .timedOut:
            return CasebasePromptCatalog.language == .simplifiedChinese
                ? "网络请求超时。请检查代理或网络连通性后重试。"
                : "The network request timed out. Check the proxy or network connection and retry."
        case .notConnectedToInternet:
            return CasebasePromptCatalog.language == .simplifiedChinese
                ? "当前网络不可用。请确认已联网后重试。"
                : "No internet connection is available. Verify connectivity and retry."
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return CasebasePromptCatalog.language == .simplifiedChinese
                ? "无法连接到 AI 服务主机。请检查代理、DNS 或服务地址配置。"
                : "Could not reach the AI service host. Check the proxy, DNS, or configured endpoint."
        case .networkConnectionLost:
            return CasebasePromptCatalog.language == .simplifiedChinese
                ? "与 AI 服务的网络连接中断。请检查代理或网络稳定性后重试。"
                : "The network connection to the AI service was lost. Check proxy or network stability and retry."
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted:
            return CasebasePromptCatalog.language == .simplifiedChinese
                ? "与 AI 服务建立安全连接失败。请检查代理证书或 HTTPS 配置。"
                : "Failed to establish a secure connection to the AI service. Check proxy certificates or HTTPS settings."
        default:
            return nil
        }
    }

    private static func authenticationFailureMessage(statusCode: Int, message: String) -> String? {
        let normalizedMessage = message.lowercased()
        let authenticationKeywords = [
            "api key",
            "authentication",
            "credentials",
            "permission denied",
            "forbidden",
            "unregistered callers",
            "access token",
            "unauthorized"
        ]

        let looksLikeAuthenticationFailure =
            statusCode == 401
            || statusCode == 403
            || authenticationKeywords.contains(where: { normalizedMessage.contains($0) })

        guard looksLikeAuthenticationFailure else {
            return nil
        }

        if CasebasePromptCatalog.language == .simplifiedChinese {
            return "API Key 鉴权失败，可能是 key 无效、权限不足，或当前代理不接受这组凭据：\(message)"
        }

        return "API key authentication failed. The key may be invalid, lack model access, or be rejected by the current proxy: \(message)"
    }
}

private final class GeminiStreamingAccumulator: @unchecked Sendable {
    private(set) var primaryText = ""
    private(set) var thoughtText = ""

    func appendPrimary(_ chunk: String) -> String {
        primaryText += chunk
        return primaryText
    }

    func appendThought(_ chunk: String) -> String {
        thoughtText += chunk
        return thoughtText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
