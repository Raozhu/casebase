import Foundation

final class CasebaseRoutedAIClient: AIClient, QueryEmbeddingProviding {
    private let deepSeekClient: DeepSeekAIClient
    private let geminiClient: GeminiAIClient?

    init(deepSeekClient: DeepSeekAIClient, geminiClient: GeminiAIClient?) {
        self.deepSeekClient = deepSeekClient
        self.geminiClient = geminiClient
    }

    func analyze(content: NormalizedContent, thoughtHandler: AIThoughtHandler?) async throws -> AnalysisResult {
        return try await deepSeekClient.analyze(content: content, thoughtHandler: thoughtHandler)
    }

    func embed(text: String) async throws -> [Float] {
        guard let geminiClient else { return [] }
        return try await geminiClient.embed(text: text)
    }

    func embedQuery(_ text: String) async throws -> [Float] {
        guard let geminiClient else { return [] }
        return try await geminiClient.embedQuery(text)
    }

    func answer(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult {
        try await deepSeekClient.answer(
            question: question,
            sources: sources,
            policy: policy,
            streamHandler: streamHandler,
            thoughtHandler: thoughtHandler
        )
    }

}
