import Foundation

private struct DeepSeekChatCompletionResponse: Decodable {
    let choices: [DeepSeekChoice]
}

private struct DeepSeekChoice: Decodable {
    let message: DeepSeekMessage?
    let delta: DeepSeekDelta?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case delta
        case finishReason = "finish_reason"
    }
}

private struct DeepSeekMessage: Decodable {
    let content: String?
    let reasoningContent: String?

    enum CodingKeys: String, CodingKey {
        case content
        case reasoningContent = "reasoning_content"
    }
}

private struct DeepSeekDelta: Decodable {
    let content: String?
    let reasoningContent: String?

    enum CodingKeys: String, CodingKey {
        case content
        case reasoningContent = "reasoning_content"
    }
}

private struct DeepSeekAnalysisPayload: Decodable {
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
    let clarification: DeepSeekClarificationPayload

    private enum CodingKeys: String, CodingKey {
        case contentType
        case contentTypeSnake = "content_type"
        case scene
        case purpose
        case title
        case shortSummary
        case shortSummarySnake = "short_summary"
        case tags
        case usefulSnippets
        case usefulSnippetsSnake = "useful_snippets"
        case structuredData
        case structuredDataSnake = "structured_data"
        case searchText
        case searchTextSnake = "search_text"
        case needsReview
        case needsReviewSnake = "needs_review"
        case clarification
        case clarificationRequest = "clarification_request"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        contentType = container.decodeFlexibleStringIfPresent(for: [.contentType, .contentTypeSnake])
            .nonEmptyOr(Self.defaultContentType)
        scene = container.decodeFlexibleStringIfPresent(for: [.scene])
            .nonEmptyOr(Self.defaultScene)
        purpose = container.decodeFlexibleStringIfPresent(for: [.purpose])
            .nonEmptyOr(Self.defaultPurpose)
        shortSummary = container.decodeFlexibleStringIfPresent(for: [.shortSummary, .shortSummarySnake])
            .nonEmptyOr(Self.defaultSummary)
        title = container.decodeFlexibleStringIfPresent(for: [.title])
            .nonEmptyOr(Self.defaultTitle(from: shortSummary))
        tags = container.decodeFlexibleStringArrayIfPresent(for: [.tags]) ?? []
        usefulSnippets = container.decodeFlexibleStringArrayIfPresent(for: [.usefulSnippets, .usefulSnippetsSnake]) ?? []
        structuredData = container.decodeValueIfPresent(
            [String: StructuredFieldValue].self,
            for: [.structuredData, .structuredDataSnake]
        ) ?? [:]
        needsReview = container.decodeFlexibleBoolIfPresent(for: [.needsReview, .needsReviewSnake]) ?? false
        clarification = container.decodeValueIfPresent(
            DeepSeekClarificationPayload.self,
            for: [.clarification, .clarificationRequest]
        ) ?? DeepSeekClarificationPayload()

        let decodedSearchText = container.decodeFlexibleStringIfPresent(for: [.searchText, .searchTextSnake])
        searchText = decodedSearchText.nonEmptyOr(
            ([title, shortSummary, contentType, scene, purpose] + tags + usefulSnippets)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static var defaultContentType: String {
        CasebasePromptCatalog.fallback.contentType(for: .text)
    }

    private static var defaultScene: String {
        CasebasePromptCatalog.fallback.scene(for: .text, fileName: "untitled", rawText: nil)
    }

    private static var defaultPurpose: String {
        CasebasePromptCatalog.fallback.purpose(for: .text, fileName: "untitled", rawText: nil)
    }

    private static var defaultSummary: String {
        CasebasePromptCatalog.fallback.summary(fileName: "untitled", rawText: nil, metadata: [:])
    }

    private static func defaultTitle(from summary: String) -> String {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            return String(trimmedSummary.prefix(40))
        }
        return CasebasePromptCatalog.fallback.title(for: .text, fileName: "untitled")
    }
}

private struct DeepSeekClarificationPayload: Decodable {
    let uncertaintySummary: String
    let impactExplanation: String
    let questions: [DeepSeekClarificationQuestionPayload]

    private enum CodingKeys: String, CodingKey {
        case uncertaintySummary
        case uncertaintySummarySnake = "uncertainty_summary"
        case impactExplanation
        case impactExplanationSnake = "impact_explanation"
        case questions
    }

