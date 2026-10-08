import SwiftUI

struct NotchHoverActionsView: View {
    let onOpenMeeting: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenTodos: () -> Void
    let onOpenSearch: () -> Void
    let onOpenRoundTable: () -> Void
    let showsSelectionCapturePrompt: Bool
    let onAuthorizeSelectionCapture: () -> Void
    let showsScreenRecordingPrompt: Bool
    let onAuthorizeScreenRecording: () -> Void
    let showsAPIKeyPrompt: Bool
    let onOpenAPIKeySettings: () -> Void
    let isMeasuring: Bool
    @ObservedObject private var knights = CasebaseKnightsService.shared
    @ObservedObject private var activity = KnightsActivityCenter.shared
    @ObservedObject private var hotKeys = CasebaseHotKeyStore.shared

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

            if showsAPIKeyPrompt {
                permissionPrompt(
                    title: CasebasePromptCatalog.ui.hoverActionAPIKeyTitle,
                    detail: CasebasePromptCatalog.ui.hoverActionAPIKeyDetail,
                    buttonTitle: CasebasePromptCatalog.ui.hoverActionAPIKeyButton,
                    icon: .warning,
                    action: onOpenAPIKeySettings
                )
            }

            HStack(spacing: 8) {
                HoverActionButton(
                    icon: .search,
                    helpText: CasebasePromptCatalog.ui.hoverActionSearchTooltip,
                    action: onOpenSearch
                )

                HoverActionButton(
                    icon: .library,
                    helpText: activity.unseenTeamMemoryCount > 0
                        ? "\(CasebasePromptCatalog.ui.hoverActionLibraryTooltip) · 新增 \(activity.unseenTeamMemoryCount) 条团队记忆"
                        : CasebasePromptCatalog.ui.hoverActionLibraryTooltip,
                    badgeCount: activity.unseenTeamMemoryCount,
                    action: onOpenLibrary
                )

                HoverActionButton(
                    icon: .check,
                    helpText: CasebasePromptCatalog.ui.hoverActionTodoTooltip,
                    action: onOpenTodos
                )

                HoverActionButton(
                    icon: .sword,
                    helpText: CasebasePromptCatalog.language == .simplifiedChinese
                        ? "圆桌 · 召集 AI 骑士（\(hotKeys.roundTableShortcut.displayString)）"
                        : "Round Table · summon the AI knights (\(hotKeys.roundTableShortcut.displayString))",
                    statusDotColor: knightsStatusDotColor,
                    badgeCount: activity.unreadCount,
                    action: onOpenRoundTable
                )
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                MeetingShortcutButton(action: onOpenMeeting)

                Spacer(minLength: 0)

                Text(CasebasePromptCatalog.ui.hoverActionHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    /// Panel height before the live measurement arrives, so the first open isn't clipped.
    /// Mirrors NotchCompositeView: 20pt padding, the 32pt settings row and 14pt spacing.
    static func measuredPanelHeight(
        showsSelectionCapturePrompt: Bool,
        showsScreenRecordingPrompt: Bool,
        showsAPIKeyPrompt: Bool,
        panelWidth: CGFloat
    ) -> CGFloat {
        let rootView = NotchHoverActionsView(
            onOpenMeeting: {},
            onOpenLibrary: {},
            onOpenTodos: {},
            onOpenSearch: {},
            onOpenRoundTable: {},
            showsSelectionCapturePrompt: showsSelectionCapturePrompt,
            onAuthorizeSelectionCapture: {},
            showsScreenRecordingPrompt: showsScreenRecordingPrompt,
            onAuthorizeScreenRecording: {},
            showsAPIKeyPrompt: showsAPIKeyPrompt,
            onOpenAPIKeySettings: {},
            isMeasuring: true
        )
        .frame(width: panelWidth - 4 - 40, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)

        let hostingView = NSHostingView(rootView: rootView)
        return ceil(hostingView.fittingSize.height + 40 + 32 + 14)
    }

    private var knightsStatusDotColor: Color? {
        switch knights.status {
        case .running:
            return Color(red: 0.36, green: 0.82, blue: 0.48)
        case .starting:
            return Color.white.opacity(0.45)
        case .portConflict, .nodeMissing, .failed:
            return Color(red: 0.93, green: 0.36, blue: 0.33)
        case .idle:
            return nil
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
    var statusDotColor: Color? = nil
    var badgeCount = 0
    let action: () -> Void

    private var label: String {
        switch icon {
        case .check:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "待办" : "To-do"
        case .library:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "数据" : "Library"
        case .search:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "探索" : "Explore"
        case .sword:
            return CasebasePromptCatalog.language == .simplifiedChinese ? "圆桌" : "Round Table"
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
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(alignment: .topTrailing) {
                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Capsule().fill(Color(red: 1.0, green: 0.73, blue: 0.22)))
                            .padding(5)
                    } else if let statusDotColor {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 6, height: 6)
                            .padding(7)
                    }
                }

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .help(helpText)
    }
}

private struct MeetingShortcutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.93, green: 0.36, blue: 0.33))
                    .frame(width: 6, height: 6)
                Text(CasebasePromptCatalog.language == .simplifiedChinese ? "录音" : "Record")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Never let the hint text squeeze the capsule (that flattened its rounded ends).
        .fixedSize()
        .layoutPriority(1)
        .help(CasebasePromptCatalog.language == .simplifiedChinese ? "开始录音（会议、访谈都可以）" : "Start a recording")
    }
}
