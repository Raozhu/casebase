import Cocoa
import Carbon.HIToolbox
import SwiftUI

private let topOverlayHeight: CGFloat = 700
private let fallbackCutoutSize = CGSize(width: 150, height: 24)

final class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var textEditingKeyMonitor: Any?
    private var dataResetObserver: Any?
    private var recordDeletedObserver: Any?
    private var recordsReorganizedObserver: Any?
    private var recordsChangedObserver: Any?
    private var appDidBecomeActiveObserver: Any?
    private let selectionAnimationController: SelectionCaptureAnimationWindowController

    init(screen: NSScreen, runtime: CasebaseRuntime?, startupError: Error? = nil) {
        let window = NotchWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        let cutoutSize = screen.notchSize == .zero ? fallbackCutoutSize : screen.notchSize
        let displayCutoutRect = CGRect(
            x: screen.frame.origin.x + (screen.frame.width - cutoutSize.width) / 2,
            y: screen.frame.origin.y + screen.frame.height - cutoutSize.height,
            width: cutoutSize.width,
            height: cutoutSize.height
        )

        viewModel = NotchViewModel(
            screenFrame: screen.frame,
            displayCutoutRect: displayCutoutRect,
            importCoordinator: runtime?.importCoordinator,
            answerService: runtime?.answerService,
            libraryService: runtime?.libraryService,
            todoService: runtime?.todoService,
            audioTranscriptService: runtime?.audioTranscriptService,
            storageRootDirectory: runtime?.configuration.storage.rootDirectory,
            dataResetService: runtime?.dataResetService,
            meetingRecorder: runtime?.meetingRecorder,
            demoModeEnabled: false,
            startupErrorMessage: startupError.map { ($0 as? LocalizedError)?.errorDescription ?? $0.localizedDescription }
        )
        selectionAnimationController = SelectionCaptureAnimationWindowController(screen: screen)
        super.init(window: window)

        contentViewController = NSHostingController(rootView: NotchView(viewModel: viewModel))

        let topRect = CGRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y + screen.frame.height - topOverlayHeight,
            width: screen.frame.width,
            height: topOverlayHeight
        )
        window.setContentSize(topRect.size)
        window.setFrameOrigin(topRect.origin)
        window.orderFrontRegardless()
        installMouseDismissMonitors()
        installTextEditingShortcutMonitor()
        installDataResetObserver()
        installRecordDeletedObserver()
        installRecordsReorganizedObserver()
        installRecordsChangedObserver()
        installAppDidBecomeActiveObserver()

        DispatchQueue.main.async { [weak self] in
            self?.viewModel.updateScreenFrame(screen.frame)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func destroy() {
        removeMouseDismissMonitors()
        removeTextEditingShortcutMonitor()
        removeDataResetObserver()
        removeRecordDeletedObserver()
        removeRecordsReorganizedObserver()
        removeRecordsChangedObserver()
        removeAppDidBecomeActiveObserver()
        selectionAnimationController.destroy()
        viewModel.collapse()
        window?.close()
        contentViewController = nil
        window = nil
    }

    deinit {
        removeMouseDismissMonitors()
        removeTextEditingShortcutMonitor()
        removeDataResetObserver()
        removeRecordDeletedObserver()
        removeRecordsReorganizedObserver()
        removeRecordsChangedObserver()
        removeAppDidBecomeActiveObserver()
    }

    private func installMouseDismissMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.dismissIfNeeded(at: NSEvent.mouseLocation)
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, let window = self.window else { return event }
            let location = window.convertPoint(toScreen: event.locationInWindow)
            if self.viewModel.surfaceRect.contains(CGPoint(x: location.x, y: location.y)), !window.isKeyWindow {
                window.makeKey()
            }
            self.dismissIfNeeded(at: location)
            return event
        }
    }

    private func removeMouseDismissMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func installTextEditingShortcutMonitor() {
        textEditingKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window else { return event }
            guard event.window === window || (event.window == nil && window.isKeyWindow) else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard modifiers == .command, let action = self.textEditingAction(for: event.keyCode) else {
                return event
            }

            guard self.performTextEditingAction(action, in: window) else { return event }
            return nil
        }
    }

    private func removeTextEditingShortcutMonitor() {
        guard let textEditingKeyMonitor else { return }
        NSEvent.removeMonitor(textEditingKeyMonitor)
        self.textEditingKeyMonitor = nil
    }

    private func textEditingAction(for keyCode: UInt16) -> Selector? {
        switch Int(keyCode) {
        case kVK_ANSI_C:
            return #selector(NSText.copy(_:))
        case kVK_ANSI_V:
            return #selector(NSText.paste(_:))
        case kVK_ANSI_X:
            return #selector(NSText.cut(_:))
        case kVK_ANSI_A:
            return #selector(NSStandardKeyBindingResponding.selectAll(_:))
        default:
            return nil
        }
    }

    private func performTextEditingAction(_ action: Selector, in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }

        if let textView = responder as? NSTextView {
            let actionName = NSStringFromSelector(action)
            if actionName == "copy:" || actionName == "selectAll:" {
                guard textView.isSelectable else { return false }
            } else {
                guard textView.isEditable else { return false }
            }
            return textView.tryToPerform(action, with: nil)
        }

        if let textField = responder as? NSTextField {
            guard textField.isEditable, let editor = textField.currentEditor() else { return false }
            return editor.tryToPerform(action, with: nil)
        }

        return false
    }

    private func installDataResetObserver() {
        dataResetObserver = NotificationCenter.default.addObserver(
            forName: .casebaseStoredDataCleared,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.handleStoredDataCleared()
            }
        }
    }

    private func removeDataResetObserver() {
        if let dataResetObserver {
            NotificationCenter.default.removeObserver(dataResetObserver)
            self.dataResetObserver = nil
        }
    }

    private func installRecordDeletedObserver() {
        recordDeletedObserver = NotificationCenter.default.addObserver(
            forName: .casebaseRecordDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let idString = notification.userInfo?["recordID"] as? String,
                  let id = UUID(uuidString: idString)
            else { return }

            Task { @MainActor [weak self] in
                self?.viewModel.handleRecordDeleted(id)
            }
        }
    }

    private func removeRecordDeletedObserver() {
        if let recordDeletedObserver {
            NotificationCenter.default.removeObserver(recordDeletedObserver)
            self.recordDeletedObserver = nil
        }
    }

    private func installAppDidBecomeActiveObserver() {
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.refreshShortcutPermissions()
            }
        }
    }

    private func installRecordsReorganizedObserver() {
        recordsReorganizedObserver = NotificationCenter.default.addObserver(
            forName: .casebaseRecordsReorganized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.handleRecordsReorganized()
            }
        }
    }

    private func installRecordsChangedObserver() {
        recordsChangedObserver = NotificationCenter.default.addObserver(
            forName: .casebaseRecordsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.handleRecordsChanged()
            }
        }
    }

    private func removeAppDidBecomeActiveObserver() {
        if let appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
            self.appDidBecomeActiveObserver = nil
        }
    }

    private func removeRecordsReorganizedObserver() {
        if let recordsReorganizedObserver {
            NotificationCenter.default.removeObserver(recordsReorganizedObserver)
            self.recordsReorganizedObserver = nil
        }
    }

    private func removeRecordsChangedObserver() {
        if let recordsChangedObserver {
            NotificationCenter.default.removeObserver(recordsChangedObserver)
            self.recordsChangedObserver = nil
        }
    }

    private func dismissIfNeeded(at screenPoint: NSPoint) {
        guard viewModel.isExpanded else { return }
        guard !viewModel.surfaceRect.contains(CGPoint(x: screenPoint.x, y: screenPoint.y)) else {
            return
        }
        Task { @MainActor [weak self] in
            self?.viewModel.dismissPreservingState()
        }
    }

    func contains(screenPoint: CGPoint) -> Bool {
        viewModel.screenFrame.contains(screenPoint)
    }

    func handleGlobalSelectionCapture(_ capture: GlobalSelectionCaptureContext) {
        if let sourcePoint = capture.sourcePoint {
            let targetPoint = CGPoint(
                x: viewModel.displayCutoutRect.midX,
                y: viewModel.displayCutoutRect.midY
            )
            selectionAnimationController.play(
                previewText: capture.previewText,
                sourceRect: capture.sourceRect,
                from: sourcePoint,
                to: targetPoint
            )
        }

        viewModel.ingestCapturedSelection(capture)
    }

    func handleGlobalScreenshotCapture(_ capture: GlobalScreenshotCaptureContext) {
        let targetPoint = CGPoint(
            x: viewModel.displayCutoutRect.midX,
            y: viewModel.displayCutoutRect.midY
        )

        if let image = NSImage(contentsOf: capture.fileURL) {
            selectionAnimationController.play(
                image: image,
                sourceRect: capture.sourceRect,
                from: capture.sourcePoint,
                to: targetPoint
            )
        }

        viewModel.ingestCapturedScreenshot(capture)
    }

    func handleGlobalSelectionCaptureError(_ error: Error) {
        viewModel.handleSelectionCaptureError(error)
    }

    func handleGlobalScreenshotCaptureError(_ error: Error) {
        viewModel.handleScreenshotCaptureError(error)
    }
}
