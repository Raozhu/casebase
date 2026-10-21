import AppKit
import Foundation

/// Picks the demo copy for the language the app UI is rendered in.
func L(_ english: String, _ chinese: String) -> String {
    CasebasePromptCatalog.language == .simplifiedChinese ? chinese : english
}

/// Deterministic stand-ins for the app's services. The UI on top of them is the real one.
@MainActor
final class DemoServices {
    let storageRoot: URL
    let library: DemoLibrary
    let importCoordinator: DemoImportCoordinator
    let answerService: DemoAnswerService
    let libraryService: DemoLibraryService
    let todoService: DemoTodoService
    let audioTranscriptService = DemoAudioTranscriptService()

    init(storageRoot: URL) throws {
        self.storageRoot = storageRoot
        try? FileManager.default.removeItem(at: storageRoot)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        library = DemoLibrary(root: storageRoot)
        try DemoContent.seed(library)
        importCoordinator = DemoImportCoordinator(library: library)
        answerService = DemoAnswerService(library: library)
        libraryService = DemoLibraryService(library: library)
        todoService = DemoTodoService(library: library)
    }
}

@MainActor
final class DemoLibrary {
    let root: URL
    var records: [ImportRecord] = []
    var todos: [TodoItem] = []

    init(root: URL) {
        self.root = root
    }

    func storeAsset(from source: URL, folder: String, name: String) throws -> String {
        let relative = "assets/\(folder)/\(name)"
        let destination = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        return relative
    }

    func record(_ id: UUID) -> ImportRecord? {
        records.first { $0.id == id }
    }

    func replace(_ record: ImportRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }
}

@MainActor
final class DemoImportCoordinator: ImportCoordinator {
    private let library: DemoLibrary

    init(library: DemoLibrary) {
        self.library = library
    }

    func importPayload(_ payload: ImportPayload, progress: ImportProgressHandler?) async throws -> ImportRecord {
        guard case let .file(file) = payload else { throw CasebaseError.storageFailed("demo only imports files") }
        let draft = file.sourceKindHint == .image ? DemoContent.screenshotResult : DemoContent.reportResult

        progress?(ImportProgressUpdate(phase: .preparing))
        await pause(0.7)
        var thought = ""
        for sentence in draft.thoughts {
            for character in sentence {
                thought.append(character)
                progress?(ImportProgressUpdate(phase: .recognizing, thoughtText: thought))
                await pause(0.022)
            }
            thought.append(" ")
            await pause(0.25)
        }
        progress?(ImportProgressUpdate(phase: .storing))
        await pause(0.6)

        let assetPath = try library.storeAsset(from: file.fileURL, folder: draft.folder, name: file.suggestedFileName ?? file.fileURL.lastPathComponent)
        let record = ImportRecord(
            assetPath: assetPath,
            assetHash: UUID().uuidString,
            fileName: file.suggestedFileName ?? file.fileURL.lastPathComponent,
            mimeType: file.mimeType,
            sourceKind: file.sourceKindHint ?? .pdf,
            contentType: draft.contentType,
            scene: draft.scene,
            purpose: draft.purpose,
            title: draft.title,
            shortSummary: draft.summary,
            usefulSnippets: draft.snippets,
            tags: draft.tags,
            searchText: draft.summary,
            parseStatus: .ready
        )
        library.replace(record)
        return record
    }

    func reanalyzeRecord(id: UUID, clarificationAnswers _: [ClarificationAnswer], skippedQuestionTitles _: [String], progress _: ImportProgressHandler?) async throws -> ImportRecord {
        guard let record = library.record(id) else { throw CasebaseError.recordNotFound(id) }
        return record
    }

    func finalizeRecordWithoutClarification(id: UUID, skippedQuestionTitles _: [String], progress _: ImportProgressHandler?) async throws -> ImportRecord {
        guard let record = library.record(id) else { throw CasebaseError.recordNotFound(id) }
        return record
    }
}

@MainActor
final class DemoAnswerService: AnswerService {
    private let library: DemoLibrary

    init(library: DemoLibrary) {
        self.library = library
    }

