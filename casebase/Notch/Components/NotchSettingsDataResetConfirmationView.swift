import AppKit
import SwiftUI

struct NotchSettingsDataResetConfirmationView: View {
    let isClearing: Bool
    let isMeasuring: Bool
    let onBack: () -> Void
    let onConfirm: () -> Void

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(CasebasePromptCatalog.ui.settingsClearDataConfirmationTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                NotchBackIconButton(action: onBack)
                    .disabled(isClearing)
            }

            Text(CasebasePromptCatalog.ui.settingsClearDataConfirmationDetail)
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
                    title: CasebasePromptCatalog.ui.settingsClearDataCancelButtonTitle,
                    action: onBack
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(isClearing)

                LibraryActionTileButton(
                    icon: isClearing ? .hourglass : .trash,
                    title: isClearing
                        ? CasebasePromptCatalog.ui.settingsClearDataProgressTitle
                        : CasebasePromptCatalog.ui.settingsClearDataConfirmButtonTitle,
                    isDestructive: true,
                    action: onConfirm
                )
                .frame(width: LibraryActionTileButton.standardWidth)
                .disabled(isClearing)
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

    static func measuredContentHeight(isClearing: Bool = false) -> CGFloat {
        let contentWidth: CGFloat = 480
        let rootView = NotchSettingsDataResetConfirmationView(
            isClearing: isClearing,
            isMeasuring: true,
            onBack: {},
            onConfirm: {}
        )
        .frame(width: contentWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)

        let hostingView = NSHostingView(rootView: rootView)
        return ceil(hostingView.fittingSize.height + 40)
    }
}
