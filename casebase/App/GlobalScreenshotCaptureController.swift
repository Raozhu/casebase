import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalScreenshotCaptureController {
    private let captureService: ScreenshotCaptureService
    private let hotKeyStore: CasebaseHotKeyStore
    private let onCapture: @MainActor (GlobalScreenshotCaptureContext) -> Void
    private let onError: @MainActor (Error) -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotKeyObserver: NSObjectProtocol?
    private var overlayController: ScreenshotCaptureOverlayWindowController?
    private var pendingSourceContext: ScreenshotSourceContext?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x63627373), id: 1)

    init(
        captureService: ScreenshotCaptureService = ScreenshotCaptureService(),
        onCapture: @escaping @MainActor (GlobalScreenshotCaptureContext) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        self.captureService = captureService
        hotKeyStore = .shared
        self.onCapture = onCapture
        self.onError = onError
        installHotKey()
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: CasebaseHotKeyStore.didChangeNotification,
            object: hotKeyStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.registerHotKey()
            }
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
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

        registerHotKey()
    }

    private func registerHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let shortcut = hotKeyStore.shortcut(for: .screenshotCapture)
        CasebaseDebugLogger.log("screenshot hotkey registering: \(shortcut.displayString) keyCode=\(shortcut.keyCode) modifiers=\(shortcut.carbonModifiers)")
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, hotKeyRef != nil else {
            CasebaseDebugLogger.log("screenshot hotkey registration failed: status=\(status)")
            onError(GlobalScreenshotCaptureError.hotKeyRegistrationFailed)
            return
        }

        CasebaseDebugLogger.log("screenshot hotkey registration succeeded")
    }

    fileprivate func handleHotKeyPressed(for pressedHotKeyID: EventHotKeyID?) {
        guard matchesRegisteredHotKey(pressedHotKeyID) else { return }
        guard captureService.hasPermission() else {
            CasebaseDebugLogger.log("screenshot hotkey ignored: screen recording permission missing")
            return
        }
        CasebaseDebugLogger.log("screenshot hotkey pressed")
        if overlayController != nil {
            cancelCaptureSession()
            return
        }
        startCaptureSession()
    }

    private func matchesRegisteredHotKey(_ pressedHotKeyID: EventHotKeyID?) -> Bool {
        guard let pressedHotKeyID else { return false }
        return pressedHotKeyID.signature == hotKeyID.signature && pressedHotKeyID.id == hotKeyID.id
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

private let screenshotHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return noErr }
    let pressedHotKeyID = event.flatMap(screenshotEventHotKeyID)
    let controller = Unmanaged<GlobalScreenshotCaptureController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handleHotKeyPressed(for: pressedHotKeyID)
    }
    return noErr
}

private func screenshotEventHotKeyID(from event: EventRef) -> EventHotKeyID? {
    var pressedHotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &pressedHotKeyID
    )

    guard status == noErr else { return nil }
    return pressedHotKeyID
}
