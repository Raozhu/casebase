import AppKit
import Foundation

final class CasebaseLibraryService: LibraryService {
    let rootDirectory: URL

    private let knowledgeStore: LocalKnowledgeStore
    private let fileManager: FileManager

    init(
        configuration: StorageConfiguration,
        knowledgeStore: LocalKnowledgeStore,
        fileManager: FileManager = .default
    ) {
        rootDirectory = configuration.rootDirectory
        self.knowledgeStore = knowledgeStore
        self.fileManager = fileManager
    }

    func recentRecords(limit: Int) async throws -> [ImportRecord] {
        try await knowledgeStore.recentRecords(limit: limit)
    }

    func deleteRecord(id: UUID) async throws {
        guard let record = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }

        try await knowledgeStore.deleteRecord(id: id)

        let assetURL = resolvedAssetURL(for: record)
        if fileManager.fileExists(atPath: assetURL.path) {
            try fileManager.removeItem(at: assetURL)
        }

        NotificationCenter.default.post(
            name: .casebaseRecordDeleted,
            object: nil,
            userInfo: ["recordID": id.uuidString]
        )
    }

    func revealInFinder(record: ImportRecord) async throws {
        let assetURL = resolvedAssetURL(for: record)
        guard fileManager.fileExists(atPath: assetURL.path) else {
            throw CasebaseError.recordNotFound(record.id)
        }
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([assetURL])
        }
    }

    func open(record: ImportRecord) async throws {
        let assetURL = resolvedAssetURL(for: record)
        guard fileManager.fileExists(atPath: assetURL.path) else {
            throw CasebaseError.recordNotFound(record.id)
        }
        let didOpen = await MainActor.run {
            NSWorkspace.shared.open(assetURL)
        }
        guard didOpen else {
            throw CasebaseError.storageFailed(assetURL.lastPathComponent)
        }
    }

    private func resolvedAssetURL(for record: ImportRecord) -> URL {
        rootDirectory.appendingPathComponent(record.assetPath, isDirectory: false)
    }
}
