import AppKit
import SwiftUI

struct NotchMeetingView: View {
    @ObservedObject var viewModel: NotchViewModel
    let isMeasuring: Bool

    init(viewModel: NotchViewModel, isMeasuring: Bool = false) {
        self.viewModel = viewModel
        self.isMeasuring = isMeasuring
    }

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.meetingTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                NotchBackIconButton(action: viewModel.closeMeeting)
            }

            if viewModel.hasActiveMeetingSession {
                activeSessionContent
            } else {
                draftContent
            }
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var draftContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.meetingPanelTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            if viewModel.meetingRecorderPermissionStatus == .denied {
                permissionPrompt
            }

            if let meetingErrorMessage = viewModel.meetingErrorMessage {
                Text(meetingErrorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            participantCard
            topicCard

            if !isMeasuring {
                Spacer(minLength: 0)
            }

            HStack {
                Spacer(minLength: 0)

                LibraryActionTileButton(
                    icon: .play,
                    title: CasebasePromptCatalog.ui.meetingStartButtonTitle,
                    action: viewModel.startMeetingRecording
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(viewModel.isMeetingRecorderBusy)
            }
        }
    }

    private var activeSessionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard

            if let meetingErrorMessage = viewModel.meetingErrorMessage {
                Text(meetingErrorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.68, blue: 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            infoCard

            if !isMeasuring {
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                LibraryActionTileButton(
                    icon: .trash,
                    title: CasebasePromptCatalog.ui.meetingCancelButtonTitle,
                    isDestructive: true,
                    action: viewModel.requestMeetingDiscard
                )
                .frame(width: LibraryActionTileButton.standardWidth)

                LibraryActionTileButton(
                    icon: viewModel.isMeetingPaused ? .play : .pause,
                    title: viewModel.isMeetingPaused
                        ? CasebasePromptCatalog.ui.meetingResumeButtonTitle
                        : CasebasePromptCatalog.ui.meetingPauseButtonTitle,
                    action: viewModel.toggleMeetingPauseResume
                )
                .frame(width: LibraryActionTileButton.standardWidth)

                LibraryActionTileButton(
                    icon: .check,
                    title: CasebasePromptCatalog.ui.meetingFinishButtonTitle,
                    action: viewModel.requestMeetingFinish
                )
                .frame(width: LibraryActionTileButton.standardWidth)
            }
            .disabled(viewModel.isMeetingRecorderBusy)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var permissionPrompt: some View {
        HStack(spacing: 12) {
            NotchPixelDisplayIcon(icon: .warning, tone: .warning, size: 18, glowOpacity: 0.14)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(CasebasePromptCatalog.ui.meetingPermissionDeniedMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: viewModel.openMicrophoneSettings) {
                Text(CasebasePromptCatalog.ui.meetingPermissionButtonTitle)
            }
            .buttonStyle(NotchActionButtonStyle(prominent: false))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.16, green: 0.13, blue: 0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(red: 0.81, green: 0.64, blue: 0.19).opacity(0.35), lineWidth: 1)
        }
    }

    private var participantCard: some View {
        meetingCard(
            title: CasebasePromptCatalog.ui.meetingParticipantLabel,
            icon: .people
        ) {
            HStack(spacing: 10) {
                meetingStepperButton(title: "-", action: {
                    viewModel.meetingParticipantCount = max(1, viewModel.meetingParticipantCount - 1)
                })

                Text(CasebasePromptCatalog.ui.meetingParticipantValue(viewModel.meetingParticipantCount))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 64, alignment: .center)

                meetingStepperButton(title: "+", action: {
                    viewModel.meetingParticipantCount = min(99, viewModel.meetingParticipantCount + 1)
                })
            }
        }
    }

    private var topicCard: some View {
        meetingCard(
            title: CasebasePromptCatalog.ui.meetingTopicLabel,
            icon: .audio
        ) {
            TextField(
                "",
                text: $viewModel.meetingTopic,
                prompt: Text(CasebasePromptCatalog.ui.meetingTopicPlaceholder)
                    .foregroundStyle(Color.white.opacity(0.34))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.white)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let pulse = CGFloat(sin(elapsed * 5.2))
                    let scale = viewModel.isMeetingPaused ? 1 : 1 + (pulse * 0.08)

                    Circle()
                        .fill(viewModel.isMeetingPaused
                            ? Color.white.opacity(0.38)
                            : Color(red: 1.0, green: 0.29, blue: 0.38))
                        .frame(width: 10, height: 10)
                        .scaleEffect(scale)
                }

                Text(viewModel.meetingPanelTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CasebasePromptCatalog.ui.meetingDurationLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))

                Text(viewModel.meetingElapsedDurationText)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            infoRow(
                title: CasebasePromptCatalog.ui.meetingParticipantLabel,
                value: viewModel.meetingParticipantValueText,
                icon: .people
            )
            infoRow(
                title: CasebasePromptCatalog.ui.meetingTopicLabel,
                value: viewModel.meetingTopicValueText,
                icon: .audio
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private func meetingCard<Content: View>(
        title: String,
        icon: NotchPixelIcon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                NotchPixelIconView(icon: icon, color: Color.white.opacity(0.78), size: 12)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.58))
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private func meetingStepperButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(NotchChromeIconButtonStyle())
    }

    private func infoRow(title: String, value: String, icon: NotchPixelIcon) -> some View {
        HStack(spacing: 10) {
            NotchPixelIconView(icon: icon, color: Color.white.opacity(0.78), size: 12)
                .frame(width: 16, height: 16)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.56))
                .frame(width: 42, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
