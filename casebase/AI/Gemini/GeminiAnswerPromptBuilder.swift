import Foundation

enum GeminiAnswerPromptBuilder {
    static func answerContents(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy
    ) throws -> [GeminiJSONObject] {
        try GeminiAnswerContentEncoder.encodeAnswerContents(
            question: question,
            sources: sources,
            policy: policy
        )
    }

    static func attributionContents(
        question: String,
        answerText: String,
        sources: [AnswerEvidencePacket]
    ) throws -> [GeminiJSONObject] {
        try GeminiAnswerContentEncoder.encodeAttributionContents(
            question: question,
            answerText: answerText,
            sources: sources
        )
    }

    static var attributionJSONSchema: GeminiJSONObject { CasebasePromptCatalog.ai.attributionJSONSchema }
}
