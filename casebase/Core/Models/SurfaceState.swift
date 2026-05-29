import Foundation

// Stable surface states so UI and orchestration can evolve without renaming state machines.
enum CasebaseSurfaceState: String, Codable, Hashable {
    case idle
    case hoverActions
    case meeting
    case meetingDiscardConfirmation
    case meetingFinishConfirmation
    case library
    case libraryDetail
    case settings
    case settingsAPIKeys
    case settingsDataResetConfirmation
    case dropTarget
    case intakeFeedback
    case taskPanel
    case ingesting
    case savedPreview
    case search
    case answering
    case answerReady
    case error
}

extension CasebaseSurfaceState {
    var keepsExpandedPresentation: Bool {
        switch self {
        case .idle, .hoverActions:
            return false
        case .meeting, .meetingDiscardConfirmation, .meetingFinishConfirmation, .library, .libraryDetail, .settings, .settingsAPIKeys, .settingsDataResetConfirmation, .dropTarget, .intakeFeedback, .taskPanel, .ingesting, .savedPreview, .search, .answering, .answerReady, .error:
            return true
        }
    }

    var usesAdaptiveExpandedHeight: Bool {
        switch self {
        case .idle:
            return false
        case .hoverActions, .meeting, .meetingDiscardConfirmation, .meetingFinishConfirmation, .library, .libraryDetail, .settings, .settingsAPIKeys, .settingsDataResetConfirmation, .dropTarget, .intakeFeedback, .taskPanel, .ingesting, .savedPreview, .search, .answering, .answerReady, .error:
            return true
        }
    }
}
