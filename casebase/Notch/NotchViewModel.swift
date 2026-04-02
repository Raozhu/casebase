import Combine
import CoreGraphics

final class NotchViewModel: ObservableObject {
    enum Status: Equatable {
        case collapsed
        case expanded
    }

    let hoverInset: CGFloat = -16
    let hoverRange: CGFloat = 32
    let contentPadding: CGFloat = 16
    let expandedPanelSize = CGSize(width: 420, height: 168)

    @Published private(set) var status: Status = .collapsed
    @Published var displayCutoutRect: CGRect
    @Published var screenFrame: CGRect

    init(screenFrame: CGRect, displayCutoutRect: CGRect) {
        self.screenFrame = screenFrame
        self.displayCutoutRect = displayCutoutRect
    }

    var isExpanded: Bool {
        status == .expanded
    }

    var surfaceSize: CGSize {
        isExpanded
            ? expandedPanelSize
            : CGSize(
                width: max(0, displayCutoutRect.width),
                height: max(0, displayCutoutRect.height + 1)
            )
    }

    var surfaceRect: CGRect {
        CGRect(
            x: screenFrame.origin.x + (screenFrame.width - surfaceSize.width) / 2,
            y: screenFrame.origin.y + screenFrame.height - surfaceSize.height,
            width: surfaceSize.width,
            height: surfaceSize.height
        )
    }

    var hoverRect: CGRect {
        surfaceRect.insetBy(dx: hoverInset, dy: hoverInset)
    }

    var cornerRadius: CGFloat {
        isExpanded ? 32 : 8
    }

    func updateScreenFrame(_ frame: CGRect) {
        screenFrame = frame
    }

    func expand() {
        status = .expanded
    }

    func collapse() {
        status = .collapsed
    }
}
