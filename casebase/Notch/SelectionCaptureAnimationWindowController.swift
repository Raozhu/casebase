import AppKit
import SwiftUI

@MainActor
final class SelectionCaptureAnimationWindowController: NSWindowController {
    private let model: SelectionCaptureAnimationModel

    init(screen: NSScreen) {
        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .mainMenu + 4
        window.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        window.hasShadow = false
        window.ignoresMouseEvents = true

        model = SelectionCaptureAnimationModel(screenFrame: screen.frame)
        super.init(window: window)

        contentViewController = NSHostingController(
            rootView: SelectionCaptureAnimationRootView(model: model)
        )
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func play(previewText: String, sourceRect: CGRect?, from sourcePoint: CGPoint, to targetPoint: CGPoint) {
        model.play(previewText: previewText, sourceRect: sourceRect, from: sourcePoint, to: targetPoint)
    }

    func play(image: NSImage, sourceRect: CGRect?, from sourcePoint: CGPoint, to targetPoint: CGPoint) {
        model.play(image: image, sourceRect: sourceRect, from: sourcePoint, to: targetPoint)
    }

    func destroy() {
        model.clear()
        contentViewController = nil
        window?.orderOut(nil)
        window = nil
    }
}

@MainActor
private final class SelectionCaptureAnimationModel: ObservableObject {
    @Published var activeFlight: SelectionCaptureFlight?
    let screenFrame: CGRect

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
    }

    func play(previewText: String, sourceRect: CGRect?, from sourcePoint: CGPoint, to targetPoint: CGPoint) {
        activeFlight = SelectionCaptureFlight(
            content: .text(previewText),
            sourceRect: sourceRect,
            sourcePoint: sourcePoint,
            targetPoint: targetPoint
        )
    }

    func play(image: NSImage, sourceRect: CGRect?, from sourcePoint: CGPoint, to targetPoint: CGPoint) {
        activeFlight = SelectionCaptureFlight(
            content: .image(image),
            sourceRect: sourceRect,
            sourcePoint: sourcePoint,
            targetPoint: targetPoint
        )
    }

    func clear() {
        activeFlight = nil
    }
}

private enum SelectionCaptureFlightContent {
    case text(String)
    case image(NSImage)
}

private struct SelectionCaptureFlight: Identifiable {
    let id = UUID()
    let content: SelectionCaptureFlightContent
    let sourceRect: CGRect?
    let sourcePoint: CGPoint
    let targetPoint: CGPoint
}

