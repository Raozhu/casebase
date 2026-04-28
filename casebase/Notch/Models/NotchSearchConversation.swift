import Foundation

struct NotchSearchConversationTurn: Identifiable, Codable, Hashable {
    let id: UUID
    let question: String
    let answer: AnswerResult
    let createdAt: Date

    init(
        id: UUID = UUID(),
        question: String,
        answer: AnswerResult,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
    }
}

struct NotchSearchConversation: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var turns: [NotchSearchConversationTurn]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        turns: [NotchSearchConversationTurn] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.turns = turns
    }
}
