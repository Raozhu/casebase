import AppKit
import SwiftUI

/// Everything on the fake screen that is not casebase itself: wallpaper, menu bar,
/// desktop file, a browser window, the cursor and a keystroke HUD.
@MainActor
final class StageProps: ObservableObject {
    @Published var cursorPosition = CGPoint(x: 1100, y: 640)
    @Published var cursorVisible = true
    @Published var cursorPressed = false
    @Published var draggedIcon: NSImage?
    @Published var desktopFile: DesktopFile?
    @Published var browser: BrowserWindow?
    @Published var keys: [String] = []
    @Published var caption: String?

    struct DesktopFile {
        let icon: NSImage
        let name: String
        let position: CGPoint
    }

    struct BrowserWindow {
        let frame: CGRect
        let title: String
        let url: String
        let chartTitle: String
        let chartSubtitle: String
        let bars: [(String, Double)]
    }

    private var segment: (from: CGPoint, to: CGPoint, start: CFTimeInterval, duration: CFTimeInterval)?

    func advance(to now: CFTimeInterval) {
        guard let segment else { return }
        let t = min(1, max(0, (now - segment.start) / segment.duration))
        let e = easeInOut(t)
        cursorPosition = CGPoint(
            x: segment.from.x + (segment.to.x - segment.from.x) * e,
            y: segment.from.y + (segment.to.y - segment.from.y) * e
        )
        if t >= 1 { self.segment = nil }
    }

    func moveCursor(to point: CGPoint, duration: TimeInterval) async {
        segment = (cursorPosition, point, CACurrentMediaTime(), duration)
        await pause(duration)
        advance(to: .infinity)
    }

    func click() async {
        cursorPressed = true
        await pause(0.12)
        cursorPressed = false
        await pause(0.08)
    }
}

func pause(_ seconds: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

// MARK: - Backdrop

struct DemoBackdrop: View {
    @ObservedObject var props: StageProps

    var body: some View {
        ZStack(alignment: .topLeading) {
            Wallpaper()
            MenuBar()

            if let file = props.desktopFile {
                VStack(spacing: 4) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                }
                .opacity(props.draggedIcon == nil ? 1 : 0.45)
                .position(file.position)
            }

            if let browser = props.browser {
                BrowserWindowView(browser: browser)
                    .frame(width: browser.frame.width, height: browser.frame.height)
                    .position(x: browser.frame.midX, y: browser.frame.midY)
            }
        }
        .frame(width: Stage.size.width, height: Stage.size.height, alignment: .topLeading)
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.16, blue: 0.33),
                    Color(red: 0.30, green: 0.22, blue: 0.45),
                    Color(red: 0.62, green: 0.38, blue: 0.48),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.98, green: 0.64, blue: 0.45).opacity(0.45), .clear],
                center: UnitPoint(x: 0.78, y: 0.92),
                startRadius: 20,
                endRadius: 620
            )
            RadialGradient(
                colors: [Color(red: 0.35, green: 0.55, blue: 0.98).opacity(0.35), .clear],
                center: UnitPoint(x: 0.12, y: 0.18),
                startRadius: 10,
                endRadius: 560
            )
        }
    }
}

/// Only the bar itself: menu titles would be cut off at the edge of the clip.
private struct MenuBar: View {
    var body: some View {
        Color.black.opacity(0.18)
            .frame(height: Stage.cutoutSize.height)
            .frame(maxWidth: .infinity)
    }
}

private struct BrowserWindowView: View {
    let browser: StageProps.BrowserWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                    Circle().fill($0).frame(width: 12, height: 12)
                }
                Spacer().frame(width: 18)
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text(browser.url).font(.system(size: 12))
                }
                .foregroundStyle(Color.black.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.black.opacity(0.06)))
                Spacer().frame(width: 60)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color(white: 0.96))

            VStack(alignment: .leading, spacing: 6) {
                Text(browser.chartTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(white: 0.12))
                Text(browser.chartSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.45))
                    .padding(.bottom, 14)
                HStack(alignment: .bottom, spacing: 18) {
                    let maxValue = browser.bars.map(\.1).max() ?? 1
                    ForEach(Array(browser.bars.enumerated()), id: \.offset) { index, bar in
                        VStack(spacing: 6) {
                            Text(String(format: "%.0f", bar.1))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.35))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(index == browser.bars.count - 1
                                    ? Color(red: 0.31, green: 0.45, blue: 0.98)
                                    : Color(red: 0.31, green: 0.45, blue: 0.98).opacity(0.35))
                                .frame(width: 44, height: CGFloat(bar.1 / maxValue) * 150)
                            Text(bar.0)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(white: 0.45))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
    }
}

// MARK: - Overlay

struct DemoOverlay: View {
    @ObservedObject var props: StageProps
    private let cursor = NSCursor.arrow

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let icon = props.draggedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .opacity(0.85)
                    .position(x: props.cursorPosition.x + 6, y: props.cursorPosition.y + 30)
            }

            if props.cursorVisible {
                Image(nsImage: cursor.image)
                    .scaleEffect(props.cursorPressed ? 0.86 : 1, anchor: .topLeading)
                    .offset(x: props.cursorPosition.x - cursor.hotSpot.x, y: props.cursorPosition.y - cursor.hotSpot.y)
            }

            if !props.keys.isEmpty {
                HStack(spacing: 8) {
                    ForEach(props.keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 58, minHeight: 58)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.14)))
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.62)))
                .position(x: Stage.size.width / 2, y: 470)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if let caption = props.caption {
                Text(caption)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .position(x: Stage.size.width / 2, y: 588)
                    .id(caption)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: props.keys)
        .animation(.easeInOut(duration: 0.25), value: props.caption)
        .frame(width: Stage.size.width, height: Stage.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
