import Foundation

final class DeepSeekTaskIntelligenceService: MeetingActionItemExtracting, TodoBreakdownProviding {
    private let executor: DeepSeekRequestExecutor
    private let model: String

    init(configuration: CasebaseConfiguration, session: URLSession? = nil) {
        executor = DeepSeekRequestExecutor(
            baseURL: configuration.ai.baseURL,
            apiKey: configuration.ai.apiKey,
            requestTimeout: configuration.ai.requestTimeout,
            proxyURLString: configuration.ai.proxyURLString,
            session: session
        )
        model = configuration.ai.analysisModel
    }

    func extractActionItems(
        transcript: String,
        meetingTitle: String,
        referenceDate: Date
    ) async throws -> [MeetingActionItemCandidate] {
        let clippedTranscript = String(transcript.prefix(60_000))
        let system = """
        你是会议行动项提取器。只提取会议中明确承诺、明确要求或能够直接执行的事项。
        不要把讨论、观点、背景信息、愿望或未达成共识的建议当成待办。
        每条必须回答：谁负责、何时完成、具体做什么、为什么判断它是行动项，并附一段原文依据。
        如果负责人或时间没有明确说出，返回空字符串或 null，不要猜测。
        title 必须是一个可以直接执行的动作，使用动词开头，最多 40 个中文字符。
        quadrant 只能是 important_urgent、important_not_urgent、urgent_not_important、not_important_not_urgent。
        仅返回 JSON：{"action_items":[{"title":"","owner":"","due_at":null,"due_text":"","reason":"","evidence":"","quadrant":"important_not_urgent"}]}
        """
        let user = """
        会议标题：\(meetingTitle)
        会议参考时间：\(Self.isoFormatter.string(from: referenceDate))

        逐字稿：
        \(clippedTranscript)
        """
        let payload: TaskIntelligenceActionResponse = try await request(
            system: system,
            user: user,
            response: TaskIntelligenceActionResponse.self,
            maxTokens: 4096
        )

        return payload.actionItems.prefix(12).compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = item.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let evidence = item.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !reason.isEmpty, !evidence.isEmpty else { return nil }
            return MeetingActionItemCandidate(
                title: title,
                owner: item.owner.trimmingCharacters(in: .whitespacesAndNewlines),
                dueAt: item.dueAt.flatMap(Self.parseDate),
                dueText: item.dueText.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                evidence: evidence,
                suggestedQuadrant: TodoQuadrant(rawValue: item.quadrant) ?? .importantNotUrgent
            )
        }
    }

    func breakDown(todo: TodoItem, sourceContext: String) async throws -> [String] {
        let system = """
        你是工作任务拆解助手。把一个长期没有推进的待办拆成 2 到 4 个可以独立完成的下一步。
        每一步必须具体、可验证、可以在一次专注工作中完成。不要写空泛建议，不要重复原任务。
        仅返回 JSON：{"steps":["步骤一","步骤二"]}
        """
        let user = """
        原待办：\(todo.title)
        描述：\(todo.detail)
        为什么要做：\(todo.sourceReason)
        相关资料摘要：\(String(sourceContext.prefix(8_000)))
        """
        let payload: TaskIntelligenceBreakdownResponse = try await request(
            system: system,
            user: user,
            response: TaskIntelligenceBreakdownResponse.self,
            maxTokens: 2048
        )
        var seen = Set<String>()
        let normalizedSteps = payload.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return Array(normalizedSteps.prefix(4))
    }

    private func request<Response: Decodable>(
        system: String,
        user: String,
        response: Response.Type,
        maxTokens: Int
    ) async throws -> Response {
        let body: DeepSeekJSONObject = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "thinking": ["type": "enabled"],
            "reasoning_effort": "high",
            "stream": false,
            "max_tokens": maxTokens,
            "response_format": ["type": "json_object"],
        ]
        let envelope: TaskIntelligenceChatResponse = try await executor.postJSON(
            path: "chat/completions",
            body: body,
            decode: TaskIntelligenceChatResponse.self
        )
        guard let content = envelope.choices.first?.message.content,
              let data = Self.jsonData(from: content)
        else {
            throw CasebaseError.emptyResponse
        }
        return try JSONDecoder().decode(response, from: data)
    }

    private static func jsonData(from content: String) -> Data? {
        var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: .newlines)
            if lines.count >= 3 {
                trimmed = lines.dropFirst().dropLast().joined(separator: "\n")
            }
        }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            return nil
        }
        return Data(trimmed[start ... end].utf8)
    }

    private static func parseDate(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter = ISO8601DateFormatter()
}

private struct TaskIntelligenceChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

private struct TaskIntelligenceActionResponse: Decodable {
    let actionItems: [Item]

    enum CodingKeys: String, CodingKey {
        case actionItems = "action_items"
    }

    struct Item: Decodable {
        let title: String
        let owner: String
        let dueAt: String?
        let dueText: String
        let reason: String
        let evidence: String
        let quadrant: String

        enum CodingKeys: String, CodingKey {
            case title, owner, reason, evidence, quadrant
            case dueAt = "due_at"
            case dueText = "due_text"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? ""
            dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
            dueText = try container.decodeIfPresent(String.self, forKey: .dueText) ?? ""
            reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
            evidence = try container.decodeIfPresent(String.self, forKey: .evidence) ?? ""
            quadrant = try container.decodeIfPresent(String.self, forKey: .quadrant) ?? TodoQuadrant.importantNotUrgent.rawValue
        }
    }
}

private struct TaskIntelligenceBreakdownResponse: Decodable {
    let steps: [String]
}
