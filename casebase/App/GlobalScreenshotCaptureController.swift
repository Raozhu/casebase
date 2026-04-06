import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalScreenshotCaptureController {
    private let captureService: ScreenshotCaptureService
    private let onCapture: @MainActor (GlobalScreenshotCaptureContext) -> Void
    private let onError: @MainActor (Error) -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var overlayController: ScreenshotCaptureOverlayWindowController?
    private var pendingSourceContext: ScreenshotSourceContext?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x63627373), id: 1)

    init(
        captureService: ScreenshotCaptureService = ScreenshotCaptureService(),
        onCapture: @escaping @MainActor (GlobalScreenshotCaptureContext) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        self.captureService = captureService
        self.onCapture = onCapture
        self.onError = onError
        installHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private func installHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            screenshotHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        RegisterEventHotKey(
            UInt32(kVK_F1),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    fileprivate func handleHotKeyPressed() {
        if overlayController != nil {
            cancelCaptureSession()
            return
        }
        startCaptureSession()
    }

    private func startCaptureSession() {
        guard captureService.ensurePermission() else {
            onError(GlobalScreenshotCaptureError.permissionRequired)
            return
        }

        guard let screen = targetScreen() else {
            onError(GlobalScreenshotCaptureError.noActiveScreen)
            return
        }

        let sourceContext = captureService.captureSourceContext()
        pendingSourceContext = sourceContext

        let controller = ScreenshotCaptureOverlayWindowController(
            screen: screen,
            onCancel: { [weak self] in
                self?.cancelCaptureSession()
            },
            onConfirm: { [weak self] rect in
                self?.completeCaptureSession(with: rect)
            }
        )
        overlayController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.present()
    }

    private func completeCaptureSession(with rect: CGRect) {
        let sourceContext = pendingSourceContext
        dismissCaptureSession()

        Task { @MainActor [weak self] in
            guard let self, let sourceContext else { return }
            try? await Task.sleep(nanoseconds: 80_000_000)

            do {
                let capture = try self.captureService.captureScreenshot(
                    in: rect,
                    sourceContext: sourceContext
                )
                sourceContext.frontmostApplication?.activate(options: [])
                self.onCapture(capture)
            } catch {
                sourceContext.frontmostApplication?.activate(options: [])
                self.onError(error)
            }
        }
    }

    private func cancelCaptureSession() {
        let sourceApplication = pendingSourceContext?.frontmostApplication
        dismissCaptureSession()
        sourceApplication?.activate(options: [])
    }

    private func dismissCaptureSession() {
        overlayController?.dismiss()
        overlayController = nil
        pendingSourceContext = nil
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.buildin ?? NSScreen.screens.first
    }
}

private let screenshotHotKeyHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let controller = Unmanaged<GlobalScreenshotCaptureController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handleHotKeyPressed()
    }
    return noErr
}
