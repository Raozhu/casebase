import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class SelectedTextCaptureService {
    func captureCurrentSelection() async throws -> GlobalSelectionCaptureContext {
        guard ensureAccessibilityPermission() else {
            throw GlobalSelectionCaptureError.accessibilityPermissionRequired
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let initialChangeCount = pasteboard.changeCount
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let pid = frontmostApplication?.processIdentifier
        let accessibilityContext = pid.map(accessibilitySnapshot(for:)) ?? AccessibilitySnapshot.empty

        try sendCopyShortcut()

        let clipboardText = try await waitForClipboardText(
            on: pasteboard,
            initialChangeCount: initialChangeCount
        )
        snapshot.restore(to: pasteboard)

        let text = normalizeCapturedText(clipboardText ?? accessibilityContext.selectedText)
        guard !text.isEmpty else {
            throw clipboardText == nil ? GlobalSelectionCaptureError.copyFailed : GlobalSelectionCaptureError.noTextFound
        }

        return GlobalSelectionCaptureContext(
            text: text,
            sourceAppName: frontmostApplication?.localizedName,
            windowTitle: accessibilityContext.windowTitle,
            capturedAt: Date(),
            sourceRect: accessibilityContext.selectedBounds,
            fallbackOriginPoint: accessibilityContext.fallbackOriginPoint
        )
    }

    private func ensureAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func sendCopyShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            throw GlobalSelectionCaptureError.copyFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func waitForClipboardText(
        on pasteboard: NSPasteboard,
        initialChangeCount: Int
    ) async throws -> String? {
        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 50_000_000)
            if pasteboard.changeCount != initialChangeCount,
               let string = pasteboard.string(forType: .string)
            {
                return string
            }
        }
        return nil
    }

    private func normalizeCapturedText(_ text: String?) -> String {
        text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func accessibilitySnapshot(for pid: pid_t) -> AccessibilitySnapshot {
        let appElement = AXUIElementCreateApplication(pid)
        let focusedWindow = copyElementAttribute(.focusedWindow, from: appElement)
        let focusedElement = copyElementAttribute(.focusedUIElement, from: appElement)

        let windowTitle = focusedWindow.flatMap { copyStringAttribute(.title, from: $0) }
        let windowFrame = focusedWindow.flatMap(boundsOfWindow)
        let selectedText = focusedElement.flatMap { copyStringAttribute(.selectedText, from: $0) }
        let selectedBounds = focusedElement.flatMap(boundsForSelectedText)
        let fallbackOriginPoint = selectedBounds.map {
            CGPoint(x: $0.midX, y: $0.midY)
        } ?? windowFrame.map {
            CGPoint(x: $0.midX, y: $0.midY)
        }

        return AccessibilitySnapshot(
            selectedText: selectedText,
            selectedBounds: selectedBounds,
            windowTitle: windowTitle,
            fallbackOriginPoint: fallbackOriginPoint
        )
    }

    private func copyElementAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value) == .success,
              let value
        else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func copyStringAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func boundsOfWindow(_ element: AXUIElement) -> CGRect? {
        guard let position = copyCGPointAttribute(.position, from: element),
              let size = copyCGSizeAttribute(.size, from: element)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func boundsForSelectedText(_ element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            AXAttribute.selectedTextRange.rawValue as CFString,
            &value
        ) == .success,
        let value
        else {
            return nil
        }

        let selectedRangeValue = value as! AXValue
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            AXParameterizedAttribute.boundsForRange.rawValue as CFString,
            selectedRangeValue,
            &boundsValue
        ) == .success,
        let boundsValue
        else {
            return nil
        }

        var rect = CGRect.zero
        let axValue = boundsValue as! AXValue
        guard AXValueGetType(axValue) == .cgRect,
              AXValueGetValue(axValue, .cgRect, &rect)
        else {
            return nil
        }
        return rect
    }

    private func copyCGPointAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value) == .success,
              let value
        else {
            return nil
        }

        let axValue = value as! AXValue
        var point = CGPoint.zero
        guard AXValueGetType(axValue) == .cgPoint,
              AXValueGetValue(axValue, .cgPoint, &point)
        else {
            return nil
        }
        return point
    }

    private func copyCGSizeAttribute(_ attribute: AXAttribute, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute.rawValue as CFString, &value) == .success,
              let value
        else {
            return nil
        }

        let axValue = value as! AXValue
        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize,
              AXValueGetValue(axValue, .cgSize, &size)
        else {
            return nil
        }
        return size
    }
}

private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems = items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}

private struct AccessibilitySnapshot {
    let selectedText: String?
    let selectedBounds: CGRect?
    let windowTitle: String?
    let fallbackOriginPoint: CGPoint?

    static let empty = AccessibilitySnapshot(
        selectedText: nil,
        selectedBounds: nil,
        windowTitle: nil,
        fallbackOriginPoint: nil
    )
}

private enum AXAttribute: String {
    case focusedWindow = "AXFocusedWindow"
    case focusedUIElement = "AXFocusedUIElement"
    case title = "AXTitle"
    case selectedText = "AXSelectedText"
    case selectedTextRange = "AXSelectedTextRange"
    case position = "AXPosition"
    case size = "AXSize"
}

private enum AXParameterizedAttribute: String {
    case boundsForRange = "AXBoundsForRange"
}
