import AppKit
import SwiftUI

/// A fake 14" MacBook screen that hosts the app's real notch views offscreen,
/// plus a synthetic cursor and props, and records frames of a region of it.
@MainActor
final class Stage {
    static let size = CGSize(width: 1512, height: 982)
    static let cutoutSize = CGSize(width: 185, height: 32)
    /// Far away from any real display so NSEvent.mouseLocation never hovers the fake notch.
    static let screenFrame = CGRect(origin: CGPoint(x: -20000, y: -20000), size: size)

    let viewModel: NotchViewModel
    let props = StageProps()
    let flightModel = SelectionCaptureAnimationModel(screenFrame: Stage.screenFrame)
    let screenshotOverlay: ScreenshotCaptureOverlayView

    private let window: NSWindow
    private let root: FlippedView
    private let notchHost: NSHostingView<AnyView>
    private var recorder: FrameRecorder?

    init(services: DemoServices) {
        let cutoutRect = CGRect(
            x: Stage.screenFrame.minX + (Stage.size.width - Stage.cutoutSize.width) / 2,
            y: Stage.screenFrame.maxY - Stage.cutoutSize.height,
            width: Stage.cutoutSize.width,
            height: Stage.cutoutSize.height
        )
        viewModel = NotchViewModel(
            screenFrame: Stage.screenFrame,
            displayCutoutRect: cutoutRect,
            importCoordinator: services.importCoordinator,
            answerService: services.answerService,
            libraryService: services.libraryService,
            todoService: services.todoService,
            audioTranscriptService: services.audioTranscriptService,
            storageRootDirectory: services.storageRoot,
            demoModeEnabled: false
        )

        window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -6000, y: -6000), size: Stage.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        root = FlippedView(frame: CGRect(origin: .zero, size: Stage.size))
        let full = CGRect(origin: .zero, size: Stage.size)

        let backdrop = NSHostingView(rootView: DemoBackdrop(props: props))
        backdrop.frame = full
        root.addSubview(backdrop)

        screenshotOverlay = ScreenshotCaptureOverlayView(
            frame: full,
            screenFrame: Stage.screenFrame,
            onCancel: {},
            onConfirm: { _ in }
        )
        screenshotOverlay.isHidden = true
        root.addSubview(screenshotOverlay)

        notchHost = NSHostingView(rootView: AnyView(NotchView(viewModel: viewModel)))
        notchHost.frame = CGRect(x: 0, y: 0, width: Stage.size.width, height: 700)
        root.addSubview(notchHost)

        let flightHost = NSHostingView(rootView: SelectionCaptureAnimationRootView(model: flightModel))
        flightHost.frame = full
        root.addSubview(flightHost)

        let overlay = NSHostingView(rootView: DemoOverlay(props: props))
        overlay.frame = full
        root.addSubview(overlay)

