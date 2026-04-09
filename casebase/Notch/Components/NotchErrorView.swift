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
    let isMeasuring: Bool
    @State private var isCopyHovered = false

    @ViewBuilder
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
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

            if !isMeasuring {
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                LibraryActionTileButton(
                    icon: .refresh,
                    title: CasebasePromptCatalog.ui.retryButtonTitle,
                    action: onRetry
                )
                .frame(width: LibraryActionTileButton.standardWidth)

                LibraryActionTileButton(
                    icon: .check,
                    title: CasebasePromptCatalog.ui.clearButtonTitle,
                    action: onDismiss
                )
                .frame(width: LibraryActionTileButton.standardWidth)
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

    private var header: some View {
        HStack(spacing: 10) {
            NotchPixelDisplayIcon(icon: .cross, tone: .danger, size: 16, glowOpacity: 0.14)

            Text(CasebasePromptCatalog.ui.errorTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            if canNavigate {
                Button(action: onPrevious) {
                    NotchPixelIconView(icon: .chevronLeft, color: Color.white.opacity(0.82), size: 10)
                }
                .buttonStyle(NotchIconButtonStyle())

                if let errorIndexLabel {
                    Text(errorIndexLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .frame(minWidth: 34)
                }

                Button(action: onNext) {
                    NotchPixelIconView(icon: .chevronRight, color: Color.white.opacity(0.82), size: 10)
                }
                .buttonStyle(NotchIconButtonStyle())
            }
        }
    }

    private var copyButton: some View {
        Button(action: copyErrorText) {
            NotchPixelIconView(
                icon: .copy,
                color: isCopyHovered ? Color.white.opacity(0.92) : Color.white.opacity(0.42),
                size: 13
            )
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
