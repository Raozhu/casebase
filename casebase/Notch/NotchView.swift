import AppKit
import SwiftUI

private let notchAnimation = Animation.interactiveSpring(duration: 0.314)

struct NotchHoverView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .top) {
            NotchBackgroundView(viewModel: viewModel)
                .zIndex(0)

            if viewModel.isExpanded {
                NotchCompositeView(viewModel: viewModel)
                    .padding(.top, viewModel.displayCutoutRect.height - viewModel.contentPadding + 1)
                    .padding(viewModel.contentPadding)
                    .frame(
                        width: viewModel.expandedPanelSize.width,
                        height: viewModel.expandedPanelSize.height
                    )
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onHover { isHovering in
            if isHovering {
                reevaluateHover()
            } else {
                self.isHovering = false
                viewModel.collapse()
            }
        }
        .onChange(of: viewModel.surfaceRect) { reevaluateHover() }
        .onChange(of: viewModel.status) { reevaluateHover() }
    }

    private func reevaluateHover() {
        let currentlyInside = viewModel.hoverRect.contains(NSEvent.mouseLocation)
        if currentlyInside != isHovering {
            isHovering = currentlyInside
            if currentlyInside {
                viewModel.expand()
            } else {
                viewModel.collapse()
            }
        }
    }
}

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        NotchHoverView(viewModel: viewModel)
            .animation(notchAnimation, value: viewModel.status)
            .background(hoverHitArea)
            .preferredColorScheme(.dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var hoverHitArea: some View {
        RoundedRectangle(cornerRadius: viewModel.cornerRadius)
            .foregroundStyle(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .frame(
                width: viewModel.surfaceSize.width + viewModel.hoverRange,
                height: viewModel.surfaceSize.height + viewModel.hoverRange
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
