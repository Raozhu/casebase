import AppKit
import Carbon.HIToolbox
import Foundation
import IOKit.hid

@MainActor
final class GlobalSelectionCaptureController {
    private let captureService: SelectedTextCaptureService
    private let hotKeyStore: CasebaseHotKeyStore
    private let onCapture: @MainActor (GlobalSelectionCaptureContext) -> Void
    private let onError: @MainActor (Error) -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var hotKeyObserver: NSObjectProtocol?
    private var fallbackKeyMonitor: Any?
    private var hidManager: IOHIDManager?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var lastTriggerTime: Date?
    private var isCaptureInFlight = false
    private let hotKeyID = EventHotKeyID(signature: OSType(0x63627365), id: 1)

    init(
        captureService: SelectedTextCaptureService = SelectedTextCaptureService(),
        onCapture: @escaping @MainActor (GlobalSelectionCaptureContext) -> Void,
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
        if let fallbackKeyMonitor {
            NSEvent.removeMonitor(fallbackKeyMonitor)
        }
        if let hidManager {
            IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, CFRunLoopMode.commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }

    private func installHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
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

        let shortcut = hotKeyStore.shortcut(for: .selectionCapture)
        let usesBareF1Fallback = shortcut.keyCode == UInt32(kVK_F1) && shortcut.carbonModifiers == 0
        CasebaseDebugLogger.log("selection hotkey registering: \(shortcut.displayString) keyCode=\(shortcut.keyCode) modifiers=\(shortcut.carbonModifiers)")
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr || hotKeyRef == nil {
            self.hotKeyRef = nil
            guard usesBareF1Fallback else {
                CasebaseDebugLogger.log("selection hotkey registration failed: status=\(status)")
                Task { @MainActor [onError] in
                    onError(GlobalSelectionCaptureError.hotKeyRegistrationFailed)
                }
                updateFallbackMonitor(for: nil)
                updateBrightnessHIDMonitor(for: nil)
                updateEventTap(for: nil)
                return
            }
            CasebaseDebugLogger.log("selection hotkey registration fell back to bare F1 monitors: status=\(status)")
        } else {
            CasebaseDebugLogger.log("selection hotkey registration succeeded")
        }

        updateFallbackMonitor(for: shortcut)
        updateBrightnessHIDMonitor(for: shortcut)
        updateEventTap(for: shortcut)
    }

    fileprivate func handleHotKeyPressed(for pressedHotKeyID: EventHotKeyID?) {
        guard matchesRegisteredHotKey(pressedHotKeyID) else { return }
        guard captureService.hasAccessibilityPermission() else {
            CasebaseDebugLogger.log("selection hotkey ignored: accessibility permission missing")
            return
        }
        triggerCapture(source: "carbon-hotkey")
    }

    private func matchesRegisteredHotKey(_ pressedHotKeyID: EventHotKeyID?) -> Bool {
        guard let pressedHotKeyID else { return false }
        return pressedHotKeyID.signature == hotKeyID.signature && pressedHotKeyID.id == hotKeyID.id
    }

