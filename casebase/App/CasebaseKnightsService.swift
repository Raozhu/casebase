import AppKit
import Darwin
import Foundation

enum KnightsStatus: Equatable {
    case idle
    case starting
    case running
    case portConflict
    case nodeMissing
    case failed(String)
}

/// Hosts the 12 Knights group-chat server (`node server.js`) as a child process of casebase.
@MainActor
final class CasebaseKnightsService: ObservableObject {
    static let shared = CasebaseKnightsService()

    @Published private(set) var status: KnightsStatus = .idle {
        didSet {
            guard status != oldValue else { return }
            log("status \(oldValue) -> \(status)")
            NotificationCenter.default.post(name: .casebaseKnightsStatusChanged, object: self)
        }
    }

    let port: Int
    let logURL: URL
    let autostartEnabled: Bool
    private let knightsHome: URL
    private let explicitNodePath: String?
    private let logWriter: KnightsLogWriter

    private var process: Process?
    private var owned = false
    private var isStopping = false
    private var startTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var restartTimestamps: [Date] = []

    private static let readyTimeout: TimeInterval = 20
    private static let restartWindow: TimeInterval = 300
    private static let maxRestartsInWindow = 5

    var rootURL: URL { URL(string: "http://127.0.0.1:\(port)")! }
    private var healthURL: URL { rootURL.appendingPathComponent("api/health") }

    private init(environment: [String: String] = CasebaseEnvironment.resolved()) {
        knightsHome = URL(
            fileURLWithPath: Self.nonEmpty(environment["KNIGHTS_HOME"]) ?? "/Users/rao/data/ai-group-chat",
            isDirectory: true
        )
        port = Int(Self.nonEmpty(environment["KNIGHTS_PORT"]) ?? "") ?? 3721
        explicitNodePath = Self.nonEmpty(environment["KNIGHTS_NODE"])
        autostartEnabled = Self.nonEmpty(environment["KNIGHTS_AUTOSTART"]) != "0"
        logURL = StorageConfiguration.load(environment: environment).rootDirectory
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("12knights.log", isDirectory: false)
        logWriter = KnightsLogWriter(url: logURL)
    }

    // MARK: - Lifecycle

    func startIfEnabled() {
        guard autostartEnabled else {
            log("autostart disabled by KNIGHTS_AUTOSTART=0")
            return
        }
        start()
    }

    func start() {
        guard startTask == nil, process?.isRunning != true else { return }
        isStopping = false
        status = .starting
        startTask = Task { [weak self] in
            await self?.performStart()
            self?.startTask = nil
        }
    }

