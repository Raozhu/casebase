import SwiftUI

struct NotchTaskRailView: View {
    let state: NotchTaskRailState
    let text: String
    let showsShimmer: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TaskRailShimmerText(text: text, isAnimating: showsShimmer)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(baseTextColor)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minWidth: 132, alignment: .leading)
                .background(
                    Capsule(style: .continuous)
                        .fill(.black.opacity(0.94))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var baseTextColor: Color {
        switch state {
        case .success:
            return Color.white.opacity(0.84)
        case .preparing, .recognizing, .storing, .needsInput:
            return Color.white.opacity(0.46)
        }
    }
}

private struct TaskRailShimmerText: View {
    let text: String
    let isAnimating: Bool

    @State private var shimmerOffset: CGFloat = -1.2

    var body: some View {
        Text(text)
            .overlay {
                if isAnimating {
                    GeometryReader { proxy in
                        shimmerGradient
                            .frame(width: max(80, proxy.size.width * 0.52))
                            .offset(x: proxy.size.width * shimmerOffset)
                            .mask(
                                Text(text)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            )
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                updateAnimation()
            }
            .onChange(of: isAnimating) {
                updateAnimation()
            }
            .animation(
                isAnimating
                    ? .linear(duration: 1.28).repeatForever(autoreverses: false)
                    : .default,
                value: shimmerOffset
            )
    }

    private var shimmerGradient: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.24),
                Color.white.opacity(0.95),
                Color.white.opacity(0.18),
                Color.white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func updateAnimation() {
        if isAnimating {
            shimmerOffset = 1.4
        } else {
            shimmerOffset = -1.2
        }
    }
}
