import Foundation

// Stable surface states so UI and orchestration can evolve without renaming state machines.
enum CasebaseSurfaceState: String, Codable, Hashable {
    case idle
    case hoverActions
    case library
    case libraryDetail
    case settings
    case settingsDataResetConfirmation
    case dropTarget
    case intakeFeedback
    case taskPanel
    case ingesting
    case savedPreview
    case answering
    case answerReady
    case error
}

extension CasebaseSurfaceState {
    var keepsExpandedPresentation: Bool {
        switch self {
        case .idle, .hoverActions:
            return false
        case .library, .libraryDetail, .settings, .settingsDataResetConfirmation, .dropTarget, .intakeFeedback, .taskPanel, .ingesting, .savedPreview, .answering, .answerReady, .error:
            return true
        }
    }

    var usesAdaptiveExpandedHeight: Bool {
        switch self {
        case .hoverActions, .settings, .settingsDataResetConfirmation, .ingesting, .savedPreview, .answering, .answerReady, .error:
            return true
        case .idle, .library, .libraryDetail, .dropTarget, .intakeFeedback, .taskPanel:
            return false
        }
    }
}