    /// Called from `applicationWillTerminate`; blocks for at most ~5 seconds.
    func stop() {
        isStopping = true
        startTask?.cancel()
        restartTask?.cancel()
        guard owned, let process, process.isRunning else { return }

        let pid = process.processIdentifier
        log("stopping pid=\(pid) with SIGTERM")
        process.terminate()
        let deadline = Date().addingTimeInterval(5)
        while process.isRunning, Date() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            log("pid=\(pid) still running after 5s, sending SIGKILL")
            kill(pid, SIGKILL)
        }
    }

    private func performStart() async {
        switch await KnightsProcessSupport.probeHealth(url: healthURL) {
        case .knights:
            owned = false
            log("found an existing 12 Knights on port \(port), reusing it")
            status = .running
            return
        case .otherService:
            log("port \(port) is used by another service")
            status = .portConflict
            return
        case .unreachable:
            break
        }

        let serverScript = knightsHome.appendingPathComponent("server.js", isDirectory: false)
        guard FileManager.default.fileExists(atPath: serverScript.path) else {
            status = .failed("找不到 \(serverScript.path)，请检查 KNIGHTS_HOME")
            return
        }

        guard let nodeURL = await KnightsProcessSupport.locateNode(explicitPath: explicitNodePath) else {
            status = .nodeMissing
            return
        }
        let path = await KnightsProcessSupport.loginShellPATH()
            ?? KnightsProcessSupport.fallbackPATH(nodeURL: nodeURL)
        guard !Task.isCancelled, !isStopping else { return }

        let launched: Process
        do {
            launched = try launch(nodeURL: nodeURL, path: path)
        } catch {
            status = .failed("启动失败：\(error.localizedDescription)")
            return
        }

        let deadline = Date().addingTimeInterval(Self.readyTimeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 500_000_000)
            // The process exited while starting: the termination handler decides what happens next.
            guard !Task.isCancelled, !isStopping, launched === process, launched.isRunning else { return }
            if await KnightsProcessSupport.probeHealth(url: healthURL) == .knights {
                status = .running
                return
            }
        }

        log("not ready after \(Int(Self.readyTimeout))s, terminating pid=\(launched.processIdentifier)")
        launched.terminate()
        status = .failed("启动超时，看日志")
    }

    private func launch(nodeURL: URL, path: String) throws -> Process {
        let process = Process()
        process.executableURL = nodeURL
        process.arguments = ["server.js"]
        process.currentDirectoryURL = knightsHome

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = path
        environment["PORT"] = String(port)
        environment["KNIGHTS_PARENT_PID"] = String(getpid())
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        let logWriter = logWriter
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                logWriter.append(data)
            }
        }
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor [weak self] in
                self?.handleTermination(of: finished)
            }
        }

        log("launching \(nodeURL.path) server.js in \(knightsHome.path) PORT=\(port)")
        try process.run()
        self.process = process
        owned = true
        log("launched pid=\(process.processIdentifier)")
        return process
    }

    private func handleTermination(of finished: Process) {
        log("pid=\(finished.processIdentifier) exited status=\(finished.terminationStatus)")
        guard finished === process else { return }
        process = nil

        if isStopping {
            status = .idle
            return
        }
        // Startup timed out and we killed it on purpose.
        if case .failed = status {
            return
        }

        let now = Date()
        restartTimestamps = restartTimestamps.filter { now.timeIntervalSince($0) < Self.restartWindow }
        guard restartTimestamps.count < Self.maxRestartsInWindow else {
            status = .failed("5 分钟内连续退出 \(Self.maxRestartsInWindow) 次，已停止自动重启")
            return
        }
        restartTimestamps.append(now)
        let attempt = restartTimestamps.count
        status = .starting
        log("unexpected exit, restarting in \(2 * attempt)s (attempt \(attempt))")
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(2 * attempt) * 1_000_000_000)
            guard !Task.isCancelled, let self, !self.isStopping else { return }
            self.start()
        }
    }

    // MARK: - Round-table entry

    /// Shows (or tucks away) the round-table window; starts the server first if it isn't running yet.
    func openRoundTable() {
        if status == .idle {
            start()
        }
        RoundTablePanelController.shared.toggle()
    }

    /// Manual retry after a failure; resets the auto-restart budget.
    func retry() {
        guard status != .running, status != .starting else { return }
        restartTimestamps.removeAll()
        start()
    }

    func openLog() {
        NSWorkspace.shared.open(logURL)
    }

    var failureDescription: String? {
        switch status {
        case .portConflict:
            return "端口 \(port) 被其他程序占用"
        case .nodeMissing:
            return "没找到 node，可在 .env 里设置 KNIGHTS_NODE"
        case let .failed(reason):
            return reason
        case .idle, .starting, .running:
            return nil
        }
    }

    // MARK: - Helpers

    private func log(_ message: String) {
        CasebaseDebugLogger.log("knights \(message)")
        logWriter.appendLine("[casebase] \(message)")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

// MARK: - Process support

private enum KnightsHealth {
    case knights
    case otherService
    case unreachable
}

private enum KnightsProcessSupport {
    private static let healthSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 1
        return URLSession(configuration: configuration)
    }()

    static func probeHealth(url: URL) async -> KnightsHealth {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1)
        do {
            let (data, response) = try await healthSession.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               payload["app"] as? String == "12 Knights"
            {
                return .knights
            }
            return .otherService
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return .unreachable
            default:
                return .otherService
            }
        } catch {
            return .unreachable
        }
    }

    static func locateNode(explicitPath: String?) async -> URL? {
        let fileManager = FileManager.default
        if let explicitPath, fileManager.isExecutableFile(atPath: explicitPath) {
            return URL(fileURLWithPath: explicitPath)
        }

        // Apps launched from Finder don't inherit the terminal PATH (nvm etc.), so ask a login shell.
        if let output = await runLoginShell("command -v node"),
           let path = output.split(whereSeparator: \.isNewline)
               .map({ $0.trimmingCharacters(in: .whitespaces) })
               .last(where: { $0.hasPrefix("/") }),
           fileManager.isExecutableFile(atPath: path)
        {
            return URL(fileURLWithPath: path)
        }

        for candidate in ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
            where fileManager.isExecutableFile(atPath: candidate)
        {
            return URL(fileURLWithPath: candidate)
        }

        let nvmVersions = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".nvm/versions/node", isDirectory: true)
        let versions = (try? fileManager.contentsOfDirectory(atPath: nvmVersions.path)) ?? []
        let newest = versions
            .compactMap { name -> (version: [Int], node: String)? in
                let node = nvmVersions.appendingPathComponent("\(name)/bin/node").path
                guard fileManager.isExecutableFile(atPath: node) else { return nil }
                let numbers = name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                    .split(separator: ".")
                    .map { Int($0) ?? 0 }
                return (numbers, node)
            }
            .max { $0.version.lexicographicallyPrecedes($1.version) }
        return newest.map { URL(fileURLWithPath: $0.node) }
    }

    static func loginShellPATH() async -> String? {
        guard let output = await runLoginShell("printf %s \"$PATH\""),
              let line = output.split(whereSeparator: \.isNewline)
                  .last(where: { $0.hasPrefix("/") })
        else {
            return nil
        }
        return String(line)
    }

    static func fallbackPATH(nodeURL: URL) -> String {
        [nodeURL.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            .joined(separator: ":")
    }

    /// Runs `/bin/zsh -ilc <script>` off the main thread and returns stdout, or nil on failure/timeout.
    private static func runLoginShell(_ script: String, timeout: TimeInterval = 5) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runLoginShellSync(script, timeout: timeout))
            }
        }
    }

    private static func runLoginShellSync(_ script: String, timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", script]
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe

        let buffer = KnightsOutputBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                buffer.append(data)
            }
        }
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }
        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            pipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
        // Give the reader a moment to drain what the shell wrote right before exiting.
        usleep(50_000)
        pipe.fileHandleForReading.readabilityHandler = nil
        buffer.append(pipe.fileHandleForReading.availableDataIfAny())
        guard process.terminationStatus == 0 else { return nil }
        return String(data: buffer.data, encoding: .utf8)
    }
}

