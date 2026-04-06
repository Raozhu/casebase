import SwiftUI

struct NotchTaskRailView: View {
    let state: NotchTaskRailState
    let badgeText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                statusIcon

                if showsFlowBar {
                    TaskRailFlowBarView(state: state)
                        .frame(width: 92, height: 6)
                }

                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
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

    private var showsFlowBar: Bool {
        switch state {
        case .needsInput, .success:
            return false
        case .preparing, .recognizing, .storing:
            return true
        }
    }

    private var statusIcon: some View {
        RotatingRailIcon(
            systemName: iconName,
            tint: iconTint,
            shouldRotate: state == .recognizing
        )
    }

    private var iconName: String {
        switch state {
        case .preparing:
            return "circle.dashed"
        case .recognizing:
            return "viewfinder.circle.fill"
        case .storing:
            return "arrow.down.circle.fill"
        case .needsInput:
            return "questionmark.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        }
    }

    private var iconTint: Color {
        switch state {
        case .preparing:
            return Color.white.opacity(0.86)
        case .recognizing:
            return Color(red: 0.57, green: 0.82, blue: 1.0)
        case .storing:
            return Color(red: 0.54, green: 1.0, blue: 0.82)
        case .needsInput:
            return Color(red: 1.0, green: 0.81, blue: 0.43)
        case .success:
            return Color(red: 0.55, green: 1.0, blue: 0.72)
        }
    }
}

private struct RotatingRailIcon: View {
    let systemName: String
    let tint: Color
    let shouldRotate: Bool
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                updateRotation()
            }
            .onChange(of: shouldRotate) {
                updateRotation()
            }
            .animation(
                shouldRotate
                    ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                    : .default,
                value: rotation
            )
    }

    private func updateRotation() {
        rotation = shouldRotate ? 360 : 0
    }
}

private struct TaskRailFlowBarView: View {
    let state: NotchTaskRailState
    @State private var shimmerOffset: CGFloat = -84

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(alignment: .leading) {
                        LinearGradient(
                            colors: [
                                accent.opacity(0.0),
                                accent.opacity(0.24),
                                accent,
                                accent.opacity(0.22),
                                accent.opacity(0.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 60)
                        .offset(x: shimmerOffset)
                    }
                    .clipped()
            }
            .onAppear {
                shimmerOffset = 96
            }
            .animation(
                .linear(duration: animationDuration).repeatForever(autoreverses: false),
                value: shimmerOffset
            )
    }

    private var accent: Color {
        switch state {
        case .preparing:
            return Color.white.opacity(0.82)
        case .recognizing:
            return Color(red: 0.48, green: 0.84, blue: 1.0)
        case .storing:
            return Color(red: 0.52, green: 1.0, blue: 0.78)
        case .needsInput, .success:
            return .clear
        }
    }

    private var animationDuration: Double {
        switch state {
        case .preparing:
            return 1.6
        case .recognizing:
            return 0.9
        case .storing:
            return 1.5
        case .needsInput, .success:
            return 0
        }
    }
}
