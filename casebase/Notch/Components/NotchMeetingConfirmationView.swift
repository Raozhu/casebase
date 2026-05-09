import AppKit
import SwiftUI

struct NotchMeetingConfirmationView: View {
    let title: String
    let detail: String
    let confirmTitle: String
    let confirmIcon: NotchPixelIcon
    let isConfirmDestructive: Bool
    let isProcessing: Bool
    let isMeasuring: Bool
    let onBack: () -> Void
    let onConfirm: () -> Void

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                NotchBackIconButton(action: onBack)
                    .disabled(isProcessing)
            }

            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if !isMeasuring {
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                LibraryActionTileButton(
                    icon: .cross,
                    title: CasebasePromptCatalog.ui.settingsCloseButtonTitle,
                    action: onBack
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(isProcessing)

                LibraryActionTileButton(
                    icon: isProcessing ? .hourglass : confirmIcon,
                    title: isProcessing
                        ? CasebasePromptCatalog.ui.settingsClearDataProgressTitle
                        : confirmTitle,
                    isDestructive: isConfirmDestructive,
                    action: onConfirm
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(isProcessing)
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
}
