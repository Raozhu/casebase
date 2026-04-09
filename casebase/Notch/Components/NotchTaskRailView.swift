import SwiftUI

struct NotchTaskRailView: View {
    let state: NotchTaskRailState
    let text: String
    let showsShimmer: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TaskRailAnimatedLabel(text: text, isAnimating: showsShimmer)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(minWidth: 112, alignment: .center)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.94))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: glowColor.opacity(0.22), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var borderColor: Color { glowColor.opacity(0.18) }

    private var glowColor: Color {
        switch state {
        case .success:
            return Color(red: 0.41, green: 0.92, blue: 0.62)
        case .needsInput:
            return Color(red: 1.0, green: 0.73, blue: 0.22)
        case .preparing, .recognizing, .storing:
            return Color.white
        }
    }
}

private struct TaskRailAnimatedLabel: View {
    let text: String
    let isAnimating: Bool

    var body: some View {
        railText
            .foregroundStyle(Color.white.opacity(isAnimating ? 0.42 : 0.84))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: true, vertical: false)
            .overlay {
                if isAnimating {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let cycle = context.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 1.35) / 1.35

                        GeometryReader { proxy in
                            let highlightWidth = max(48, proxy.size.width * 0.7)
                            let travelDistance = proxy.size.width + highlightWidth * 2
                            let offset = -highlightWidth + (travelDistance * cycle)

                            shimmerGradient
                                .frame(width: highlightWidth, height: proxy.size.height + 2)
                                .offset(x: offset)
                                .mask(
                                    railText
                                        .lineLimit(1)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private var railText: Text {
        Text(text)
            .font(.system(size: 11, weight: .medium))
    }

    private var shimmerGradient: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.12),
                Color.white.opacity(0.96),
                Color.white.opacity(0.24),
                Color.white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
