import SwiftUI

struct NotchDropZoneView: View {
    let noticeMessage: String?
    let showsAnimation: Bool
    let isMeasuring: Bool
    @State private var isFloating = false

    init(noticeMessage: String?, showsAnimation: Bool = true, isMeasuring: Bool = false) {
        self.noticeMessage = noticeMessage
        self.showsAnimation = showsAnimation
        self.isMeasuring = isMeasuring
    }

    @ViewBuilder
    var body: some View {
        let content = VStack(spacing: 12) {
            if !isMeasuring {
                Spacer(minLength: 0)
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.44),
                    style: StrokeStyle(lineWidth: 2.5, dash: [10, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .frame(height: 138)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(y: isFloating ? -4 : 4)

                        Text(CasebasePromptCatalog.ui.dropZoneCallToAction)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isFloating
                    )
                }
                .shadow(color: Color.white.opacity(0.08), radius: 16, y: 8)

            if let noticeMessage {
                Text(noticeMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            if !isMeasuring {
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            guard showsAnimation else { return }
            isFloating = true
        }

        if isMeasuring {
            content
                .frame(maxWidth: .infinity, alignment: .top)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
