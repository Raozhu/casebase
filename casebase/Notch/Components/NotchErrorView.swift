import SwiftUI

struct NotchErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(CasebasePromptCatalog.ui.errorTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onRetry) {
                    Text(CasebasePromptCatalog.ui.retryButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: true))

                Button(action: onClear) {
                    Text(CasebasePromptCatalog.ui.clearButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