private struct SelectionCaptureAnimationRootView: View {
    @ObservedObject var model: SelectionCaptureAnimationModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let activeFlight = model.activeFlight {
                SelectionCaptureFlightView(
                    flight: activeFlight,
                    screenFrame: model.screenFrame
                ) {
                    model.clear()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

private struct SelectionCaptureFlightView: View {
    private let animationDuration: Double = 1.08
    let flight: SelectionCaptureFlight
    let screenFrame: CGRect
    let onCompletion: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }

            previewContent
        }
        .frame(width: tileSize.width, height: tileSize.height, alignment: .topLeading)
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18 * (1 - terminalProgress)), lineWidth: 1)
                .blur(radius: 6)
                .opacity(0.6 - (terminalProgress * 0.5))
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
        .shadow(color: Color.white.opacity(0.06), radius: 12)
        .compositingGroup()
        .position(currentPosition)
        .scaleEffect(x: scaleX, y: scaleY)
        .rotationEffect(.degrees(rotationDegrees))
        .opacity(opacity)
        .blur(radius: blurRadius)
        .saturation(Double(1 - (terminalProgress * 0.35)))
        .brightness(0.04 * (1 - progress))
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.timingCurve(0.18, 0.94, 0.18, 1, duration: animationDuration)) {
                progress = 1
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000) + 60_000_000)
                onCompletion()
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch flight.content {
        case let .text(previewText):
            VStack(alignment: .leading, spacing: tileSize.height > 56 ? 8 : 0) {
                Text(previewText)
                    .font(.system(size: tileSize.height > 64 ? 13 : 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(tileSize.height > 60 ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if tileSize.height > 56 {
                    VStack(alignment: .leading, spacing: 6) {
                        placeholderLine(widthFactor: 0.82)
                        placeholderLine(widthFactor: 0.56)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, tileSize.height > 56 ? 12 : 10)

        case let .image(image):
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize.width, height: tileSize.height)
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                }
        }
    }

    private func placeholderLine(widthFactor: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.18))
            .frame(width: max(32, tileSize.width * widthFactor), height: 5)
    }

    private var tileSize: CGSize {
        switch flight.content {
        case .image:
            return imageTileSize
        case let .text(previewText):
            return textTileSize(for: previewText)
        }
    }

    private var imageTileSize: CGSize {
        if let sourceRect = flight.sourceRect, !sourceRect.isEmpty {
            let scaled = aspectFitSize(for: sourceRect.size, maxSize: CGSize(width: 360, height: 220))
            return CGSize(
                width: clamp(scaled.width, min: 120, max: 360),
                height: clamp(scaled.height, min: 72, max: 220)
            )
        }

        return CGSize(width: 180, height: 120)
    }

    private func textTileSize(for previewText: String) -> CGSize {
        if let sourceRect = flight.sourceRect, !sourceRect.isEmpty {
            return CGSize(
                width: clamp(sourceRect.width + 42, min: 120, max: 360),
                height: clamp(sourceRect.height + 24, min: 40, max: 112)
            )
        }

        let measured = NSString(string: previewText).boundingRect(
            with: CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)],
            context: nil
        ).integral.size

        return CGSize(
            width: clamp(measured.width + 34, min: 120, max: 260),
            height: clamp(measured.height + 24, min: 40, max: 78)
        )
    }

    private var cornerRadius: CGFloat {
        clamp(tileSize.height * 0.28, min: 12, max: 18)
    }

    private var terminalProgress: CGFloat {
        max(0, min(1, (progress - 0.76) / 0.24))
    }

    private var scaleX: CGFloat {
        let travelPulse = CGFloat(sin(Double(progress) * .pi)) * 0.06
        return max(0.08, 1 + travelPulse - (terminalProgress * 0.56))
    }

    private var scaleY: CGFloat {
        let travelCompression = CGFloat(sin(Double(progress) * .pi)) * 0.05
        return max(0.08, 1 - travelCompression - (terminalProgress * 0.64))
    }

    private var rotationDegrees: Double {
        let start = localPoint(for: flight.sourcePoint)
        let end = localPoint(for: flight.targetPoint)
        let horizontalDirection = clamp((end.x - start.x) / 240, min: -1, max: 1)
        return Double(horizontalDirection) * Double(1 - terminalProgress) * 6
    }

    private var opacity: Double {
        Double(max(0.02, 1 - (terminalProgress * 0.94)))
    }

    private var blurRadius: CGFloat {
        terminalProgress * 16
    }

    private var currentPosition: CGPoint {
        let start = localPoint(for: flight.sourcePoint)
        let end = localPoint(for: flight.targetPoint)
        let distance = hypot(end.x - start.x, end.y - start.y)
        let arcHeight = clamp(max(118, distance * 0.24), min: 118, max: 240)
        let control1 = CGPoint(
            x: start.x + ((end.x - start.x) * 0.18),
            y: start.y - arcHeight
        )
        let control2 = CGPoint(
            x: start.x + ((end.x - start.x) * 0.78),
            y: end.y - (arcHeight * 0.58)
        )
        return cubicBezier(from: start, control1: control1, control2: control2, to: end, t: progress)
    }

    private func localPoint(for screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: screenPoint.x - screenFrame.minX,
            y: screenFrame.maxY - screenPoint.y
        )
    }

    private func cubicBezier(
        from start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        to end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let x = (oneMinusT * oneMinusT * oneMinusT * start.x)
            + (3 * oneMinusT * oneMinusT * t * control1.x)
            + (3 * oneMinusT * t * t * control2.x)
            + (t * t * t * end.x)
        let y = (oneMinusT * oneMinusT * oneMinusT * start.y)
            + (3 * oneMinusT * oneMinusT * t * control1.y)
            + (3 * oneMinusT * t * t * control2.y)
            + (t * t * t * end.y)
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    private func aspectFitSize(for size: CGSize, maxSize: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return maxSize }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height, 1)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
