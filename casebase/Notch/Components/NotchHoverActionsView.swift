import SwiftUI

struct NotchHoverActionsView: View {
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void
    let showsSelectionCapturePrompt: Bool
    let onAuthorizeSelectionCapture: () -> Void
    let showsScreenRecordingPrompt: Bool
    let onAuthorizeScreenRecording: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if showsSelectionCapturePrompt {
                permissionPrompt(
                    title: CasebasePromptCatalog.ui.hoverActionAccessibilityTitle,
                    detail: CasebasePromptCatalog.ui.hoverActionAccessibilityDetail,
                    buttonTitle: CasebasePromptCatalog.ui.hoverActionAccessibilityButton,
                    iconName: "exclamationmark.triangle.fill",
                    action: onAuthorizeSelectionCapture
                )
            }

            if showsScreenRecordingPrompt {
                permissionPrompt(
                    title: CasebasePromptCatalog.ui.hoverActionScreenRecordingTitle,
                    detail: CasebasePromptCatalog.ui.hoverActionScreenRecordingDetail,
                    buttonTitle: CasebasePromptCatalog.ui.hoverActionScreenRecordingButton,
                    iconName: "display.trianglebadge.exclamationmark",
                    action: onAuthorizeScreenRecording
                )
            }

            HStack(spacing: 14) {
                HoverActionButton(
                    systemImage: "gearshape.fill",
                    helpText: CasebasePromptCatalog.ui.hoverActionSettingsTooltip,
                    action: onOpenSettings
                )

                HoverActionButton(
                    systemImage: "square.stack.3d.up.fill",
                    helpText: CasebasePromptCatalog.ui.hoverActionLibraryTooltip,
                    action: onOpenLibrary
                )

                HoverActionButton(
                    systemImage: "magnifyingglass",
                    helpText: CasebasePromptCatalog.ui.hoverActionSearchTooltip,
                    action: {}
                )
            }

            Text(CasebasePromptCatalog.ui.hoverActionHint)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func permissionPrompt(
        title: String,
        detail: String,
        buttonTitle: String,
        iconName: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.34))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color(red: 0.35, green: 0.29, blue: 0.06))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Text(buttonTitle)
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
}

private struct HoverActionButton: View {
    let systemImage: String
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
