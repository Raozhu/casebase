import Foundation

enum StructuredFieldValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([StructuredFieldValue])
    case object([String: StructuredFieldValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: StructuredFieldValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([StructuredFieldValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                StructuredFieldValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported structured field value.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct ClarificationQuestion: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let reason: String
    let suggestedOptions: [String]

    init(
        id: String,
        title: String,
        reason: String,
        suggestedOptions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.reason = reason
        self.suggestedOptions = suggestedOptions
    }
}

struct ClarificationRequest: Codable, Hashable {
    let uncertaintySummary: String
    let impactExplanation: String
    let questions: [ClarificationQuestion]

    init(
        uncertaintySummary: String,
        impactExplanation: String,
        questions: [ClarificationQuestion] = []
    ) {
        self.uncertaintySummary = uncertaintySummary
        self.impactExplanation = impactExplanation
        self.questions = questions
    }
}

struct ClarificationAnswer: Codable, Hashable {
    let questionID: String
    let questionTitle: String
    let answer: String

    init(questionID: String, questionTitle: String, answer: String) {
        self.questionID = questionID
        self.questionTitle = questionTitle
        self.answer = answer
    }
}

struct ClarificationRound: Codable, Hashable {
    let roundIndex: Int
    let answers: [ClarificationAnswer]
    let skippedQuestionTitles: [String]
    let createdAt: Date

    init(
        roundIndex: Int,
        answers: [ClarificationAnswer],
        skippedQuestionTitles: [String] = [],
        createdAt: Date = Date()
    ) {
        self.roundIndex = roundIndex
        self.answers = answers
        self.skippedQuestionTitles = skippedQuestionTitles
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case roundIndex
        case answers
        case skippedQuestionTitles
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roundIndex = try container.decode(Int.self, forKey: .roundIndex)
        answers = try container.decode([ClarificationAnswer].self, forKey: .answers)
        skippedQuestionTitles = try container.decodeIfPresent([String].self, forKey: .skippedQuestionTitles) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roundIndex, forKey: .roundIndex)
        try container.encode(answers, forKey: .answers)
        try container.encode(skippedQuestionTitles, forKey: .skippedQuestionTitles)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// Persisted knowledge records and analysis outputs shared across import, storage, and QA.
struct ImportRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var assetPath: String
    var assetHash: String
    var fileName: String
    var mimeType: String?
    var sourceKind: ImportSourceKind
    var contentType: String
    var scene: String
    var purpose: String
    var title: String
    var shortSummary: String
    var usefulSnippets: [String]
    var tags: [String]
    var structuredData: [String: StructuredFieldValue]
    var searchText: String
    var userSupplement: String?
    var clarificationRequest: ClarificationRequest?
    var clarificationHistory: [ClarificationRound]
    var clarificationRoundCount: Int
    var needsReview: Bool
    var embedding: [Float]
    var parseStatus: RecordParseStatus
    var createdAt: Date
    var updatedAt: Date
    var importCount: Int

    init(
        id: UUID = UUID(),
        assetPath: String,
        assetHash: String,
        fileName: String,
        mimeType: String? = nil,
        sourceKind: ImportSourceKind,
        contentType: String,
        scene: String,
        purpose: String,
        title: String,
        shortSummary: String,
        usefulSnippets: [String],
        tags: [String],
        structuredData: [String: StructuredFieldValue] = [:],
        searchText: String,
        userSupplement: String? = nil,
        clarificationRequest: ClarificationRequest? = nil,
        clarificationHistory: [ClarificationRound] = [],
        clarificationRoundCount: Int = 0,
        needsReview: Bool = false,
        embedding: [Float] = [],
        parseStatus: RecordParseStatus,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        importCount: Int = 1
    ) {
        self.id = id
        self.assetPath = assetPath
        self.assetHash = assetHash
        self.fileName = fileName
        self.mimeType = mimeType
        self.sourceKind = sourceKind
        self.contentType = contentType
        self.scene = scene
        self.purpose = purpose
        self.title = title
        self.shortSummary = shortSummary
        self.usefulSnippets = usefulSnippets
        self.tags = tags
        self.structuredData = structuredData
        self.searchText = searchText
        self.userSupplement = userSupplement
        self.clarificationRequest = clarificationRequest
        self.clarificationHistory = clarificationHistory
        self.clarificationRoundCount = clarificationRoundCount
        self.needsReview = needsReview
        self.embedding = embedding
        self.parseStatus = parseStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importCount = importCount
    }

    mutating func registerReimport(at timestamp: Date = Date()) {
        importCount += 1
        updatedAt = timestamp
    }
}

struct AnalysisResult: Codable, Hashable {
    let contentType: String
    let scene: String
    let purpose: String
    let title: String
    let shortSummary: String
    let aiThoughtSummary: String?
    let usefulSnippets: [String]
    let tags: [String]
    let structuredData: [String: StructuredFieldValue]
    let searchText: String
    let clarificationRequest: ClarificationRequest?
    let needsReview: Bool

    init(
        contentType: String,
        scene: String,
        purpose: String,
        title: String,
        shortSummary: String,
        aiThoughtSummary: String? = nil,
        usefulSnippets: [String] = [],
        tags: [String] = [],
        structuredData: [String: StructuredFieldValue] = [:],
        searchText: String,
        clarificationRequest: ClarificationRequest? = nil,
        needsReview: Bool = false
    ) {
        self.contentType = contentType
        self.scene = scene
        self.purpose = purpose
        self.title = title
        self.shortSummary = shortSummary
        self.aiThoughtSummary = aiThoughtSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.usefulSnippets = usefulSnippets
        self.tags = tags
        self.structuredData = structuredData
        self.searchText = searchText
        self.clarificationRequest = clarificationRequest
        self.needsReview = needsReview
    }
}

struct SearchHit: Codable, Hashable {
    let record: ImportRecord
    let score: Double
    let matchedSnippets: [String]

    init(record: ImportRecord, score: Double, matchedSnippets: [String] = []) {
        self.record = record
        self.score = score
        self.matchedSnippets = matchedSnippets
    }
}
