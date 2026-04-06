import Foundation

// Cross-module contracts owned by the Core layer. Feature modules should depend on these only.
typealias ImportProgressHandler = @Sendable (ImportProcessingPhase) -> Void

protocol Extractor {
    var supportedSourceKinds: Set<ImportSourceKind> { get }
    func canExtract(_ payload: ImportPayload) -> Bool
    func normalize(_ payload: ImportPayload) async throws -> NormalizedContent
}

protocol KnowledgeStore {
    func findRecord(byAssetHash assetHash: String) async throws -> ImportRecord?
    func save(_ record: ImportRecord) async throws
    func update(_ record: ImportRecord) async throws
    func fetchRecord(id: UUID) async throws -> ImportRecord?
    func fetchRecords(ids: [UUID]) async throws -> [ImportRecord]
    func search(query: String, embedding: [Float], limit: Int) async throws -> [SearchHit]
}

protocol AIClient {
    func analyze(content: NormalizedContent) async throws -> AnalysisResult
    func embed(text: String) async throws -> [Float]
    func answer(question: String, hits: [SearchHit], policy: AnswerPolicy) async throws -> AnswerResult
}

protocol DataResetService {
    func clearAllStoredData() async throws
}

protocol LibraryService {
    var rootDirectory: URL { get }
    func recentRecords(limit: Int) async throws -> [ImportRecord]
    func deleteRecord(id: UUID) async throws
    func revealInFinder(record: ImportRecord) async throws
    func open(record: ImportRecord) async throws
}

protocol ImportCoordinator {
    func importPayload(_ payload: ImportPayload, progress: ImportProgressHandler?) async throws -> ImportRecord
    func importPayload(_ payload: ImportPayload) async throws -> ImportRecord
    func reanalyzeRecord(
        id: UUID,
        clarificationAnswers: [ClarificationAnswer],
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord
}

extension ImportCoordinator {
    func importPayload(_ payload: ImportPayload) async throws -> ImportRecord {
        try await importPayload(payload, progress: nil)
    }

    func reanalyzeRecord(id: UUID) async throws -> ImportRecord {
        try await reanalyzeRecord(id: id, clarificationAnswers: [], skippedQuestionTitles: [], progress: nil)
    }

    func reanalyzeRecord(id: UUID, clarificationAnswers: [ClarificationAnswer]) async throws -> ImportRecord {
        try await reanalyzeRecord(id: id, clarificationAnswers: clarificationAnswers, skippedQuestionTitles: [], progress: nil)
    }

    func reanalyzeRecord(
        id: UUID,
        clarificationAnswers: [ClarificationAnswer],
        skippedQuestionTitles: [String]
    ) async throws -> ImportRecord {
        try await reanalyzeRecord(
            id: id,
            clarificationAnswers: clarificationAnswers,
            skippedQuestionTitles: skippedQuestionTitles,
            progress: nil
        )
    }
}

protocol AnswerService {
    func answer(question: String, limit: Int) async throws -> AnswerResult
}
