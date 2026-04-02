import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [NotchWindowController] = []

    func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)
        rebuildApplicationWindows()
    }

    @objc func rebuildApplicationWindows() {
        for windowController in windowControllers {
            windowController.destroy()
        }
        windowControllers.removeAll()

        for screen in NSScreen.screens {
            windowControllers.append(NotchWindowController(screen: screen))
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        true
    }
}
