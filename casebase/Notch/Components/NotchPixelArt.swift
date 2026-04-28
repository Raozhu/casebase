import Foundation
import SwiftUI

enum NotchPixelTone {
    case neutral
    case accent
    case warning
    case danger
    case success
    case info

    var plateColor: Color {
        switch self {
        case .neutral:
            return Color.white.opacity(0.08)
        case .accent:
            return Color(red: 0.10, green: 0.23, blue: 0.40)
        case .warning:
            return Color(red: 0.29, green: 0.20, blue: 0.05)
        case .danger:
            return Color(red: 0.29, green: 0.08, blue: 0.09)
        case .success:
            return Color(red: 0.07, green: 0.24, blue: 0.14)
        case .info:
            return Color(red: 0.13, green: 0.18, blue: 0.28)
        }
    }

    var glyphColor: Color {
        switch self {
        case .neutral:
            return Color.white.opacity(0.86)
        case .accent:
            return Color(red: 0.78, green: 0.91, blue: 1.0)
        case .warning:
            return Color(red: 1.0, green: 0.88, blue: 0.46)
        case .danger:
            return Color(red: 1.0, green: 0.76, blue: 0.78)
        case .success:
            return Color(red: 0.82, green: 1.0, blue: 0.74)
        case .info:
            return Color(red: 0.67, green: 0.86, blue: 1.0)
        }
    }

    var borderColor: Color {
        glyphColor.opacity(0.34)
    }
}

enum NotchPixelIcon {
    case warning
    case question
    case check
    case cross
    case hourglass
    case gear
    case library
    case search
    case chevronLeft
    case chevronRight
    case arrowRight
    case arrowUp
    case replyAll
    case skip
    case refresh
    case trash
    case power
    case folder
    case open
    case copy
    case image
    case text
    case pdf
    case audio
    case file
    case screen
    case box
    case reset

    var pattern: [String] {
        switch self {
        case .warning:
            return [
                "0011100",
                "0011100",
                "0011100",
                "0011100",
                "0011100",
                "0000000",
                "0011100",
            ]
        case .question:
            return [
                "0011100",
                "0100010",
                "0000010",
                "0001100",
                "0001000",
                "0000000",
                "0001000",
            ]
        case .check:
            return [
                "0000000",
                "0000010",
                "0000110",
                "0101100",
                "0111000",
                "0010000",
                "0000000",
            ]
        case .cross:
            return [
                "1000001",
                "0100010",
                "0010100",
                "0001000",
                "0010100",
                "0100010",
                "1000001",
            ]
        case .hourglass:
            return [
                "1111111",
                "0100010",
                "0011100",
                "0001000",
                "0011100",
                "0100010",
                "1111111",
            ]
        case .gear:
            return [
                "000111000",
                "001111100",
                "011010110",
                "111101111",
                "111010111",
                "111101111",
                "011010110",
                "001111100",
                "000111000",
            ]
        case .library:
            return [
                "110011001",
                "110011001",
                "111011101",
                "110011001",
                "110011001",
                "111111111",
                "110110011",
                "110110011",
                "111111111",
            ]
        case .search:
            return [
                "000111000",
                "001000100",
                "010000010",
                "010110010",
                "010110010",
                "010000010",
                "001000110",
                "000111101",
                "000000011",
            ]
        case .chevronLeft:
            return [
                "0001000",
                "0010000",
                "0100000",
                "1000000",
                "0100000",
                "0010000",
                "0001000",
            ]
        case .chevronRight:
            return [
                "0001000",
                "0000100",
                "0000010",
                "0000001",
                "0000010",
                "0000100",
                "0001000",
            ]
        case .arrowRight:
            return [
                "0001000",
                "0001100",
                "1111111",
                "1111111",
                "0001100",
                "0001000",
                "0000000",
            ]
        case .arrowUp:
            return [
                "0001000",
                "0011100",
                "0111110",
                "0001000",
                "0001000",
                "0001000",
                "0001000",
            ]
        case .replyAll:
            return [
                "0001000",
                "0001100",
                "1111111",
                "1111111",
                "0001100",
                "0001000",
                "0000000",
            ]
        case .skip:
            return [
                "0010001",
                "0011001",
                "1111101",
                "1111111",
                "1111101",
                "0011001",
                "0010001",
            ]
        case .refresh, .reset:
            return [
                "0011110",
                "0100001",
                "1001111",
                "1001000",
                "1001110",
                "0100010",
                "0011100",
            ]
        case .trash:
            return [
                "0011100",
                "0111110",
                "0011100",
                "0110110",
                "0110110",
                "0111110",
                "0011100",
            ]
        case .power:
            return [
                "0011100",
                "0100010",
                "1001001",
                "1001001",
                "1000001",
                "0100010",
                "0011100",
            ]
        case .folder:
            return [
                "0011100",
                "0111111",
                "1100001",
                "1111111",
                "1111111",
                "1111111",
                "0000000",
            ]
        case .open:
            return [
                "1111110",
                "1000010",
                "1000010",
                "1011111",
                "0000110",
                "0001100",
                "0011000",
            ]
        case .copy:
            return [
                "0111100",
                "0100100",
                "0111100",
                "0011110",
                "0010010",
                "0011110",
                "0000000",
            ]
        case .image:
            return [
                "1111111",
                "1000001",
                "1010001",
                "1001101",
                "1011111",
                "1000001",
                "1111111",
            ]
        case .text:
            return [
                "1111111",
                "1000000",
                "1111100",
                "1000000",
                "1111110",
                "1000000",
                "1000000",
            ]
        case .pdf:
            return [
                "1111100",
                "1000010",
                "1111100",
                "1000000",
                "1000000",
                "1000000",
                "0000000",
            ]
        case .audio:
            return [
                "0100010",
                "0100010",
                "0110110",
                "0111110",
                "0011100",
                "0011100",
                "0001000",
            ]
        case .file:
            return [
                "1111100",
                "1000100",
                "1000100",
                "1000100",
                "1000100",
                "1111110",
                "0000000",
            ]
        case .screen:
            return [
                "1111111",
                "1000001",
                "1000001",
                "1000001",
                "1111111",
                "0011100",
                "0001000",
            ]
        case .box:
            return [
                "0011100",
                "0111110",
                "1100011",
                "1111111",
                "1111111",
                "1100011",
                "1000001",
            ]
        }
    }
}

