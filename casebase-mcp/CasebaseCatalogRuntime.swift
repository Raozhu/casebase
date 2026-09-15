import Foundation

struct CasebaseCatalogRuntime {
    let storage: StorageConfiguration
    let knowledgeStore: LocalKnowledgeStore

    static func bootstrap(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> CasebaseCatalogRuntime {
        let storage = StorageConfiguration.load(
            environment: environment,
            fileManager: fileManager
        )
        let knowledgeStore = try LocalKnowledgeStore(
            configuration: storage,
            fileManager: fileManager
        )
        return CasebaseCatalogRuntime(storage: storage, knowledgeStore: knowledgeStore)
    }

    func listRecords(
        limit: Int,
        offset: Int,
        filters: RecordCatalogFilters
    ) async throws -> CatalogPagePayload {
        let page = try await knowledgeStore.listRecords(
            limit: limit,
            offset: offset,
            filters: filters
        )
        return CatalogPagePayload(
            items: page.items.map(summaryPayload(for:)),
            limit: page.limit,
            offset: page.offset,
            hasMore: page.hasMore
        )
    }

    func searchRecords(
        query: String,
        limit: Int,
        offset: Int,
        filters: RecordCatalogFilters
    ) async throws -> CatalogPagePayload {
        let page = try await knowledgeStore.searchRecords(
            query: query,
            limit: limit,
            offset: offset,
            filters: filters
        )
        return CatalogPagePayload(
            items: page.items.map(summaryPayload(for:)),
            limit: page.limit,
            offset: page.offset,
            hasMore: page.hasMore
        )
    }

    func getRecord(id: UUID) async throws -> CatalogRecordDetailPayload {
        guard let record = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }
        return detailPayload(for: record)
    }

    func listTodos(
        filters: TodoFilters,
        limit: Int,
        offset: Int
    ) async throws -> TodoCatalogPagePayload {
        let page = try await knowledgeStore.listTodos(
            filters: filters,
            limit: limit,
            offset: offset
        )
        return TodoCatalogPagePayload(
            items: page.items.map(todoPayload(for:)),
            limit: page.limit,
            offset: page.offset,
            hasMore: page.hasMore
        )
    }

    func getTodo(id: UUID) async throws -> TodoCatalogItemPayload {
        guard let todo = try await knowledgeStore.fetchTodo(id: id) else {
            throw CasebaseError.storageFailed("Could not find todo for id \(id.uuidString).")
        }
        return todoPayload(for: todo)
    }

    func createTodo(
        title: String,
        detail: String,
        dueAt: Date?,
        quadrant: TodoQuadrant,
        sourceRecordIDs: [UUID],
        sourceReason: String
    ) async throws -> TodoCatalogItemPayload {
        let now = Date()
        let todo = TodoItem(
            title: title,
            detail: detail,
            dueAt: dueAt,
            quadrant: quadrant,
            createdAt: now,
            updatedAt: now,
            sourceReferences: try await sourceReferences(for: sourceRecordIDs),
            sourceReason: sourceReason,
            origin: .mcp,
            lastProgressAt: now
        )
        try await knowledgeStore.saveTodo(todo)
        return todoPayload(for: todo)
    }

    func updateTodo(
        id: UUID,
        title: String?,
        detail: String?,
        dueAt: Date?,
        dueAtProvided: Bool,
        quadrant: TodoQuadrant?,
        completed: Bool?,
        executionResult: String?,
        sourceRecordIDs: [UUID]?,
        sourceReason: String?
    ) async throws -> TodoCatalogItemPayload {
        guard let existing = try await knowledgeStore.fetchTodo(id: id) else {
            throw CasebaseError.storageFailed("Could not find todo for id \(id.uuidString).")
        }
        let now = Date()
        let resolvedCompleted = completed ?? existing.isCompleted
        let updated = TodoItem(
            id: existing.id,
            title: title ?? existing.title,
            detail: detail ?? existing.detail,
            dueAt: dueAtProvided ? dueAt : existing.dueAt,
            quadrant: quadrant ?? existing.quadrant,
            isCompleted: resolvedCompleted,
            createdAt: existing.createdAt,
            updatedAt: now,
            completedAt: resolvedCompleted ? (existing.completedAt ?? now) : nil,
            sourceReferences: sourceRecordIDs == nil
                ? existing.sourceReferences
                : try await sourceReferences(for: sourceRecordIDs ?? []),
            sourceReason: sourceReason ?? existing.sourceReason,
            executionResult: executionResult ?? existing.executionResult,
            origin: existing.origin,
            lastProgressAt: now,
            deferredUntil: nil,
            parentTodoID: existing.parentTodoID
        )
        try await knowledgeStore.saveTodo(updated)
        return todoPayload(for: updated)
    }

