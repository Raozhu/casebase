import Foundation

struct AIServiceConfiguration: Hashable {
    let baseURL: URL
    let apiKey: String
    let analysisModel: String
    let answerModel: String
    let embeddingModel: String
    let transcriptionModel: String
    let requestTimeout: TimeInterval
}

struct StorageConfiguration: Hashable {
    let rootDirectory: URL
    let assetsDirectory: URL
    let databaseURL: URL
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
        let apiKey = environment["CASEBASE_API_KEY"] ?? environment["OPENAI_API_KEY"]
        guard let apiKey, !apiKey.isEmpty else {
            throw CasebaseError.missingConfiguration("CASEBASE_API_KEY")
        }

        let baseURLString = environment["CASEBASE_API_BASE_URL"] ?? "https://api.openai.com/v1"
        guard let baseURL = URL(string: baseURLString) else {
            throw CasebaseError.missingConfiguration("CASEBASE_API_BASE_URL")
        }

        let analysisModel = environment["CASEBASE_ANALYSIS_MODEL"] ?? "gemini-3.1-flash-lite-preview"
        let answerModel = environment["CASEBASE_ANSWER_MODEL"] ?? analysisModel
        let embeddingModel = environment["CASEBASE_EMBEDDING_MODEL"] ?? "text-embedding-3-small"
        let transcriptionModel = environment["CASEBASE_TRANSCRIPTION_MODEL"] ?? "gpt-4o-mini-transcribe"
        let timeout = Double(environment["CASEBASE_REQUEST_TIMEOUT_SECONDS"] ?? "") ?? 60
        let defaultResultLimit = Int(environment["CASEBASE_DEFAULT_RESULT_LIMIT"] ?? "") ?? 6

        let rootDirectory: URL
        if let customRoot = environment["CASEBASE_STORAGE_ROOT"], !customRoot.isEmpty {
            rootDirectory = URL(fileURLWithPath: customRoot, isDirectory: true)
        } else if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            rootDirectory = appSupport.appendingPathComponent("casebase", isDirectory: true)
        } else {
            rootDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/casebase", isDirectory: true)
        }

        return CasebaseConfiguration(
            ai: AIServiceConfiguration(
                baseURL: baseURL,
                apiKey: apiKey,
                analysisModel: analysisModel,
                answerModel: answerModel,
                embeddingModel: embeddingModel,
                transcriptionModel: transcriptionModel,
                requestTimeout: timeout
            ),
            storage: StorageConfiguration(
                rootDirectory: rootDirectory,
                assetsDirectory: rootDirectory.appendingPathComponent("assets", isDirectory: true),
                databaseURL: rootDirectory.appendingPathComponent("casebase.sqlite", isDirectory: false)
            ),
            answering: AnsweringConfiguration(
                defaultResultLimit: max(1, defaultResultLimit),
                policy: .defaultOpenEnded
            )
        )
    }
}