struct NotchPixelGlyphView: View {
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
                    context.fill(Path(roundedRect: rect, cornerRadius: corner), with: .color(color))
                }
            }
        }
    }
}

struct NotchPixelIconView: View {
    let icon: NotchPixelIcon
    let color: Color
    var size: CGFloat = 14

    var body: some View {
        Group {
            if let svgSymbol = icon.svgSymbol {
                NotchSVGPathView(
                    pathData: svgSymbol.pathData,
                    color: color,
                    renderingMode: svgSymbol.renderingMode
                )
            } else {
                NotchPixelGlyphView(pattern: icon.pattern, color: color)
            }
        }
        .frame(width: size, height: size)
    }
}

struct NotchPixelBadge: View {
    let icon: NotchPixelIcon
    let tone: NotchPixelTone
    var size: CGFloat = 20
    var showsGlow: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tone.plateColor)

            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .strokeBorder(tone.borderColor, lineWidth: 1)

            NotchPixelIconView(icon: icon, color: tone.glyphColor, size: size * 0.56)
        }
        .frame(width: size, height: size)
        .shadow(color: showsGlow ? tone.glyphColor.opacity(0.18) : .clear, radius: 6, y: 3)
    }
}

struct NotchPixelDisplayIcon: View {
    let icon: NotchPixelIcon
    let tone: NotchPixelTone
    var size: CGFloat = 16
    var glowOpacity: Double = 0.12

    var body: some View {
        NotchPixelIconView(icon: icon, color: tone.glyphColor, size: size)
            .shadow(color: tone.glyphColor.opacity(glowOpacity), radius: 6, y: 2)
    }
}

struct NotchPixelTextView: View {
    let text: String
    let color: Color
    var size: CGFloat = 11

    var body: some View {
        let normalized = Array(text.uppercased())
        HStack(spacing: max(1, size * 0.08)) {
            ForEach(Array(normalized.enumerated()), id: \.offset) { item in
                let character = item.element
                if let pattern = NotchPixelFontPattern.pattern(for: character) {
                    NotchPixelGlyphView(pattern: pattern, color: color)
                        .frame(width: size * 0.72, height: size)
                }
            }
        }
        .fixedSize()
    }
}

