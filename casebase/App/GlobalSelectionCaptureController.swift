import Carbon.HIToolbox
import Foundation

final class GlobalSelectionCaptureController {
    private let captureService: SelectedTextCaptureService
    private let onCapture: @MainActor (GlobalSelectionCaptureContext) -> Void
    private let onError: @MainActor (Error) -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x63627365), id: 1)

    init(
        captureService: SelectedTextCaptureService = SelectedTextCaptureService(),
        onCapture: @escaping @MainActor (GlobalSelectionCaptureContext) -> Void,
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
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        RegisterEventHotKey(
            UInt32(kVK_F3),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    fileprivate func handleHotKeyPressed() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let capture = try await captureService.captureCurrentSelection()
                await onCapture(capture)
            } catch {
                await onError(error)
            }
        }
    }
}

private let hotKeyHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let controller = Unmanaged<GlobalSelectionCaptureController>.fromOpaque(userData).takeUnretainedValue()
    controller.handleHotKeyPressed()
    return noErr
}