    init(
        uncertaintySummary: String = "",
        impactExplanation: String = "",
        questions: [DeepSeekClarificationQuestionPayload] = []
    ) {
        self.uncertaintySummary = uncertaintySummary
        self.impactExplanation = impactExplanation
        self.questions = questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uncertaintySummary = container.decodeFlexibleStringIfPresent(
            for: [.uncertaintySummary, .uncertaintySummarySnake]
        ) ?? ""
        impactExplanation = container.decodeFlexibleStringIfPresent(
            for: [.impactExplanation, .impactExplanationSnake]
        ) ?? ""
        questions = container.decodeValueIfPresent(
            [DeepSeekClarificationQuestionPayload].self,
            for: [.questions]
        ) ?? []
    }
}

private struct DeepSeekClarificationQuestionPayload: Decodable {
    let title: String
    let reason: String
    let suggestedOptions: [String]

    private enum CodingKeys: String, CodingKey {
        case title
        case reason
        case suggestedOptions
        case suggestedOptionsSnake = "suggested_options"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeFlexibleStringIfPresent(for: [.title]) ?? ""
        reason = container.decodeFlexibleStringIfPresent(for: [.reason]) ?? ""
        suggestedOptions = container.decodeFlexibleStringArrayIfPresent(
            for: [.suggestedOptions, .suggestedOptionsSnake]
        ) ?? []
    }
}

private struct DeepSeekLossyString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = ""
        } else if let decoded = try? container.decode(String.self) {
            value = decoded
        } else if let decoded = try? container.decode(Int.self) {
            value = String(decoded)
        } else if let decoded = try? container.decode(Double.self) {
            value = String(decoded)
        } else if let decoded = try? container.decode(Bool.self) {
            value = decoded ? "true" : "false"
        } else {
            value = ""
        }
    }
}

