import Combine
import Foundation

/// Follows the 12 Knights event stream while the round-table window is tucked away, so the notch can
/// surface new replies, plus a count of team memories that were imported silently.
@MainActor
final class KnightsActivityCenter: ObservableObject {
    static let shared = KnightsActivityCenter()

    struct Notice: Equatable {
        let id = UUID()
        let text: String
        let conversationID: String?
        let needsAttention: Bool
    }

    @Published private(set) var notice: Notice?
    @Published private(set) var unreadCount = 0
    @Published private(set) var unseenTeamMemoryCount = 0

    private let knights = CasebaseKnightsService.shared
    private var statusObserver: AnyCancellable?
    private var streamTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var userName = "我"
    private var conversationNames: [String: String] = [:]
    private var recentSenders: [String] = []

    private static let noticeDuration: UInt64 = 6_000_000_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 7 * 24 * 3600
        return URLSession(configuration: configuration)
    }()

    private init() {}

    func start() {
        guard statusObserver == nil else { return }
        statusObserver = knights.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .running {
                    self?.connect()
                } else {
                    self?.disconnect()
                }
            }
    }

    // MARK: - Read state

    func markRoundTableSeen() {
        unreadCount = 0
        recentSenders.removeAll()
        clearNotice()
    }

    func noteTeamMemoryImported() {
        unseenTeamMemoryCount += 1
    }

    func markTeamMemoriesSeen() {
        unseenTeamMemoryCount = 0
    }

    func clearNotice() {
        noticeTask?.cancel()
        notice = nil
    }

    /// Shows a one-off line in the notch rail (used for round-table errors raised by casebase itself).
    func post(_ text: String, conversationID: String? = nil, needsAttention: Bool = true) {
        show(Notice(text: text, conversationID: conversationID, needsAttention: needsAttention))
    }

    // MARK: - Event stream

    private func connect() {
        guard streamTask == nil else { return }
        streamTask = Task { [weak self] in
            await self?.runStream()
        }
    }

    private func disconnect() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func runStream() async {
        while !Task.isCancelled, knights.status == .running {
            await refreshState()
            do {
                let url = knights.rootURL.appendingPathComponent("events")
                let (bytes, _) = try await Self.session.bytes(from: url)
                var event = "message"
                // Every event carries a single-line JSON `data:` field, so dispatch on it directly.
                for try await line in bytes.lines {
                    if line.hasPrefix("event:") {
                        event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        handle(event: event, data: Data(line.dropFirst(5).utf8))
                        event = "message"
                    }
                }
            } catch {
                if Task.isCancelled { break }
                CasebaseDebugLogger.log("knights activity stream ended error=\(error.localizedDescription)")
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
        streamTask = nil
    }

    private func refreshState() async {
        let url = knights.rootURL.appendingPathComponent("api/state")
        guard let (data, _) = try? await Self.session.data(from: url),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if let user = state["user"] as? String, !user.isEmpty {
            userName = user
        }
        if let convs = state["convs"] as? [[String: Any]] {
            updateConversationNames(convs)
        }
    }

    private func handle(event: String, data: Data) {
        guard let payload = try? JSONSerialization.jsonObject(with: data) else { return }
        switch event {
        case "convs":
            if let convs = payload as? [[String: Any]] {
                updateConversationNames(convs)
            }
        case "message":
            guard let body = payload as? [String: Any],
                  let message = body["msg"] as? [String: Any]
            else { return }
            handleMessage(message, conversationID: body["conv"] as? String)
        default:
            break
        }
    }

    private func handleMessage(_ message: [String: Any], conversationID: String?) {
        // The user is looking at the round table already.
        guard !RoundTablePanelController.shared.isFrontmost else { return }

        let from = message["from"] as? String ?? ""
        let kind = message["kind"] as? String ?? ""
        let text = message["text"] as? String ?? ""
        let place = conversationID.flatMap { conversationNames[$0] }.map { "「\(Self.clip($0, 10))」" } ?? ""

        if kind == "chat", from != userName, !from.isEmpty {
            unreadCount += 1
            recentSenders.removeAll { $0 == from }
            recentSenders.append(from)
            let line: String
            if recentSenders.count > 1, notice != nil {
                line = "\(recentSenders.suffix(3).joined(separator: "、")) 有新回复\(place.isEmpty ? "" : " · \(place)")"
            } else {
                line = "\(from)：\(Self.clip(Self.firstLine(of: text), 22))"
            }
            show(Notice(text: line, conversationID: conversationID, needsAttention: false))
        } else if kind == "system", message["retry"] != nil {
            unreadCount += 1
            show(Notice(text: Self.clip(Self.firstLine(of: text), 28), conversationID: conversationID, needsAttention: true))
        } else if kind == "system", message["kb"] != nil || message["suggest"] != nil {
            unreadCount += 1
            show(Notice(text: "Jev 有推荐等你确认\(place.isEmpty ? "" : " · \(place)")", conversationID: conversationID, needsAttention: true))
        }
    }

    private func show(_ notice: Notice) {
        CasebaseDebugLogger.log("knights activity notice unread=\(unreadCount) text=\(notice.text)")
        self.notice = notice
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.noticeDuration)
            guard !Task.isCancelled, let self else { return }
            self.notice = nil
            self.recentSenders.removeAll()
        }
    }

    private func updateConversationNames(_ convs: [[String: Any]]) {
        for conv in convs {
            if let id = conv["id"] as? String, let name = conv["name"] as? String {
                conversationNames[id] = name
            }
        }
    }

    private static func firstLine(of text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "#", with: "")
        return cleaned.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
