import Foundation

enum GeminiAnswerPromptBuilder {
    static func answerPrompt(question: String, hits: [SearchHit], policy: AnswerPolicy) -> String {
        CasebasePromptCatalog.ai.answerPrompt(question: question, hits: hits, policy: policy)
    }

    static func attributionPrompt(question: String, answerText: String, hits: [SearchHit]) -> String {
        CasebasePromptCatalog.ai.attributionPrompt(question: question, answerText: answerText, hits: hits)
    }

    static var attributionJSONSchema: GeminiJSONObject { CasebasePromptCatalog.ai.attributionJSONSchema }
}
