import Foundation

actor CasebaseDataResetService: DataResetService {
    private let knowledgeStore: LocalKnowledgeStore
    private let assetVault: AssetVault
    private let visibleShortcutService: CasebaseVisibleShortcutService?
    private let fileManager: FileManager

    init(
        knowledgeStore: LocalKnowledgeStore,
        assetVault: AssetVault,
        visibleShortcutService: CasebaseVisibleShortcutService? = nil,
        fileManager: FileManager = .default
    ) {
        self.knowledgeStore = knowledgeStore
        self.assetVault = assetVault
        self.visibleShortcutService = visibleShortcutService
        self.fileManager = fileManager
    }

    func clearAllStoredData() async throws {
        try await knowledgeStore.deleteAllRecords()
        try await assetVault.deleteAllStoredAssets()
        try await visibleShortcutService?.removeAllShortcuts()
        try TemporaryPreviewWriter.clearAllCachedPreviews(fileManager: fileManager)
    }
}