    private func sourceReferences(for ids: [UUID]) async throws -> [TodoSourceReference] {
        guard !ids.isEmpty else { return [] }
        let uniqueIDs = Array(Set(ids))
        let records = try await knowledgeStore.fetchRecords(ids: uniqueIDs)
        guard records.count == uniqueIDs.count else {
            let foundIDs = Set(records.map(\.id))
            let missing = uniqueIDs.filter { !foundIDs.contains($0) }.map(\.uuidString).joined(separator: ", ")
            throw CasebaseError.storageFailed("Source records not found: \(missing)")
        }
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return uniqueIDs.compactMap { id in
            guard let record = recordsByID[id] else { return nil }
            return TodoSourceReference(recordID: id, title: record.title, sourceKind: record.sourceKind)
        }
    }

    private func summaryPayload(for record: ImportRecord) -> CatalogRecordSummaryPayload {
        CatalogRecordSummaryPayload(
            id: record.id,
            title: record.title,
            shortSummary: record.shortSummary,
            tags: record.tags,
            purpose: record.purpose,
            scene: record.scene,
            contentType: record.contentType,
            sourceKind: record.sourceKind,
            mimeType: record.mimeType,
            fileName: record.fileName,
            localFilePath: storage.rootDirectory
                .appendingPathComponent(record.assetPath, isDirectory: false)
                .path,
            relativeAssetPath: record.assetPath,
            updatedAt: record.updatedAt,
            needsReview: record.needsReview,
            parseStatus: record.parseStatus
        )
    }

    private func detailPayload(for record: ImportRecord) -> CatalogRecordDetailPayload {
        let summary = summaryPayload(for: record)
        return CatalogRecordDetailPayload(
            id: summary.id,
            title: summary.title,
            shortSummary: summary.shortSummary,
            tags: summary.tags,
            purpose: summary.purpose,
            scene: summary.scene,
            contentType: summary.contentType,
            sourceKind: summary.sourceKind,
            mimeType: summary.mimeType,
            fileName: summary.fileName,
            localFilePath: summary.localFilePath,
            relativeAssetPath: summary.relativeAssetPath,
            updatedAt: summary.updatedAt,
            needsReview: summary.needsReview,
            parseStatus: summary.parseStatus,
            createdAt: record.createdAt,
            usefulSnippets: record.usefulSnippets,
            structuredData: record.structuredData,
            clarificationRequest: record.clarificationRequest,
            clarificationRoundCount: record.clarificationRoundCount,
            importCount: record.importCount
        )
    }

    private func todoPayload(for todo: TodoItem) -> TodoCatalogItemPayload {
        TodoCatalogItemPayload(
            id: todo.id,
            title: todo.title,
            detail: todo.detail,
            dueAt: todo.dueAt,
            quadrant: todo.quadrant,
            quadrantNumber: todo.quadrant.sortRank,
            isCompleted: todo.isCompleted,
            createdAt: todo.createdAt,
            updatedAt: todo.updatedAt,
            completedAt: todo.completedAt,
            sourceReferences: todo.sourceReferences,
            sourceReason: todo.sourceReason,
            executionResult: todo.executionResult,
            origin: todo.origin,
            lastProgressAt: todo.lastProgressAt,
            deferredUntil: todo.deferredUntil,
            parentTodoID: todo.parentTodoID,
            isStale: todo.isStale()
        )
    }
}

struct CatalogPagePayload: Encodable {
    let items: [CatalogRecordSummaryPayload]
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

struct CatalogRecordSummaryPayload: Encodable {
    let id: UUID
    let title: String
    let shortSummary: String
    let tags: [String]
    let purpose: String
    let scene: String
    let contentType: String
    let sourceKind: ImportSourceKind
    let mimeType: String?
    let fileName: String
    let localFilePath: String
    let relativeAssetPath: String
    let updatedAt: Date
    let needsReview: Bool
    let parseStatus: RecordParseStatus
}

struct CatalogRecordDetailPayload: Encodable {
    let id: UUID
    let title: String
    let shortSummary: String
    let tags: [String]
    let purpose: String
    let scene: String
    let contentType: String
    let sourceKind: ImportSourceKind
    let mimeType: String?
    let fileName: String
    let localFilePath: String
    let relativeAssetPath: String
    let updatedAt: Date
    let needsReview: Bool
    let parseStatus: RecordParseStatus
    let createdAt: Date
    let usefulSnippets: [String]
    let structuredData: [String: StructuredFieldValue]
    let clarificationRequest: ClarificationRequest?
    let clarificationRoundCount: Int
    let importCount: Int
}

struct TodoCatalogPagePayload: Encodable {
    let items: [TodoCatalogItemPayload]
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

struct TodoCatalogItemPayload: Encodable {
    let id: UUID
    let title: String
    let detail: String
    let dueAt: Date?
    let quadrant: TodoQuadrant
    let quadrantNumber: Int
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let sourceReferences: [TodoSourceReference]
    let sourceReason: String
    let executionResult: String
    let origin: TodoOrigin
    let lastProgressAt: Date
    let deferredUntil: Date?
    let parentTodoID: UUID?
    let isStale: Bool
}
