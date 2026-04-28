import Foundation

// Shared answer-generation types used by retrieval and the notch UI.
enum AnswerScope: String, Codable, Hashable {
    case knowledgeOnly
    case knowledgeFirst
    case openEnded
}

enum AnswerQueryScope: Hashable {
    case global
    case recordIDs([UUID])
}

struct AnswerPolicy: Codable, Hashable {
    let scope: AnswerScope
    let requiresCitations: Bool

    static let defaultOpenEnded = AnswerPolicy(scope: .openEnded, requiresCitations: true)
    static let defaultKnowledgeFirst = AnswerPolicy(scope: .knowledgeFirst, requiresCitations: true)

    init(scope: AnswerScope, requiresCitations: Bool = true) {
        self.scope = scope
        self.requiresCitations = requiresCitations
    }
}

struct AnswerEvidencePacket: Identifiable, Hashable {
    let id: UUID
    let record: ImportRecord
    let rawText: String?
    let modelTextContext: String?
    let evidenceExcerpt: String?
    let attachments: [NormalizedAttachment]
    let previewAssetPath: String?
    let openTarget: String
    let matchedSnippets: [String]

    init(
        id: UUID,
        record: ImportRecord,
        rawText: String? = nil,
        modelTextContext: String? = nil,
        evidenceExcerpt: String? = nil,
        attachments: [NormalizedAttachment] = [],
        previewAssetPath: String? = nil,
        openTarget: String,
        matchedSnippets: [String] = []
    ) {
        self.id = id
        self.record = record
        self.rawText = rawText
        self.modelTextContext = modelTextContext
        self.evidenceExcerpt = evidenceExcerpt
        self.attachments = attachments
        self.previewAssetPath = previewAssetPath
        self.openTarget = openTarget
        self.matchedSnippets = matchedSnippets
    }
}

struct AnswerCitation: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceKind: ImportSourceKind
    let title: String
    let shortSummary: String
    let sourceTags: [String]
    let evidenceExcerpt: String?
    let previewAssetPath: String?
    let openTarget: String
    let supportNote: String?

    init(
        id: UUID,
        sourceKind: ImportSourceKind,
        title: String,
        shortSummary: String,
        sourceTags: [String] = [],
        evidenceExcerpt: String? = nil,
        previewAssetPath: String? = nil,
        openTarget: String,
        supportNote: String? = nil
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.title = title
        self.shortSummary = shortSummary
        self.sourceTags = sourceTags
        self.evidenceExcerpt = evidenceExcerpt
        self.previewAssetPath = previewAssetPath
        self.openTarget = openTarget
        self.supportNote = supportNote
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceKind
        case title
        case shortSummary
        case sourceTags
        case evidenceExcerpt
        case previewAssetPath
        case openTarget
        case supportNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceKind = try container.decode(ImportSourceKind.self, forKey: .sourceKind)
        title = try container.decode(String.self, forKey: .title)
        shortSummary = try container.decode(String.self, forKey: .shortSummary)
        sourceTags = try container.decodeIfPresent([String].self, forKey: .sourceTags) ?? []
        evidenceExcerpt = try container.decodeIfPresent(String.self, forKey: .evidenceExcerpt)
        previewAssetPath = try container.decodeIfPresent(String.self, forKey: .previewAssetPath)
        openTarget = try container.decode(String.self, forKey: .openTarget)
        supportNote = try container.decodeIfPresent(String.self, forKey: .supportNote)
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
