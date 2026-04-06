import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let notchAnimation = Animation.interactiveSpring(duration: 0.314)
private let supportedDropTypes = [
    UTType.fileURL.identifier,
    UTType.image.identifier,
    UTType.plainText.identifier,
    UTType.utf8PlainText.identifier
]

struct NotchHoverView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .top) {
            NotchBackgroundView(viewModel: viewModel)
                .scaleEffect(viewModel.feedbackScale, anchor: .top)
                .zIndex(0)

            if !viewModel.selectionCaptureAuthorized, !viewModel.isExpanded {
                SelectionCaptureWarningAccessoryView()
                    .offset(x: -((viewModel.surfaceSize.width / 2) + 26), y: 0)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(0.5)
            }

            if viewModel.showsTaskRail {
                NotchTaskRailView(
                    state: viewModel.taskRailState,
                    badgeText: viewModel.taskRailBadgeText,
                    onTap: viewModel.openTaskPanel
                )
                .offset(y: viewModel.taskRailOffsetY)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            if viewModel.isExpanded {
                NotchCompositeView(viewModel: viewModel)
                    .padding(.top, viewModel.displayCutoutRect.height - viewModel.contentPadding + 1)
                    .padding(viewModel.contentPadding)
                    .frame(
                        width: viewModel.expandedPanelSize.width,
                        height: viewModel.expandedPanelSize.height
                    )
                    .scaleEffect(viewModel.feedbackScale, anchor: .top)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .onDrop(
            of: supportedDropTypes,
            isTargeted: dropTargetBinding,
            perform: viewModel.handleDrop(providers:)
        )
        .onHover { isHovering in
            guard !viewModel.shouldRemainExpanded || viewModel.isDismissed else {
                self.isHovering = isHovering
                return
            }

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

    private var dropTargetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isDropTargeted },
            set: { viewModel.updateDropTargeted($0) }
        )
    }

    private func reevaluateHover() {
        guard !viewModel.shouldRemainExpanded || viewModel.isDismissed else { return }
        let currentlyInside = viewModel.hoverRect.contains(NSEvent.mouseLocation)
        isHovering = currentlyInside

        if currentlyInside {
            viewModel.expand()
        } else {
            viewModel.collapse()
        }
    }
}

private struct SelectionCaptureWarningAccessoryView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.black)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(Color(red: 1.0, green: 0.84, blue: 0.32))
                )
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(.black)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }
}

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        NotchHoverView(viewModel: viewModel)
            .animation(notchAnimation, value: viewModel.status)
            .animation(notchAnimation, value: viewModel.surfaceState)
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
