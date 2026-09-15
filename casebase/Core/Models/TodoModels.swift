import Foundation

enum MeetingActionItemStatus: String, Codable, Hashable {
    case pending
    case accepted
    case dismissed
}

struct MeetingActionItemCandidate: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let owner: String
    let dueAt: Date?
    let dueText: String
    let reason: String
    let evidence: String
    let suggestedQuadrant: TodoQuadrant
    var status: MeetingActionItemStatus

    init(
        id: UUID = UUID(),
        title: String,
        owner: String = "",
        dueAt: Date? = nil,
        dueText: String = "",
        reason: String,
        evidence: String,
        suggestedQuadrant: TodoQuadrant = .importantNotUrgent,
        status: MeetingActionItemStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.owner = owner
        self.dueAt = dueAt
        self.dueText = dueText
        self.reason = reason
        self.evidence = evidence
        self.suggestedQuadrant = suggestedQuadrant
        self.status = status
    }
}

enum TodoQuadrant: String, Codable, CaseIterable, Hashable, Identifiable {
    case importantUrgent = "important_urgent"
    case importantNotUrgent = "important_not_urgent"
    case urgentNotImportant = "urgent_not_important"
    case notImportantNotUrgent = "not_important_not_urgent"

    var id: String { rawValue }

    var sortRank: Int {
        switch self {
        case .importantUrgent: return 1
        case .importantNotUrgent: return 2
        case .urgentNotImportant: return 3
        case .notImportantNotUrgent: return 4
        }
    }
}

enum TodoOrigin: String, Codable, Hashable {
    case manual
    case meeting
    case mcp
    case breakdown
}

struct TodoSourceReference: Codable, Hashable, Identifiable {
    let recordID: UUID
    let title: String
    let sourceKind: ImportSourceKind
    let evidence: String

    var id: UUID { recordID }

    init(recordID: UUID, title: String, sourceKind: ImportSourceKind, evidence: String = "") {
        self.recordID = recordID
        self.title = title
        self.sourceKind = sourceKind
        self.evidence = evidence
    }
}

struct TodoItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let dueAt: Date?
    let quadrant: TodoQuadrant
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let sourceReferences: [TodoSourceReference]
    let sourceReason: String
    let executionResult: String
    let origin: TodoOrigin
    let lastProgressAt: Date
    let deferredUntil: Date?
    let parentTodoID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        dueAt: Date? = nil,
        quadrant: TodoQuadrant = .importantNotUrgent,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        sourceReferences: [TodoSourceReference] = [],
        sourceReason: String = "",
        executionResult: String = "",
        origin: TodoOrigin = .manual,
        lastProgressAt: Date? = nil,
        deferredUntil: Date? = nil,
        parentTodoID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.dueAt = dueAt
        self.quadrant = quadrant
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.sourceReferences = sourceReferences
        self.sourceReason = sourceReason
        self.executionResult = executionResult
        self.origin = origin
        self.lastProgressAt = lastProgressAt ?? updatedAt
        self.deferredUntil = deferredUntil
        self.parentTodoID = parentTodoID
    }


    func isStale(at date: Date = Date(), inactivityDays: Int = 7) -> Bool {
        guard !isCompleted else { return false }
        if let deferredUntil, deferredUntil > date { return false }
        let threshold = Calendar.current.date(byAdding: .day, value: -inactivityDays, to: date)
            ?? date.addingTimeInterval(-Double(inactivityDays) * 86_400)
        return lastProgressAt < threshold
    }
}

struct TodoFilters: Hashable {
    let query: String?
    let quadrant: TodoQuadrant?
    let isCompleted: Bool?
    let dueBefore: Date?
    let dueAfter: Date?

    init(
        query: String? = nil,
        quadrant: TodoQuadrant? = nil,
        isCompleted: Bool? = nil,
        dueBefore: Date? = nil,
        dueAfter: Date? = nil
    ) {
        self.query = query
        self.quadrant = quadrant
        self.isCompleted = isCompleted
        self.dueBefore = dueBefore
        self.dueAfter = dueAfter
    }
}

struct TodoPage: Hashable {
    let items: [TodoItem]
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

enum TodoPaging {
    static let defaultLimit = 50
    static let maximumLimit = 200

    static func normalizedLimit(_ limit: Int) -> Int {
        min(max(limit, 1), maximumLimit)
    }

    static func normalizedOffset(_ offset: Int) -> Int {
        max(offset, 0)
    }
}
