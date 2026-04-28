import SwiftUI

struct NotchHoverActionsView: View {
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSearch: () -> Void
    let showsSelectionCapturePrompt: Bool
    let onAuthorizeSelectionCapture: () -> Void
    let showsScreenRecordingPrompt: Bool
    let onAuthorizeScreenRecording: () -> Void
    let isMeasuring: Bool

    @ViewBuilder
    var body: some View {
        let content = VStack(spacing: 20) {
            if showsSelectionCapturePrompt {
                permissionPrompt(
                    title: CasebasePromptCatalog.ui.hoverActionAccessibilityTitle,
                    detail: CasebasePromptCatalog.ui.hoverActionAccessibilityDetail,
                    buttonTitle: CasebasePromptCatalog.ui.hoverActionAccessibilityButton,
                    icon: .warning,
                    action: onAuthorizeSelectionCapture
                )
            }

            if showsScreenRecordingPrompt {
                permissionPrompt(
                    title: CasebasePromptCatalog.ui.hoverActionScreenRecordingTitle,
                    detail: CasebasePromptCatalog.ui.hoverActionScreenRecordingDetail,
                    buttonTitle: CasebasePromptCatalog.ui.hoverActionScreenRecordingButton,
                    icon: .warning,
                    action: onAuthorizeScreenRecording
                )
            }

            HStack(spacing: 14) {
                HoverActionButton(
                    icon: .gear,
                    helpText: CasebasePromptCatalog.ui.hoverActionSettingsTooltip,
                    action: onOpenSettings
                )

                HoverActionButton(
                    icon: .library,
                    helpText: CasebasePromptCatalog.ui.hoverActionLibraryTooltip,
                    action: onOpenLibrary
                )

                HoverActionButton(
                    icon: .search,
                    helpText: CasebasePromptCatalog.ui.hoverActionSearchTooltip,
                    action: onOpenSearch
                )
            }

            Text(CasebasePromptCatalog.ui.hoverActionHint)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func permissionPrompt(
        title: String,
        detail: String,
        buttonTitle: String,
        icon: NotchPixelIcon,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            NotchPixelDisplayIcon(icon: icon, tone: .warning, size: 18, glowOpacity: 0.14)
                .frame(width: 30, height: 30)

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
    let icon: NotchPixelIcon
    let helpText: String
    let action: () -> Void

    private var label: String {
        switch icon {
        case .gear:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "设置" : "Settings"
        case .library:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "数据" : "Library"
        case .search:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "探索" : "Explore"
        default:
            return ""
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)

                    NotchPixelDisplayIcon(icon: icon, tone: .neutral, size: 20, glowOpacity: 0.08)
                }
                .frame(width: 56, height: 48)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
