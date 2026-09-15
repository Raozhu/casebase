import Foundation

// Cross-module contracts owned by the Core layer. Feature modules should depend on these only.
typealias ImportProgressHandler = @Sendable (ImportProgressUpdate) -> Void
typealias AIThoughtHandler = @Sendable (String) -> Void
typealias AnswerStreamHandler = @Sendable (String) -> Void

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
    func recentRecords(limit: Int) async throws -> [ImportRecord]
    func search(query: String, embedding: [Float], limit: Int, scope: AnswerQueryScope) async throws -> [SearchHit]
}

protocol AIClient {
    func analyze(content: NormalizedContent, thoughtHandler: AIThoughtHandler?) async throws -> AnalysisResult
    func analyze(content: NormalizedContent) async throws -> AnalysisResult
    func embed(text: String) async throws -> [Float]
    func answer(
        question: String,
        sources: [AnswerEvidencePacket],
        policy: AnswerPolicy,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult
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

protocol AudioTranscriptService {
    func linkedTranscript(forAudioRecordID id: UUID) async throws -> ImportRecord?
    func sourceAudio(forTranscriptRecordID id: UUID) async throws -> ImportRecord?
    func transcribeAudioRecord(id: UUID, progress: ImportProgressHandler?) async throws -> ImportRecord
}

protocol TodoService {
    func listTodos(filters: TodoFilters, limit: Int, offset: Int) async throws -> TodoPage
    func fetchTodo(id: UUID) async throws -> TodoItem?
    func saveTodo(_ todo: TodoItem) async throws
    func deleteTodo(id: UUID) async throws
    func acceptMeetingActionItem(recordID: UUID, candidateID: UUID) async throws -> TodoItem
    func dismissMeetingActionItem(recordID: UUID, candidateID: UUID) async throws
    func deferStaleTodo(id: UUID, days: Int) async throws -> TodoItem
    func breakDownStaleTodo(id: UUID) async throws -> [TodoItem]
}

protocol MeetingActionItemExtracting {
    func extractActionItems(transcript: String, meetingTitle: String, referenceDate: Date) async throws -> [MeetingActionItemCandidate]
}

protocol TodoBreakdownProviding {
    func breakDown(todo: TodoItem, sourceContext: String) async throws -> [String]
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
    func finalizeRecordWithoutClarification(
        id: UUID,
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord
}

protocol AssetOrganizationService {
    func organizeLegacyAssets() async throws -> Int
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

    func finalizeRecordWithoutClarification(
        id: UUID,
        skippedQuestionTitles: [String]
    ) async throws -> ImportRecord {
        try await finalizeRecordWithoutClarification(
            id: id,
            skippedQuestionTitles: skippedQuestionTitles,
            progress: nil
        )
    }
}

extension AIClient {
    func analyze(content: NormalizedContent) async throws -> AnalysisResult {
        try await analyze(content: content, thoughtHandler: nil)
    }
}

protocol AnswerService {
    func answer(
        question: String,
        scope: AnswerQueryScope,
        limit: Int,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult
}

extension KnowledgeStore {
    func search(query: String, embedding: [Float], limit: Int) async throws -> [SearchHit] {
        try await search(query: query, embedding: embedding, limit: limit, scope: .global)
    }
}

extension AnswerService {
    func answer(question: String, limit: Int) async throws -> AnswerResult {
        try await answer(question: question, scope: .global, limit: limit)
    }

    func answer(question: String, scope: AnswerQueryScope, limit: Int) async throws -> AnswerResult {
        try await answer(question: question, scope: scope, limit: limit, streamHandler: nil, thoughtHandler: nil)
    }

    func answer(
        question: String,
        scope: AnswerQueryScope,
        limit: Int,
        streamHandler: AnswerStreamHandler?
    ) async throws -> AnswerResult {
        try await answer(
            question: question,
            scope: scope,
            limit: limit,
            streamHandler: streamHandler,
            thoughtHandler: nil
        )
    }
}

extension AIClient {
    func answer(question: String, sources: [AnswerEvidencePacket], policy: AnswerPolicy) async throws -> AnswerResult {
        try await answer(
            question: question,
            sources: sources,
            policy: policy,
            streamHandler: nil,
            thoughtHandler: nil
        )
    }
}
