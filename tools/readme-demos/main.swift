import AppKit
import SwiftUI

// Renders README demo clips from the app's real notch UI, driven by a script.
// Usage: DemoRenderer <scene> <output-dir>   (scene: drop | capture | ask | meeting | probe)
// Language comes from the app's own setting: -casebase.language en | zh-Hans

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: DemoRenderer <scene> <output-dir>")
    exit(2)
}
let sceneName = arguments[1]
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)

Task { @MainActor in
    do {
        let services = try DemoServices(storageRoot: outputDirectory.appendingPathComponent("storage"))
        let stage = Stage(services: services)
        await pause(0.8)
        try await Scenes(stage: stage, services: services, output: outputDirectory).run(sceneName)
        exit(0)
    } catch {
        print("failed: \(error)")
        exit(1)
    }
}

app.run()

@MainActor
struct Scenes {
    let stage: Stage
    let services: DemoServices
    let output: URL

    private var props: StageProps { stage.props }
    private var viewModel: NotchViewModel { stage.viewModel }
    /// The part of the fake screen that ends up in the clip.
    static let region = CGRect(x: Stage.size.width / 2 - 420, y: 0, width: 840, height: 620)

    func run(_ name: String) async throws {
        switch name {
        case "drop": try await drop()
        case "capture": try await capture()
        case "ask": try await ask()
        case "meeting": try await meeting()
        case "probe": await probe()
        case "seed": try await seed()
        default: print("unknown scene \(name)")
        }
    }

    private func record() {
        stage.startRecording(region: Scenes.region, to: output.appendingPathComponent("frames"))
    }

    // MARK: Helpers

