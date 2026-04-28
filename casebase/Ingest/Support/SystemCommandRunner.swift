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

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        var standardOutput = Data()
        var standardError = Data()
        let ioGroup = DispatchGroup()

        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            standardOutput = stdoutHandle.readDataToEndOfFile()
            ioGroup.leave()
        }

        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            standardError = stderrHandle.readDataToEndOfFile()
            ioGroup.leave()
        }

        if let input {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try process.run()
            let stdinHandle = stdinPipe.fileHandleForWriting
            DispatchQueue.global(qos: .userInitiated).async {
                stdinHandle.write(input)
                try? stdinHandle.close()
            }
        } else {
            try process.run()
        }

        process.waitUntilExit()
        ioGroup.wait()
        let result = Result(
            standardOutput: standardOutput,
            standardError: standardError,
            terminationStatus: process.terminationStatus
        )

        guard process.terminationStatus == 0 else {
            let stderrText = String(decoding: standardError, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let stdoutText = String(decoding: standardOutput, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let message = [stderrText, stdoutText]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw CommandError.nonZeroExit(message)
        }

        return result
    }
}
