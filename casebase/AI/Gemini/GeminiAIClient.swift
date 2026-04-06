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

private struct GeminiAttributionPayload: Decodable {
    let citedIndexes: [Int]
    let usedModelSupplement: Bool
}

final class GeminiAIClient: AIClient, GeminiEmbeddingModeProviding {
    private let executor: GeminiRequestExecutor
    private let analysisModel: String
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
            session: session
        )
        analysisModel = GeminiRuntimeDefaults.resolvedAnalysisModel(from: configuration.ai.analysisModel)
        answerModel = GeminiRuntimeDefaults.resolvedAnswerModel(from: configuration.ai.answerModel)
        embeddingModel = GeminiRuntimeDefaults.resolvedEmbeddingModel(from: configuration.ai.embeddingModel)
    }

    func analyze(content: NormalizedContent) async throws -> AnalysisResult {
        do {
            let contents = try GeminiContentEncoder.encodeAnalysisContents(content)
            let requestBody: GeminiJSONObject = [
                "contents": contents,
                "generationConfig": [
                    "responseMimeType": "application/json",
                    "responseJsonSchema": GeminiAnalysisPromptBuilder.responseJSONSchema,
                ],
            ]

            let response: GeminiGenerateContentResponse = try await executor.postJSON(
                path: "models/\(analysisModel):generateContent",
                body: requestBody,
                decode: GeminiGenerateContentResponse.self
            )
            let text = try extractPrimaryText(from: response)
            let payload = try decodeJSONPayload(GeminiAnalysisPayload.self, from: text)
            return try validate(payload: payload)
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

    func answer(question: String, hits: [SearchHit], policy: AnswerPolicy) async throws -> AnswerResult {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw CasebaseError.emptyQuery
        }

        do {
            let answerRequest: GeminiJSONObject = [
                "contents": [[
                    "parts": [[
                        "text": GeminiAnswerPromptBuilder.answerPrompt(question: trimmedQuestion, hits: hits, policy: policy),
                    ]],
                ]],
            ]

            let answerResponse: GeminiGenerateContentResponse = try await executor.postJSON(
                path: "models/\(answerModel):generateContent",
                body: answerRequest,
                decode: GeminiGenerateContentResponse.self
            )
            let answerText = try extractPrimaryText(from: answerResponse)

            guard !hits.isEmpty else {
                return AnswerResult(
                    answerText: answerText,
                    citedRecordIDs: [],
                    citations: [],
                    usedModelSupplement: true
                )
            }

            do {
                let attributionRequest: GeminiJSONObject = [
                    "contents": [[
                        "parts": [[
                            "text": GeminiAnswerPromptBuilder.attributionPrompt(
                                question: trimmedQuestion,
                                answerText: answerText,
                                hits: hits
                            ),
                        ]],
                    ]],
                    "generationConfig": [
                        "responseMimeType": "application/json",
                        "responseJsonSchema": GeminiAnswerPromptBuilder.attributionJSONSchema,
                    ],
                ]

                let attributionResponse: GeminiGenerateContentResponse = try await executor.postJSON(
                    path: "models/\(answerModel):generateContent",
                    body: attributionRequest,
                    decode: GeminiGenerateContentResponse.self
                )
                let attributionText = try extractPrimaryText(from: attributionResponse)
                let attribution = try decodeJSONPayload(GeminiAttributionPayload.self, from: attributionText)
                let (recordIDs, citations) = attributionResolver.resolveCitations(
                    from: hits,
                    citedIndexes: attribution.citedIndexes
                )

                return AnswerResult(
                    answerText: answerText,
                    citedRecordIDs: recordIDs,
                    citations: citations,
                    usedModelSupplement: attribution.usedModelSupplement
                )
            } catch {
                return AnswerResult(
                    answerText: answerText,
                    citedRecordIDs: [],
                    citations: [],
                    usedModelSupplement: true
                )
            }
        } catch let error as CasebaseError {
            throw error
        } catch let error as GeminiTransportError {
            throw CasebaseError.answerFailed(Self.describeTransportError(error))
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

    private func validate(payload: GeminiAnalysisPayload) throws -> AnalysisResult {
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
        let text = response.candidates?
            .compactMap(\.content?.parts)
            .flatMap { $0 }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw CasebaseError.emptyResponse
        }
        return text
    }

    private func decodeJSONPayload<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let data = text.data(using: .utf8) else {
            throw CasebaseError.emptyResponse
        }
        return try JSONDecoder().decode(type, from: data)
    }

    private static func describeTransportError(_ error: GeminiTransportError) -> String {
        switch error {
        case .invalidRequestBody:
            return CasebasePromptCatalog.errors.invalidAIRequestBody
        case .invalidResponse:
            return CasebasePromptCatalog.errors.invalidAIResponse
        case let .transport(underlying):
            return underlying.localizedDescription
        case let .server(statusCode, message, _):
            return CasebasePromptCatalog.errors.httpStatus(statusCode, message: message)
        case let .decodingFailed(preview):
            return CasebasePromptCatalog.errors.failedToDecodeAIResponse(preview)
        }
    }
}
