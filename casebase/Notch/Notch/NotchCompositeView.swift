import SwiftUI

struct NotchCompositeView: View {
    @ObservedObject var viewModel: NotchViewModel
    private let panelShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        panelShape
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            .background(
                panelShape
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                measuredContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            )
            .clipShape(panelShape)
            .padding(.top, 2)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var measuredContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                if showsChromeSettingsButton {
                    settingsButton
                }
            }

            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: NotchContentHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(NotchContentHeightPreferenceKey.self) { height in
            viewModel.updateMeasuredExpandedContentHeight(height, for: viewModel.surfaceState)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.surfaceState {
        case .idle:
            NotchIdleView()
        case .hoverActions:
            NotchHoverActionsView(
                onOpenLibrary: viewModel.openLibrary,
                onOpenSettings: viewModel.openSettings,
                showsSelectionCapturePrompt: !viewModel.selectionCaptureAuthorized,
                onAuthorizeSelectionCapture: viewModel.openSelectionCaptureAccessibilitySettings,
                showsScreenRecordingPrompt: !viewModel.screenshotCaptureAuthorized,
                onAuthorizeScreenRecording: viewModel.openScreenRecordingSettings
            )
        case .library:
            NotchLibraryView(viewModel: viewModel)
        case .libraryDetail:
            NotchLibraryDetailView(viewModel: viewModel)
        case .settings:
            NotchSettingsView(
                onClose: viewModel.closeSettings,
                showsSelectionCaptureAccess: !viewModel.selectionCaptureAuthorized,
                onOpenSelectionCaptureAccess: viewModel.openSelectionCaptureAccessibilitySettings,
                showsScreenRecordingAccess: !viewModel.screenshotCaptureAuthorized,
                onOpenScreenRecordingAccess: viewModel.openScreenRecordingSettings,
                onOpenClearData: viewModel.openDataResetConfirmation,
                onQuit: viewModel.quitApplication,
                canClearData: viewModel.canOpenDataResetConfirmation
            )
        case .settingsDataResetConfirmation:
            NotchSettingsDataResetConfirmationView(
                isClearing: viewModel.isClearingStoredData,
                onBack: viewModel.closeDataResetConfirmation,
                onConfirm: viewModel.confirmDataReset
            )
        case .dropTarget:
            NotchDropZoneView(noticeMessage: viewModel.noticeMessage)
        case .intakeFeedback:
            NotchDigestingFeedbackView(
                message: viewModel.intakeFeedbackMessage ?? CasebasePromptCatalog.ui.intakeDigestingFeedback
            )
        case .taskPanel:
            NotchTaskPanelView(viewModel: viewModel)
        case .ingesting:
            NotchImportProgressView(
                title: CasebasePromptCatalog.ui.ingestingTitle,
                detail: CasebasePromptCatalog.ui.ingestingDetail,
                footnote: viewModel.noticeMessage
            )
        case .savedPreview:
            NotchSavedPreviewView(viewModel: viewModel)
        case .answering:
            NotchImportProgressView(
                title: CasebasePromptCatalog.ui.answeringTitle,
                detail: CasebasePromptCatalog.ui.answeringDetail,
                footnote: nil
            )
        case .answerReady:
            NotchAnswerResultView(viewModel: viewModel)
        case .error:
            NotchErrorView(
                title: viewModel.currentErrorTitle,
                message: viewModel.currentErrorMessage,
                errorIndexLabel: viewModel.currentErrorIndexLabel,
                canNavigate: viewModel.hasMultipleFailedTasks,
                onPrevious: viewModel.selectPreviousFailedTask,
                onNext: viewModel.selectNextFailedTask,
                onRetry: viewModel.retryCurrentError,
                onDismiss: viewModel.dismissCurrentError,
                copyText: viewModel.currentErrorCopyText
            )
        }
    }

    private var showsChromeSettingsButton: Bool {
        switch viewModel.surfaceState {
        case .idle, .hoverActions, .library, .libraryDetail, .settings, .settingsDataResetConfirmation, .dropTarget, .intakeFeedback, .taskPanel, .savedPreview:
            return false
        case .ingesting, .answering, .answerReady, .error:
            return true
        }
    }

    private var settingsButton: some View {
        Button(action: viewModel.openSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct NotchContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
