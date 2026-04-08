import Foundation

enum CasebaseDebugLogger {
    private static let logURL = URL(fileURLWithPath: "/tmp/casebase-debug.log")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let queue = DispatchQueue(label: "ai.casebase.debug-logger")

    static func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async {
            let data = Data(line.utf8)
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    defer { try? handle.close() }
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    return
                }
            }

            try? data.write(to: logURL, options: .atomic)
        }
    }
}
