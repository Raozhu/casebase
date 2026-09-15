import Foundation

final class CasebaseTodoService: TodoService {
    private let knowledgeStore: LocalKnowledgeStore
    private let breakdownProvider: TodoBreakdownProviding?

    init(knowledgeStore: LocalKnowledgeStore, breakdownProvider: TodoBreakdownProviding? = nil) {
        self.knowledgeStore = knowledgeStore
        self.breakdownProvider = breakdownProvider
    }

    func listTodos(
        filters: TodoFilters,
        limit: Int,
        offset: Int
    ) async throws -> TodoPage {
        try await knowledgeStore.listTodos(
            filters: filters,
            limit: limit,
            offset: offset
        )
    }

    func fetchTodo(id: UUID) async throws -> TodoItem? {
        try await knowledgeStore.fetchTodo(id: id)
    }

    func saveTodo(_ todo: TodoItem) async throws {
        try await knowledgeStore.saveTodo(todo)
    }

    func deleteTodo(id: UUID) async throws {
        try await knowledgeStore.deleteTodo(id: id)
    }

    func acceptMeetingActionItem(recordID: UUID, candidateID: UUID) async throws -> TodoItem {
        guard var record = try await knowledgeStore.fetchRecord(id: recordID) else {
            throw CasebaseError.recordNotFound(recordID)
        }
        var candidates = MeetingRecordMetadata.actionItems(in: record)
        guard let index = candidates.firstIndex(where: { $0.id == candidateID && $0.status == .pending }) else {
            throw CasebaseError.storageFailed("Could not find pending meeting action item.")
        }

        let candidate = candidates[index]
        let sourceRecords = try await relatedSourceRecords(for: record)
        let references = sourceRecords.map { source in
            TodoSourceReference(
                recordID: source.id,
                title: source.title,
                sourceKind: source.sourceKind,
                evidence: candidate.evidence
            )
        }
        let now = Date()
        let ownerDetail = candidate.owner.isEmpty ? "" : localized(chinese: "负责人：\(candidate.owner)", english: "Owner: \(candidate.owner)")
        let dueDetail = candidate.dueText.isEmpty ? "" : localized(chinese: "会议时间要求：\(candidate.dueText)", english: "Meeting due note: \(candidate.dueText)")
        let todo = TodoItem(
            title: candidate.title,
            detail: [ownerDetail, dueDetail].filter { !$0.isEmpty }.joined(separator: "\n"),
            dueAt: candidate.dueAt,
            quadrant: candidate.suggestedQuadrant,
            createdAt: now,
            updatedAt: now,
            sourceReferences: references,
            sourceReason: candidate.reason,
            origin: .meeting,
            lastProgressAt: now
        )
        try await knowledgeStore.saveTodo(todo)

        candidates[index].status = .accepted
        try MeetingRecordMetadata.setActionItems(candidates, in: &record)
        record.updatedAt = now
        try await knowledgeStore.update(record)
        NotificationCenter.default.post(name: .casebaseRecordsChanged, object: nil)
        return todo
    }

    func dismissMeetingActionItem(recordID: UUID, candidateID: UUID) async throws {
        guard var record = try await knowledgeStore.fetchRecord(id: recordID) else {
            throw CasebaseError.recordNotFound(recordID)
        }
        var candidates = MeetingRecordMetadata.actionItems(in: record)
        guard let index = candidates.firstIndex(where: { $0.id == candidateID && $0.status == .pending }) else {
            return
        }
        candidates[index].status = .dismissed
        try MeetingRecordMetadata.setActionItems(candidates, in: &record)
        record.updatedAt = Date()
        try await knowledgeStore.update(record)
        NotificationCenter.default.post(name: .casebaseRecordsChanged, object: nil)
    }

