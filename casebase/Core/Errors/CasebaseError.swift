import Foundation

enum CasebaseError: LocalizedError, Equatable {
    case missingConfiguration(String)
    case unsupportedPayload(String)
    case invalidPayload(String)
    case normalizationFailed(String)
    case analysisFailed(String)
    case storageFailed(String)
    case answerFailed(String)
    case operationTimedOut(String)
    case recordNotFound(UUID)
    case emptyQuery
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .missingConfiguration(name):
            return CasebasePromptCatalog.errors.missingConfiguration(name)
        case let .unsupportedPayload(description):
            return CasebasePromptCatalog.errors.unsupportedPayload(description)
        case let .invalidPayload(description):
            return CasebasePromptCatalog.errors.invalidPayload(description)
        case let .normalizationFailed(description):
            return CasebasePromptCatalog.errors.normalizationFailed(description)
        case let .analysisFailed(description):
            return CasebasePromptCatalog.errors.analysisFailed(description)
        case let .storageFailed(description):
            return CasebasePromptCatalog.errors.storageFailed(description)
        case let .answerFailed(description):
            return CasebasePromptCatalog.errors.answerFailed(description)
        case let .operationTimedOut(description):
            return CasebasePromptCatalog.errors.operationTimedOut(description)
        case let .recordNotFound(id):
            return CasebasePromptCatalog.errors.recordNotFound(id)
        case .emptyQuery:
            return CasebasePromptCatalog.errors.emptyQuery
        case .emptyResponse:
            return CasebasePromptCatalog.errors.emptyResponse
        }
    }
}
