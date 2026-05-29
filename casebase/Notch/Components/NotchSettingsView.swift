import Carbon.HIToolbox
import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject private var languageController = CasebaseLanguageController.shared
    @ObservedObject private var hotKeyStore = CasebaseHotKeyStore.shared
    @ObservedObject private var apiKeyStore = CasebaseAPIKeyStore.shared
    @State private var recordingAction: CasebaseHotKeyAction?
    @State private var shortcutErrorMessage: String?
    @State private var keyMonitor: Any?
    let allowsLiveShortcutRecording: Bool
    let isMeasuring: Bool
    let onClose: () -> Void
    let showsSelectionCaptureAccess: Bool
    let onOpenSelectionCaptureAccess: () -> Void
    let showsScreenRecordingAccess: Bool
    let onOpenScreenRecordingAccess: () -> Void
    let onOpenClearData: () -> Void
    let onOpenAPIKeys: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void
    let canClearData: Bool

    init(
        allowsLiveShortcutRecording: Bool = true,
        isMeasuring: Bool = false,
        onClose: @escaping () -> Void,
        showsSelectionCaptureAccess: Bool,
        onOpenSelectionCaptureAccess: @escaping () -> Void,
        showsScreenRecordingAccess: Bool,
        onOpenScreenRecordingAccess: @escaping () -> Void,
        onOpenClearData: @escaping () -> Void,
        onOpenAPIKeys: @escaping () -> Void,
        onRestart: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        canClearData: Bool
    ) {
        self.allowsLiveShortcutRecording = allowsLiveShortcutRecording
        self.isMeasuring = isMeasuring
        self.onClose = onClose
        self.showsSelectionCaptureAccess = showsSelectionCaptureAccess
        self.onOpenSelectionCaptureAccess = onOpenSelectionCaptureAccess
        self.showsScreenRecordingAccess = showsScreenRecordingAccess
        self.onOpenScreenRecordingAccess = onOpenScreenRecordingAccess
        self.onOpenClearData = onOpenClearData
        self.onOpenAPIKeys = onOpenAPIKeys
        self.onRestart = onRestart
        self.onQuit = onQuit
        self.canClearData = canClearData
    }

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.settingsTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                NotchBackIconButton(action: onClose)
            }

            shortcutsSection

            modelAccessSection

            if !isMeasuring {
                Spacer(minLength: 0)
            }

            bottomActionArea
        }
        .onAppear {
            guard allowsLiveShortcutRecording else { return }
            updateMonitorState()
        }
        .onChange(of: recordingAction) { _, _ in
            guard allowsLiveShortcutRecording else { return }
            updateMonitorState()
        }
        .onDisappear {
            guard allowsLiveShortcutRecording else { return }
            removeKeyMonitor()
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CasebasePromptCatalog.ui.settingsShortcutsLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.46))

            VStack(alignment: .leading, spacing: 12) {
                HotKeyRecorderRow(
                    title: CasebasePromptCatalog.ui.settingsSelectionShortcutLabel,
                    shortcut: hotKeyStore.selectionCaptureShortcut,
                    isRecording: recordingAction == .selectionCapture,
                    onStartRecording: { beginRecording(.selectionCapture) },
                    onReset: {
                        hotKeyStore.resetShortcut(for: .selectionCapture)
                        shortcutErrorMessage = nil
                    }
                )

                HotKeyRecorderRow(
                    title: CasebasePromptCatalog.ui.settingsScreenshotShortcutLabel,
                    shortcut: hotKeyStore.screenshotCaptureShortcut,
                    isRecording: recordingAction == .screenshotCapture,
                    onStartRecording: { beginRecording(.screenshotCapture) },
                    onReset: {
                        hotKeyStore.resetShortcut(for: .screenshotCapture)
                        shortcutErrorMessage = nil
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutErrorMessage {
                Text(shortcutErrorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.9))
            }
        }
    }

    private var modelAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(CasebasePromptCatalog.ui.settingsAPIKeyLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.46))

            Button(action: onOpenAPIKeys) {
                SettingsNavigationRow(
                    icon: apiKeyStore.isConfigured ? .check : .warning,
                    tone: apiKeyStore.isConfigured ? .success : .warning,
                    title: CasebasePromptCatalog.ui.settingsAPIKeyLabel,
                    detail: apiKeyStore.isConfigured
                        ? CasebasePromptCatalog.ui.settingsAPIKeyStatusConfigured
                        : CasebasePromptCatalog.ui.settingsAPIKeyStatusMissing
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var footerActionRow: some View {
        HStack(spacing: 10) {
            NotchLanguagePickerView(
                selectedLanguage: languageController.language,
                onSelectLanguage: languageController.setLanguage
            )

            Spacer(minLength: 0)

            LibraryActionTileButton(
                icon: .trash,
                title: CasebasePromptCatalog.ui.settingsClearActionTitle,
                action: onOpenClearData
            )
            .frame(width: LibraryActionTileButton.standardWidth)
            .disabled(!canClearData)

            LibraryActionTileButton(
                icon: .refresh,
                title: CasebasePromptCatalog.ui.settingsRestartActionTitle,
                action: onRestart
            )
            .frame(width: LibraryActionTileButton.standardWidth)

            LibraryActionTileButton(
                icon: .power,
                title: CasebasePromptCatalog.ui.settingsQuitActionTitle,
                isDestructive: true,
                action: onQuit
            )
            .frame(width: LibraryActionTileButton.standardWidth)
        }
    }

    private var bottomActionArea: some View {
        footerActionRow
    }

    private func beginRecording(_ action: CasebaseHotKeyAction) {
        shortcutErrorMessage = nil
        recordingAction = action
    }

    private func updateMonitorState() {
        if recordingAction == nil {
            removeKeyMonitor()
            return
        }

        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action = recordingAction else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                recordingAction = nil
                shortcutErrorMessage = nil
                return nil
            }

            guard let shortcut = CasebaseHotKeyDescriptor(event: event) else {
                return nil
            }

            guard hotKeyStore.setShortcut(shortcut, for: action) else {
                shortcutErrorMessage = CasebasePromptCatalog.ui.settingsShortcutDuplicateMessage
                return nil
            }

            shortcutErrorMessage = nil
            recordingAction = nil
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    static func measuredContentHeight(
        showsSelectionCaptureAccess: Bool,
        showsScreenRecordingAccess: Bool,
        canClearData: Bool
    ) -> CGFloat {
        let contentWidth: CGFloat = 480
        let rootView = NotchSettingsView(
            allowsLiveShortcutRecording: false,
            isMeasuring: true,
            onClose: {},
            showsSelectionCaptureAccess: showsSelectionCaptureAccess,
            onOpenSelectionCaptureAccess: {},
            showsScreenRecordingAccess: showsScreenRecordingAccess,
            onOpenScreenRecordingAccess: {},
            onOpenClearData: {},
            onOpenAPIKeys: {},
            onRestart: {},
            onQuit: {},
            canClearData: canClearData
        )
        .frame(width: contentWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)

        let hostingView = NSHostingView(rootView: rootView)
        return ceil(hostingView.fittingSize.height + 40)
    }
}

private struct SettingsNavigationRow: View {
    let icon: NotchPixelIcon
    let tone: NotchPixelTone
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            NotchPixelDisplayIcon(icon: icon, tone: tone, size: 16, glowOpacity: 0.12)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            NotchPixelIconView(
                icon: .chevronRight,
                color: Color.white.opacity(0.48),
                size: 10
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct HotKeyRecorderRow: View {
    let title: String
    let shortcut: CasebaseHotKeyDescriptor
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 16)

            HStack(spacing: 6) {
                Button(action: onStartRecording) {
                    Text(isRecording ? CasebasePromptCatalog.ui.settingsShortcutRecordingState : shortcut.displayString)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isRecording ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isRecording ? Color.white : Color.white.opacity(0.06))
                        )
                        .frame(width: 96)
                }
                .buttonStyle(.plain)

                Button(action: onReset) {
                    NotchPixelIconView(
                        icon: .reset,
                        color: Color.white.opacity(0.82),
                        size: 10
                    )
                }
                .buttonStyle(NotchShortcutResetIconButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NotchShortcutResetIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.96 : 0.56))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.04))
            )
    }
}
