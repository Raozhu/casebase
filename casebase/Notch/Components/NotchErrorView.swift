import AppKit
import SwiftUI

struct NotchErrorView: View {
    let title: String
    let message: String
    let errorIndexLabel: String?
    let canNavigate: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onRetry: () -> Void
    let onDismiss: () -> Void
    let copyText: String
    @State private var isCopyHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(alignment: .top, spacing: 10) {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    copyButton
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }

            HStack(spacing: 10) {
                Button(action: onRetry) {
                    Text(CasebasePromptCatalog.ui.retryButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: true))

                Button(action: onDismiss) {
                    Text(CasebasePromptCatalog.ui.clearButtonTitle)
                }
                .buttonStyle(NotchActionButtonStyle(prominent: false))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38))

            Text(CasebasePromptCatalog.ui.errorTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            if canNavigate {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(NotchIconButtonStyle())

                if let errorIndexLabel {
                    Text(errorIndexLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .frame(minWidth: 34)
                }

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(NotchIconButtonStyle())
            }
        }
    }

    private var copyButton: some View {
        Button(action: copyErrorText) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCopyHovered ? Color.white.opacity(0.92) : Color.white.opacity(0.42))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(isCopyHovered ? 0.08 : 0.03))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            isCopyHovered = isHovered
        }
    }

    private func copyErrorText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copyText, forType: .string)
    }
}

private struct NotchIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.96 : 0.68))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
    }
}
