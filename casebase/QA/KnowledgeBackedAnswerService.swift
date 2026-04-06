import Foundation

protocol GeminiEmbeddingModeProviding {
    func embedQuery(_ text: String) async throws -> [Float]
}

final class KnowledgeBackedAnswerService: AnswerService {
    private let knowledgeStore: KnowledgeStore
    private let aiClient: AIClient
    private let defaultLimit: Int
    private let policy: AnswerPolicy

    init(
        knowledgeStore: KnowledgeStore,
        aiClient: AIClient,
        configuration: CasebaseConfiguration
    ) {
        self.knowledgeStore = knowledgeStore
        self.aiClient = aiClient
        defaultLimit = configuration.answering.defaultResultLimit
        policy = configuration.answering.policy
    }

    func answer(question: String, limit: Int) async throws -> AnswerResult {
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
            limit: resultLimit
        )

        return try await aiClient.answer(question: trimmedQuestion, hits: hits, policy: policy)
    }
}