    private func updateFallbackMonitor(for shortcut: CasebaseHotKeyDescriptor?) {
        if let fallbackKeyMonitor {
            NSEvent.removeMonitor(fallbackKeyMonitor)
            self.fallbackKeyMonitor = nil
        }

        guard let shortcut,
              shortcut.keyCode == UInt32(kVK_F1),
              shortcut.carbonModifiers == 0
        else { return }

        fallbackKeyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .systemDefined]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFallbackEvent(event)
            }
        }
        CasebaseDebugLogger.log("selection fallback monitor enabled for F1")
    }

    private func updateBrightnessHIDMonitor(for shortcut: CasebaseHotKeyDescriptor?) {
        if let hidManager {
            IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.hidManager = nil
        }

        guard let shortcut,
              shortcut.keyCode == UInt32(kVK_F1),
              shortcut.carbonModifiers == 0
        else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Int]] = [[
            kIOHIDDeviceUsagePageKey as String: Int(kHIDPage_Consumer),
            kIOHIDDeviceUsageKey as String: Int(kHIDUsage_Csmr_DisplayBrightnessDecrement)
        ]]

        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        IOHIDManagerRegisterInputValueCallback(
            manager,
            selectionBrightnessInputValueCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            CasebaseDebugLogger.log("selection HID monitor failed to open: status=\(status)")
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return
        }

        hidManager = manager
        CasebaseDebugLogger.log("selection HID monitor enabled for brightness-down")
    }

    private func updateEventTap(for shortcut: CasebaseHotKeyDescriptor?) {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, CFRunLoopMode.commonModes)
            self.eventTapSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        guard let shortcut,
              shortcut.keyCode == UInt32(kVK_F1),
              shortcut.carbonModifiers == 0
        else { return }

        let hasListenAccess = CGPreflightListenEventAccess()
        CasebaseDebugLogger.log("selection event tap listen access preflight: \(hasListenAccess)")

        guard hasListenAccess else {
            CasebaseDebugLogger.log("selection event tap skipped because listen access is not granted")
            return
        }

        guard let systemDefinedType = CGEventType(rawValue: UInt32(NX_SYSDEFINED)) else {
            CasebaseDebugLogger.log("selection event tap failed: NX_SYSDEFINED unavailable")
            return
        }

        let eventMask =
            (CGEventMask(1) << UInt64(CGEventType.keyDown.rawValue)) |
            (CGEventMask(1) << UInt64(systemDefinedType.rawValue))

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: selectionEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            CasebaseDebugLogger.log("selection event tap creation failed")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        eventTapSource = source
        CasebaseDebugLogger.log("selection event tap enabled")
    }

    private func handleFallbackEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == UInt16(kVK_F1) {
            CasebaseDebugLogger.log("selection fallback keyDown matched F1")
            triggerCapture(source: "fallback-keydown")
            return
        }

        guard event.type == .systemDefined,
              event.subtype.rawValue == 8,
              mediaKeyCode(from: event) == 3,
              mediaKeyIsDown(event)
        else {
            return
        }

        CasebaseDebugLogger.log("selection fallback media-key matched brightness-down")
        triggerCapture(source: "fallback-media-key")
    }

    fileprivate func handleEventTapEvent(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                CasebaseDebugLogger.log("selection event tap re-enabled after disable event")
            }
            return
        }

        guard let nsEvent = NSEvent(cgEvent: event) else { return }

        if type == .keyDown, nsEvent.keyCode == UInt16(kVK_F1) {
            CasebaseDebugLogger.log("selection event tap matched keyDown F1")
            triggerCapture(source: "event-tap-keydown")
            return
        }

        guard type.rawValue == UInt32(NX_SYSDEFINED) else { return }
        handleFallbackEvent(nsEvent)
    }

    fileprivate func handleBrightnessHIDEvent() {
        CasebaseDebugLogger.log("selection HID event matched brightness-down")
        triggerCapture(source: "hid-brightness-down")
    }

    private func mediaKeyCode(from event: NSEvent) -> Int {
        Int((event.data1 & 0xFFFF0000) >> 16)
    }

    private func mediaKeyIsDown(_ event: NSEvent) -> Bool {
        ((event.data1 & 0x0000FF00) >> 8) == 0xA
    }

    private func triggerCapture(source: String) {
        if let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           frontmostBundleIdentifier == Bundle.main.bundleIdentifier {
            CasebaseDebugLogger.log("selection trigger ignored because casebase is frontmost: source=\(source)")
            return
        }

        let now = Date()
        if isCaptureInFlight {
            CasebaseDebugLogger.log("selection trigger ignored because capture is already in flight: source=\(source)")
            return
        }
        if let lastTriggerTime, now.timeIntervalSince(lastTriggerTime) < 0.35 {
            CasebaseDebugLogger.log("selection trigger ignored as duplicate: source=\(source)")
            return
        }

        lastTriggerTime = now
        isCaptureInFlight = true
        CasebaseDebugLogger.log("selection trigger accepted: source=\(source)")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isCaptureInFlight = false }
            do {
                let capture = try await captureService.captureCurrentSelection()
                CasebaseDebugLogger.log("selection capture succeeded: chars=\(capture.text.count)")
                onCapture(capture)
            } catch {
                if let selectionError = error as? GlobalSelectionCaptureError,
                   selectionError == .noTextFound {
                    CasebaseDebugLogger.log("selection capture ignored because no text is selected")
                    return
                }
                CasebaseDebugLogger.log("selection capture failed: \(String(describing: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription))")
                onError(error)
            }
        }
    }
}

private let selectionBrightnessInputValueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }

    let element = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intValue = IOHIDValueGetIntegerValue(value)

    guard usagePage == kHIDPage_Consumer,
          usage == kHIDUsage_Csmr_DisplayBrightnessDecrement,
          intValue != 0 else {
        return
    }

    let controller = Unmanaged<GlobalSelectionCaptureController>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in
        controller.handleBrightnessHIDEvent()
    }
}

private let selectionEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let controller = Unmanaged<GlobalSelectionCaptureController>.fromOpaque(userInfo).takeUnretainedValue()
    let eventCopy = event.copy()
    Task { @MainActor in
        guard let eventCopy else { return }
        controller.handleEventTapEvent(type, event: eventCopy)
    }
    return Unmanaged.passUnretained(event)
}

private let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return noErr }
    let pressedHotKeyID = event.flatMap(selectionEventHotKeyID)
    let controller = Unmanaged<GlobalSelectionCaptureController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.handleHotKeyPressed(for: pressedHotKeyID)
    }
    return noErr
}

private func selectionEventHotKeyID(from event: EventRef) -> EventHotKeyID? {
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
