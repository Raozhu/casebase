import AppKit
import Foundation

@MainActor
final class ScreenshotCaptureOverlayWindowController: NSWindowController {
    init(
        screen: NSScreen,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (CGRect) -> Void
    ) {
        let window = ScreenshotCaptureOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .mainMenu + 7
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .ignoresCycle, .stationary]
        window.hasShadow = false
        window.ignoresMouseEvents = false

        super.init(window: window)

        let overlayView = ScreenshotCaptureOverlayView(
            frame: CGRect(origin: .zero, size: screen.frame.size),
            screenFrame: screen.frame,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
        window.contentView = overlayView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        guard let window else { return }
        window.orderFrontRegardless()
        window.makeKey()
        window.makeFirstResponder(window.contentView)
    }

    func dismiss() {
        window?.orderOut(nil)
        close()
    }
}

private final class ScreenshotCaptureOverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ScreenshotCaptureOverlayView: NSView {
    private struct ResizeEdges: OptionSet {
        let rawValue: Int

        static let minX = ResizeEdges(rawValue: 1 << 0)
        static let maxX = ResizeEdges(rawValue: 1 << 1)
        static let minY = ResizeEdges(rawValue: 1 << 2)
        static let maxY = ResizeEdges(rawValue: 1 << 3)
    }

    private enum Interaction {
        case none
        case creating(anchor: CGPoint)
        case moving(initialRect: CGRect, dragOffset: CGPoint)
        case resizing(initialRect: CGRect, edges: ResizeEdges)
    }

    private let screenFrame: CGRect
    private let onCancel: () -> Void
    private let onConfirm: (CGRect) -> Void
    private let minimumSelectionSize = CGSize(width: 18, height: 18)

    private var selectionRect: CGRect?
    private var interaction: Interaction = .none
    private var didDragDuringInteraction = false

    override var acceptsFirstResponder: Bool { true }

