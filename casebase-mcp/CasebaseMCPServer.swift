import CoreFoundation
import Foundation

final class CasebaseMCPServer {
    private let runtime: CasebaseCatalogRuntime
    private let transport = StdioJSONRPCTransport()
    private let encoder: JSONEncoder
    private var shouldExit = false

    init(runtime: CasebaseCatalogRuntime) {
        self.runtime = runtime
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    func run() async throws {
        while !shouldExit, let body = try transport.readMessage() {
            do {
                let response = try await handleMessage(body)
                if let response {
                    try transport.writeMessage(response)
                }
            } catch let protocolError as MCPProtocolError {
                if let errorResponse = errorResponseData(
                    id: protocolError.id,
                    code: protocolError.code,
                    message: protocolError.message
                ) {
                    try transport.writeMessage(errorResponse)
                }
            } catch {
                if let errorResponse = errorResponseData(
                    id: nil,
                    code: -32603,
                    message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                ) {
                    try transport.writeMessage(errorResponse)
                }
            }
        }
    }

    private func handleMessage(_ body: Data) async throws -> Data? {
        let jsonObject = try JSONSerialization.jsonObject(with: body)
        let request = try MCPRequest(jsonObject: jsonObject)

        do {
            switch request.method {
            case "initialize":
                return try successResponseData(id: request.id, result: initializeResult())
            case "ping":
                return try successResponseData(id: request.id, result: [:])
            case "tools/list":
                return try successResponseData(id: request.id, result: toolsListResult())
            case "tools/call":
                let result = try await handleToolCall(params: request.params)
                return try successResponseData(id: request.id, result: result)
            case "shutdown":
                return try successResponseData(id: request.id, result: [:])
            case "exit":
                shouldExit = true
                return nil
            case "notifications/initialized":
                return nil
            default:
                if request.id == nil {
                    return nil
                }
                throw MCPProtocolError(
                    code: -32601,
                    message: "Unsupported method: \(request.method)",
                    id: request.id
                )
            }
        } catch let protocolError as MCPProtocolError {
            throw MCPProtocolError(
                code: protocolError.code,
                message: protocolError.message,
                id: protocolError.id ?? request.id
            )
        }
    }

    private func handleToolCall(params: [String: Any]) async throws -> [String: Any] {
        guard let toolName = params["name"] as? String, !toolName.isEmpty else {
            throw MCPProtocolError(code: -32602, message: "Missing tool name.")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]

        switch toolName {
        case "casebase_list_records":
            let parsed = try parseCommonListArguments(arguments)
            let payload = try await runtime.listRecords(
                limit: parsed.limit,
                offset: parsed.offset,
                filters: parsed.filters
            )
            return try toolResult(from: payload)
        case "casebase_search_records":
            let parsed = try parseSearchArguments(arguments)
            let payload = try await runtime.searchRecords(
                query: parsed.query,
                limit: parsed.limit,
                offset: parsed.offset,
                filters: parsed.filters
            )
            return try toolResult(from: payload)
        case "casebase_get_record":
            let recordID = try requireUUID(arguments, key: "id")
            let payload = try await runtime.getRecord(id: recordID)
            return try toolResult(from: payload)
        default:
            throw MCPProtocolError(code: -32602, message: "Unknown tool: \(toolName)")
        }
    }

    private func initializeResult() -> [String: Any] {
        [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [:],
            ],
            "serverInfo": [
                "name": "casebase-mcp",
                "version": "0.1.0",
            ],
        ]
    }

    private func toolsListResult() -> [String: Any] {
        [
            "tools": [
                [
                    "name": "casebase_list_records",
                    "description": "List casebase records with optional local metadata filters.",
                    "inputSchema": commonListSchema(
                        queryRequired: false,
                        queryDescription: nil
                    ),
                ],
                [
                    "name": "casebase_search_records",
                    "description": "Search casebase records locally using SQLite FTS and metadata filters.",
                    "inputSchema": commonListSchema(
                        queryRequired: true,
                        queryDescription: "Required local search query. This only searches local metadata and does not upload files."
                    ),
                ],
                [
                    "name": "casebase_get_record",
                    "description": "Fetch one casebase record by id, including local absolute file path and structured metadata.",
                    "inputSchema": [
                        "type": "object",
                        "properties": [
                            "id": [
                                "type": "string",
                                "description": "Record UUID.",
                            ],
                        ],
                        "required": ["id"],
                        "additionalProperties": false,
                    ],
                ],
            ],
        ]
    }

