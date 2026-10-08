import AppKit
import Carbon.HIToolbox
import Foundation

/// Global shortcut (default ⌘F4) that shows or tucks away the round-table window.
@MainActor
final class GlobalRoundTableHotKeyController {
    private let hotKeyStore: CasebaseHotKeyStore
    private let onPress: @MainActor () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotKeyObserver: NSObjectProtocol?
    fileprivate static let hotKeyID = EventHotKeyID(signature: OSType(0x63627274), id: 1)

    init(onPress: @escaping @MainActor () -> Void) {
        hotKeyStore = .shared
        self.onPress = onPress
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
            roundTableHotKeyHandler,
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

        let shortcut = hotKeyStore.shortcut(for: .roundTable)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        CasebaseDebugLogger.log("round table hotkey \(shortcut.displayString) registration status=\(status)")
    }

    fileprivate func handlePress() {
        onPress()
    }
}

/// Unlike the capture handlers, this one passes other hotkeys on (`eventNotHandledErr`) so that being
/// installed last does not swallow the capture shortcuts.
private let roundTableHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var pressed = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &pressed
    )
    let expected = GlobalRoundTableHotKeyController.hotKeyID
    guard status == noErr, pressed.signature == expected.signature, pressed.id == expected.id else {
        return OSStatus(eventNotHandledErr)
    }
    let controller = Unmanaged<GlobalRoundTableHotKeyController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handlePress()
    }
    return noErr
}
