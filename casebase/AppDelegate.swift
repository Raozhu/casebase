import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [NotchWindowController] = []
    private var runtime: CasebaseRuntime?
    private var startupError: Error?
    private var selectionCaptureController: GlobalSelectionCaptureController?
    private var screenshotCaptureController: GlobalScreenshotCaptureController?
    private var apiKeyUpdatedObserver: Any?
    private var inboxWatcher: CasebaseInboxWatcher?
    private var roundTableHotKeyController: GlobalRoundTableHotKeyController?

    func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)
        CasebaseInboxWatcher.ensureDirectories(for: StorageConfiguration.load())
        CasebaseKnightsService.shared.startIfEnabled()
        KnightsActivityCenter.shared.start()
        #if DEBUG
        CasebaseDebugProbe.install()
        #endif
        reloadRuntime()
        rebuildApplicationWindows()
        installAPIKeyUpdatedObserver()
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
        // Installed last: its handler passes other hotkeys on, the capture handlers do not.
        roundTableHotKeyController = GlobalRoundTableHotKeyController {
            CasebaseKnightsService.shared.openRoundTable()
        }
    }

    func applicationWillTerminate(_: Notification) {
        inboxWatcher?.stop()
        CasebaseKnightsService.shared.stop()
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

    @MainActor
    private func reloadRuntime() {
        CasebaseAPIKeyStore.shared.reload()
        inboxWatcher?.stop()
        inboxWatcher = nil
        do {
            runtime = try CasebaseRuntime.bootstrap()
            startupError = nil
            if let runtime {
                let watcher = CasebaseInboxWatcher(
                    storage: runtime.configuration.storage,
                    importCoordinator: runtime.importCoordinator
                )
                watcher.start()
                inboxWatcher = watcher
                Task {
                    do {
                        let reorganizedCount = try await runtime.assetOrganizationService.organizeLegacyAssets()
                        guard reorganizedCount > 0 else { return }
                        NotificationCenter.default.post(
                            name: .casebaseRecordsReorganized,
                            object: nil,
                            userInfo: ["reorganizedCount": reorganizedCount]
                        )
                    } catch {
                        CasebaseDebugLogger.log(
                            "legacy asset organization failed error=\(String(describing: error))"
                        )
                    }
                }
            }
        } catch {
            runtime = nil
            startupError = error
        }
    }

    private func installAPIKeyUpdatedObserver() {
        apiKeyUpdatedObserver = NotificationCenter.default.addObserver(
            forName: .casebaseAPIKeyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reloadRuntime()
                self.rebuildApplicationWindows()
            }
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
