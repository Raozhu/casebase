import Foundation
import SwiftUI

final class CasebaseAPIKeyStore: ObservableObject {
    static let shared = CasebaseAPIKeyStore()

    @Published private(set) var isConfigured: Bool
    @Published private(set) var googleKeyConfigured: Bool
    @Published private(set) var statusMessage: String?

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        isConfigured = Self.hasConfiguredDeepSeekKey(fileManager: fileManager)
        googleKeyConfigured = Self.hasConfiguredGoogleKey(fileManager: fileManager)
    }

    func reload() {
        isConfigured = Self.hasConfiguredDeepSeekKey(fileManager: fileManager)
        googleKeyConfigured = Self.hasConfiguredGoogleKey(fileManager: fileManager)
    }

    func saveDeepSeekAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CasebaseError.missingConfiguration("DEEPSEEK_API_KEY")
        }

        var environment = Self.loadEnvironment(fileManager: fileManager)
        environment["DEEPSEEK_API_KEY"] = trimmed
        environment["CASEBASE_API_BASE_URL"] = "https://api.deepseek.com"
        environment["CASEBASE_ANALYSIS_MODEL"] = "deepseek-v4-pro"
        environment["CASEBASE_ANSWER_MODEL"] = "deepseek-v4-pro"
        environment["CASEBASE_EMBEDDING_MODEL"] = ""
        try Self.writeEnvironment(environment, fileManager: fileManager)

        isConfigured = true
        statusMessage = CasebasePromptCatalog.ui.settingsAPIKeySavedMessage
        NotificationCenter.default.post(name: .casebaseAPIKeyUpdated, object: nil)
    }

    func saveGoogleAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CasebaseError.missingConfiguration("CASEBASE_GOOGLE_API_KEY")
        }

        var environment = Self.loadEnvironment(fileManager: fileManager)
        environment["CASEBASE_GOOGLE_API_KEY"] = trimmed
        environment["CASEBASE_GOOGLE_API_BASE_URL"] = "https://generativelanguage.googleapis.com/v1beta"
        environment["CASEBASE_GOOGLE_ANALYSIS_MODEL"] = "gemini-2.5-flash-lite"
        environment["CASEBASE_GOOGLE_ANSWER_MODEL"] = "gemini-2.5-flash"
        environment["CASEBASE_GOOGLE_EMBEDDING_MODEL"] = "gemini-embedding-001"
        try Self.writeEnvironment(environment, fileManager: fileManager)

        googleKeyConfigured = true
        statusMessage = CasebasePromptCatalog.ui.settingsAPIKeySavedMessage
        NotificationCenter.default.post(name: .casebaseAPIKeyUpdated, object: nil)
    }

    static func resolvedDeepSeekAPIKey(
        from environment: [String: String]
    ) -> String? {
        if let key = nonEmptyValue("DEEPSEEK_API_KEY", in: environment) {
            return key
        }

        guard let compatibilityKey = nonEmptyValue("CASEBASE_API_KEY", in: environment),
              !looksLikeGoogleAPIKey(compatibilityKey)
        else {
            return nil
        }
        return compatibilityKey
    }

    static func resolvedGoogleAPIKey(from environment: [String: String]) -> String? {
        let keys = [
            "CASEBASE_GOOGLE_API_KEY",
            "CASEBASE_GEMINI_API_KEY",
            "GOOGLE_API_KEY",
            "GEMINI_API_KEY",
        ]

        for key in keys {
            if let value = nonEmptyValue(key, in: environment) {
                return value
            }
        }

        guard let compatibilityKey = nonEmptyValue("CASEBASE_API_KEY", in: environment),
              looksLikeGoogleAPIKey(compatibilityKey)
        else {
            return nil
        }
        return compatibilityKey
    }

    static func loadEnvironment(fileManager: FileManager = .default) -> [String: String] {
        let environmentFileURL = defaultEnvironmentFileURL(fileManager: fileManager)
        guard
            let data = try? Data(contentsOf: environmentFileURL),
            let contents = String(data: data, encoding: .utf8)
        else {
            return [:]
        }

        var values: [String: String] = [:]
        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            var value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value.removeFirst()
                value.removeLast()
            }

            values[key] = value
        }

        return values
    }

    static func defaultEnvironmentFileURL(fileManager: FileManager = .default) -> URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport
                .appendingPathComponent("casebase", isDirectory: true)
                .appendingPathComponent(".env", isDirectory: false)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/casebase", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
    }

    private static func writeEnvironment(
        _ environment: [String: String],
        fileManager: FileManager
    ) throws {
        let environmentFileURL = defaultEnvironmentFileURL(fileManager: fileManager)
        try fileManager.createDirectory(
            at: environmentFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let preferredKeys = [
            "DEEPSEEK_API_KEY",
            "CASEBASE_GOOGLE_API_KEY",
            "CASEBASE_API_KEY",
            "CASEBASE_ALL_PROXY",
            "CASEBASE_API_BASE_URL",
            "CASEBASE_ANALYSIS_MODEL",
            "CASEBASE_ANSWER_MODEL",
            "CASEBASE_EMBEDDING_MODEL",
            "CASEBASE_GOOGLE_API_BASE_URL",
            "CASEBASE_GOOGLE_ANALYSIS_MODEL",
            "CASEBASE_GOOGLE_ANSWER_MODEL",
            "CASEBASE_GOOGLE_EMBEDDING_MODEL",
        ]
        let remainingKeys = environment.keys
            .filter { !preferredKeys.contains($0) }
            .sorted()
        let orderedKeys = preferredKeys.filter { environment.keys.contains($0) } + remainingKeys

        let contents = orderedKeys
            .map { "\($0)=\(environment[$0] ?? "")" }
            .joined(separator: "\n") + "\n"
        try contents.write(to: environmentFileURL, atomically: true, encoding: .utf8)
    }

    private static func hasConfiguredDeepSeekKey(fileManager: FileManager) -> Bool {
        resolvedDeepSeekAPIKey(from: loadEnvironment(fileManager: fileManager)) != nil
    }

    private static func hasConfiguredGoogleKey(fileManager: FileManager) -> Bool {
        resolvedGoogleAPIKey(from: loadEnvironment(fileManager: fileManager)) != nil
    }

    private static func nonEmptyValue(_ key: String, in environment: [String: String]) -> String? {
        guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func looksLikeGoogleAPIKey(_ value: String) -> Bool {
        value.hasPrefix("AIza")
    }
}
