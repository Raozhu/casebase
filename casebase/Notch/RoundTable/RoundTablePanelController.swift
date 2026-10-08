import AppKit
import Combine
import SwiftUI
import WebKit

/// Dark window under the notch that hosts the 12 Knights web UI in a WKWebView.
@MainActor
final class RoundTablePanelController: NSObject {
    static let shared = RoundTablePanelController()

    private static let frameAutosaveName = "casebase.roundTable.window"
    /// How far the window travels toward the notch while sliding in/out.
    private static let slideDistance: CGFloat = 28

    private let knights = CasebaseKnightsService.shared
    private let webView: WKWebView
    private var panel: RoundTablePanel?
    private var placeholderView: NSView?
    private var statusObserver: AnyCancellable?
    private var needsLoad = true
    private var isAnimatingOut = false

    private override init() {
        let configuration = WKWebViewConfiguration()
        // Default the page to its dark theme (matches the notch); a theme the user picked in the page still wins.
        configuration.userContentController.addUserScript(WKUserScript(
            source: "try{if(!localStorage.getItem('theme5'))localStorage.setItem('theme5','dark')}catch(e){}",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = RoundTablePalette.pageBackground
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self

        statusObserver = knights.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
    }

    /// Clicking the round-table entry again while the window is in front tucks it away.
    func toggle() {
        if let panel, panel.isVisible, panel.isKeyWindow, !isAnimatingOut {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        loadIfNeeded()
        updateContentVisibility()
        NSApp.activate(ignoringOtherApps: true)

        guard !panel.isVisible || isAnimatingOut else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        isAnimatingOut = false
        // First launch uses defaultFrame(); afterwards the autosaved frame the user left it at.
        let target = panel.frame
        panel.setFrame(target.offsetBy(dx: 0, dy: Self.slideDistance), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible, !isAnimatingOut else { return }
        isAnimatingOut = true
        let resting = panel.frame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(resting.offsetBy(dx: 0, dy: Self.slideDistance), display: true)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isAnimatingOut else { return }
                self.isAnimatingOut = false
                panel.orderOut(nil)
                // Restore the resting frame so position/size persist (and autosave) correctly.
                panel.setFrame(resting, display: false)
                panel.alphaValue = 1
            }
        }
    }

    func reload() {
        guard knights.status == .running else { return }
        if webView.url == nil {
            needsLoad = true
            loadIfNeeded()
        } else {
            webView.reload()
        }
    }

    func openInBrowser() {
        NSWorkspace.shared.open(webView.url ?? knights.rootURL)
    }

    private func handleStatusChange(_ status: KnightsStatus) {
        if status == .running {
            if panel?.isVisible == true {
                loadIfNeeded()
            }
        } else {
            // The server went away (restart / failure); load a fresh page once it is back.
            needsLoad = true
        }
        updateContentVisibility(for: status)
    }

    private func updateContentVisibility(for status: KnightsStatus? = nil) {
        let isRunning = (status ?? knights.status) == .running
        webView.isHidden = !isRunning
        placeholderView?.isHidden = isRunning
    }

    private func loadIfNeeded() {
        guard needsLoad, knights.status == .running else { return }
        needsLoad = false
        webView.load(URLRequest(url: knights.rootURL))
    }

    private func makePanel() -> RoundTablePanel {
        // A titled, opaque window with a hidden title bar: the system draws the rounded corners and
        // shadow, so the web view is never masked/composited offscreen on every frame.
        let panel = RoundTablePanel(
            contentRect: defaultFrame(),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.backgroundColor = .black
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 640, height: 420)
        panel.onClose = { [weak self] in self?.hide() }
        panel.onReload = { [weak self] in self?.reload() }
        panel.setFrameAutosaveName(Self.frameAutosaveName)

        let header = NSHostingView(rootView: RoundTableHeaderView(
            knights: knights,
            onReload: { [weak self] in self?.reload() },
            onOpenInBrowser: { [weak self] in self?.openInBrowser() },
            onClose: { [weak self] in self?.hide() }
        ))
        let placeholder = NSHostingView(rootView: RoundTablePlaceholderView(knights: knights))
        placeholderView = placeholder

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = RoundTablePalette.pageBackground.cgColor
        for view in [header, placeholder, webView] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: RoundTablePalette.headerHeight),
        ])
        for view in [placeholder, webView] as [NSView] {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: header.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        panel.contentView = container
        self.panel = panel
        return panel
    }

    /// Centered horizontally on the screen under the mouse, just below the menu bar / notch.
    private func defaultFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            return NSRect(x: 200, y: 200, width: 1000, height: 700)
        }
        let width = min(1040, visible.width - 80)
        let height = min(720, visible.height - 40)
        return NSRect(x: visible.midX - width / 2, y: visible.maxY - 12 - height, width: width, height: height)
    }
}

