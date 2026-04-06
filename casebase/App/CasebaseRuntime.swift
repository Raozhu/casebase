import Foundation

struct CasebaseRuntime {
    let configuration: CasebaseConfiguration
    let knowledgeStore: KnowledgeStore
    let libraryService: LibraryService
    let importCoordinator: ImportCoordinator
    let answerService: AnswerService
    let dataResetService: DataResetService

    static func bootstrap() throws -> CasebaseRuntime {
        let configuration = try CasebaseConfiguration.load()
        let aiClient = GeminiAIClient(configuration: configuration)
        let extractor = CompositeExtractor(configuration: configuration)
        let assetVault = AssetVault(configuration: configuration.storage)
        let knowledgeStore = try LocalKnowledgeStore(configuration: configuration.storage)
        let libraryService = CasebaseLibraryService(
            configuration: configuration.storage,
            knowledgeStore: knowledgeStore
        )
        let importCoordinator = CasebaseImportCoordinator(
            extractor: extractor,
            knowledgeStore: knowledgeStore,
            aiClient: aiClient,
            assetVault: assetVault
        )
        let answerService = KnowledgeBackedAnswerService(
            knowledgeStore: knowledgeStore,
            aiClient: aiClient,
            configuration: configuration
        )
        let dataResetService = CasebaseDataResetService(
            knowledgeStore: knowledgeStore,
            assetVault: assetVault
        )

        return CasebaseRuntime(
            configuration: configuration,
            knowledgeStore: knowledgeStore,
            libraryService: libraryService,
            importCoordinator: importCoordinator,
            answerService: answerService,
            dataResetService: dataResetService
        )
    }
}
