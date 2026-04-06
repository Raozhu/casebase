import Foundation

actor CasebaseDataResetService: DataResetService {
    private let knowledgeStore: LocalKnowledgeStore
    private let assetVault: AssetVault
    private let fileManager: FileManager

    init(
        knowledgeStore: LocalKnowledgeStore,
        assetVault: AssetVault,
        fileManager: FileManager = .default
    ) {
        self.knowledgeStore = knowledgeStore
        self.assetVault = assetVault
        self.fileManager = fileManager
    }

    func clearAllStoredData() async throws {
        try await knowledgeStore.deleteAllRecords()
        try await assetVault.deleteAllStoredAssets()
        try TemporaryPreviewWriter.clearAllCachedPreviews(fileManager: fileManager)
    }
}
