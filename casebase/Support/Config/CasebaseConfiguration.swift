import Foundation

struct AIServiceConfiguration: Hashable {
    let baseURL: URL
    let apiKey: String
    let analysisModel: String
    let answerModel: String
    let embeddingModel: String
    let googleBaseURL: URL
    let googleAPIKey: String?
    let googleAnalysisModel: String
    let googleAnswerModel: String
    let googleEmbeddingModel: String
    let transcriptionModel: String
    let requestTimeout: TimeInterval
    let maxImportFileBytes: Int64
    let proxyURLString: String?
}

struct StorageConfiguration: Hashable {
    let rootDirectory: URL
    let assetsDirectory: URL
    let visibleShortcutDirectory: URL
    let databaseURL: URL

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> StorageConfiguration {
        let resolvedEnvironment = resolvedCasebaseEnvironment(
            processEnvironment: environment,
            fileManager: fileManager
        )
        return resolvedStorageConfiguration(
            environment: resolvedEnvironment,
            fileManager: fileManager
        )
    }
}

struct AnsweringConfiguration: Hashable {
    let defaultResultLimit: Int
    let policy: AnswerPolicy
}

struct CasebaseConfiguration: Hashable {
    let ai: AIServiceConfiguration
    let storage: StorageConfiguration
    let answering: AnsweringConfiguration

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> CasebaseConfiguration {
        let resolvedEnvironment = resolvedCasebaseEnvironment(
            processEnvironment: environment,
            fileManager: fileManager
        )
        let storage = resolvedStorageConfiguration(
            environment: resolvedEnvironment,
            fileManager: fileManager
        )

        let apiKey = resolvedDeepSeekAPIKey(from: resolvedEnvironment)
        guard let apiKey, !apiKey.isEmpty else {
            throw CasebaseError.missingConfiguration("DEEPSEEK_API_KEY")
        }

        let baseURLString = resolvedEnvironment["CASEBASE_API_BASE_URL"] ?? "https://api.deepseek.com"
        guard let baseURL = URL(string: baseURLString) else {
            throw CasebaseError.missingConfiguration("CASEBASE_API_BASE_URL")
        }

        let analysisModel = resolvedEnvironment["CASEBASE_ANALYSIS_MODEL"] ?? "deepseek-v4-pro"
        let answerModel = resolvedEnvironment["CASEBASE_ANSWER_MODEL"] ?? "deepseek-v4-pro"
        let embeddingModel = resolvedEnvironment["CASEBASE_EMBEDDING_MODEL"] ?? ""
        let googleBaseURLString = resolvedEnvironment["CASEBASE_GOOGLE_API_BASE_URL"] ?? "https://generativelanguage.googleapis.com/v1beta"
        guard let googleBaseURL = URL(string: googleBaseURLString) else {
            throw CasebaseError.missingConfiguration("CASEBASE_GOOGLE_API_BASE_URL")
        }
        let googleAPIKey = resolvedGoogleAPIKey(from: resolvedEnvironment)
        let googleAnalysisModel = resolvedEnvironment["CASEBASE_GOOGLE_ANALYSIS_MODEL"]
            ?? resolvedEnvironment["CASEBASE_GEMINI_ANALYSIS_MODEL"]
            ?? "gemini-2.5-flash-lite"
        let googleAnswerModel = resolvedEnvironment["CASEBASE_GOOGLE_ANSWER_MODEL"]
            ?? resolvedEnvironment["CASEBASE_GEMINI_ANSWER_MODEL"]
            ?? "gemini-2.5-flash"
        let googleEmbeddingModel = resolvedEnvironment["CASEBASE_GOOGLE_EMBEDDING_MODEL"]
            ?? resolvedEnvironment["CASEBASE_GEMINI_EMBEDDING_MODEL"]
            ?? "gemini-embedding-001"
        let transcriptionModel = resolvedEnvironment["CASEBASE_TRANSCRIPTION_MODEL"] ?? "gpt-4o-mini-transcribe"
        let timeout = Double(resolvedEnvironment["CASEBASE_REQUEST_TIMEOUT_SECONDS"] ?? "") ?? 60
        let defaultResultLimit = Int(resolvedEnvironment["CASEBASE_DEFAULT_RESULT_LIMIT"] ?? "") ?? 6
        let maxImportFileBytes = Int64(resolvedEnvironment["CASEBASE_MAX_IMPORT_FILE_BYTES"] ?? "") ?? 8_000_000
        let proxyURLString = resolvedEnvironment["CASEBASE_ALL_PROXY"]
            ?? resolvedEnvironment["ALL_PROXY"]
            ?? resolvedEnvironment["HTTPS_PROXY"]
            ?? resolvedEnvironment["HTTP_PROXY"]

        return CasebaseConfiguration(
            ai: AIServiceConfiguration(
                baseURL: baseURL,
                apiKey: apiKey,
                analysisModel: analysisModel,
                answerModel: answerModel,
                embeddingModel: embeddingModel,
                googleBaseURL: googleBaseURL,
                googleAPIKey: googleAPIKey,
                googleAnalysisModel: googleAnalysisModel,
                googleAnswerModel: googleAnswerModel,
                googleEmbeddingModel: googleEmbeddingModel,
                transcriptionModel: transcriptionModel,
                requestTimeout: timeout,
                maxImportFileBytes: max(1_000_000, maxImportFileBytes),
                proxyURLString: proxyURLString
            ),
            storage: storage,
            answering: AnsweringConfiguration(
                defaultResultLimit: max(1, defaultResultLimit),
                policy: .defaultKnowledgeFirst
            )
        )
    }
}

