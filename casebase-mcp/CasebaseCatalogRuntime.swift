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
