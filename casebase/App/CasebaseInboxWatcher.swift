import Foundation

/// Watches `CB_ROOT/inbox/12knights/` and silently imports team-memory markdown files written by 12 Knights.
@MainActor
final class CasebaseInboxWatcher {
    let inboxURL: URL
    private let importedURL: URL
    private let failedURL: URL
    private let importCoordinator: ImportCoordinator

    private var directorySource: DispatchSourceFileSystemObject?
    private var rescanTimer: Timer?
    private var isScanning = false
    private var rescanRequested = false
    private var isStopped = false

    /// Shared across watcher instances so a runtime reload never imports the same file twice at once.
    private static var inFlightPaths = Set<String>()

    init(storage: StorageConfiguration, importCoordinator: ImportCoordinator) {
        inboxURL = Self.inboxDirectory(for: storage)
        importedURL = inboxURL.appendingPathComponent("imported", isDirectory: true)
        failedURL = inboxURL.appendingPathComponent("failed", isDirectory: true)
        self.importCoordinator = importCoordinator
    }

    static func inboxDirectory(for storage: StorageConfiguration) -> URL {
        storage.rootDirectory
            .appendingPathComponent("inbox", isDirectory: true)
            .appendingPathComponent("12knights", isDirectory: true)
    }

    /// 12 Knights only delivers memories here when this directory exists, so create it on every launch.
    static func ensureDirectories(for storage: StorageConfiguration) {
        let inbox = inboxDirectory(for: storage)
        for directory in [inbox, inbox.appendingPathComponent("imported"), inbox.appendingPathComponent("failed")] {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                CasebaseDebugLogger.log("inbox create directory failed path=\(directory.path) error=\(error)")
            }
        }
    }

    func start() {
        installDirectorySource()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
        scan()
    }

    func stop() {
        isStopped = true
        directorySource?.cancel()
        directorySource = nil
        rescanTimer?.invalidate()
        rescanTimer = nil
    }

    private func installDirectorySource() {
        let descriptor = open(inboxURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            CasebaseDebugLogger.log("inbox watch open failed path=\(inboxURL.path) errno=\(errno)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        directorySource = source
    }

    private func scan() {
        guard !isStopped else { return }
        guard !isScanning else {
            rescanRequested = true
            return
        }
        isScanning = true
        Task { @MainActor [weak self] in
            await self?.drainInbox()
        }
    }

    private func drainInbox() async {
        repeat {
            rescanRequested = false
            for fileURL in pendingFiles() {
                guard !isStopped else { break }
                await importFile(fileURL)
            }
        } while rescanRequested && !isStopped
        isScanning = false
    }

    private func pendingFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { url in
                !url.lastPathComponent.hasPrefix(".")
                    && url.pathExtension.lowercased() == "md"
                    && (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                    && !Self.inFlightPaths.contains(url.path)
            }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate == rhsDate ? lhs.lastPathComponent < rhs.lastPathComponent : lhsDate < rhsDate
            }
    }

    private func importFile(_ fileURL: URL) async {
        Self.inFlightPaths.insert(fileURL.path)
        defer { Self.inFlightPaths.remove(fileURL.path) }

        let metadata = Self.frontMatterMetadata(of: fileURL)
        CasebaseDebugLogger.log("inbox import started file=\(fileURL.lastPathComponent)")
        do {
            let record = try await importCoordinator.importPayload(
                .file(FileImportPayload(
                    fileURL: fileURL,
                    suggestedFileName: fileURL.lastPathComponent,
                    mimeType: "text/markdown",
                    contextMetadata: metadata
                )),
                progress: nil
            )
            move(fileURL, into: importedURL)
            CasebaseDebugLogger.log(
                "inbox import completed file=\(fileURL.lastPathComponent) recordID=\(record.id.uuidString)"
            )
            NotificationCenter.default.post(name: .casebaseRecordsChanged, object: nil)
        } catch {
            move(fileURL, into: failedURL)
            CasebaseDebugLogger.log(
                "inbox import failed file=\(fileURL.lastPathComponent) error=\(String(describing: error))"
            )
        }
    }

    private func move(_ fileURL: URL, into directory: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var destination = directory.appendingPathComponent(fileURL.lastPathComponent)
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            let baseName = fileURL.deletingPathExtension().lastPathComponent
            destination = directory.appendingPathComponent("\(baseName)-\(suffix).\(fileURL.pathExtension)")
            suffix += 1
        }
        do {
            try fileManager.moveItem(at: fileURL, to: destination)
        } catch {
            CasebaseDebugLogger.log("inbox move failed file=\(fileURL.lastPathComponent) error=\(error)")
        }
    }

    /// Parses the leading `---` block into `key: value` pairs; `tags: [a, b]` becomes `a,b`.
    static func frontMatterMetadata(of fileURL: URL) -> [String: String] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [:] }
        var lines = text.components(separatedBy: .newlines)[...]
        guard lines.first?.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{FEFF}"))) == "---" else {
            return [:]
        }
        lines = lines.dropFirst()

        var metadata: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            var value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            if key == "tags" {
                value = value
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"'"))) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ",")
            }
            metadata[key] = value
        }
        return metadata
    }
}