// MARK: - Web view delegates

extension RoundTablePanelController: WKNavigationDelegate, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              navigationAction.targetFrame?.isMainFrame != false,
              !Self.isRoundTableURL(url, port: knights.port)
        else {
            decisionHandler(.allow)
            return
        }
        // Links leaving the round table go to the user's browser.
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        needsLoad = true
        loadIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "好")
        runAlert(alert) { _ in completionHandler() }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        runAlert(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = prompt
        let field = NSTextField(string: defaultText ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        runAlert(alert) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }

    private func runAlert(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let panel, panel.isVisible {
            alert.beginSheetModal(for: panel, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private static func isRoundTableURL(_ url: URL, port: Int) -> Bool {
        if ["about", "blob", "data"].contains(url.scheme ?? "") { return true }
        return ["127.0.0.1", "localhost"].contains(url.host ?? "") && (url.port ?? 80) == port
    }
}

// MARK: - Panel

final class RoundTablePanel: NSWindow {
    var onClose: (() -> Void)?
    var onReload: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// casebase has no main menu, so wire the standard editing shortcuts here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard event.type == .keyDown, flags.contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }

        let action: Selector?
        switch (key, flags) {
        case ("w", [.command]):
            onClose?()
            return true
        case ("r", [.command]):
            onReload?()
            return true
        case ("c", [.command]): action = #selector(NSText.copy(_:))
        case ("v", [.command]): action = #selector(NSText.paste(_:))
        case ("x", [.command]): action = #selector(NSText.cut(_:))
        case ("a", [.command]): action = #selector(NSText.selectAll(_:))
        case ("z", [.command]): action = Selector(("undo:"))
        case ("z", [.command, .shift]): action = Selector(("redo:"))
        default: action = nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - SwiftUI chrome

enum RoundTablePalette {
    static let headerHeight: CGFloat = 44
    /// 12 Knights dark theme background (`--bg`), so the page and the chrome blend.
    static let pageBackground = NSColor(red: 0x26 / 255, green: 0x26 / 255, blue: 0x24 / 255, alpha: 1)
    /// 12 Knights dark sidebar (`--side`), used for the header strip.
    static let headerBackground = Color(red: 0x1F / 255, green: 0x1E / 255, blue: 0x1D / 255)
}

private struct RoundTableHeaderView: View {
    @ObservedObject var knights: CasebaseKnightsService
    let onReload: () -> Void
    let onOpenInBrowser: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            NotchPixelIconView(icon: .sword, color: .white.opacity(0.86), size: 14)
            Text("圆桌")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("12 Knights")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))

            Spacer(minLength: 0)

            RoundTableHeaderButton(icon: .refresh, helpText: "重新载入（⌘R）", action: onReload)
                .disabled(knights.status != .running)
            RoundTableHeaderButton(icon: .open, helpText: "在浏览器打开", action: onOpenInBrowser)
                .disabled(knights.status != .running)
            RoundTableHeaderButton(icon: .cross, helpText: "收起（⌘W）", action: onClose)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragArea())
        .background(RoundTablePalette.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var statusColor: Color {
        switch knights.status {
        case .running:
            return Color(red: 0.36, green: 0.82, blue: 0.48)
        case .starting, .idle:
            return Color.white.opacity(0.45)
        case .portConflict, .nodeMissing, .failed:
            return Color(red: 0.93, green: 0.36, blue: 0.33)
        }
    }
}

private struct RoundTablePlaceholderView: View {
    @ObservedObject var knights: CasebaseKnightsService

    var body: some View {
        VStack(spacing: 14) {
            if let failure = knights.failureDescription {
                NotchPixelDisplayIcon(icon: .warning, tone: .danger, size: 26)
                Text(failure)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button("重试", action: knights.retry)
                        .buttonStyle(NotchActionButtonStyle(prominent: true))
                    Button("查看日志", action: knights.openLog)
                        .buttonStyle(NotchActionButtonStyle(prominent: false))
                }
            } else {
                NotchPixelDisplayIcon(icon: .hourglass, tone: .neutral, size: 26)
                Text("圆桌启动中…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: RoundTablePalette.pageBackground))
    }
}

private struct RoundTableHeaderButton: View {
    let icon: NotchPixelIcon
    let helpText: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            NotchPixelIconView(icon: icon, color: .white.opacity(isEnabled ? 0.8 : 0.3), size: 12)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay { Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

/// Lets the header act as a title bar.
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.zoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
