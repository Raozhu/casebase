#if DEBUG
import AppKit

/// Debug-only remote control for visual checks without screen-recording access:
/// `casebase.debug` distributed notifications carry commands such as `expand`, `state:library`,
/// `roundtable` and `snap:/path/prefix` (renders every visible casebase window to PNG).
@MainActor
enum CasebaseDebugProbe {
    private static var observer: NSObjectProtocol?

    static func install() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("casebase.debug"),
            object: nil,
            queue: .main
        ) { note in
            let command = note.object as? String ?? ""
            Task { @MainActor in run(command) }
        }
    }

    private static var viewModels: [NotchViewModel] {
        NSApp.windows.compactMap { ($0.windowController as? NotchWindowController)?.viewModel }
    }

    private static func run(_ command: String) {
        CasebaseDebugLogger.log("debug probe command=\(command)")
        let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
        let argument = parts.count > 1 ? parts[1] : ""
        switch parts.first ?? "" {
        case "expand":
            viewModels.forEach { $0.debugShowHoverActions() }
        case "collapse":
            viewModels.forEach { $0.collapse() }
        case "state":
            guard let state = CasebaseSurfaceState(rawValue: argument) else { return }
            for viewModel in viewModels {
                switch state {
                case .library: viewModel.openLibrary()
                case .todos: viewModel.openTodos()
                case .search: viewModel.openSearch()
                case .meeting: viewModel.openMeeting()
                case .settings: viewModel.openSettings()
                default: break
                }
            }
        case "record":
            if let id = UUID(uuidString: argument) {
                viewModels.forEach { $0.openLibraryRecord(id) }
            }
        case "roundtable":
            CasebaseKnightsService.shared.openRoundTable()
        case "snap":
            snapshot(prefix: argument)
        default:
            break
        }
    }

    private static func snapshot(prefix: String) {
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView, view.bounds.width > 0 else { continue }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let name = String(describing: type(of: window))
            try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(index)-\(name).png"))
        }
    }
}
#endif
