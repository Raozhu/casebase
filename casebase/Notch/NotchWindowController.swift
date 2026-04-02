import Cocoa
import SwiftUI

private let topOverlayHeight: CGFloat = 280
private let fallbackCutoutSize = CGSize(width: 150, height: 24)

final class NotchWindowController: NSWindowController {
    let viewModel: NotchViewModel

    init(screen: NSScreen) {
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

        viewModel = NotchViewModel(screenFrame: screen.frame, displayCutoutRect: displayCutoutRect)
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

        DispatchQueue.main.async { [weak self] in
            self?.viewModel.updateScreenFrame(screen.frame)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func destroy() {
        viewModel.collapse()
        window?.close()
        contentViewController = nil
        window = nil
    }
}
