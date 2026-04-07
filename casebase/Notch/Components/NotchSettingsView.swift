import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject private var languageController = CasebaseLanguageController.shared
    let onClose: () -> Void
    let showsSelectionCaptureAccess: Bool
    let onOpenSelectionCaptureAccess: () -> Void
    let showsScreenRecordingAccess: Bool
    let onOpenScreenRecordingAccess: () -> Void
    let onOpenClearData: () -> Void
    let onQuit: () -> Void
    let canClearData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.settingsTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onClose) {
                    Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
            }

            VStack(alignment: .leading, spacing: 10) {
                NotchLanguagePickerView(
                    selectedLanguage: languageController.language,
                    onSelectLanguage: languageController.setLanguage
                )
            }

            if showsSelectionCaptureAccess {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onOpenSelectionCaptureAccess) {
                        Text(CasebasePromptCatalog.ui.settingsAccessibilityButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NotchActionButtonStyle(prominent: false))
                }
            }

            if showsScreenRecordingAccess {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: onOpenScreenRecordingAccess) {
                        Text(CasebasePromptCatalog.ui.settingsScreenRecordingButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NotchActionButtonStyle(prominent: false))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onOpenClearData) {
                    Text(CasebasePromptCatalog.ui.settingsClearDataButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
                .disabled(!canClearData)
            }

            Button(action: onQuit) {
                Text(CasebasePromptCatalog.ui.settingsQuitButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NotchActionButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
