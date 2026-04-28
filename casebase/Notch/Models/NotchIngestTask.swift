import Foundation

enum NotchIngestTaskStatus: Equatable {
    case queued
    case preparing
    case recognizing
    case storing
    case needsInput
    case succeeded
    case failed(String)
}

enum NotchTaskRailState: Equatable {
    case preparing
    case recognizing
    case storing
    case needsInput
    case success
}

struct NotchIngestTask: Identifiable, Equatable {
    let id: UUID
    let payload: ImportPayload
    let sourceKind: ImportSourceKind
    var title: String
    var status: NotchIngestTaskStatus
    var record: ImportRecord?
    var thinkingText: String?
    var progressDetail: String?
    var supplementDraft: String
    var clarificationAnswers: [String: String]
    var skippedClarificationQuestionIDs: [String]
    var clarificationValidationMessage: String?
    var currentClarificationQuestionIndex: Int
    var prefersAutomaticExpansion: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        payload: ImportPayload,
        sourceKind: ImportSourceKind,
        title: String,
        status: NotchIngestTaskStatus = .queued,
        record: ImportRecord? = nil,
        thinkingText: String? = nil,
        progressDetail: String? = nil,
        supplementDraft: String = "",
        clarificationAnswers: [String: String] = [:],
        skippedClarificationQuestionIDs: [String] = [],
        clarificationValidationMessage: String? = nil,
        currentClarificationQuestionIndex: Int = 0,
        prefersAutomaticExpansion: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.payload = payload
        self.sourceKind = sourceKind
        self.title = title
        self.status = status
        self.record = record
        self.thinkingText = thinkingText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.progressDetail = progressDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.supplementDraft = supplementDraft
        self.clarificationAnswers = clarificationAnswers
        self.skippedClarificationQuestionIDs = skippedClarificationQuestionIDs
        self.clarificationValidationMessage = clarificationValidationMessage
        self.currentClarificationQuestionIndex = currentClarificationQuestionIndex
        self.prefersAutomaticExpansion = prefersAutomaticExpansion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isPending: Bool {
        switch status {
        case .queued, .preparing, .recognizing, .storing, .needsInput:
            return true
        case .succeeded, .failed:
            return false
        }
    }

    var isCompleted: Bool {
        !isPending
    }
}