private func resolvedCasebaseEnvironment(
    processEnvironment: [String: String],
    fileManager: FileManager
) -> [String: String] {
    let fileEnvironment = loadCasebaseEnvironmentFile(fileManager: fileManager)
    return fileEnvironment.merging(processEnvironment) { _, processValue in
        processValue
    }
}

private func loadCasebaseEnvironmentFile(fileManager: FileManager) -> [String: String] {
    let environmentFileURL = defaultCasebaseEnvironmentFileURL(fileManager: fileManager)
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

private func defaultCasebaseEnvironmentFileURL(fileManager: FileManager) -> URL {
    if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        return appSupport
            .appendingPathComponent("casebase", isDirectory: true)
            .appendingPathComponent(".env", isDirectory: false)
    }

    return fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/casebase", isDirectory: true)
        .appendingPathComponent(".env", isDirectory: false)
}

private func resolvedDeepSeekAPIKey(from environment: [String: String]) -> String? {
    if let key = nonEmptyEnvironmentValue("DEEPSEEK_API_KEY", in: environment) {
        return key
    }

    guard let compatibilityKey = nonEmptyEnvironmentValue("CASEBASE_API_KEY", in: environment),
          !compatibilityKey.hasPrefix("AIza")
    else {
        return nil
    }
    return compatibilityKey
}

private func resolvedGoogleAPIKey(from environment: [String: String]) -> String? {
    let keys = [
        "CASEBASE_GOOGLE_API_KEY",
        "CASEBASE_GEMINI_API_KEY",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
    ]

    for key in keys {
        if let value = nonEmptyEnvironmentValue(key, in: environment) {
            return value
        }
    }

    guard let compatibilityKey = nonEmptyEnvironmentValue("CASEBASE_API_KEY", in: environment),
          compatibilityKey.hasPrefix("AIza")
    else {
        return nil
    }
    return compatibilityKey
}

private func nonEmptyEnvironmentValue(_ key: String, in environment: [String: String]) -> String? {
    guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }
    return value
}

private func resolvedStorageConfiguration(
    environment: [String: String],
    fileManager: FileManager
) -> StorageConfiguration {
    let rootDirectory: URL
    if let customRoot = environment["CASEBASE_STORAGE_ROOT"], !customRoot.isEmpty {
        rootDirectory = URL(fileURLWithPath: customRoot, isDirectory: true)
    } else if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        rootDirectory = appSupport.appendingPathComponent("casebase", isDirectory: true)
    } else {
        rootDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/casebase", isDirectory: true)
    }

    return StorageConfiguration(
        rootDirectory: rootDirectory,
        assetsDirectory: rootDirectory.appendingPathComponent("assets", isDirectory: true),
        visibleShortcutDirectory: resolvedVisibleShortcutDirectory(
            environment: environment,
            fileManager: fileManager
        ),
        databaseURL: rootDirectory.appendingPathComponent("casebase.sqlite", isDirectory: false)
    )
}

private func resolvedVisibleShortcutDirectory(
    environment: [String: String],
    fileManager: FileManager
) -> URL {
    if let customRoot = environment["CASEBASE_VISIBLE_SHORTCUT_ROOT"], !customRoot.isEmpty {
        return URL(fileURLWithPath: customRoot, isDirectory: true)
    }

    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
    return documentsDirectory.appendingPathComponent("Casebase 标签入口", isDirectory: true)
}