private extension Optional where Wrapped == String {
    func nonEmptyOr(_ fallback: String) -> String {
        let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(for keys: [Key]) -> String? {
        for key in keys {
            if let decoded = try? decode(DeepSeekLossyString.self, forKey: key) {
                let trimmed = decoded.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    func decodeFlexibleStringArrayIfPresent(for keys: [Key]) -> [String]? {
        for key in keys {
            if let decoded = try? decode([DeepSeekLossyString].self, forKey: key) {
                return decoded
                    .map(\.value)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }

            if let decoded = try? decode(DeepSeekLossyString.self, forKey: key) {
                let trimmed = decoded.value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? [] : [trimmed]
            }
        }
        return nil
    }

    func decodeFlexibleBoolIfPresent(for keys: [Key]) -> Bool? {
        for key in keys {
            if let decoded = try? decode(Bool.self, forKey: key) {
                return decoded
            }

            guard let text = decodeFlexibleStringIfPresent(for: [key])?.lowercased() else {
                continue
            }
            if ["true", "yes", "y", "1"].contains(text) {
                return true
            }
            if ["false", "no", "n", "0"].contains(text) {
                return false
            }
        }
        return nil
    }

    func decodeValueIfPresent<T: Decodable>(_ type: T.Type, for keys: [Key]) -> T? {
        for key in keys {
            if let decoded = try? decode(type, forKey: key) {
                return decoded
            }
        }
        return nil
    }
}

private struct DeepSeekAttributionCitationPayload: Decodable {
    let index: Int
    let supportNote: String
}

private struct DeepSeekAttributionPayload: Decodable {
    let citations: [DeepSeekAttributionCitationPayload]
    let usedModelSupplement: Bool
}

final class DeepSeekAIClient: AIClient {
    private let executor: DeepSeekRequestExecutor
    private let analysisModel: String
    private let answerModel: String
    private let attributionResolver = AnswerAttributionResolver()

    init(
        configuration: CasebaseConfiguration,
        session: URLSession? = nil
    ) {
        executor = DeepSeekRequestExecutor(
            baseURL: configuration.ai.baseURL,
            apiKey: configuration.ai.apiKey,
            requestTimeout: configuration.ai.requestTimeout,
            proxyURLString: configuration.ai.proxyURLString,
            session: session
        )
        analysisModel = Self.resolvedModel(from: configuration.ai.analysisModel)
        answerModel = Self.resolvedModel(from: configuration.ai.answerModel)
    }

    func analyze(content: NormalizedContent, thoughtHandler: AIThoughtHandler?) async throws -> AnalysisResult {
        do {
            let request = Self.analysisRequest(content: content, repair: false, model: analysisModel)
            let initial = try await fetchAnalysis(request: request, thoughtHandler: thoughtHandler)

            if Self.requiresClarificationRepair(initial.payload) {
                let repairRequest = Self.analysisRequest(content: content, repair: true, model: analysisModel)
                let repaired = try await fetchAnalysis(request: repairRequest, thoughtHandler: thoughtHandler)
                return try validate(payload: repaired.payload, thoughtSummary: repaired.thoughtSummary)
            }

            return try validate(payload: initial.payload, thoughtSummary: initial.thoughtSummary)
        } catch let error as CasebaseError {
            throw error
        } catch let error as DeepSeekTransportError {
            throw CasebaseError.analysisFailed(Self.describeTransportError(error))
        } catch {
            throw CasebaseError.analysisFailed(error.localizedDescription)
        }
    }

    func embed(text _: String) async throws -> [Float] {
        []
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
            let answerText = try await streamAnswer(
                question: trimmedQuestion,
                sources: sources,
                policy: policy,
                streamHandler: streamHandler,
                thoughtHandler: thoughtHandler
            )
            return try await attributedAnswer(
                question: trimmedQuestion,
                answerText: answerText,
                sources: sources
            )
        } catch let error as DeepSeekTransportError {
            throw CasebaseError.answerFailed(Self.describeTransportError(error))
        } catch let error as CasebaseError {
            throw error
        } catch {
            throw CasebaseError.answerFailed(error.localizedDescription)
        }
    }

    private func fetchAnalysis(
        request: DeepSeekJSONObject,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> (payload: DeepSeekAnalysisPayload, thoughtSummary: String?) {
        let response: DeepSeekChatCompletionResponse = try await executor.postJSON(
            path: "chat/completions",
            body: request,
            decode: DeepSeekChatCompletionResponse.self
        )
        let message = try Self.primaryMessage(from: response)
        let thoughtSummary = message.reasoningContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let thoughtSummary, !thoughtSummary.isEmpty {
            thoughtHandler?(thoughtSummary)
        }
        let text = try Self.primaryContent(from: message)
        let payload = try decodeJSONPayload(DeepSeekAnalysisPayload.self, from: text)
        return (payload, thoughtSummary)
    }

    private func streamAnswer(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> String {
        let request = Self.answerRequest(
            question: question,
            sources: sources,
            policy: policy,
            model: answerModel,
            stream: true
        )
        let accumulator = DeepSeekStreamingAccumulator()

        do {
            try await executor.streamJSON(
                path: "chat/completions",
                body: request,
                decode: DeepSeekChatCompletionResponse.self
            ) { response in
                for choice in response.choices {
                    if let reasoning = choice.delta?.reasoningContent, !reasoning.isEmpty {
                        let visibleThought = accumulator.appendThought(reasoning)
                        thoughtHandler?(visibleThought)
                    }
                    if let content = choice.delta?.content, !content.isEmpty {
                        let visibleText = accumulator.appendPrimary(content)
                        streamHandler?(visibleText)
                    }
                }
            }
        } catch {
            let fallbackText = try await fetchAnswerNonStreaming(
                question: question,
                sources: sources,
                policy: policy
            )
            streamHandler?(fallbackText)
            return fallbackText
        }

        let primaryText = accumulator.primaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryText.isEmpty else {
            throw DeepSeekTransportError.server(
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
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy
    ) async throws -> String {
        let request = Self.answerRequest(
            question: question,
            sources: sources,
            policy: policy,
            model: answerModel,
            stream: false
        )
        let response: DeepSeekChatCompletionResponse = try await executor.postJSON(
            path: "chat/completions",
            body: request,
            decode: DeepSeekChatCompletionResponse.self
        )
        let message = try Self.primaryMessage(from: response)
        return try Self.primaryContent(from: message)
    }

    private func attributedAnswer(
        question: String,
        answerText: String,
        sources: [AnswerEvidencePacket]
    ) async throws -> AnswerResult {
        do {
            let request = Self.attributionRequest(
                question: question,
                answerText: answerText,
                sources: sources,
                model: answerModel
            )
            let response: DeepSeekChatCompletionResponse = try await executor.postJSON(
                path: "chat/completions",
                body: request,
                decode: DeepSeekChatCompletionResponse.self
            )
            let message = try Self.primaryMessage(from: response)
            let attribution = try decodeJSONPayload(
                DeepSeekAttributionPayload.self,
                from: try Self.primaryContent(from: message)
            )
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

    private func validate(
        payload: DeepSeekAnalysisPayload,
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
            throw CasebaseError.analysisFailed(CasebasePromptCatalog.errors.geminiReturnedEmptyRequiredFields)
        }

        let usefulSnippets = payload.usefulSnippets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tags = payload.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

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
            clarificationRequest: sanitizeClarification(payload.clarification),
            needsReview: payload.needsReview
        )
    }

    private func sanitizeClarification(_ payload: DeepSeekClarificationPayload) -> ClarificationRequest? {
        let uncertaintySummary = payload.uncertaintySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let impactExplanation = payload.impactExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        let questions = payload.questions
            .prefix(3)
            .enumerated()
            .compactMap { offset, questionPayload -> ClarificationQuestion? in
                let title = questionPayload.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let reason = questionPayload.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, !reason.isEmpty else { return nil }
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

        guard !questions.isEmpty else { return nil }
        return ClarificationRequest(
            uncertaintySummary: uncertaintySummary,
            impactExplanation: impactExplanation,
            questions: questions
        )
    }

    private func decodeJSONPayload<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText = Self.extractJSONObject(from: Self.stripMarkdownFence(from: trimmed))
        guard let data = jsonText.data(using: .utf8) else {
            throw CasebaseError.emptyResponse
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let description = Self.describeDecodingError(error)
            let preview = Self.preview(jsonText)
            CasebaseDebugLogger.log(
                "DeepSeek JSON payload decode failed type=\(String(describing: type)) error=\(description) preview=\(preview)"
            )
            throw CasebaseError.analysisFailed(
                CasebasePromptCatalog.errors.failedToDecodeAIResponse(description)
            )
        }
    }

    private static func analysisRequest(
        content: NormalizedContent,
        repair: Bool,
        model: String
    ) -> DeepSeekJSONObject {
        var system = CasebasePromptCatalog.ai.analysisInstructions
        system += "\n\nReturn a valid JSON object only. Do not wrap it in Markdown."
        if let schema = Self.encodedJSONString(CasebasePromptCatalog.ai.analysisResponseJSONSchema) {
            system += "\n\nThe JSON object must match this schema exactly:\n\(schema)"
        }
        if repair {
            system += "\n\n\(CasebasePromptCatalog.ai.clarificationRepairInstruction)"
        }

        return chatRequest(
            model: model,
            messages: [
                ["role": "system", "content": system],
                ["role": "user", "content": DeepSeekContentEncoder.analysisUserPrompt(for: content)],
            ],
            stream: false,
            jsonMode: true,
            maxTokens: 8192
        )
    }

    private static func answerRequest(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        model: String,
        stream: Bool
    ) -> DeepSeekJSONObject {
        chatRequest(
            model: model,
            messages: [
                ["role": "system", "content": CasebasePromptCatalog.ai.answerAppPreamble],
                [
                    "role": "user",
                    "content": CasebasePromptCatalog.ai.answerPrompt(
                        question: question,
                        sources: sources,
                        policy: policy
                    ),
                ],
            ],
            stream: stream,
            jsonMode: false,
            maxTokens: 8192
        )
    }

    private static func attributionRequest(
        question: String,
        answerText: String,
        sources: [AnswerEvidencePacket],
        model: String
    ) -> DeepSeekJSONObject {
        chatRequest(
            model: model,
            messages: [
                ["role": "system", "content": "Return a valid JSON object only. Do not wrap it in Markdown."],
                [
                    "role": "user",
                    "content": CasebasePromptCatalog.ai.attributionPrompt(
                        question: question,
                        answerText: answerText,
                        sources: sources
                    ),
                ],
            ],
            stream: false,
            jsonMode: true,
            maxTokens: 4096
        )
    }

    private static func chatRequest(
        model: String,
        messages: [[String: String]],
        stream: Bool,
        jsonMode: Bool,
        maxTokens: Int
    ) -> DeepSeekJSONObject {
        var request: DeepSeekJSONObject = [
            "model": model,
            "messages": messages,
            "thinking": ["type": "enabled"],
            "reasoning_effort": "high",
            "stream": stream,
            "max_tokens": maxTokens,
        ]
        if jsonMode {
            request["response_format"] = ["type": "json_object"]
        }
        return request
    }

    private static func primaryMessage(from response: DeepSeekChatCompletionResponse) throws -> DeepSeekMessage {
        guard let message = response.choices.first?.message else {
            throw CasebaseError.emptyResponse
        }
        return message
    }

    private static func primaryContent(from message: DeepSeekMessage) throws -> String {
        let text = message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw CasebaseError.emptyResponse
        }
        return text
    }

    private static func requiresClarificationRepair(_ payload: DeepSeekAnalysisPayload) -> Bool {
        payload.needsReview && payload.clarification.questions.isEmpty
    }

    private static func stripMarkdownFence(from text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        trimmed.removeFirst(3)
        if let newline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: newline)...])
        }
        if let closing = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<closing.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let start = trimmed.firstIndex(of: "{"),
            let end = trimmed.lastIndex(of: "}"),
            start <= end
        else {
            return trimmed
        }
        return String(trimmed[start...end])
    }

    private static func encodedJSONString(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return text
    }

    private static func preview(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(flattened.prefix(1_000))
    }

    private static func describeDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case let .keyNotFound(key, context):
            return "missing key '\(key.stringValue)' at \(codingPathDescription(context.codingPath))"
        case let .typeMismatch(type, context):
            return "type mismatch for \(type) at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "missing value for \(type) at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "data corrupted at \(codingPathDescription(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func codingPathDescription(_ path: [CodingKey]) -> String {
        let joined = path.map(\.stringValue).joined(separator: ".")
        return joined.isEmpty ? "<root>" : joined
    }

    private static func resolvedModel(from configured: String) -> String {
        let first = configured
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        if first == "deepseek-v4-pro" || first == "deepseek-v4-flash" {
            return first
        }
        return "deepseek-v4-pro"
    }

    private static func describeTransportError(_ error: DeepSeekTransportError) -> String {
        switch error {
        case .invalidRequestBody:
            return "Invalid DeepSeek request body."
        case .invalidResponse:
            return "DeepSeek returned an invalid response."
        case let .transport(error):
            return error.localizedDescription
        case let .server(statusCode, message, _):
            return "DeepSeek API error \(statusCode): \(message)"
        case let .decodingFailed(payload):
            return "Failed to decode DeepSeek response: \(payload)"
        }
    }
}

private enum DeepSeekContentEncoder {
    static func analysisUserPrompt(for content: NormalizedContent) -> String {
        var sections: [String] = []

        if let userSupplement = content.fallbackMetadata[CasebasePromptCatalog.ai.userSupplementMetadataKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !userSupplement.isEmpty {
            sections.append("\(CasebasePromptCatalog.ai.userSupplementLabel):\n\(userSupplement)")
        }

        if let rawText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawText.isEmpty {
            sections.append("\(CasebasePromptCatalog.ai.normalizedTextLabel):\n\(rawText)")
        }

        let visibleMetadata = content.fallbackMetadata
            .filter { $0.key != CasebasePromptCatalog.ai.userSupplementMetadataKey }
        if !visibleMetadata.isEmpty {
            let metadataBlock = visibleMetadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            sections.append("\(CasebasePromptCatalog.ai.fallbackMetadataLabel):\n\(metadataBlock)")
        }

        let urls = extractedPublicHTTPURLs(from: sections.joined(separator: "\n\n"))
        if !urls.isEmpty {
            sections.append("""
            \(CasebasePromptCatalog.ai.urlContextLabel):
            \(urls.map(\.absoluteString).joined(separator: "\n"))

            These URLs are included only as text references. Do not claim to have fetched or read their pages.
            """)
        }

        if sections.isEmpty {
            sections.append("No parsed text is available. Use only the file metadata and mark the record for review if needed.")
        }

        return sections.joined(separator: "\n\n")
    }

    private static func extractedPublicHTTPURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        var urls: [URL] = []
        var seen: Set<String> = []
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host?.lowercased(),
                  !host.isEmpty,
                  host != "localhost",
                  !host.hasSuffix(".local")
            else {
                continue
            }

            let key = url.absoluteString.lowercased()
            guard seen.insert(key).inserted else { continue }
            urls.append(url)
            if urls.count >= 6 { break }
        }
        return urls
    }
}

private final class DeepSeekStreamingAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var primaryText = ""
    private var thoughtText = ""

    func appendPrimary(_ text: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        primaryText += text
        return primaryText
    }

    func appendThought(_ text: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        thoughtText += text
        return thoughtText
    }
}