    init(
        frame frameRect: NSRect,
        screenFrame: CGRect,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (CGRect) -> Void
    ) {
        self.screenFrame = screenFrame
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        updateCursor(for: convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        didDragDuringInteraction = false
        updateCursor(for: point)

        if let selectionRect, selectionRect.contains(point), event.clickCount >= 2 {
            onConfirm(globalRect(for: selectionRect))
            return
        }

        guard let selectionRect else {
            interaction = .creating(anchor: point)
            self.selectionRect = CGRect(origin: point, size: .zero)
            needsDisplay = true
            return
        }

        if selectionRect.contains(point) {
            let offset = CGPoint(x: point.x - selectionRect.minX, y: point.y - selectionRect.minY)
            interaction = .moving(initialRect: selectionRect, dragOffset: offset)
        } else {
            interaction = .resizing(initialRect: selectionRect, edges: resizeEdges(for: point, relativeTo: selectionRect))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        didDragDuringInteraction = true

        switch interaction {
        case let .creating(anchor):
            selectionRect = normalizedRect(from: anchor, to: point)
        case let .moving(initialRect, dragOffset):
            selectionRect = movedRect(initialRect, to: point, dragOffset: dragOffset)
        case let .resizing(initialRect, edges):
            selectionRect = resizedRect(initialRect, edges: edges, to: point)
        case .none:
            break
        }

        needsDisplay = true
        updateCursor(for: point)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            interaction = .none
            needsDisplay = true
            let point = convert(event.locationInWindow, from: nil)
            updateCursor(for: point)
        }

        if case .resizing = interaction, !didDragDuringInteraction {
            selectionRect = nil
            return
        }

        if let selectionRect, selectionRect.width < minimumSelectionSize.width || selectionRect.height < minimumSelectionSize.height {
            self.selectionRect = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let overlayPath = NSBezierPath(rect: bounds)
        if let selectionRect {
            overlayPath.appendRoundedRect(selectionRect, xRadius: 14, yRadius: 14)
            overlayPath.windingRule = .evenOdd
        }

        NSColor.black.withAlphaComponent(0.58).setFill()
        overlayPath.fill()

        guard let selectionRect else { return }

        let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 14, yRadius: 14)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        selectionPath.lineWidth = 1.6
        selectionPath.stroke()

        NSColor.white.withAlphaComponent(0.1).setFill()
        selectionPath.fill()

        for handle in handleRects(for: selectionRect) {
            let handlePath = NSBezierPath(ovalIn: handle)
            NSColor.white.setFill()
            handlePath.fill()
            NSColor.black.withAlphaComponent(0.18).setStroke()
            handlePath.lineWidth = 1
            handlePath.stroke()
        }
    }

    private func normalizedRect(from anchor: CGPoint, to point: CGPoint) -> CGRect {
        let rect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x),
            height: abs(point.y - anchor.y)
        )
        return rect.intersection(bounds)
    }

    private func movedRect(_ rect: CGRect, to point: CGPoint, dragOffset: CGPoint) -> CGRect {
        var moved = rect
        moved.origin = CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)
        moved.origin.x = min(max(bounds.minX, moved.origin.x), bounds.maxX - moved.width)
        moved.origin.y = min(max(bounds.minY, moved.origin.y), bounds.maxY - moved.height)
        return moved
    }

    private func resizedRect(_ rect: CGRect, edges: ResizeEdges, to point: CGPoint) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        if edges.contains(.minX) {
            minX = min(max(bounds.minX, point.x), maxX - minimumSelectionSize.width)
        }
        if edges.contains(.maxX) {
            maxX = max(minX + minimumSelectionSize.width, min(bounds.maxX, point.x))
        }
        if edges.contains(.minY) {
            minY = min(max(bounds.minY, point.y), maxY - minimumSelectionSize.height)
        }
        if edges.contains(.maxY) {
            maxY = max(minY + minimumSelectionSize.height, min(bounds.maxY, point.y))
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func resizeEdges(for point: CGPoint, relativeTo rect: CGRect) -> ResizeEdges {
        var edges: ResizeEdges = []

        if point.x < rect.minX {
            edges.insert(.minX)
        } else if point.x > rect.maxX {
            edges.insert(.maxX)
        }

        if point.y < rect.minY {
            edges.insert(.minY)
        } else if point.y > rect.maxY {
            edges.insert(.maxY)
        }

        return edges
    }

    private func globalRect(for localRect: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + localRect.minX,
            y: screenFrame.minY + localRect.minY,
            width: localRect.width,
            height: localRect.height
        )
    }

    private func handleRects(for rect: CGRect) -> [CGRect] {
        let size: CGFloat = 8
        let half = size / 2
        let points = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        return points.map { point in
            CGRect(x: point.x - half, y: point.y - half, width: size, height: size)
        }
    }

    private func updateCursor(for point: CGPoint) {
        cursor(for: point).set()
    }

    private func cursor(for point: CGPoint) -> NSCursor {
        guard let selectionRect else {
            return .crosshair
        }

        if selectionRect.contains(point) {
            return .crosshair
        }

        let withinVerticalBand = point.y >= selectionRect.minY && point.y <= selectionRect.maxY
        let withinHorizontalBand = point.x >= selectionRect.minX && point.x <= selectionRect.maxX

        if withinVerticalBand && (point.x < selectionRect.minX || point.x > selectionRect.maxX) {
            return .resizeLeftRight
        }

        if withinHorizontalBand && (point.y < selectionRect.minY || point.y > selectionRect.maxY) {
            return .resizeUpDown
        }

        let horizontalDistance = min(abs(point.x - selectionRect.minX), abs(point.x - selectionRect.maxX))
        let verticalDistance = min(abs(point.y - selectionRect.minY), abs(point.y - selectionRect.maxY))
        return horizontalDistance <= verticalDistance ? .resizeLeftRight : .resizeUpDown
    }
}
