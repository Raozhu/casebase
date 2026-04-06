import Foundation

// Shared answer-generation types used by retrieval and the notch UI.
enum AnswerScope: String, Codable, Hashable {
    case knowledgeOnly
    case knowledgeFirst
    case openEnded
}

struct AnswerPolicy: Codable, Hashable {
    let scope: AnswerScope
    let requiresCitations: Bool

    static let defaultOpenEnded = AnswerPolicy(scope: .openEnded, requiresCitations: true)

    init(scope: AnswerScope, requiresCitations: Bool = true) {
        self.scope = scope
        self.requiresCitations = requiresCitations
    }
}

struct AnswerCitation: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let shortSummary: String
    let relevantSnippet: String?

    init(
        id: UUID,
        title: String,
        shortSummary: String,
        relevantSnippet: String? = nil
    ) {
        self.id = id
        self.title = title
        self.shortSummary = shortSummary
        self.relevantSnippet = relevantSnippet
    }
}

struct AnswerResult: Codable, Hashable {
    let answerText: String
    let citedRecordIDs: [UUID]
    let citations: [AnswerCitation]
    let usedModelSupplement: Bool

    init(
        answerText: String,
        citedRecordIDs: [UUID] = [],
        citations: [AnswerCitation] = [],
        usedModelSupplement: Bool = false
    ) {
        self.answerText = answerText
        self.citedRecordIDs = citedRecordIDs
        self.citations = citations
        self.usedModelSupplement = usedModelSupplement
    }
}
