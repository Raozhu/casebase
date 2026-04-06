import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [NotchWindowController] = []
    private var runtime: CasebaseRuntime?
    private var startupError: Error?
    private var selectionCaptureController: GlobalSelectionCaptureController?
    private var screenshotCaptureController: GlobalScreenshotCaptureController?

    func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)
        do {
            runtime = try CasebaseRuntime.bootstrap()
            startupError = nil
        } catch {
            runtime = nil
            startupError = error
        }
        rebuildApplicationWindows()
        selectionCaptureController = GlobalSelectionCaptureController(
            onCapture: { [weak self] capture in
                self?.routeSelectionCapture(capture)
            },
            onError: { [weak self] error in
                self?.routeSelectionCaptureError(error)
            }
        )
        screenshotCaptureController = GlobalScreenshotCaptureController(
            onCapture: { [weak self] capture in
                self?.routeScreenshotCapture(capture)
            },
            onError: { [weak self] error in
                self?.routeScreenshotCaptureError(error)
            }
        )
    }

    @objc func rebuildApplicationWindows() {
        for windowController in windowControllers {
            windowController.destroy()
        }
        windowControllers.removeAll()

        for screen in NSScreen.screens {
            windowControllers.append(NotchWindowController(screen: screen, runtime: runtime, startupError: startupError))
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        true
    }

    @MainActor
    private func routeSelectionCapture(_ capture: GlobalSelectionCaptureContext) {
        targetWindowController(for: capture)?.handleGlobalSelectionCapture(capture)
    }

    @MainActor
    private func routeSelectionCaptureError(_ error: Error) {
        fallbackWindowController()?.handleGlobalSelectionCaptureError(error)
    }

    @MainActor
    private func routeScreenshotCapture(_ capture: GlobalScreenshotCaptureContext) {
        targetWindowController(for: capture.sourcePoint)?.handleGlobalScreenshotCapture(capture)
    }

    @MainActor
    private func routeScreenshotCaptureError(_ error: Error) {
        fallbackWindowController()?.handleGlobalScreenshotCaptureError(error)
    }

    @MainActor
    private func targetWindowController(for capture: GlobalSelectionCaptureContext) -> NotchWindowController? {
        targetWindowController(for: capture.sourcePoint)
    }

    @MainActor
    private func targetWindowController(for point: CGPoint?) -> NotchWindowController? {
        if let point,
           let matched = windowControllers.first(where: { $0.contains(screenPoint: point) })
        {
            return matched
        }

        if let currentScreen = NSScreen.main,
           let matched = windowControllers.first(where: { $0.window?.screen == currentScreen })
        {
            return matched
        }

        return fallbackWindowController()
    }

    @MainActor
    private func fallbackWindowController() -> NotchWindowController? {
        if let builtin = NSScreen.buildin,
           let matched = windowControllers.first(where: { $0.window?.screen == builtin })
        {
            return matched
        }
        return windowControllers.first
    }
}