    private func commonListSchema(
        queryRequired: Bool,
        queryDescription: String?
    ) -> [String: Any] {
        var properties: [String: Any] = [
            "limit": [
                "type": "integer",
                "minimum": 1,
                "maximum": RecordCatalogPaging.maximumLimit,
                "default": RecordCatalogPaging.defaultLimit,
            ],
            "offset": [
                "type": "integer",
                "minimum": 0,
                "default": 0,
            ],
            "purpose": [
                "type": "string",
                "description": "Exact purpose filter.",
            ],
            "tags_any": [
                "type": "array",
                "items": ["type": "string"],
                "description": "Match records containing any of these tags.",
            ],
            "source_kinds": [
                "type": "array",
                "items": [
                    "type": "string",
                    "enum": ImportSourceKind.allCases.map(\.rawValue),
                ],
            ],
            "needs_review": [
                "type": "boolean",
                "description": "Filter by clarification-needed records.",
            ],
        ]

        var required: [String] = []
        if let queryDescription {
            properties["query"] = [
                "type": "string",
                "description": queryDescription,
            ]
        }
        if queryRequired {
            required.append("query")
        }

        return [
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": false,
        ]
    }

    private func parseCommonListArguments(_ arguments: [String: Any]) throws -> ParsedListArguments {
        let limit = try optionalInt(arguments, key: "limit") ?? RecordCatalogPaging.defaultLimit
        guard limit >= 1, limit <= RecordCatalogPaging.maximumLimit else {
            throw MCPProtocolError(
                code: -32602,
                message: "limit must be between 1 and \(RecordCatalogPaging.maximumLimit)."
            )
        }

        let offset = try optionalInt(arguments, key: "offset") ?? 0
        guard offset >= 0 else {
            throw MCPProtocolError(code: -32602, message: "offset must be >= 0.")
        }

        let purpose = try optionalString(arguments, key: "purpose")
        let tagsAny = try optionalStringArray(arguments, key: "tags_any") ?? []
        let sourceKindsRaw = try optionalStringArray(arguments, key: "source_kinds") ?? []
        let sourceKinds = try sourceKindsRaw.map { rawValue -> ImportSourceKind in
            guard let sourceKind = ImportSourceKind(rawValue: rawValue) else {
                throw MCPProtocolError(
                    code: -32602,
                    message: "Unsupported source_kind: \(rawValue)."
                )
            }
            return sourceKind
        }
        let needsReview = try optionalBool(arguments, key: "needs_review")

        return ParsedListArguments(
            limit: limit,
            offset: offset,
            filters: RecordCatalogFilters(
                purpose: purpose,
                tagsAny: tagsAny,
                sourceKinds: sourceKinds,
                needsReview: needsReview
            )
        )
    }

    private func parseSearchArguments(_ arguments: [String: Any]) throws -> ParsedSearchArguments {
        let common = try parseCommonListArguments(arguments)
        let query = try requireString(arguments, key: "query")
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            throw MCPProtocolError(code: -32602, message: "query must not be empty.")
        }