struct NotchPixelCountBadge: View {
    let text: String
    let tone: NotchPixelTone

    var body: some View {
        NotchPixelTextView(text: text, color: tone.glyphColor, size: 9)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tone.plateColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tone.borderColor, lineWidth: 1)
            }
    }
}

enum NotchPixelFontPattern {
    static func pattern(for character: Character) -> [String]? {
        switch character {
        case "0":
            return ["11111","10001","10001","10001","10001","10001","11111"]
        case "1":
            return ["00100","01100","00100","00100","00100","00100","01110"]
        case "2":
            return ["11110","00001","00001","11110","10000","10000","11111"]
        case "3":
            return ["11110","00001","00001","01110","00001","00001","11110"]
        case "4":
            return ["10010","10010","10010","11111","00010","00010","00010"]
        case "5":
            return ["11111","10000","10000","11110","00001","00001","11110"]
        case "6":
            return ["01110","10000","10000","11110","10001","10001","01110"]
        case "7":
            return ["11111","00001","00010","00100","01000","01000","01000"]
        case "8":
            return ["01110","10001","10001","01110","10001","10001","01110"]
        case "9":
            return ["01110","10001","10001","01111","00001","00001","01110"]
        case "+":
            return ["00000","00100","00100","11111","00100","00100","00000"]
        default:
            return nil
        }
    }
}

private struct NotchSVGSymbol {
    let pathData: String
    let renderingMode: NotchSVGRenderingMode
}

private enum NotchSVGRenderingMode {
    case fill
    case stroke(lineWidth: CGFloat, lineCap: CGLineCap)
}

