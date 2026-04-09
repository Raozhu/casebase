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
                CollapsedTrailingBadgeView(
                    text: collapsedTrailingText,
                    tone: viewModel.collapsedIndicator == .error ? .danger : .info
                )
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
                    onTap: viewModel.openLibrary
                )
                .offset(y: viewModel.taskRailOffsetY)
                .transition(.notchRailMorph)
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
    let tone: NotchPixelTone

    var body: some View {
        NotchPixelCountBadge(text: text, tone: tone)
            .scaleEffect(0.88)
    }
}

private struct CollapsedIndicatorView: View {
    let indicator: NotchViewModel.CollapsedIndicator?

    var body: some View {
        Group {
            if let indicator {
                PixelCollapsedIndicatorBadge(indicator: indicator)
            }
        }
    }
}

private struct PixelCollapsedIndicatorBadge: View {
    let indicator: NotchViewModel.CollapsedIndicator

    var body: some View {
        TimelineView(.animation(minimumInterval: timelineInterval)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let discreteStep = Int(floor(elapsed / 0.26))
            let pulse = CGFloat(sin(elapsed * pulseFrequency))
            let scale = 1 + (pulse * pulseAmplitude)
            let yOffset = pulse * bobAmplitude

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(plateColor)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)

                if isHourglass {
                    PixelGlyph(pattern: PixelGlyphPattern.hourglassFrame, color: glyphColor)
                    PixelGlyph(pattern: PixelGlyphPattern.hourglassSand(step: discreteStep), color: accentColor)
                } else {
                    PixelGlyph(pattern: glyphPattern, color: glyphColor)
                }
            }
            .frame(width: 20, height: 20)
            .shadow(color: accentColor.opacity(0.22), radius: 8, y: 4)
            .scaleEffect(scale)
            .offset(y: yOffset)
        }
    }

    private var isHourglass: Bool {
        switch indicator {
        case .preparing, .recognizing, .storing:
            return true
        case .warning, .error, .needsInput, .success:
            return false
        }
    }

    private var glyphPattern: [String] {
        switch indicator {
        case .warning:
            return PixelGlyphPattern.exclamation
        case .error:
            return PixelGlyphPattern.cross
        case .needsInput:
            return PixelGlyphPattern.question
        case .success:
            return PixelGlyphPattern.check
        case .preparing, .recognizing, .storing:
            return PixelGlyphPattern.hourglassFrame
        }
    }

    private var plateColor: Color {
        switch indicator {
        case .warning:
            return Color(red: 0.29, green: 0.20, blue: 0.05)
        case .error:
            return Color(red: 0.29, green: 0.08, blue: 0.09)
        case .preparing:
            return Color(red: 0.17, green: 0.18, blue: 0.22)
        case .recognizing:
            return Color(red: 0.12, green: 0.19, blue: 0.28)
        case .storing:
            return Color(red: 0.08, green: 0.22, blue: 0.18)
        case .needsInput:
            return Color(red: 0.27, green: 0.18, blue: 0.05)
        case .success:
            return Color(red: 0.07, green: 0.24, blue: 0.14)
        }
    }

    private var borderColor: Color {
        accentColor.opacity(0.42)
    }

    private var glyphColor: Color {
        switch indicator {
        case .warning:
            return Color(red: 1.0, green: 0.88, blue: 0.46)
        case .error:
            return Color(red: 1.0, green: 0.76, blue: 0.78)
        case .preparing:
            return Color.white.opacity(0.86)
        case .recognizing:
            return Color(red: 0.82, green: 0.93, blue: 1.0)
        case .storing:
            return Color(red: 0.84, green: 1.0, blue: 0.92)
        case .needsInput:
            return Color(red: 1.0, green: 0.88, blue: 0.46)
        case .success:
            return Color(red: 0.82, green: 1.0, blue: 0.74)
        }
    }

    private var accentColor: Color {
        switch indicator {
        case .warning:
            return Color(red: 1.0, green: 0.78, blue: 0.22)
        case .error:
            return Color(red: 0.94, green: 0.27, blue: 0.29)
        case .preparing:
            return Color.white.opacity(0.72)
        case .recognizing:
            return Color(red: 0.43, green: 0.80, blue: 1.0)
        case .storing:
            return Color(red: 0.47, green: 1.0, blue: 0.78)
        case .needsInput:
            return Color(red: 1.0, green: 0.78, blue: 0.22)
        case .success:
            return Color(red: 0.47, green: 1.0, blue: 0.67)
        }
    }

    private var timelineInterval: TimeInterval {
        isHourglass ? 0.16 : 1.0 / 30.0
    }

    private var pulseFrequency: Double {
        switch indicator {
        case .preparing:
            return 2.8
        case .recognizing:
            return 3.8
        case .storing:
            return 3.2
        case .warning, .needsInput:
            return 2.6
        case .error:
            return 5.0
        case .success:
            return 3.4
        }
    }

    private var pulseAmplitude: CGFloat {
        switch indicator {
        case .warning, .needsInput, .success:
            return 0.03
        case .error:
            return 0.04
        case .preparing, .recognizing, .storing:
            return 0.02
        }
    }

    private var bobAmplitude: CGFloat {
        switch indicator {
        case .preparing, .recognizing, .storing:
            return 0.8
        case .warning, .needsInput, .success:
            return 0.4
        case .error:
            return 0.55
        }
    }
}