        window.contentView = root
        window.orderFrontRegardless()
    }

    // MARK: Coordinates

    /// Stage points use a top-left origin; the app works in global screen coordinates.
    static func screenPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: screenFrame.minX + point.x, y: screenFrame.maxY - point.y)
    }

    static func screenRect(_ rect: CGRect) -> CGRect {
        CGRect(x: screenFrame.minX + rect.minX, y: screenFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    var notchCenter: CGPoint { CGPoint(x: Stage.size.width / 2, y: Stage.cutoutSize.height / 2) }

    /// Finds an on-screen element of the notch UI by its accessibility label or help text.
    func elementFrame(_ label: String, occurrence: Int = 0) -> CGRect? {
        var matches: [CGRect] = []
        func walk(_ element: Any, depth: Int) {
            guard depth < 40, let element = element as? NSAccessibilityProtocol else { return }
            let texts = [
                element.accessibilityLabel(),
                element.accessibilityHelp(),
                element.accessibilityValue() as? String,
                element.accessibilityTitle(),
            ].compactMap { $0 }
            if texts.contains(where: { $0 == label }) {
                matches.append(element.accessibilityFrame())
            }
            for child in element.accessibilityChildren() ?? [] {
                walk(child, depth: depth + 1)
            }
        }
        walk(notchHost, depth: 0)
        guard occurrence < matches.count else { return nil }
        let screenRect = matches[occurrence]
        let windowRect = window.convertFromScreen(screenRect)
        return root.convert(windowRect, from: nil)
    }

    func dumpAccessibility() {
        func walk(_ element: Any, depth: Int) {
            guard depth < 40, let element = element as? NSAccessibilityProtocol else { return }
            let texts = [element.accessibilityLabel(), element.accessibilityHelp(), element.accessibilityTitle()]
                .compactMap { $0 }.filter { !$0.isEmpty }
            if !texts.isEmpty {
                let rect = root.convert(window.convertFromScreen(element.accessibilityFrame()), from: nil)
                print(String(repeating: " ", count: depth) + "\(element.accessibilityRole()?.rawValue ?? "?") \(texts) \(rect.integral)")
            }
            for child in element.accessibilityChildren() ?? [] { walk(child, depth: depth + 1) }
        }
        walk(notchHost, depth: 0)
    }

    /// Scrolls the first scroll view inside the notch UI to its end, the way a trackpad would.
    func scrollNotchToBottom(duration: TimeInterval) async {
        guard let scrollView = notchHost.firstDescendant(of: NSScrollView.self) else { return }
        let clip = scrollView.contentView
        let farthest = clip.constrainBoundsRect(CGRect(origin: CGPoint(x: 0, y: 1_000_000), size: clip.bounds.size))
        await scrollNotch(by: max(0, farthest.origin.y - clip.bounds.origin.y), duration: duration)
    }

    /// Scrolls the first scroll view inside the notch UI, the way a trackpad would.
    func scrollNotch(by delta: CGFloat, duration: TimeInterval) async {
        guard let scrollView = notchHost.firstDescendant(of: NSScrollView.self) else { return }
        let clip = scrollView.contentView
        let start = clip.bounds.origin.y
        let steps = max(1, Int(duration * 60))
        for step in 1...steps {
            let t = easeInOut(Double(step) / Double(steps))
            clip.scroll(to: CGPoint(x: clip.bounds.origin.x, y: start + delta * t))
            scrollView.reflectScrolledClipView(clip)
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 60))
        }
    }

    // MARK: Recording

    func startRecording(region: CGRect, to directory: URL) {
        recorder = FrameRecorder(view: root, region: region, directory: directory, beforeCapture: { [props] in
            props.advance(to: CACurrentMediaTime())
        })
        recorder?.start()
    }

    func stopRecording() async {
        await recorder?.stop()
        recorder = nil
    }

    /// Renders part of the stage into a PNG file, for the screenshot scene's captured image.
    func snapshot(_ rect: CGRect, to url: URL) {
        guard let rep = root.bitmapImageRepForCachingDisplay(in: rect) else { return }
        root.cacheDisplay(in: rect, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

extension NSView {
    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T { return match }
            if let match = subview.firstDescendant(of: type) { return match }
        }
        return nil
    }
}

func easeInOut(_ t: Double) -> Double {
    t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
}

// MARK: - Frame recorder

@MainActor
final class FrameRecorder {
    private let view: NSView
    private let region: CGRect
    private let directory: URL
    private let beforeCapture: () -> Void
    private var timer: Timer?
    private var timestamps: [CFTimeInterval] = []
    private let encodeQueue = DispatchQueue(label: "frame-encode", qos: .userInitiated, attributes: .concurrent)
    private let encodeGroup = DispatchGroup()

    init(view: NSView, region: CGRect, directory: URL, beforeCapture: @escaping () -> Void) {
        self.view = view
        self.region = region
        self.directory = directory
        self.beforeCapture = beforeCapture
    }

    func start() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.capture() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        capture()
    }

    private func capture() {
        beforeCapture()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: region) else { return }
        view.cacheDisplay(in: region, to: rep)
        let index = timestamps.count
        timestamps.append(CACurrentMediaTime())
        let url = directory.appendingPathComponent(String(format: "f%05d.png", index))
        encodeGroup.enter()
        encodeQueue.async { [encodeGroup] in
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            encodeGroup.leave()
        }
    }

    func stop() async {
        timer?.invalidate()
        timer = nil
        capture()
        await withCheckedContinuation { continuation in
            encodeGroup.notify(queue: .main) { continuation.resume() }
        }
        // ffconcat list with the real time between captures, so playback runs at real speed.
        var lines = ["ffconcat version 1.0"]
        for index in timestamps.indices {
            let next = index + 1 < timestamps.count ? timestamps[index + 1] : timestamps[index] + 1.0 / 30.0
            lines.append(String(format: "file f%05d.png", index))
            lines.append(String(format: "duration %.4f", next - timestamps[index]))
        }
        lines.append(String(format: "file f%05d.png", timestamps.count - 1))
        try? lines.joined(separator: "\n").write(
            to: directory.appendingPathComponent("frames.ffconcat"),
            atomically: true,
            encoding: .utf8
        )
        print("recorded \(timestamps.count) frames in \(String(format: "%.1f", (timestamps.last ?? 0) - (timestamps.first ?? 0)))s")
    }
}