private extension NotchPixelIcon {
    var svgSymbol: NotchSVGSymbol? {
        switch self {
        case .gear:
            return NotchSVGSymbol(
                pathData: "M3 8h4m0 0V6h4v2M7 8v2h4V8m0 0h10M3 16h10m0 0v-2h4v2m-4 0v2h4v-2m0 0h4",
                renderingMode: .stroke(lineWidth: 2, lineCap: .square)
            )
        case .library:
            return NotchSVGSymbol(
                pathData: "M6 6H4v2h2V6zm14 0H8v2h12V6zM4 11h2v2H4v-2zm16 0H8v2h12v-2zM4 16h2v2H4v-2zm16 0H8v2h12v-2z",
                renderingMode: .fill
            )
        case .search:
            return NotchSVGSymbol(
                pathData: "M6 2h8v2H6V2zM4 6V4h2v2H4zm0 8H2V6h2v8zm2 2H4v-2h2v2zm8 0v2H6v-2h8zm2-2h-2v2h2v2h2v2h2v2h2v-2h-2v-2h-2v-2h-2v-2zm0-8h2v8h-2V6zm0 0V4h-2v2h2z",
                renderingMode: .fill
            )
        case .chevronLeft:
            return NotchSVGSymbol(
                pathData: "M16 5v2h-2V5h2zm-4 4V7h2v2h-2zm-2 2V9h2v2h-2zm0 2H8v-2h2v2zm2 2v-2h-2v2h2zm0 0h2v2h-2v-2zm4 4v-2h-2v2h2z",
                renderingMode: .fill
            )
        case .chevronRight:
            return NotchSVGSymbol(
                pathData: "M8 5v2h2V5H8zm4 4V7h-2v2h2zm2 2V9h-2v2h2zm0 2h2v-2h-2v2zm-2 2v-2h2v2h-2zm0 0h-2v2h2v-2zm-4 4v-2h2v2H8z",
                renderingMode: .fill
            )
        case .arrowRight:
            return NotchSVGSymbol(
                pathData: "M4 11v2h12v2h2v-2h2v-2h-2V9h-2v2H4zm10-4h2v2h-2V7zm0 0h-2V5h2v2zm0 10h2v-2h-2v2zm0 0h-2v2h2v-2z",
                renderingMode: .fill
            )
        case .arrowUp:
            return NotchSVGSymbol(
                pathData: "M11 20h2V8h2V6h2V4h-2V2h-2v2h-2v2H9v2h2v12zm-4-8h2v2H7v-2zm8 0h2v2h-2v-2z",
                renderingMode: .fill
            )
        case .replyAll:
            return NotchSVGSymbol(
                pathData: "M13 19h2v-4h7V9h-7V5h-2v2h-2v2H9v2H7v2h2v2h2v2h2v2zM8 7H6v2H4v2H2v2h2v2h2v2h2v2h2v-2H8v-2H6v-2H4v-2h2V9h2V7zm0 0h2V5H8v2z",
                renderingMode: .fill
            )
        case .skip:
            return nil
        case .refresh, .reset:
            return NotchSVGSymbol(
                pathData: "M16 2h-2v2h2v2H4v2H2v5h2V8h12v2h-2v2h2v-2h2V8h2V6h-2V4h-2V2zM6 20h2v2h2v-2H8v-2h12v-2h2v-5h-2v5H8v-2h2v-2H8v2H6v2H4v2h2v2z",
                renderingMode: .fill
            )
        case .trash:
            return NotchSVGSymbol(
                pathData: "M16 2v4h6v2h-2v14H4V8H2V6h6V2h8zm-2 2h-4v2h4V4zm0 4H6v12h12V8h-4zm-5 2h2v8H9v-8zm6 0h-2v8h2v-8z",
                renderingMode: .fill
            )
        case .power:
            return NotchSVGSymbol(
                pathData: "M11 2h2v8h-2V2zm5 2h2v2h2v8h-2v2h-2v2H8v-2H6v-2H4V6h2V4h2v2H6v8h2v2h8v-2h2V6h-2V4z",
                renderingMode: .fill
            )
        case .folder:
            return NotchSVGSymbol(
                pathData: "M4 4h8v2h10v14H2V4h2zm16 4H10V6H4v12h16V8z",
                renderingMode: .fill
            )
        case .copy:
            return NotchSVGSymbol(
                pathData: "M4 2h11v2H6v13H4V2zm4 4h12v16H8V6zm2 2v12h8V8h-8z",
                renderingMode: .fill
            )
        case .image:
            return NotchSVGSymbol(
                pathData: "M4 3H2v18h20V3H4zm16 2v14H4V5h16zm-6 4h-2v2h-2v2H8v2H6v2h2v-2h2v-2h2v-2h2v2h2v2h2v-2h-2v-2h-2V9zM8 7H6v2h2V7z",
                renderingMode: .fill
            )
        case .file:
            return NotchSVGSymbol(
                pathData: "M3 22h18V8h-2V6h-2v2h-2V6h2V4h-2V2H3v20zm2-2V4h8v6h6v10H5z",
                renderingMode: .fill
            )
        case .pdf, .text, .audio, .warning, .question, .check, .cross, .hourglass, .open, .screen, .box:
            return nil
        }
    }
}

private struct NotchSVGPathView: View {
    let pathData: String
    let color: Color
    let renderingMode: NotchSVGRenderingMode

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scaleX = size.width / 24
            let scaleY = size.height / 24

            Group {
                switch renderingMode {
                case .fill:
                    svgPath
                        .fill(color, style: FillStyle(eoFill: false, antialiased: false))
                case let .stroke(lineWidth, lineCap):
                    svgPath
                        .stroke(
                            color,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: lineCap,
                                lineJoin: .miter
                            )
                        )
                }
            }
            .scaleEffect(x: scaleX, y: scaleY, anchor: .topLeading)
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private var svgPath: Path {
        SVGPixelPathParser.makePath(from: pathData)
    }
}