private struct PixelGlyph: View {
    let pattern: [String]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard let firstRow = pattern.first, !firstRow.isEmpty else { return }

            let rows = pattern.count
            let columns = firstRow.count
            let cellSize = floor(min(size.width / CGFloat(columns), size.height / CGFloat(rows)))
            guard cellSize > 0 else { return }

            let glyphWidth = CGFloat(columns) * cellSize
            let glyphHeight = CGFloat(rows) * cellSize
            let originX = (size.width - glyphWidth) / 2
            let originY = (size.height - glyphHeight) / 2
            let pixelSize = max(1, cellSize - 0.8)
            let corner = min(1.2, pixelSize * 0.22)

            for (rowIndex, row) in pattern.enumerated() {
                for (columnIndex, character) in row.enumerated() where character == "1" {
                    let rect = CGRect(
                        x: originX + (CGFloat(columnIndex) * cellSize),
                        y: originY + (CGFloat(rowIndex) * cellSize),
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: corner),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

private enum PixelGlyphPattern {
    static let exclamation = [
        "0011100",
        "0011100",
        "0011100",
        "0011100",
        "0011100",
        "0000000",
        "0011100",
    ]

    static let question = [
        "0011100",
        "0100010",
        "0000010",
        "0001100",
        "0001000",
        "0000000",
        "0001000",
    ]

    static let check = [
        "0000000",
        "0000010",
        "0000110",
        "0101100",
        "0111000",
        "0010000",
        "0000000",
    ]

    static let cross = [
        "1000001",
        "0100010",
        "0010100",
        "0001000",
        "0010100",
        "0100010",
        "1000001",
    ]

    static let hourglassFrame = [
        "1111111",
        "0100010",
        "0011100",
        "0001000",
        "0011100",
        "0100010",
        "1111111",
    ]

    static func hourglassSand(step: Int) -> [String] {
        switch step % 4 {
        case 0:
            return [
                "0000000",
                "0011100",
                "0001000",
                "0000000",
                "0000000",
                "0000000",
                "0000000",
            ]
        case 1:
            return [
                "0000000",
                "0001000",
                "0001000",
                "0001000",
                "0000000",
                "0000000",
                "0000000",
            ]
        case 2:
            return [
                "0000000",
                "0000000",
                "0001000",
                "0001000",
                "0001000",
                "0000000",
                "0000000",
            ]
        default:
            return [
                "0000000",
                "0000000",
                "0000000",
                "0000000",
                "0001000",
                "0011100",
                "0000000",
            ]
        }
    }
}

private struct TaskRailMorphModifier: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 0.46 + (0.54 * progress),
                y: 0.18 + (0.82 * progress),
                anchor: .top
            )
            .offset(y: -8 * (1 - progress))
            .blur(radius: 8 * (1 - progress))
            .opacity(progress)
    }
}

private extension AnyTransition {
    static var notchRailMorph: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: TaskRailMorphModifier(progress: 0.02),
                identity: TaskRailMorphModifier(progress: 1)
            ),
            removal: .modifier(
                active: TaskRailMorphModifier(progress: 0.02),
                identity: TaskRailMorphModifier(progress: 1)
            )
        )
    }
}

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        NotchHoverView(viewModel: viewModel)
            .animation(notchAnimation, value: viewModel.status)
            .animation(notchAnimation, value: viewModel.surfaceState)
            .animation(notchAnimation, value: viewModel.showsTaskRail)
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
