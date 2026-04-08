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

        guard let image = captureImage(in: captureRect) else {
            throw GlobalScreenshotCaptureError.captureFailed
        }

        let fileURL = try previewWriter.writePNG(image: image, prefix: sourceContext.sourceAppName ?? "screenshot")

        return GlobalScreenshotCaptureContext(
            fileURL: fileURL,
            sourceAppName: sourceContext.sourceAppName,
            windowTitle: sourceContext.windowTitle,
            capturedAt: sourceContext.triggeredAt,
            sourceRect: captureRect
        )
    }

    private func captureImage(in captureRect: CGRect) -> NSImage? {
        if let displayImage = captureDisplayImage(in: captureRect) {
            return displayImage
        }

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: captureRect.width, height: captureRect.height)
        )
    }

    private func captureDisplayImage(in captureRect: CGRect) -> NSImage? {
        guard let screen = screen(containing: captureRect),
              let displayID = displayID(for: screen),
              let displayCGImage = CGDisplayCreateImage(displayID)
        else {
            return nil
        }

        let localRect = CGRect(
            x: captureRect.minX - screen.frame.minX,
            y: captureRect.minY - screen.frame.minY,
            width: captureRect.width,
            height: captureRect.height
        ).intersection(CGRect(origin: .zero, size: screen.frame.size))

        guard localRect.width >= 2, localRect.height >= 2 else {
            return nil
        }

        let displayImage = NSImage(cgImage: displayCGImage, size: screen.frame.size)
        let croppedImage = NSImage(size: localRect.size)
        croppedImage.lockFocus()
        defer { croppedImage.unlockFocus() }

        displayImage.draw(
            in: CGRect(origin: .zero, size: localRect.size),
            from: localRect,
            operation: .copy,
            fraction: 1
        )

        return croppedImage
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(rect.origin) && screen.frame.contains(CGPoint(x: rect.maxX, y: rect.maxY))
        } ?? NSScreen.screens.first(where: { $0.frame.intersects(rect) })
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let screenNumberKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
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