    private func center(of label: String, occurrence: Int = 0, fallback: CGPoint) -> CGPoint {
        guard let frame = stage.elementFrame(label, occurrence: occurrence) else {
            print("element not found: \(label), using fallback")
            return fallback
        }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func hoverNotch() async {
        await props.moveCursor(to: CGPoint(x: Stage.size.width / 2 + 30, y: 18), duration: 0.8)
        viewModel.debugShowHoverActions()
        await pause(0.7)
    }

    private func clickHoverAction(_ label: String, fallback: CGPoint, then action: () -> Void) async {
        await props.moveCursor(to: center(of: label, fallback: fallback), duration: 0.55)
        await props.click()
        action()
    }

    private func waitForImportToFinish(timeout: TimeInterval = 15) async {
        let deadline = Date().addingTimeInterval(timeout)
        await pause(0.5)
        while Date() < deadline, viewModel.ingestTasks.contains(where: { !$0.status.isTerminal }) {
            await pause(0.1)
        }
    }

    private func openSavedResult() async {
        await props.moveCursor(to: CGPoint(x: Stage.size.width / 2, y: 52), duration: 0.7)
        await props.click()
        viewModel.handleTaskRailTap()
    }

    // MARK: Scenes

    private func drop() async throws {
        let reportURL = output.appendingPathComponent(DemoContent.reportFileName)
        try DemoContent.makeReport(at: reportURL)
        let icon = NSWorkspace.shared.icon(forFile: reportURL.path)
        props.desktopFile = .init(icon: icon, name: DemoContent.reportFileName, position: CGPoint(x: 470, y: 400))
        props.cursorPosition = CGPoint(x: 980, y: 470)

        record()
        await pause(0.6)
        props.caption = L("Drag any file onto the notch", "把文件拖到刘海上")
        await props.moveCursor(to: CGPoint(x: 476, y: 392), duration: 0.9)
        props.cursorPressed = true
        await pause(0.15)
        props.draggedIcon = icon
        await props.moveCursor(to: CGPoint(x: 690, y: 230), duration: 0.8)
        viewModel.updateDropTargeted(true)
        await props.moveCursor(to: CGPoint(x: 752, y: 96), duration: 0.6)
        await pause(0.7)

        props.cursorPressed = false
        props.draggedIcon = nil
        props.desktopFile = nil
        _ = viewModel.handleDrop(providers: [NSItemProvider(object: reportURL as NSURL)])
        viewModel.updateDropTargeted(false)
        props.caption = L("casebase reads the file and files it", "casebase 读取内容并归类")
        await props.moveCursor(to: CGPoint(x: 1000, y: 430), duration: 0.9)
        await waitForImportToFinish()
        await pause(0.6)

        props.caption = L("Open it to see the summary and tags", "点开查看摘要和标签")
        await openSavedResult()
        await props.moveCursor(to: CGPoint(x: 1080, y: 470), duration: 0.8)
        await pause(3.2)
        await stage.stopRecording()
    }

    private func capture() async throws {
        let browser = DemoContent.browser
        props.browser = browser
        props.cursorPosition = CGPoint(x: 1010, y: 540)

        record()
        await pause(0.6)
        props.caption = L("Press ⌘F2 and select an area", "按 ⌘F2 框选一块区域")
        await pause(0.4)
        props.keys = ["⌘", "F2"]
        await pause(0.8)
        props.keys = []
        stage.screenshotOverlay.isHidden = false
        stage.screenshotOverlay.needsDisplay = true

        let start = CGPoint(x: browser.frame.minX + 14, y: browser.frame.minY + 56)
        let end = CGPoint(x: browser.frame.maxX - 14, y: browser.frame.maxY - 12)
        await props.moveCursor(to: start, duration: 0.6)
        props.cursorPressed = true
        let steps = 42
        for step in 1...steps {
            let t = easeInOut(Double(step) / Double(steps))
            let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
            props.cursorPosition = point
            let rect = CGRect(x: start.x, y: start.y, width: point.x - start.x, height: point.y - start.y)
            stage.screenshotOverlay.selectionRect = CGRect(x: rect.minX, y: Stage.size.height - rect.maxY, width: rect.width, height: rect.height)
            stage.screenshotOverlay.needsDisplay = true
            await pause(1.0 / 40)
        }
        props.cursorPressed = false
        await pause(0.35)

        let selection = CGRect(x: start.x, y: start.y, width: end.x - start.x, height: end.y - start.y)
        stage.screenshotOverlay.isHidden = true
        stage.screenshotOverlay.selectionRect = nil
        props.cursorVisible = false
        let shotURL = output.appendingPathComponent(DemoContent.screenshotFileName)
        stage.snapshot(selection, to: shotURL)
        props.cursorVisible = true

        let context = GlobalScreenshotCaptureContext(
            fileURL: shotURL,
            sourceAppName: "Safari",
            windowTitle: browser.title,
            capturedAt: Date(),
            sourceRect: Stage.screenRect(selection)
        )
        if let image = NSImage(contentsOf: shotURL) {
            stage.flightModel.play(
                image: image,
                sourceRect: context.sourceRect,
                from: context.sourcePoint,
                to: Stage.screenPoint(stage.notchCenter)
            )
        }
        viewModel.ingestCapturedScreenshot(context)
        props.caption = L("The capture is saved and analyzed", "截图已保存，正在分析")
        await props.moveCursor(to: CGPoint(x: 1090, y: 520), duration: 0.9)
        await waitForImportToFinish()
        await pause(0.6)

        props.caption = L("Title, summary and tags are filled in", "已生成标题、摘要和标签")
        await openSavedResult()
        await props.moveCursor(to: CGPoint(x: 1090, y: 500), duration: 0.8)
        await pause(3.2)
        await stage.stopRecording()
    }

    private func ask() async throws {
        props.cursorPosition = CGPoint(x: 1000, y: 460)
        record()
        await pause(0.5)
        props.caption = L("Ask a question across your saved items", "对存过的资料提问")
        await hoverNotch()
        await clickHoverAction(L("Explore", "探索"), fallback: CGPoint(x: 624, y: 125)) {
            viewModel.openSearch()
        }
        await pause(0.6)
        await props.moveCursor(to: CGPoint(x: 1080, y: 470), duration: 0.6)

        for character in DemoContent.question {
            viewModel.draftQuestion.append(character)
            await pause(CasebasePromptCatalog.language == .simplifiedChinese ? 0.11 : 0.055)
        }
        await pause(0.4)
        props.keys = ["↩"]
        await pause(0.35)
        props.keys = []
        viewModel.submitQuestion()
        props.caption = L("The answer lists the meeting and notes it used", "回答会列出用到的会议和笔记")

        let deadline = Date().addingTimeInterval(20)
        await pause(1)
        while Date() < deadline, viewModel.latestAnswer == nil {
            await pause(0.1)
        }
        await pause(3.5)
        await stage.stopRecording()
    }

    private func meeting() async throws {
        guard let meeting = services.library.records.first(where: { MeetingRecordMetadata.isMeetingRecord($0) }) else { return }
        props.cursorPosition = CGPoint(x: 1000, y: 460)
        record()
        await pause(0.5)
        props.caption = L("Open a recorded meeting", "打开一场录过的会议")
        await hoverNotch()
        await clickHoverAction(L("View data", "查看数据"), fallback: CGPoint(x: 712, y: 125)) {
            viewModel.openLibrary()
        }
        await pause(1.0)

        await props.moveCursor(to: center(of: meeting.title, fallback: CGPoint(x: 756, y: 160)), duration: 0.7)
        await props.click()
        viewModel.openLibraryRecord(meeting.id)
        await pause(1.0)
        await props.moveCursor(to: CGPoint(x: 900, y: 330), duration: 0.5)
        await stage.scrollNotchToBottom(duration: 1.2)
        await pause(0.6)

        props.caption = L("Add the action items that are yours", "把属于你的行动项加入待办")
        let addLabel = L("Add to-do", "加入待办")
        for _ in 0..<2 {
            let pending = viewModel.pendingMeetingActionItems(for: viewModel.selectedLibraryRecord ?? meeting)
            guard let item = pending.first else { break }
            await props.moveCursor(to: center(of: addLabel, fallback: CGPoint(x: 1040, y: 400)), duration: 0.6)
            await props.click()
            viewModel.acceptMeetingActionItem(recordID: meeting.id, candidateID: item.id)
            await pause(1.1)
        }

        props.caption = L("Accepted items appear in To-do", "确认的事项出现在待办里")
        viewModel.collapse()
        await props.moveCursor(to: CGPoint(x: 1000, y: 420), duration: 0.5)
        await pause(0.4)
        await hoverNotch()
        await clickHoverAction(L("To-do", "待办"), fallback: CGPoint(x: 800, y: 125)) {
            viewModel.openTodos()
        }
        await props.moveCursor(to: CGPoint(x: 1090, y: 470), duration: 0.8)
        await pause(3.0)
        await stage.stopRecording()
    }

    /// Writes the demo library into a real casebase.sqlite, for the round table and MCP demos.
    private func seed() async throws {
        let root = services.storageRoot
        let configuration = StorageConfiguration(
            rootDirectory: root,
            assetsDirectory: root.appendingPathComponent("assets", isDirectory: true),
            visibleShortcutDirectory: root.appendingPathComponent("shortcuts", isDirectory: true),
            databaseURL: root.appendingPathComponent("casebase.sqlite")
        )
        let store = try LocalKnowledgeStore(configuration: configuration)
        for record in services.library.records {
            try await store.save(record)
        }
        print("seeded \(services.library.records.count) records into \(configuration.databaseURL.path)")
    }

    private func probe() async {
        let shots = output.appendingPathComponent("probe")
        try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
        func shoot(_ name: String) {
            print("=== \(name)")
            stage.dumpAccessibility()
            stage.snapshot(Scenes.region, to: shots.appendingPathComponent("\(name).png"))
        }
        viewModel.debugShowHoverActions()
        await pause(1)
        shoot("hover")
        viewModel.openLibrary()
        await pause(1.2)
        shoot("library")
        if let meeting = services.library.records.first(where: { MeetingRecordMetadata.isMeetingRecord($0) }) {
            viewModel.openLibraryRecord(meeting.id)
            await pause(1.2)
            shoot("detail")
            await stage.scrollNotchToBottom(duration: 0.5)
            await pause(0.5)
            shoot("detail-scrolled")
            if let item = viewModel.pendingMeetingActionItems(for: meeting).first {
                viewModel.acceptMeetingActionItem(recordID: meeting.id, candidateID: item.id)
                await pause(1.2)
                shoot("detail-accepted")
            }
        }
        viewModel.collapse()
        await pause(0.6)
        viewModel.debugShowHoverActions()
        await pause(0.8)
        viewModel.openSearch()
        await pause(1)
        shoot("search")
        viewModel.closeSearch()
        viewModel.collapse()
        await pause(0.6)
        viewModel.openTodos()
        await pause(1)
        shoot("todos")
    }
}

private extension NotchIngestTaskStatus {
    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .needsInput: return true
        default: return false
        }
    }
}