private final class KnightsOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private extension FileHandle {
    func availableDataIfAny() -> Data {
        var flags = fcntl(fileDescriptor, F_GETFL)
        guard flags >= 0 else { return Data() }
        flags |= O_NONBLOCK
        _ = fcntl(fileDescriptor, F_SETFL, flags)
        var result = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fileDescriptor, &chunk, chunk.count)
            guard count > 0 else { break }
            result.append(chunk, count: count)
        }
        return result
    }
}

// MARK: - Log file

/// Appends child-process output to `CB_ROOT/logs/12knights.log`, rotating to `.1` past 5MB.
private final class KnightsLogWriter: @unchecked Sendable {
    private static let maxBytes: UInt64 = 5 * 1024 * 1024
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let url: URL
    private let queue = DispatchQueue(label: "ai.casebase.knights-log")
    private var handle: FileHandle?
    private var size: UInt64 = 0

    init(url: URL) {
        self.url = url
    }

    func append(_ data: Data) {
        queue.async { [self] in
            write(data)
        }
    }

    func appendLine(_ line: String) {
        append(Data("\(Self.timestampFormatter.string(from: Date())) \(line)\n".utf8))
    }

    private func write(_ data: Data) {
        if handle == nil {
            openHandle()
        }
        if size + UInt64(data.count) > Self.maxBytes {
            rotate()
        }
        guard let handle else { return }
        do {
            try handle.write(contentsOf: data)
            size += UInt64(data.count)
        } catch {
            try? handle.close()
            self.handle = nil
        }
    }

    private func openHandle() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        size = (try? handle?.seekToEnd()) ?? 0
    }

    private func rotate() {
        try? handle?.close()
        handle = nil
        let rotatedURL = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: rotatedURL)
        try? FileManager.default.moveItem(at: url, to: rotatedURL)
        openHandle()
    }
}
