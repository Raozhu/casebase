import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct ScreenshotSourceContext {
    let frontmostApplication: NSRunningApplication?
    let sourceAppName: String?
    let windowTitle: String?
    let triggeredAt: Date
}

final class ScreenshotCaptureService {
    private let previewWriter: TemporaryPreviewWriter

    init(previewWriter: TemporaryPreviewWriter = TemporaryPreviewWriter()) {
        self.previewWriter = previewWriter
    }

    func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }

    func captureSourceContext() -> ScreenshotSourceContext {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let windowTitle: String?
        if let pid = frontmostApplication?.processIdentifier {
            windowTitle = focusedWindowTitle(for: pid)
        } else {
            windowTitle = nil
        }
        return ScreenshotSourceContext(
            frontmostApplication: frontmostApplication,
            sourceAppName: frontmostApplication?.localizedName,
            windowTitle: windowTitle,
            triggeredAt: Date()
        )
    }

    func captureScreenshot(
        in globalRect: CGRect,
        sourceContext: ScreenshotSourceContext
    ) throws -> GlobalScreenshotCaptureContext {
        let captureRect = globalRect.integral
        guard captureRect.width >= 2, captureRect.height >= 2 else {
            throw GlobalScreenshotCaptureError.captureFailed
        }

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw GlobalScreenshotCaptureError.captureFailed
        }

        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: captureRect.width, height: captureRect.height)
        )
        let fileURL = try previewWriter.writePNG(image: image, prefix: sourceContext.sourceAppName ?? "screenshot")

        return GlobalScreenshotCaptureContext(
            fileURL: fileURL,
            sourceAppName: sourceContext.sourceAppName,
            windowTitle: sourceContext.windowTitle,
            capturedAt: sourceContext.triggeredAt,
            sourceRect: captureRect
        )
    }

    private func focusedWindowTitle(for pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXFocusedWindow" as CFString, &value) == .success,
              let value
        else {
            return nil
        }

        let focusedWindow = unsafeBitCast(value, to: AXUIElement.self)
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedWindow, "AXTitle" as CFString, &titleValue) == .success else {
            return nil
        }
        return titleValue as? String
    }
}
