import Foundation

// Shared ingest-side value types for drag/drop intake and normalized extraction output.
enum ImportSourceKind: String, Codable, Hashable {
    case image
    case text
    case pdf
    case audio
    case folder
    case binary
}

struct FileImportPayload: Hashable {
    let fileURL: URL
    let suggestedFileName: String?
    let mimeType: String?
    let sourceKindHint: ImportSourceKind?
    let contextMetadata: [String: String]

    init(
        fileURL: URL,
        suggestedFileName: String? = nil,
        mimeType: String? = nil,
        sourceKindHint: ImportSourceKind? = nil,
        contextMetadata: [String: String] = [:]
    ) {
        self.fileURL = fileURL
        self.suggestedFileName = suggestedFileName
        self.mimeType = mimeType
        self.sourceKindHint = sourceKindHint
        self.contextMetadata = contextMetadata
    }
}

struct TextImportPayload: Hashable {
    let text: String
    let suggestedFileName: String?
    let mimeType: String?
    let contextMetadata: [String: String]

    init(
        text: String,
        suggestedFileName: String? = nil,
        mimeType: String? = "text/plain",
        contextMetadata: [String: String] = [:]
    ) {
        self.text = text
        self.suggestedFileName = suggestedFileName
        self.mimeType = mimeType
        self.contextMetadata = contextMetadata
    }
}

enum ImportPayload: Hashable {
    case file(FileImportPayload)
    case text(TextImportPayload)

    var displayName: String {
        switch self {
        case let .file(payload):
            return payload.suggestedFileName ?? payload.fileURL.lastPathComponent
        case let .text(payload):
            return payload.suggestedFileName ?? CasebasePromptCatalog.ui.draggedTextFileName
        }
    }

    var mimeType: String? {
        switch self {
        case let .file(payload):
            return payload.mimeType
        case let .text(payload):
            return payload.mimeType
        }
    }

    var sourceKindHint: ImportSourceKind? {
        switch self {
        case let .file(payload):
            return payload.sourceKindHint
        case .text:
            return .text
        }
    }

    var contextMetadata: [String: String] {
        switch self {
        case let .file(payload):
            return payload.contextMetadata
        case let .text(payload):
            return payload.contextMetadata
        }
    }
}

enum NormalizedAttachmentKind: String, Codable, Hashable {
    case originalAsset
    case imagePreview
    case pagePreview
    case audioSource
    case supplementalAsset
}

struct NormalizedAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: NormalizedAttachmentKind
    let path: String
    let mimeType: String?

    init(
        id: UUID = UUID(),
        kind: NormalizedAttachmentKind,
        path: String,
        mimeType: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.mimeType = mimeType
    }
}

struct NormalizedContent: Codable, Hashable {
    let sourceKind: ImportSourceKind
    let rawText: String?
    let attachments: [NormalizedAttachment]
    let fallbackMetadata: [String: String]

    init(
        sourceKind: ImportSourceKind,
        rawText: String? = nil,
        attachments: [NormalizedAttachment] = [],
        fallbackMetadata: [String: String] = [:]
    ) {
        self.sourceKind = sourceKind
        self.rawText = rawText
        self.attachments = attachments
        self.fallbackMetadata = fallbackMetadata
    }
}

enum RecordParseStatus: String, Codable, Hashable {
    case pending
    case ready
    case partial
    case failed
}

enum ImportProcessingPhase: String, Codable, Hashable {
    case preparing
    case recognizing
    case storing
}

struct ImportProgressUpdate: Codable, Hashable, Sendable {
    let phase: ImportProcessingPhase
    let thoughtText: String?
    let detailText: String?

    init(
        phase: ImportProcessingPhase,
        thoughtText: String? = nil,
        detailText: String? = nil
    ) {
        self.phase = phase
        self.thoughtText = thoughtText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.detailText = detailText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
