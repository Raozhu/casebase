import Foundation

protocol GeminiEmbeddingModeProviding {
    func embedQuery(_ text: String) async throws -> [Float]
}

final class KnowledgeBackedAnswerService: AnswerService {
    private let knowledgeStore: KnowledgeStore
    private let aiClient: AIClient
    private let evidenceBuilder: AnswerEvidenceBuilder
    private let defaultLimit: Int
    private let policy: AnswerPolicy

    init(
        knowledgeStore: KnowledgeStore,
        aiClient: AIClient,
        extractor: Extractor,
        assetVault: AssetVault,
        configuration: CasebaseConfiguration
    ) {
        self.knowledgeStore = knowledgeStore
        self.aiClient = aiClient
        evidenceBuilder = AnswerEvidenceBuilder(extractor: extractor, assetVault: assetVault)
        defaultLimit = configuration.answering.defaultResultLimit
        policy = configuration.answering.policy
    }

    func answer(
        question: String,
        scope: AnswerQueryScope,
        limit: Int,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            throw CasebaseError.emptyQuery
        }

        let queryEmbedding: [Float]
        if let queryEmbeddingClient = aiClient as? GeminiEmbeddingModeProviding {
            queryEmbedding = try await queryEmbeddingClient.embedQuery(trimmedQuestion)
        } else {
            queryEmbedding = try await aiClient.embed(text: trimmedQuestion)
        }

        let resultLimit = limit > 0 ? limit : defaultLimit
        let hits = try await knowledgeStore.search(
            query: trimmedQuestion,
            embedding: queryEmbedding,
            limit: resultLimit,
            scope: scope
        )

        guard !hits.isEmpty else {
            return AnswerResult(
                answerText: CasebasePromptCatalog.ui.answerNoEvidenceMessage,
                citedRecordIDs: [],
                citations: [],
                usedModelSupplement: false
            )
        }

        let evidencePackets = await evidenceBuilder.buildEvidencePackets(question: trimmedQuestion, hits: hits)
        guard !evidencePackets.isEmpty else {
            return AnswerResult(
                answerText: CasebasePromptCatalog.ui.answerEvidenceUnavailableMessage,
                citedRecordIDs: [],
                citations: [],
                usedModelSupplement: false
            )
        }

        return try await aiClient.answer(
            question: trimmedQuestion,
            sources: evidencePackets,
            policy: policy,
            streamHandler: streamHandler,
            thoughtHandler: thoughtHandler
        )
    }
}
