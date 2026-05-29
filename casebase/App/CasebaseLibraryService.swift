import AppKit
import Foundation

final class CasebaseLibraryService: LibraryService {
    let rootDirectory: URL

    private let assetsDirectory: URL
    private let knowledgeStore: LocalKnowledgeStore
    private let visibleShortcutService: CasebaseVisibleShortcutService?
    private let fileManager: FileManager

    init(
        configuration: StorageConfiguration,
        knowledgeStore: LocalKnowledgeStore,
        visibleShortcutService: CasebaseVisibleShortcutService? = nil,
        fileManager: FileManager = .default
    ) {
        rootDirectory = configuration.rootDirectory
        assetsDirectory = configuration.assetsDirectory
        self.knowledgeStore = knowledgeStore
        self.visibleShortcutService = visibleShortcutService
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
            try removeEmptyPurposeFolderIfNeeded(for: assetURL)
        }
        await removeVisibleShortcut(for: record, reason: "delete-record")

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

    private func removeEmptyPurposeFolderIfNeeded(for assetURL: URL) throws {
        let parentURL = assetURL.deletingLastPathComponent()
        guard parentURL.deletingLastPathComponent().path == assetsDirectory.path else {
            return
        }

        let remainingContents = try fileManager.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard remainingContents.isEmpty else {
            return
        }

        try fileManager.removeItem(at: parentURL)
    }

    private func removeVisibleShortcut(for record: ImportRecord, reason: String) async {
        guard let visibleShortcutService else { return }

        do {
            try await visibleShortcutService.removeShortcut(for: record)
            CasebaseDebugLogger.log(
                "visible shortcut removed reason=\(reason) recordID=\(record.id.uuidString)"
            )
        } catch {
            CasebaseDebugLogger.log(
                "visible shortcut remove failed reason=\(reason) recordID=\(record.id.uuidString) error=\(String(describing: error))"
            )
        }
    }
}