    func answer(
        question _: String,
        scope _: AnswerQueryScope,
        limit _: Int,
        streamHandler: AnswerStreamHandler?,
        thoughtHandler: AIThoughtHandler?
    ) async throws -> AnswerResult {
        var thought = ""
        for character in DemoContent.answerThought {
            thought.append(character)
            thoughtHandler?(thought)
            await pause(0.03)
        }
        await pause(0.5)

        let answer = DemoContent.answerText
        var visible = ""
        for character in answer {
            visible.append(character)
            streamHandler?(visible)
            await pause(CasebasePromptCatalog.language == .simplifiedChinese ? 0.045 : 0.02)
        }

        let cited = DemoContent.answerCitationTitles.compactMap { title in library.records.first { $0.title == title } }
        let citations = cited.map { record in
            AnswerCitation(
                id: record.id,
                sourceKind: record.sourceKind,
                title: record.title,
                shortSummary: record.shortSummary,
                sourceTags: record.tags,
                evidenceExcerpt: record.usefulSnippets.first,
                previewAssetPath: record.sourceKind == .image ? record.assetPath : nil,
                openTarget: record.assetPath
            )
        }
        return AnswerResult(answerText: answer, citedRecordIDs: cited.map(\.id), citations: citations)
    }
}

@MainActor
final class DemoLibraryService: LibraryService {
    private let library: DemoLibrary
    var rootDirectory: URL { library.root }

    init(library: DemoLibrary) {
        self.library = library
    }

    func recentRecords(limit: Int) async throws -> [ImportRecord] {
        Array(library.records.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func deleteRecord(id _: UUID) async throws {}
    func revealInFinder(record _: ImportRecord) async throws {}
    func open(record _: ImportRecord) async throws {}
}

@MainActor
final class DemoTodoService: TodoService {
    private let library: DemoLibrary

    init(library: DemoLibrary) {
        self.library = library
    }

    func listTodos(filters: TodoFilters, limit: Int, offset _: Int) async throws -> TodoPage {
        let items = library.todos
            .filter { filters.isCompleted == nil || $0.isCompleted == filters.isCompleted }
            .filter { filters.quadrant == nil || $0.quadrant == filters.quadrant }
            .sorted { $0.createdAt > $1.createdAt }
        return TodoPage(items: Array(items.prefix(limit)), limit: limit, offset: 0, hasMore: false)
    }

    func fetchTodo(id: UUID) async throws -> TodoItem? {
        library.todos.first { $0.id == id }
    }

    func saveTodo(_ todo: TodoItem) async throws {
        library.todos.removeAll { $0.id == todo.id }
        library.todos.append(todo)
    }

    func deleteTodo(id: UUID) async throws {
        library.todos.removeAll { $0.id == id }
    }

    func acceptMeetingActionItem(recordID: UUID, candidateID: UUID) async throws -> TodoItem {
        guard var record = library.record(recordID) else { throw CasebaseError.recordNotFound(recordID) }
        var items = MeetingRecordMetadata.actionItems(in: record)
        guard let index = items.firstIndex(where: { $0.id == candidateID }) else { throw CasebaseError.recordNotFound(candidateID) }
        await pause(0.35)
        items[index].status = .accepted
        try MeetingRecordMetadata.setActionItems(items, in: &record)
        library.replace(record)

        let item = items[index]
        let todo = TodoItem(
            title: item.title,
            detail: item.reason,
            dueAt: item.dueAt,
            quadrant: item.suggestedQuadrant,
            sourceReferences: [TodoSourceReference(recordID: record.id, title: record.title, sourceKind: record.sourceKind, evidence: item.evidence)],
            sourceReason: item.reason,
            origin: .meeting
        )
        library.todos.append(todo)
        return todo
    }

    func dismissMeetingActionItem(recordID _: UUID, candidateID _: UUID) async throws {}

    func deferStaleTodo(id: UUID, days _: Int) async throws -> TodoItem {
        guard let todo = library.todos.first(where: { $0.id == id }) else { throw CasebaseError.recordNotFound(id) }
        return todo
    }

    func breakDownStaleTodo(id _: UUID) async throws -> [TodoItem] { [] }
}

final class DemoAudioTranscriptService: AudioTranscriptService {
    func linkedTranscript(forAudioRecordID _: UUID) async throws -> ImportRecord? { nil }
    func sourceAudio(forTranscriptRecordID _: UUID) async throws -> ImportRecord? { nil }
    func transcribeAudioRecord(id: UUID, progress _: ImportProgressHandler?) async throws -> ImportRecord {
        throw CasebaseError.recordNotFound(id)
    }
}
