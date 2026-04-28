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
            .overlay(alignment: .topLeading) {
                visibleContent
            }
            .clipShape(panelShape)
            .padding(.top, 2)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var visibleContent: some View {
        panelContent(forMeasurement: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .topLeading) {
                if viewModel.surfaceState.usesAdaptiveExpandedHeight {
                    panelContent(forMeasurement: true)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .allowsHitTesting(false)
                }
            }
    }

    private func panelContent(forMeasurement: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                if showsChromeSettingsButton {
                    settingsButton
                }
            }

            content(forMeasurement: forMeasurement)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .background {
            if forMeasurement {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: NotchContentHeightPreferenceKey.self, value: proxy.size.height)
                }
            }
        }
        .onPreferenceChange(NotchContentHeightPreferenceKey.self) { height in
            guard forMeasurement else { return }
            viewModel.updateMeasuredExpandedContentHeight(height, for: viewModel.surfaceState)
        }
    }

    @ViewBuilder
    private func content(forMeasurement: Bool) -> some View {
        switch viewModel.surfaceState {
        case .idle:
            EmptyView()
        case .hoverActions:
            NotchHoverActionsView(
                onOpenLibrary: viewModel.openLibrary,
                onOpenSettings: viewModel.openSettings,
                onOpenSearch: viewModel.openSearch,
                showsSelectionCapturePrompt: !viewModel.selectionCaptureAuthorized,
                onAuthorizeSelectionCapture: viewModel.openSelectionCaptureAccessibilitySettings,
                showsScreenRecordingPrompt: !viewModel.screenshotCaptureAuthorized,
                onAuthorizeScreenRecording: viewModel.openScreenRecordingSettings,
                isMeasuring: forMeasurement
            )
        case .library:
            NotchLibraryView(viewModel: viewModel, isMeasuring: forMeasurement)
        case .libraryDetail:
            NotchLibraryDetailView(viewModel: viewModel, isMeasuring: forMeasurement)
        case .settings:
            NotchSettingsView(
                allowsLiveShortcutRecording: !forMeasurement,
                isMeasuring: forMeasurement,
                onClose: viewModel.closeSettings,
                showsSelectionCaptureAccess: !viewModel.selectionCaptureAuthorized,
                onOpenSelectionCaptureAccess: viewModel.openSelectionCaptureAccessibilitySettings,
                showsScreenRecordingAccess: !viewModel.screenshotCaptureAuthorized,
                onOpenScreenRecordingAccess: viewModel.openScreenRecordingSettings,
                onOpenClearData: viewModel.openDataResetConfirmation,
                onRestart: viewModel.restartApplication,
                onQuit: viewModel.quitApplication,
                canClearData: viewModel.canOpenDataResetConfirmation
            )
        case .settingsDataResetConfirmation:
            NotchSettingsDataResetConfirmationView(
                isClearing: viewModel.isClearingStoredData,
                isMeasuring: forMeasurement,
                onBack: viewModel.closeDataResetConfirmation,
                onConfirm: viewModel.confirmDataReset
            )
        case .dropTarget:
            NotchDropZoneView(
                noticeMessage: viewModel.noticeMessage,
                showsAnimation: !forMeasurement,
                isMeasuring: forMeasurement
            )
        case .intakeFeedback:
            NotchDigestingFeedbackView(
                message: viewModel.intakeFeedbackMessage ?? CasebasePromptCatalog.ui.intakeDigestingFeedback
            )
        case .taskPanel:
            NotchTaskPanelView(viewModel: viewModel, isMeasuring: forMeasurement)
        case .ingesting:
            NotchImportProgressView(
                title: CasebasePromptCatalog.ui.ingestingTitle,
                detail: CasebasePromptCatalog.ui.ingestingDetail,
                footnote: viewModel.noticeMessage
            )
        case .savedPreview:
            NotchSavedPreviewView(viewModel: viewModel)
        case .search:
            NotchAnswerResultView(viewModel: viewModel)
        case .answering:
            NotchAnswerResultView(viewModel: viewModel)
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
                copyText: viewModel.currentErrorCopyText,
                isMeasuring: forMeasurement
            )
        }
    }

    private var showsChromeSettingsButton: Bool {
        switch viewModel.surfaceState {
        case .idle, .hoverActions, .library, .libraryDetail, .settings, .settingsDataResetConfirmation, .dropTarget, .intakeFeedback, .taskPanel, .savedPreview, .search:
            return false
        case .ingesting, .answering, .answerReady, .error:
            return true
        }
    }

    private var settingsButton: some View {
        Button(action: viewModel.openSettings) {
            NotchPixelDisplayIcon(icon: .gear, tone: .neutral, size: 14, glowOpacity: 0.08)
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
