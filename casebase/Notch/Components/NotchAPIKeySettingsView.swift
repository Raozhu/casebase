import SwiftUI

struct NotchAPIKeySettingsView: View {
    @ObservedObject private var apiKeyStore = CasebaseAPIKeyStore.shared
    @State private var draftDeepSeekAPIKey = ""
    @State private var draftGoogleAPIKey = ""
    @State private var deepSeekMessage: String?
    @State private var deepSeekErrorMessage: String?
    @State private var googleMessage: String?
    @State private var googleErrorMessage: String?

    let isMeasuring: Bool
    let onBack: () -> Void

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.settingsAPIKeyLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                NotchBackIconButton(action: onBack)
            }

            apiKeyCard(
                isConfigured: apiKeyStore.isConfigured,
                configuredText: CasebasePromptCatalog.ui.settingsAPIKeyStatusConfigured,
                missingText: CasebasePromptCatalog.ui.settingsAPIKeyStatusMissing,
                placeholder: apiKeyStore.isConfigured
                    ? CasebasePromptCatalog.ui.settingsAPIKeyConfiguredPlaceholder
                    : CasebasePromptCatalog.ui.settingsAPIKeyPlaceholder,
                text: $draftDeepSeekAPIKey,
                errorMessage: deepSeekErrorMessage,
                statusMessage: deepSeekMessage,
                saveAction: saveDeepSeekAPIKey
            )

            apiKeyCard(
                isConfigured: apiKeyStore.googleKeyConfigured,
                configuredText: CasebasePromptCatalog.ui.settingsGoogleAPIKeyStatusConfigured,
                missingText: CasebasePromptCatalog.ui.settingsGoogleAPIKeyStatusMissing,
                placeholder: apiKeyStore.googleKeyConfigured
                    ? CasebasePromptCatalog.ui.settingsGoogleAPIKeyConfiguredPlaceholder
                    : CasebasePromptCatalog.ui.settingsGoogleAPIKeyPlaceholder,
                text: $draftGoogleAPIKey,
                errorMessage: googleErrorMessage,
                statusMessage: googleMessage,
                saveAction: saveGoogleAPIKey
            )

            if !isMeasuring {
                Spacer(minLength: 0)
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

    private func apiKeyCard(
        isConfigured: Bool,
        configuredText: String,
        missingText: String,
        placeholder: String,
        text: Binding<String>,
        errorMessage: String?,
        statusMessage: String?,
        saveAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                NotchPixelDisplayIcon(
                    icon: isConfigured ? .check : .warning,
                    tone: isConfigured ? .success : .warning,
                    size: 16,
                    glowOpacity: 0.12
                )
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 7) {
                    Text(isConfigured ? configuredText : missingText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(isConfigured ? 0.76 : 0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        SecureField(placeholder, text: text)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            }

                        Button(action: saveAction) {
                            Text(CasebasePromptCatalog.ui.settingsAPIKeySaveButtonTitle)
                        }
                        .buttonStyle(NotchActionButtonStyle(prominent: false))
                        .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isConfigured ? Color.white.opacity(0.035) : Color(red: 0.16, green: 0.13, blue: 0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isConfigured
                            ? Color.white.opacity(0.08)
                            : Color(red: 0.81, green: 0.64, blue: 0.19).opacity(0.35),
                        lineWidth: 1
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.9))
            } else if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.56))
            }
        }
    }

    private func saveDeepSeekAPIKey() {
        let trimmed = draftDeepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deepSeekMessage = nil
            deepSeekErrorMessage = CasebasePromptCatalog.ui.settingsAPIKeyEmptyMessage
            return
        }

        do {
            try apiKeyStore.saveDeepSeekAPIKey(trimmed)
            draftDeepSeekAPIKey = ""
            deepSeekErrorMessage = nil
            deepSeekMessage = CasebasePromptCatalog.ui.settingsAPIKeySavedMessage
        } catch {
            deepSeekMessage = nil
            deepSeekErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveGoogleAPIKey() {
        let trimmed = draftGoogleAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            googleMessage = nil
            googleErrorMessage = CasebasePromptCatalog.ui.settingsGoogleAPIKeyEmptyMessage
            return
        }

        do {
            try apiKeyStore.saveGoogleAPIKey(trimmed)
            draftGoogleAPIKey = ""
            googleErrorMessage = nil
            googleMessage = CasebasePromptCatalog.ui.settingsAPIKeySavedMessage
        } catch {
            googleMessage = nil
            googleErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    static func measuredContentHeight() -> CGFloat {
        let contentWidth: CGFloat = 480
        let rootView = NotchAPIKeySettingsView(isMeasuring: true, onBack: {})
            .frame(width: contentWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)

        let hostingView = NSHostingView(rootView: rootView)
        return ceil(hostingView.fittingSize.height + 40)
    }
}
