import Foundation

enum SystemCommandRunner {
    struct Result {
        let standardOutput: Data
        let standardError: Data
        let terminationStatus: Int32
    }

    enum CommandError: Error {
        case launchFailed(String)
        case nonZeroExit(String)
    }

    @discardableResult
    static func run(
        executableURL: URL,
        arguments: [String],
        input: Data? = nil
    ) throws -> Result {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let input {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            stdinPipe.fileHandleForWriting.writeabilityHandler = { handle in
                handle.write(input)
                try? handle.close()
                handle.writeabilityHandler = nil
            }
        } else {
            try process.run()
        }

        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let result = Result(
            standardOutput: stdout,
            standardError: stderr,
            terminationStatus: process.terminationStatus
        )

        guard process.terminationStatus == 0 else {
            let stderrText = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let stdoutText = String(decoding: stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = [stderrText, stdoutText]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw CommandError.nonZeroExit(message)
        }

        return result
    }
}
