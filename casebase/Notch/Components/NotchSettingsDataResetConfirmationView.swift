import SwiftUI

struct NotchSettingsDataResetConfirmationView: View {
    let isClearing: Bool
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.settingsClearDataConfirmationTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onBack) {
                    Text(CasebasePromptCatalog.ui.settingsCloseButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
                .disabled(isClearing)
            }

            Text(CasebasePromptCatalog.ui.settingsClearDataConfirmationDetail)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onBack) {
                    Text(CasebasePromptCatalog.ui.settingsClearDataCancelButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
                .disabled(isClearing)

                Button(action: onConfirm) {
                    Text(
                        isClearing
                            ? CasebasePromptCatalog.ui.settingsClearDataProgressTitle
                            : CasebasePromptCatalog.ui.settingsClearDataConfirmButtonTitle
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: true))
                .disabled(isClearing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