        return ParsedSearchArguments(
            query: normalizedQuery,
            limit: common.limit,
            offset: common.offset,
            filters: common.filters
        )
    }

    private func toolResult<T: Encodable>(from payload: T) throws -> [String: Any] {
        let structured = try jsonObject(from: payload)
        return [
            "content": [
                [
                    "type": "text",
                    "text": try prettyJSONString(from: structured),
                ],
            ],
            "structuredContent": structured,
        ]
    }

    private func successResponseData(id: Any?, result: Any) throws -> Data {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result,
        ]
        payload["id"] = id ?? NSNull()
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private func errorResponseData(id: Any?, code: Int, message: String) -> Data? {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": [
                "code": code,
                "message": message,
            ],
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func jsonObject<T: Encodable>(from value: T) throws -> Any {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func prettyJSONString(from jsonObject: Any) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private func requireString(_ arguments: [String: Any], key: String) throws -> String {
        guard let value = try optionalString(arguments, key: key) else {
            throw MCPProtocolError(code: -32602, message: "Missing required string: \(key).")
        }
        return value
    }

    private func requireUUID(_ arguments: [String: Any], key: String) throws -> UUID {
        let rawValue = try requireString(arguments, key: key)
        guard let uuid = UUID(uuidString: rawValue) else {
            throw MCPProtocolError(code: -32602, message: "Invalid UUID for \(key).")
        }
        return uuid
    }

    private func optionalString(_ arguments: [String: Any], key: String) throws -> String? {
        guard let rawValue = arguments[key] else { return nil }
        if rawValue is NSNull {
            return nil
        }
        guard let value = rawValue as? String else {
            throw MCPProtocolError(code: -32602, message: "\(key) must be a string.")
        }
        return value
    }

    private func optionalStringArray(_ arguments: [String: Any], key: String) throws -> [String]? {
        guard let rawValue = arguments[key] else { return nil }
        if rawValue is NSNull {
            return nil
        }
        guard let values = rawValue as? [Any] else {
            throw MCPProtocolError(code: -32602, message: "\(key) must be an array of strings.")
        }

        return try values.map { value in
            guard let stringValue = value as? String else {
                throw MCPProtocolError(code: -32602, message: "\(key) must be an array of strings.")
            }
            return stringValue
        }
    }

    private func optionalInt(_ arguments: [String: Any], key: String) throws -> Int? {
        guard let rawValue = arguments[key] else { return nil }
        if rawValue is NSNull {
            return nil
        }
        if let intValue = rawValue as? Int {
            return intValue
        }
        if let numberValue = rawValue as? NSNumber, !isBoolean(numberValue) {
            return numberValue.intValue
        }
        throw MCPProtocolError(code: -32602, message: "\(key) must be an integer.")
    }

    private func optionalBool(_ arguments: [String: Any], key: String) throws -> Bool? {
        guard let rawValue = arguments[key] else { return nil }
        if rawValue is NSNull {
            return nil
        }
        if let boolValue = rawValue as? Bool {
            return boolValue
        }
        if let numberValue = rawValue as? NSNumber, isBoolean(numberValue) {
            return numberValue.boolValue
        }
        throw MCPProtocolError(code: -32602, message: "\(key) must be a boolean.")
    }

    private func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

private struct ParsedListArguments {
    let limit: Int
    let offset: Int
    let filters: RecordCatalogFilters
}

private struct ParsedSearchArguments {
    let query: String
    let limit: Int
    let offset: Int
    let filters: RecordCatalogFilters
}

private struct MCPRequest {
    let id: Any?
    let method: String
    let params: [String: Any]

    init(jsonObject: Any) throws {
        guard let dictionary = jsonObject as? [String: Any] else {
            throw MCPProtocolError(code: -32600, message: "Request payload must be an object.")
        }

        let jsonrpc = dictionary["jsonrpc"] as? String
        guard jsonrpc == "2.0" else {
            throw MCPProtocolError(code: -32600, message: "Unsupported jsonrpc version.")
        }

        guard let method = dictionary["method"] as? String, !method.isEmpty else {
            throw MCPProtocolError(code: -32600, message: "Request method is required.")
        }

        let params: [String: Any]
        if let rawParams = dictionary["params"] {
            if rawParams is NSNull {
                params = [:]
            } else if let parsedParams = rawParams as? [String: Any] {
                params = parsedParams
            } else {
                throw MCPProtocolError(code: -32602, message: "params must be an object.")
            }
        } else {
            params = [:]
        }

        id = dictionary["id"]
        self.method = method
        self.params = params
    }
}

private struct MCPProtocolError: Error {
    let code: Int
    let message: String
    let id: Any?

    init(code: Int, message: String, id: Any? = nil) {
        self.code = code
        self.message = message
        self.id = id
    }
}

private final class StdioJSONRPCTransport {
    private let input = FileHandle.standardInput
    private let output = FileHandle.standardOutput
    private var buffer = Data()
    private var framing: MessageFraming?

    func readMessage() throws -> Data? {
        while true {
            if let message = try drainMessageFromBuffer() {
                return message
            }

            let chunk = input.availableData
            guard !chunk.isEmpty else {
                if buffer.isEmpty {
                    return nil
                }
                throw MCPProtocolError(code: -32700, message: "Unexpected EOF while reading MCP message.")
            }
            buffer.append(chunk)
        }
    }

    func writeMessage(_ body: Data) throws {
        switch framing ?? .jsonLine {
        case .contentLength:
            guard let headerData = "Content-Length: \(body.count)\r\n\r\n".data(using: .utf8) else {
                throw MCPProtocolError(code: -32603, message: "Failed to encode MCP header.")
            }
            try output.write(contentsOf: headerData)
            try output.write(contentsOf: body)
        case .jsonLine:
            try output.write(contentsOf: body)
            try output.write(contentsOf: Data("\n".utf8))
        }
    }

    private func drainMessageFromBuffer() throws -> Data? {
        if framing == nil {
            framing = detectFraming()
        }

        switch framing {
        case .contentLength:
            return try drainContentLengthMessageFromBuffer()
        case .jsonLine:
            return try drainJSONLineMessageFromBuffer()
        case nil:
            return nil
        }
    }

    private func detectFraming() -> MessageFraming? {
        guard let firstByte = firstMeaningfulByte() else {
            return nil
        }

        if firstByte == UInt8(ascii: "{") || firstByte == UInt8(ascii: "[") {
            return .jsonLine
        }

        if firstByte == UInt8(ascii: "C") || firstByte == UInt8(ascii: "c") {
            return .contentLength
        }

        return nil
    }

    private func firstMeaningfulByte() -> UInt8? {
        for byte in buffer {
            switch byte {
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\r"), UInt8(ascii: "\n"):
                continue
            default:
                return byte
            }
        }
        return nil
    }

    private func drainContentLengthMessageFromBuffer() throws -> Data? {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: delimiter) else {
            return nil
        }

        let headerData = buffer.subdata(in: 0 ..< headerRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw MCPProtocolError(code: -32700, message: "Failed to decode MCP headers.")
        }

        let contentLength = try parseContentLength(from: headerString)
        let messageStart = headerRange.upperBound
        let totalLength = messageStart + contentLength
        guard buffer.count >= totalLength else {
            return nil
        }

        let message = buffer.subdata(in: messageStart ..< totalLength)
        buffer.removeSubrange(0 ..< totalLength)
        return message
    }

    private func drainJSONLineMessageFromBuffer() throws -> Data? {
        let newline = UInt8(ascii: "\n")
        guard let lineEnd = buffer.firstIndex(of: newline) else {
            return nil
        }

        var line = buffer.subdata(in: 0 ..< lineEnd)
        buffer.removeSubrange(0 ... lineEnd)

        if line.last == UInt8(ascii: "\r") {
            line.removeLast()
        }

        if line.allSatisfy({ byte in
            byte == UInt8(ascii: " ") ||
                byte == UInt8(ascii: "\t") ||
                byte == UInt8(ascii: "\r")
        }) {
            return try drainJSONLineMessageFromBuffer()
        }

        return line
    }

    private func parseContentLength(from headerString: String) throws -> Int {
        for line in headerString.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0].lowercased() == "content-length" {
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard let length = Int(value), length >= 0 else {
                    break
                }
                return length
            }
        }

        throw MCPProtocolError(code: -32700, message: "Missing Content-Length header.")
    }
}

private enum MessageFraming {
    case contentLength
    case jsonLine
}

private extension ImportSourceKind {
    static var allCases: [ImportSourceKind] {
        [.image, .text, .pdf, .audio, .folder, .binary]
    }
}