    func deferStaleTodo(id: UUID, days: Int) async throws -> TodoItem {
        guard let todo = try await knowledgeStore.fetchTodo(id: id) else {
            throw CasebaseError.storageFailed("Could not find todo for id \(id.uuidString).")
        }
        let now = Date()
        let deferredUntil = Calendar.current.date(byAdding: .day, value: max(1, days), to: now)
            ?? now.addingTimeInterval(Double(max(1, days)) * 86_400)
        let updated = copy(
            todo,
            dueAt: todo.dueAt.map { max($0, deferredUntil) } ?? deferredUntil,
            updatedAt: now,
            lastProgressAt: now,
            deferredUntil: deferredUntil
        )
        try await knowledgeStore.saveTodo(updated)
        return updated
    }

    func breakDownStaleTodo(id: UUID) async throws -> [TodoItem] {
        guard let breakdownProvider else {
            throw CasebaseError.missingConfiguration("Todo breakdown provider")
        }
        guard let todo = try await knowledgeStore.fetchTodo(id: id) else {
            throw CasebaseError.storageFailed("Could not find todo for id \(id.uuidString).")
        }
        let records = try await knowledgeStore.fetchRecords(ids: todo.sourceReferences.map(\.recordID))
        let context = records.map { "\($0.title)：\($0.shortSummary)" }.joined(separator: "\n")
        let steps = try await breakdownProvider.breakDown(todo: todo, sourceContext: context)
        guard !steps.isEmpty else { throw CasebaseError.emptyResponse }

        let now = Date()
        let children = steps.map { step in
            TodoItem(
                title: step,
                detail: localized(chinese: "由待办「\(todo.title)」重新拆解", english: "Broken down from \"\(todo.title)\""),
                dueAt: todo.dueAt,
                quadrant: todo.quadrant,
                createdAt: now,
                updatedAt: now,
                sourceReferences: todo.sourceReferences,
                sourceReason: todo.sourceReason,
                origin: .breakdown,
                lastProgressAt: now,
                parentTodoID: todo.id
            )
        }
        for child in children { try await knowledgeStore.saveTodo(child) }
        let completedOriginal = copy(
            todo,
            isCompleted: true,
            updatedAt: now,
            completedAt: now,
            executionResult: localized(chinese: "已重新拆解为 \(children.count) 个下一步", english: "Broken down into \(children.count) next steps"),
            lastProgressAt: now
        )
        try await knowledgeStore.saveTodo(completedOriginal)
        return children
    }

    private func relatedSourceRecords(for record: ImportRecord) async throws -> [ImportRecord] {
        var ids = [record.id]
        if let audioID = MeetingRecordMetadata.sourceAudioRecordID(in: record) { ids.append(audioID) }
        if let transcriptID = MeetingRecordMetadata.linkedTranscriptRecordID(in: record) { ids.append(transcriptID) }
        return try await knowledgeStore.fetchRecords(ids: Array(Set(ids)))
    }

    private func copy(
        _ todo: TodoItem,
        dueAt: Date? = nil,
        isCompleted: Bool? = nil,
        updatedAt: Date,
        completedAt: Date? = nil,
        executionResult: String? = nil,
        lastProgressAt: Date,
        deferredUntil: Date? = nil
    ) -> TodoItem {
        TodoItem(
            id: todo.id,
            title: todo.title,
            detail: todo.detail,
            dueAt: dueAt ?? todo.dueAt,
            quadrant: todo.quadrant,
            isCompleted: isCompleted ?? todo.isCompleted,
            createdAt: todo.createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt ?? todo.completedAt,
            sourceReferences: todo.sourceReferences,
            sourceReason: todo.sourceReason,
            executionResult: executionResult ?? todo.executionResult,
            origin: todo.origin,
            lastProgressAt: lastProgressAt,
            deferredUntil: deferredUntil,
            parentTodoID: todo.parentTodoID
        )
    }

    private func localized(chinese: String, english: String) -> String {
        CasebasePromptCatalog.language == .simplifiedChinese ? chinese : english
    }
}
