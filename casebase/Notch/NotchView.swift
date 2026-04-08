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

            if viewModel.collapsedLeadingExtensionWidth > 0 {
                CollapsedIndicatorView(indicator: viewModel.collapsedIndicator)
                    .frame(
                        width: viewModel.collapsedLeadingExtensionWidth,
                        height: viewModel.surfaceSize.height,
                        alignment: .center
                    )
                    .offset(
                        x: -((viewModel.surfaceSize.width / 2) - (viewModel.collapsedLeadingExtensionWidth / 2)),
                        y: 0
                    )
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let collapsedTrailingText = viewModel.collapsedTrailingText,
               viewModel.collapsedTrailingExtensionWidth > 0
            {
                CollapsedTrailingBadgeView(text: collapsedTrailingText)
                    .frame(
                        width: viewModel.collapsedTrailingExtensionWidth,
                        height: viewModel.surfaceSize.height,
                        alignment: .center
                    )
                    .offset(
                        x: (viewModel.surfaceSize.width / 2) - (viewModel.collapsedTrailingExtensionWidth / 2),
                        y: 0
                    )
                    .transition(.opacity)
                    .zIndex(1)
            }

            if viewModel.showsTaskRail {
                NotchTaskRailView(
                    state: viewModel.taskRailState,
                    text: viewModel.taskRailDisplayText,
                    showsShimmer: viewModel.taskRailShowsShimmer,
                    onTap: viewModel.openTaskPanel
                )
                .offset(y: viewModel.taskRailOffsetY)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            if viewModel.isExpanded {
                NotchCompositeView(viewModel: viewModel)
                    .padding(.top, viewModel.expandedContentTopInset)
                    .padding(viewModel.contentPadding)
                    .frame(
                        width: viewModel.expandedPanelSize.width,
                        height: viewModel.expandedSurfaceHeight,
                        alignment: .top
                    )
                    .scaleEffect(viewModel.feedbackScale, anchor: .top)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .offset(x: viewModel.surfaceHorizontalOffset)
        .onDrop(
            of: supportedDropTypes,
            isTargeted: dropTargetBinding,
            perform: viewModel.handleDrop(providers:)
        )
        .onHover { isHovering in
            if !isHovering {
                self.isHovering = false
                viewModel.restoreHoverAfterMouseExit()
                guard !viewModel.shouldRemainExpanded || viewModel.isDismissed else { return }
                viewModel.collapse()
                return
            }

            guard !viewModel.suppressHoverUntilMouseExit else {
                self.isHovering = true
                return
            }

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

        if !currentlyInside {
            viewModel.restoreHoverAfterMouseExit()
        }

        guard !viewModel.suppressHoverUntilMouseExit else { return }

        if currentlyInside {
            viewModel.expand()
        } else {
            viewModel.collapse()
        }
    }
}

private struct CollapsedTrailingBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 18)
    }
}

private struct CollapsedIndicatorView: View {
    let indicator: NotchViewModel.CollapsedIndicator?

    var body: some View {
        switch indicator {
        case .warning:
            collapsedIndicatorIcon(
                systemName: "exclamationmark",
                fill: Color(red: 1.0, green: 0.84, blue: 0.32),
                foreground: .black
            )
        case .error:
            collapsedIndicatorIcon(
                systemName: "xmark",
                fill: Color(red: 0.91, green: 0.25, blue: 0.25),
                foreground: .white
            )
        case .preparing:
            collapsedIndicatorIcon(
                systemName: "ellipsis",
                fill: Color.white.opacity(0.92),
                foreground: .black
            )
        case .recognizing:
            AnimatedCollapsedIndicatorIcon(
                systemName: "sparkles",
                fill: Color(red: 0.62, green: 0.84, blue: 1.0),
                foreground: .black,
                rotates: true
            )
        case .storing:
            collapsedIndicatorIcon(
                systemName: "arrow.down",
                fill: Color(red: 0.64, green: 1.0, blue: 0.82),
                foreground: .black
            )
        case .needsInput:
            collapsedIndicatorIcon(
                systemName: "questionmark",
                fill: Color(red: 1.0, green: 0.84, blue: 0.32),
                foreground: .black
            )
        case .success:
            collapsedIndicatorIcon(
                systemName: "checkmark",
                fill: Color.white.opacity(0.94),
                foreground: .black
            )
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func collapsedIndicatorIcon(systemName: String, fill: Color, foreground: Color) -> some View {
        AnimatedCollapsedIndicatorIcon(
            systemName: systemName,
            fill: fill,
            foreground: foreground,
            rotates: false
        )
    }
}

private struct AnimatedCollapsedIndicatorIcon: View {
    let systemName: String
    let fill: Color
    let foreground: Color
    let rotates: Bool

    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(foreground)
            .rotationEffect(.degrees(rotation))
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(fill)
            )
            .onAppear {
                updateRotation()
            }
            .onChange(of: rotates) {
                updateRotation()
            }
            .animation(
                rotates
                    ? .linear(duration: 1.4).repeatForever(autoreverses: false)
                    : .default,
                value: rotation
            )
    }

    private func updateRotation() {
        rotation = rotates ? 360 : 0
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
            .offset(x: viewModel.surfaceHorizontalOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