private enum SVGPixelPathParser {
    static func makePath(from string: String) -> Path {
        var path = Path()
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var command: Character?

        while !scanner.isAtEnd {
            if let next = scanner.peekCommand() {
                command = next
                _ = scanner.scanCharacter()
            }

            guard var activeCommand = command else { break }

            switch activeCommand {
            case "M":
                if let x = scanner.scanCGFloat(), let y = scanner.scanCGFloat() {
                    current = CGPoint(x: x, y: y)
                    subpathStart = current
                    path.move(to: current)
                    activeCommand = "L"
                    command = activeCommand
                }
            case "m":
                if let dx = scanner.scanCGFloat(), let dy = scanner.scanCGFloat() {
                    current = CGPoint(x: current.x + dx, y: current.y + dy)
                    subpathStart = current
                    path.move(to: current)
                    activeCommand = "l"
                    command = activeCommand
                }
            case "L":
                if let x = scanner.scanCGFloat(), let y = scanner.scanCGFloat() {
                    current = CGPoint(x: x, y: y)
                    path.addLine(to: current)
                }
            case "l":
                if let dx = scanner.scanCGFloat(), let dy = scanner.scanCGFloat() {
                    current = CGPoint(x: current.x + dx, y: current.y + dy)
                    path.addLine(to: current)
                }
            case "H":
                if let x = scanner.scanCGFloat() {
                    current = CGPoint(x: x, y: current.y)
                    path.addLine(to: current)
                }
            case "h":
                if let dx = scanner.scanCGFloat() {
                    current = CGPoint(x: current.x + dx, y: current.y)
                    path.addLine(to: current)
                }
            case "V":
                if let y = scanner.scanCGFloat() {
                    current = CGPoint(x: current.x, y: y)
                    path.addLine(to: current)
                }
            case "v":
                if let dy = scanner.scanCGFloat() {
                    current = CGPoint(x: current.x, y: current.y + dy)
                    path.addLine(to: current)
                }
            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
                command = nil
            default:
                _ = scanner.scanCharacter()
            }
        }

        return path
    }
}

private extension Scanner {
    func peekCommand() -> Character? {
        guard let scalar = string[currentIndex...].unicodeScalars.first else { return nil }
        let character = Character(scalar)
        return character.isLetter ? character : nil
    }

    @discardableResult
    func scanCharacter() -> Character? {
        guard !isAtEnd else { return nil }
        let character = string[currentIndex]
        currentIndex = string.index(after: currentIndex)
        return character
    }

    func scanCGFloat() -> CGFloat? {
        _ = scanCharacters(from: CharacterSet(charactersIn: ", "))
        var value: Double = 0
        if scanDouble(&value) {
            _ = scanCharacters(from: CharacterSet(charactersIn: ", "))
            return CGFloat(value)
        }
        return nil
    }
}

func notchPixelIcon(for sourceKind: ImportSourceKind) -> NotchPixelIcon {
    switch sourceKind {
    case .image:
        return .image
    case .pdf:
        return .pdf
    case .text:
        return .text
    case .audio:
        return .audio
    case .binary:
        return .file
    }
}

func notchPixelTone(for sourceKind: ImportSourceKind) -> NotchPixelTone {
    switch sourceKind {
    case .image:
        return .accent
    case .pdf:
        return .danger
    case .text:
        return .success
    case .audio:
        return .warning
    case .binary:
        return .neutral
    }
}

func notchPixelIcon(for parseStatus: RecordParseStatus) -> NotchPixelIcon {
    switch parseStatus {
    case .pending:
        return .hourglass
    case .ready:
        return .check
    case .partial:
        return .warning
    case .failed:
        return .cross
    }
}

func notchPixelTone(for parseStatus: RecordParseStatus) -> NotchPixelTone {
    switch parseStatus {
    case .pending:
        return .info
    case .ready:
        return .success
    case .partial:
        return .warning
    case .failed:
        return .danger
    }
}

func notchPixelIcon(for status: NotchIngestTaskStatus) -> NotchPixelIcon {
    switch status {
    case .queued, .preparing, .recognizing, .storing:
        return .hourglass
    case .needsInput:
        return .question
    case .succeeded:
        return .check
    case .failed:
        return .cross
    }
}

func notchPixelTone(for status: NotchIngestTaskStatus) -> NotchPixelTone {
    switch status {
    case .queued, .preparing:
        return .neutral
    case .recognizing:
        return .info
    case .storing:
        return .success
    case .needsInput:
        return .warning
    case .succeeded:
        return .success
    case .failed:
        return .danger
    }
}

func notchLibraryInfoTone(for sourceKind: ImportSourceKind) -> LibraryInfoPillTone {
    switch sourceKind {
    case .image:
        return .accent
    case .pdf:
        return .danger
    case .text:
        return .success
    case .audio:
        return .warning
    case .binary:
        return .neutral
    }
}

func notchLibraryInfoTone(for parseStatus: RecordParseStatus) -> LibraryInfoPillTone {
    switch parseStatus {
    case .pending:
        return .info
    case .ready:
        return .success
    case .partial:
        return .warning
    case .failed:
        return .danger
    }
}
