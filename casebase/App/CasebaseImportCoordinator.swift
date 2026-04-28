import Foundation

actor CasebaseImportCoordinator: ImportCoordinator, AssetOrganizationService {
    private struct AnalysisContext {
        let result: AnalysisResult
        let parseStatus: RecordParseStatus
        let failureDescription: String?
    }

    private struct PurposeFolderContext {
        let purpose: String
        let title: String
        let scene: String
        let tags: [String]
        let searchText: String
    }

    private struct PurposeFolderSelection {
        let folderName: String
        let reusedExisting: Bool
        let reason: String
    }

    private struct PurposeFolderBucket {
        let folderName: String
        let weightedKeywords: [String: Double]
        let baseScore: Double
    }

    private let userSupplementMetadataKey = CasebasePromptCatalog.ai.userSupplementMetadataKey
    private let previousAnalysisMetadataKey = "__casebase_previousAnalysis"
    private let clarificationHistoryMetadataKey = "__casebase_clarificationHistory"
    private let skippedClarificationQuestionsMetadataKey = "__casebase_skippedClarificationQuestions"
    private let maxClarificationRounds = 3
    private let legacyAssetOrganizationLimit = 10_000
    private var purposeFolderBuckets: [PurposeFolderBucket] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return [
                PurposeFolderBucket(
                    folderName: "待处理",
                    weightedKeywords: [
                        "待处理": 12,
                        "待办": 12,
                        "稍后": 9,
                        "后续": 7,
                        "知识库": 8,
                        "链接": 7,
                        "归档失败": 12,
                        "失效": 10,
                        "受限": 10,
                        "人工介入": 10,
                        "补充": 6,
                        "飞书": 4
                    ],
                    baseScore: 0.2
                ),
                PurposeFolderBucket(
                    folderName: "组织管理",
                    weightedKeywords: [
                        "员工": 10,
                        "公司": 7,
                        "制度": 10,
                        "流程": 9,
                        "规范": 9,
                        "守则": 12,
                        "手册": 10,
                        "指南": 10,
                        "交接": 12,
                        "权限": 7,
                        "账号": 7,
                        "考勤": 9,
                        "报销": 9,
                        "行政": 8,
                        "人事": 8,
                        "管理": 5
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "课程资料",
                    weightedKeywords: [
                        "课程": 12,
                        "训练": 11,
                        "练习": 8,
                        "康复": 8,
                        "动作": 6,
                        "体态": 7,
                        "瑜伽": 7,
                        "盆底肌": 6,
                        "产后修复": 7,
                        "健身档案": 10
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "产品规划",
                    weightedKeywords: [
                        "产品": 7,
                        "原型": 12,
                        "设计": 9,
                        "功能": 7,
                        "项目": 6,
                        "规划": 10,
                        "方案": 8,
                        "战略": 9,
                        "策略": 9,
                        "okr": 10,
                        "mvp": 10,
                        "诊断": 7,
                        "体验": 6,
                        "服务逻辑": 10,
                        "优先级": 6
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "运营增长",
                    weightedKeywords: [
                        "运营": 11,
                        "增长": 11,
                        "转化": 12,
                        "留存": 11,
                        "复盘": 10,
                        "经营": 10,
                        "营收": 9,
                        "漏斗": 9,
                        "私域": 11,
                        "数据": 6,
                        "指标": 6,
                        "投放": 7,
                        "gmv": 9,
                        "roi": 9,
                        "效率": 5,
                        "业绩": 6,
                        "商业模式": 7,
                        "业务": 5
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "行业研究",
                    weightedKeywords: [
                        "行业": 12,
                        "市场": 11,
                        "竞品": 11,
                        "竞对": 11,
                        "调研": 12,
                        "洞察": 12,
                        "研究": 10,
                        "画像": 9,
                        "人群": 8,
                        "年龄": 7,
                        "需求": 7,
                        "赛道": 9,
                        "用户画像": 11,
                        "智能硬件": 8,
                        "对比": 7
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "通用资料",
                    weightedKeywords: [:],
                    baseScore: 0.01
                )
            ]
        case .english:
            return [
                PurposeFolderBucket(
                    folderName: "Backlog",
                    weightedKeywords: [
                        "todo": 12,
                        "backlog": 12,
                        "later": 9,
                        "followup": 8,
                        "link": 7,
                        "failed": 10,
                        "manual": 8
                    ],
                    baseScore: 0.2
                ),
                PurposeFolderBucket(
                    folderName: "Operations",
                    weightedKeywords: [
                        "employee": 10,
                        "company": 7,
                        "policy": 10,
                        "process": 9,
                        "guide": 10,
                        "handbook": 10,
                        "handover": 12,
                        "account": 7,
                        "admin": 8,
                        "hr": 8,
                        "management": 5
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "Training",
                    weightedKeywords: [
                        "course": 12,
                        "training": 11,
                        "exercise": 8,
                        "rehab": 8,
                        "postpartum": 7,
                        "plan": 5
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "Product Planning",
                    weightedKeywords: [
                        "product": 7,
                        "prototype": 12,
                        "design": 9,
                        "feature": 7,
                        "project": 6,
                        "planning": 10,
                        "strategy": 9,
                        "okr": 10,
                        "mvp": 10,
                        "diagnosis": 7
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "Growth Ops",
                    weightedKeywords: [
                        "operations": 11,
                        "growth": 11,
                        "conversion": 12,
                        "retention": 11,
                        "review": 10,
                        "revenue": 9,
                        "funnel": 9,
                        "metrics": 6,
                        "data": 6,
                        "roi": 9,
                        "business": 5
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "Research",
                    weightedKeywords: [
                        "industry": 12,
                        "market": 11,
                        "competitor": 11,
                        "research": 10,
                        "insight": 12,
                        "persona": 9,
                        "audience": 8,
                        "needs": 7,
                        "landscape": 9
                    ],
                    baseScore: 0.1
                ),
                PurposeFolderBucket(
                    folderName: "General",
                    weightedKeywords: [:],
                    baseScore: 0.01
                )
            ]
        }
    }
    private let extractor: Extractor
    private let knowledgeStore: KnowledgeStore
    private let aiClient: AIClient
    private let assetVault: AssetVault
    private let maximumImportFileBytes: Int64

    init(
        extractor: Extractor,
        knowledgeStore: KnowledgeStore,
        aiClient: AIClient,
        assetVault: AssetVault,
        maximumImportFileBytes: Int64
    ) {
        self.extractor = extractor
        self.knowledgeStore = knowledgeStore
        self.aiClient = aiClient
        self.assetVault = assetVault
        self.maximumImportFileBytes = maximumImportFileBytes
    }

    func importPayload(_ payload: ImportPayload, progress: ImportProgressHandler?) async throws -> ImportRecord {
        let importStartedAt = Date()
        let payloadContext = payloadLogContext(payload)
        CasebaseDebugLogger.log("import request started \(payloadContext)")

        try ensurePayloadWithinSizeLimit(payload)
        progress?(ImportProgressUpdate(
            phase: .preparing,
            detailText: CasebasePromptCatalog.errors.importStageSavingAsset
        ))
        let storedAsset = try await measureImportStage(
            "store-asset",
            context: payloadContext,
            successSummary: { [self] storedAsset in
                storedAssetLogContext(storedAsset)
            }
        ) {
            try await assetVault.store(payload)
        }

        if var existingRecord = try await knowledgeStore.findRecord(byAssetHash: storedAsset.assetHash) {
            progress?(ImportProgressUpdate(
                phase: .storing,
                detailText: CasebasePromptCatalog.errors.importStageUpdatingExistingRecord
            ))
            let organizedAsset = try await measureImportStage(
                "organize-existing-asset",
                context: storedAssetLogContext(storedAsset),
                successSummary: { [self] organizedAsset in
                    organizedAssetLogSummary(organizedAsset)
                }
            ) {
                try await organizeStoredAsset(
                    storedAsset,
                    using: purposeFolderContext(for: existingRecord),
                    embedding: existingRecord.embedding,
                    currentFolderHint: currentPurposeFolderName(from: existingRecord.assetPath)
                )
            }
            existingRecord.assetPath = organizedAsset.assetPath
            existingRecord.fileName = organizedAsset.fileName
            existingRecord.mimeType = organizedAsset.mimeType
            existingRecord.sourceKind = organizedAsset.sourceKind
            existingRecord.registerReimport()
            try await measureImportStage(
                "update-existing-record",
                context: storedAssetLogContext(organizedAsset),
                successSummary: { _ in
                    "recordID=\(existingRecord.id.uuidString)"
                }
            ) {
                try await knowledgeStore.update(existingRecord)
            }
            CasebaseDebugLogger.log(
                "import request finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: importStartedAt)) \(storedAssetLogContext(organizedAsset)) recordID=\(existingRecord.id.uuidString) reusedExisting=true"
            )
            return existingRecord
        }

        let canonicalPayload = await canonicalPayload(for: storedAsset)
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageExtractingContent
        ))
        let normalizedContent = try await measureImportStage(
            "normalize",
            context: storedAssetLogContext(storedAsset),
            successSummary: { [self] normalizedContent in
                normalizedContentLogSummary(normalizedContent)
            }
        ) {
            try await extractor.normalize(canonicalPayload)
        }
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageAnalyzingContent
        ))
        let analysisContext = try await measureImportStage(
            "analyze",
            context: storedAssetLogContext(storedAsset),
            successSummary: { [self] analysisContext in
                analysisContextLogSummary(analysisContext)
            }
        ) {
            try await analyze(
                storedAsset: storedAsset,
                content: normalizedContent,
                progress: progress
            )
        }
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: normalizedContent,
            parseStatus: analysisContext.parseStatus,
            roundCount: 0
        )
        try ensureReviewableRecordCanBeStored(
            result: analysisContext.result,
            parseStatus: analysisContext.parseStatus,
            analysisFailureDescription: analysisContext.failureDescription,
            clarificationRequest: clarificationRequest,
            roundCount: 0
        )
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageGeneratingEmbedding
        ))
        let embedding = try await measureImportStage(
            "embed",
            context: storedAssetLogContext(storedAsset),
            successSummary: { embedding in
                "dimensions=\(embedding.count)"
            }
        ) {
            try await aiClient.embed(text: analysisContext.result.searchText)
        }
        let organizedAsset = try await measureImportStage(
            "organize-asset",
            context: storedAssetLogContext(storedAsset),
            successSummary: { [self] organizedAsset in
                organizedAssetLogSummary(organizedAsset)
            }
        ) {
            try await organizeStoredAsset(
                storedAsset,
                using: purposeFolderContext(for: analysisContext.result),
                embedding: embedding
            )
        }

        let record = ImportRecord(
            assetPath: organizedAsset.assetPath,
            assetHash: organizedAsset.assetHash,
            fileName: organizedAsset.fileName,
            mimeType: organizedAsset.mimeType,
            sourceKind: organizedAsset.sourceKind,
            contentType: analysisContext.result.contentType,
            scene: analysisContext.result.scene,
            purpose: analysisContext.result.purpose,
            title: analysisContext.result.title,
            shortSummary: analysisContext.result.shortSummary,
            usefulSnippets: analysisContext.result.usefulSnippets,
            tags: analysisContext.result.tags,
            structuredData: analysisContext.result.structuredData,
            searchText: analysisContext.result.searchText,
            userSupplement: nil,
            clarificationRequest: clarificationRequest,
            clarificationHistory: [],
            clarificationRoundCount: 0,
            needsReview: clarificationRequest != nil || analysisContext.result.needsReview,
            embedding: embedding,
            parseStatus: analysisContext.parseStatus
        )

        progress?(ImportProgressUpdate(
            phase: .storing,
            detailText: CasebasePromptCatalog.errors.importStageSavingRecord
        ))
        try await measureImportStage(
            "save-record",
            context: storedAssetLogContext(organizedAsset),
            successSummary: { _ in
                "recordID=\(record.id.uuidString) parseStatus=\(analysisContext.parseStatus.rawValue)"
            }
        ) {
            try await knowledgeStore.save(record)
        }
        CasebaseDebugLogger.log(
            "import request finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: importStartedAt)) \(storedAssetLogContext(organizedAsset)) recordID=\(record.id.uuidString) reusedExisting=false"
        )
        return record
    }

    func reanalyzeRecord(
        id: UUID,
        clarificationAnswers: [ClarificationAnswer],
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord {
        let reanalysisStartedAt = Date()
        progress?(ImportProgressUpdate(
            phase: .preparing,
            detailText: CasebasePromptCatalog.errors.importStageSavingAsset
        ))
        guard var existingRecord = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }

        let storedAssetURL = await assetVault.url(for: existingRecord.assetPath)
        let storedAsset = StoredAsset(
            assetPath: existingRecord.assetPath,
            assetHash: existingRecord.assetHash,
            fileName: existingRecord.fileName,
            mimeType: existingRecord.mimeType,
            sourceKind: existingRecord.sourceKind,
            fileSize: FileMetadataReader.fileSizeBytes(for: storedAssetURL) ?? 0,
            contextMetadata: [:]
        )
        try ensureStoredAssetWithinSizeLimit(storedAsset)

        let canonicalPayload = await canonicalPayload(for: storedAsset)
        let storedAssetContext = storedAssetLogContext(storedAsset)
        CasebaseDebugLogger.log("reanalyze request started \(storedAssetContext) recordID=\(id.uuidString)")
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageExtractingContent
        ))
        let normalizedContent = try await measureImportStage(
            "reanalyze-normalize",
            context: storedAssetContext,
            successSummary: { [self] normalizedContent in
                normalizedContentLogSummary(normalizedContent)
            }
        ) {
            try await extractor.normalize(canonicalPayload)
        }
        let resolvedAnswers = clarificationAnswers.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resolvedSkippedQuestionTitles = skippedQuestionTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let hasClarificationInput = !resolvedAnswers.isEmpty || !resolvedSkippedQuestionTitles.isEmpty
        let nextRoundCount = hasClarificationInput
            ? min(existingRecord.clarificationRoundCount + 1, maxClarificationRounds)
            : existingRecord.clarificationRoundCount
        let updatedHistory = makeUpdatedClarificationHistory(
            existing: existingRecord.clarificationHistory,
            roundCount: nextRoundCount,
            answers: resolvedAnswers,
            skippedQuestionTitles: resolvedSkippedQuestionTitles
        )
        let latestSupplement = combinedSupplement(from: resolvedAnswers) ?? existingRecord.userSupplement
        let augmentedContent = applyingClarificationContext(
            record: existingRecord,
            latestSupplement: latestSupplement,
            clarificationHistory: updatedHistory,
            skippedQuestionTitles: resolvedSkippedQuestionTitles,
            to: normalizedContent
        )
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageAnalyzingContent
        ))
        let analysisContext = try await measureImportStage(
            "reanalyze-analyze",
            context: storedAssetContext,
            successSummary: { [self] analysisContext in
                analysisContextLogSummary(analysisContext)
            }
        ) {
            try await analyze(
                storedAsset: storedAsset,
                content: augmentedContent,
                progress: progress
            )
        }
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: augmentedContent,
            parseStatus: analysisContext.parseStatus,
            roundCount: nextRoundCount
        )
        try ensureReviewableRecordCanBeStored(
            result: analysisContext.result,
            parseStatus: analysisContext.parseStatus,
            analysisFailureDescription: analysisContext.failureDescription,
            clarificationRequest: clarificationRequest,
            roundCount: nextRoundCount
        )
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageGeneratingEmbedding
        ))
        let embedding = try await measureImportStage(
            "reanalyze-embed",
            context: storedAssetContext,
            successSummary: { embedding in
                "dimensions=\(embedding.count)"
            }
        ) {
            try await aiClient.embed(text: analysisContext.result.searchText)
        }
        let organizedAsset = try await measureImportStage(
            "reanalyze-organize-asset",
            context: storedAssetContext,
            successSummary: { [self] organizedAsset in
                organizedAssetLogSummary(organizedAsset)
            }
        ) {
            try await organizeStoredAsset(
                storedAsset,
                using: purposeFolderContext(for: analysisContext.result),
                embedding: embedding,
                currentFolderHint: currentPurposeFolderName(from: existingRecord.assetPath)
            )
        }

        progress?(ImportProgressUpdate(
            phase: .storing,
            detailText: CasebasePromptCatalog.errors.importStageSavingRecord
        ))
        existingRecord.assetPath = organizedAsset.assetPath
        existingRecord.fileName = organizedAsset.fileName
        existingRecord.mimeType = organizedAsset.mimeType
        existingRecord.sourceKind = organizedAsset.sourceKind
        existingRecord.contentType = analysisContext.result.contentType
        existingRecord.scene = analysisContext.result.scene
        existingRecord.purpose = analysisContext.result.purpose
        existingRecord.title = analysisContext.result.title
        existingRecord.shortSummary = analysisContext.result.shortSummary
        existingRecord.usefulSnippets = analysisContext.result.usefulSnippets
        existingRecord.tags = analysisContext.result.tags
        existingRecord.structuredData = analysisContext.result.structuredData
        existingRecord.searchText = analysisContext.result.searchText
        existingRecord.userSupplement = latestSupplement
        existingRecord.clarificationRequest = clarificationRequest
        existingRecord.clarificationHistory = updatedHistory
        existingRecord.clarificationRoundCount = nextRoundCount
        existingRecord.needsReview = clarificationRequest != nil || analysisContext.result.needsReview
        existingRecord.embedding = embedding
        existingRecord.parseStatus = analysisContext.parseStatus
        existingRecord.updatedAt = Date()

        try await measureImportStage(
            "reanalyze-save-record",
            context: storedAssetContext,
            successSummary: { _ in
                "recordID=\(existingRecord.id.uuidString) parseStatus=\(analysisContext.parseStatus.rawValue)"
            }
        ) {
            try await knowledgeStore.update(existingRecord)
        }
        CasebaseDebugLogger.log(
            "reanalyze request finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: reanalysisStartedAt)) \(storedAssetContext) recordID=\(existingRecord.id.uuidString)"
        )
        return existingRecord
    }

    func finalizeRecordWithoutClarification(
        id: UUID,
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord {
        progress?(ImportProgressUpdate(phase: .preparing))

        guard var existingRecord = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }

        let resolvedSkippedQuestionTitles = skippedQuestionTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !resolvedSkippedQuestionTitles.isEmpty {
            existingRecord.clarificationHistory = makeUpdatedClarificationHistory(
                existing: existingRecord.clarificationHistory,
                roundCount: min(existingRecord.clarificationRoundCount + 1, maxClarificationRounds),
                answers: [],
                skippedQuestionTitles: resolvedSkippedQuestionTitles
            )
            existingRecord.clarificationRoundCount = min(existingRecord.clarificationRoundCount + 1, maxClarificationRounds)
        }

        existingRecord.clarificationRequest = nil
        existingRecord.needsReview = false
        existingRecord.updatedAt = Date()

        progress?(ImportProgressUpdate(phase: .storing))
        try await knowledgeStore.update(existingRecord)
        return existingRecord
    }

    func organizeLegacyAssets() async throws -> Int {
        let migrationStartedAt = Date()
        let records = try await knowledgeStore.recentRecords(limit: legacyAssetOrganizationLimit)
        var reorganizedCount = 0
        var missingAssetCount = 0

        CasebaseDebugLogger.log("legacy asset organization started totalRecords=\(records.count)")

        for var record in records {
            let assetURL = await assetVault.url(for: record.assetPath)
            guard FileManager.default.fileExists(atPath: assetURL.path) else {
                missingAssetCount += 1
                CasebaseDebugLogger.log(
                    "legacy asset organization skipped missingAsset recordID=\(record.id.uuidString) assetPath=\(quotedLogValue(record.assetPath))"
                )
                continue
            }

            let storedAsset = StoredAsset(
                assetPath: record.assetPath,
                assetHash: record.assetHash,
                fileName: record.fileName,
                mimeType: record.mimeType,
                sourceKind: record.sourceKind,
                fileSize: FileMetadataReader.fileSizeBytes(for: assetURL) ?? 0,
                contextMetadata: [:]
            )

            let organizedAsset = try await organizeStoredAsset(
                storedAsset,
                using: purposeFolderContext(for: record),
                embedding: record.embedding,
                currentFolderHint: currentPurposeFolderName(from: record.assetPath)
            )

            guard organizedAsset.assetPath != record.assetPath else {
                continue
            }

            record.assetPath = organizedAsset.assetPath
            record.fileName = organizedAsset.fileName
            record.mimeType = organizedAsset.mimeType
            record.sourceKind = organizedAsset.sourceKind
            try await knowledgeStore.update(record)
            reorganizedCount += 1
        }

        CasebaseDebugLogger.log(
            "legacy asset organization finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: migrationStartedAt)) reorganized=\(reorganizedCount) missingAssets=\(missingAssetCount)"
        )
        return reorganizedCount
    }

    private func purposeFolderContext(for result: AnalysisResult) -> PurposeFolderContext {
        PurposeFolderContext(
            purpose: result.purpose,
            title: result.title,
            scene: result.scene,
            tags: result.tags,
            searchText: result.searchText
        )
    }

    private func purposeFolderContext(for record: ImportRecord) -> PurposeFolderContext {
        PurposeFolderContext(
            purpose: record.purpose,
            title: record.title,
            scene: record.scene,
            tags: record.tags,
            searchText: record.searchText
        )
    }

    private func organizeStoredAsset(
        _ storedAsset: StoredAsset,
        using context: PurposeFolderContext,
        embedding: [Float],
        currentFolderHint: String? = nil
    ) async throws -> StoredAsset {
        let selection = try await selectPurposeFolder(
            for: context,
            embedding: embedding,
            currentFolderHint: currentFolderHint
        )
        let sourceFolder = currentPurposeFolderName(from: storedAsset.assetPath) ?? currentFolderHint ?? "-"
        CasebaseDebugLogger.log(
            "purpose folder selected sourceFolder=\(quotedLogValue(sourceFolder)) targetFolder=\(quotedLogValue(selection.folderName)) reusedExisting=\(selection.reusedExisting) reason=\(quotedLogValue(selection.reason))"
        )

        return try await assetVault.relocate(
            storedAsset,
            intoPurposeFolder: selection.folderName,
            preferredDisplayName: preferredPhysicalFileDisplayName(for: context, fallbackFileName: storedAsset.fileName)
        )
    }

    private func selectPurposeFolder(
        for context: PurposeFolderContext,
        embedding: [Float],
        currentFolderHint: String? = nil
    ) async throws -> PurposeFolderSelection {
        let preferredLabel = derivedPurposeFolderLabel(from: context)
        _ = embedding

        if currentFolderHint == preferredLabel {
            return PurposeFolderSelection(
                folderName: preferredLabel,
                reusedExisting: true,
                reason: "already-in-canonical-bucket"
            )
        }

        let existingFolders = try await assetVault.purposeFolderNames()
        let reusedExisting = existingFolders.contains(preferredLabel)

        return PurposeFolderSelection(
            folderName: preferredLabel,
            reusedExisting: reusedExisting,
            reason: reusedExisting ? "reuse-canonical-bucket" : "create-canonical-bucket"
        )
    }

    private func currentPurposeFolderName(from assetPath: String) -> String? {
        let components = assetPath.split(separator: "/").map(String.init)
        guard components.count >= 3, components.first == "assets" else {
            return nil
        }
        return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func derivedPurposeFolderLabel(from context: PurposeFolderContext) -> String {
        let normalizedText = normalizedContextText(for: context)
        var bestBucket = purposeFolderBuckets.first ?? PurposeFolderBucket(
            folderName: CasebasePromptCatalog.language == .simplifiedChinese ? "通用资料" : "General",
            weightedKeywords: [:],
            baseScore: 0.01
        )
        var bestScore = Double.leastNonzeroMagnitude

        for bucket in purposeFolderBuckets {
            let score = purposeFolderScore(for: bucket, normalizedText: normalizedText, context: context)
            if score > bestScore {
                bestScore = score
                bestBucket = bucket
            }
        }

        return bestBucket.folderName
    }

    private func normalizedContextText(for context: PurposeFolderContext) -> String {
        normalizedSemanticText(
            [
                context.title,
                context.purpose,
                context.scene,
                context.tags.joined(separator: " "),
                context.searchText
            ]
            .joined(separator: " ")
        )
    }

    private func purposeFolderScore(
        for bucket: PurposeFolderBucket,
        normalizedText: String,
        context: PurposeFolderContext
    ) -> Double {
        var score = bucket.baseScore

        for (keyword, weight) in bucket.weightedKeywords {
            let normalizedKeyword = normalizedSemanticText(keyword)
            guard !normalizedKeyword.isEmpty else { continue }
            if normalizedText.contains(normalizedKeyword) {
                score += weight
            }
        }

        let normalizedTags = context.tags.map(normalizedSemanticText)
        if normalizedTags.contains(where: { normalizedTextHasStrongTagMatch($0, for: bucket) }) {
            score += 2.5
        }

        if normalizedSemanticText(context.title).contains(normalizedSemanticText(bucket.folderName)) {
            score += 1.2
        }

        return score
    }

    private func preferredPhysicalFileDisplayName(
        for context: PurposeFolderContext,
        fallbackFileName: String
    ) -> String {
        let title = context.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }

        let purpose = context.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if !purpose.isEmpty {
            return purpose
        }

        return URL(fileURLWithPath: fallbackFileName)
            .deletingPathExtension()
            .lastPathComponent
    }

    private func normalizedTextHasStrongTagMatch(_ normalizedTag: String, for bucket: PurposeFolderBucket) -> Bool {
        guard !normalizedTag.isEmpty else { return false }

        if normalizedTag == normalizedSemanticText(bucket.folderName) {
            return true
        }

        return bucket.weightedKeywords.keys.contains { keyword in
            let normalizedKeyword = normalizedSemanticText(keyword)
            return !normalizedKeyword.isEmpty && (normalizedTag == normalizedKeyword || normalizedTag.contains(normalizedKeyword))
        }
    }

    private func normalizedSemanticText(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(
                of: "[^\\p{Han}A-Za-z0-9]+",
                with: "",
                options: .regularExpression
            )
            .lowercased()
    }

    private func canonicalPayload(for storedAsset: StoredAsset) async -> ImportPayload {
        .file(
            FileImportPayload(
                fileURL: await assetVault.url(for: storedAsset.assetPath),
                suggestedFileName: storedAsset.fileName,
                mimeType: storedAsset.mimeType,
                sourceKindHint: storedAsset.sourceKind,
                contextMetadata: storedAsset.contextMetadata
            )
        )
    }

    private func analyze(
        storedAsset: StoredAsset,
        content: NormalizedContent,
        progress: ImportProgressHandler?
    ) async throws -> AnalysisContext {
        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: CasebasePromptCatalog.errors.importStageAnalyzingContent
        ))
        let stableLinkFallback = stableLinkFallbackAnalysis(
            storedAsset: storedAsset,
            content: content
        )
        if canUseAIAnalysis(for: content) {
            let analysisStartedAt = Date()
            CasebaseDebugLogger.log(
                "AI analysis started \(storedAssetLogContext(storedAsset)) \(normalizedContentLogSummary(content))"
            )
            do {
                let analyzed = try await aiClient.analyze(content: content) { thoughtText in
                    progress?(ImportProgressUpdate(phase: .recognizing, thoughtText: thoughtText))
                }
                CasebaseDebugLogger.log(
                    "AI analysis finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: analysisStartedAt)) \(storedAssetLogContext(storedAsset)) needsReview=\(analyzed.needsReview) clarificationQuestions=\(analyzed.clarificationRequest?.questions.count ?? 0)"
                )

                if let stableLinkFallback,
                   analyzed.needsReview,
                   analyzed.clarificationRequest == nil
                {
                    return AnalysisContext(
                        result: stableLinkFallback,
                        parseStatus: .ready,
                        failureDescription: nil
                    )
                }

                return AnalysisContext(
                    result: analyzed,
                    parseStatus: .ready,
                    failureDescription: nil
                )
            } catch {
                let failureDescription = normalizedFailureDescription(from: error)
                CasebaseDebugLogger.log(
                    "AI analysis failed elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: analysisStartedAt)) \(storedAssetLogContext(storedAsset)) error=\(sanitizedLogValue(failureDescription))"
                )

                if let stableLinkFallback {
                    return AnalysisContext(
                        result: stableLinkFallback,
                        parseStatus: .ready,
                        failureDescription: failureDescription
                    )
                }
                let fallback = makeFallbackAnalysis(storedAsset: storedAsset, content: content)
                return AnalysisContext(
                    result: fallback,
                    parseStatus: .partial,
                    failureDescription: failureDescription
                )
            }
        }

        CasebaseDebugLogger.log(
            "AI analysis skipped \(storedAssetLogContext(storedAsset)) reason=no-usable-ai-input"
        )

        if let stableLinkFallback {
            return AnalysisContext(
                result: stableLinkFallback,
                parseStatus: .ready,
                failureDescription: nil
            )
        }
        return AnalysisContext(
            result: makeFallbackAnalysis(storedAsset: storedAsset, content: content),
            parseStatus: .partial,
            failureDescription: nil
        )
    }

    private func canUseAIAnalysis(for content: NormalizedContent) -> Bool {
        let rawText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawText, !rawText.isEmpty {
            return true
        }

        if let supplement = userSupplement(in: content), !supplement.isEmpty {
            return true
        }

        if let previousAnalysis = content.fallbackMetadata[previousAnalysisMetadataKey],
           !previousAnalysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }

        return content.attachments.contains { attachment in
            attachment.kind == .imagePreview
                || attachment.kind == .pagePreview
                || (
                    attachment.kind == .originalAsset
                        && attachment.mimeType?.lowercased() == "application/pdf"
                )
        }
    }

    private func ensurePayloadWithinSizeLimit(_ payload: ImportPayload) throws {
        let payloadSize = try payloadByteCount(payload)
        guard payloadSize <= maximumImportFileBytes else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.importPayloadExceedsSizeLimit(
                    fileName: payload.displayName,
                    sizeDescription: formattedByteCount(payloadSize),
                    limitDescription: formattedByteCount(maximumImportFileBytes)
                )
            )
        }
    }

    private func ensureStoredAssetWithinSizeLimit(_ storedAsset: StoredAsset) throws {
        guard storedAsset.fileSize <= maximumImportFileBytes else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.importPayloadExceedsSizeLimit(
                    fileName: storedAsset.fileName,
                    sizeDescription: formattedByteCount(storedAsset.fileSize),
                    limitDescription: formattedByteCount(maximumImportFileBytes)
                )
            )
        }
    }

    private func payloadByteCount(_ payload: ImportPayload) throws -> Int64 {
        switch payload {
        case let .text(textPayload):
            return Int64(textPayload.text.lengthOfBytes(using: .utf8))
        case let .file(filePayload):
            if let fileSize = FileMetadataReader.fileSizeBytes(for: filePayload.fileURL) {
                return fileSize
            }
            let data = try Data(contentsOf: filePayload.fileURL, options: .mappedIfSafe)
            return Int64(data.count)
        }
    }

    private func formattedByteCount(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: byteCount)
    }

    private func makeFallbackAnalysis(
        storedAsset: StoredAsset,
        content: NormalizedContent
    ) -> AnalysisResult {
        let rawText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let supplement = userSupplement(in: content)
        let visibleMetadata = visibleFallbackMetadata(from: content)
        let title = CasebasePromptCatalog.fallback.title(
            for: storedAsset.sourceKind,
            fileName: storedAsset.fileName
        )
        let summary = CasebasePromptCatalog.fallback.summary(
            fileName: storedAsset.fileName,
            rawText: rawText,
            metadata: visibleMetadata
        )
        var snippets = CasebasePromptCatalog.fallback.snippets(
            rawText: rawText,
            metadata: visibleMetadata
        )
        let tags = CasebasePromptCatalog.fallback.tags(
            sourceKind: storedAsset.sourceKind,
            mimeType: storedAsset.mimeType,
            fileName: storedAsset.fileName,
            hasParsedText: rawText?.isEmpty == false
        )
        let contentType = CasebasePromptCatalog.fallback.contentType(for: storedAsset.sourceKind)
        let scene = CasebasePromptCatalog.fallback.scene(
            for: storedAsset.sourceKind,
            fileName: storedAsset.fileName,
            rawText: rawText
        )
        let purpose = CasebasePromptCatalog.fallback.purpose(
            for: storedAsset.sourceKind,
            fileName: storedAsset.fileName,
            rawText: rawText
        )
        var structuredData = CasebasePromptCatalog.fallback.structuredData(
            fileName: storedAsset.fileName,
            rawText: rawText,
            metadata: visibleMetadata
        )

        if let supplement, !supplement.isEmpty {
            if !snippets.contains(supplement) {
                snippets.append(supplement)
            }
            structuredData["userSupplement"] = .string(supplement)
        }

        let searchText = ([title, summary, contentType, scene, purpose] + snippets + tags)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AnalysisResult(
            contentType: contentType,
            scene: scene,
            purpose: purpose,
            title: title,
            shortSummary: summary,
            aiThoughtSummary: nil,
            usefulSnippets: snippets,
            tags: tags,
            structuredData: structuredData,
            searchText: searchText,
            clarificationRequest: nil,
            needsReview: true
        )
    }

    private func trimmedSupplement(_ supplement: String?) -> String? {
        guard let supplement else { return nil }
        let trimmed = supplement.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyingClarificationContext(
        record: ImportRecord,
        latestSupplement: String?,
        clarificationHistory: [ClarificationRound],
        skippedQuestionTitles: [String],
        to content: NormalizedContent
    ) -> NormalizedContent {
        var metadata = content.fallbackMetadata
        if let latestSupplement = trimmedSupplement(latestSupplement) {
            metadata[userSupplementMetadataKey] = latestSupplement
        }
        metadata[previousAnalysisMetadataKey] = previousAnalysisBlock(from: record)
        if !clarificationHistory.isEmpty {
            metadata[clarificationHistoryMetadataKey] = clarificationHistoryBlock(from: clarificationHistory)
        }
        if !skippedQuestionTitles.isEmpty {
            metadata[skippedClarificationQuestionsMetadataKey] = skippedQuestionsBlock(from: skippedQuestionTitles)
        }

        return NormalizedContent(
            sourceKind: content.sourceKind,
            rawText: content.rawText,
            attachments: content.attachments,
            fallbackMetadata: metadata
        )
    }

    private func userSupplement(in content: NormalizedContent) -> String? {
        content.fallbackMetadata[userSupplementMetadataKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func visibleFallbackMetadata(from content: NormalizedContent) -> [String: String] {
        content.fallbackMetadata.filter { !$0.key.hasPrefix("__casebase_") }
    }

    private func clarificationRequest(
        from result: AnalysisResult,
        storedAsset: StoredAsset,
        content: NormalizedContent,
        parseStatus: RecordParseStatus,
        roundCount: Int
    ) -> ClarificationRequest? {
        guard roundCount < maxClarificationRounds else {
            return nil
        }

        if let request = result.clarificationRequest, !request.questions.isEmpty {
            return request
        }

        guard parseStatus == .ready else {
            return nil
        }

        if let synthesized = synthesizedClarificationRequest(
            from: result,
            for: storedAsset,
            content: content,
            roundCount: roundCount
        ) {
            return synthesized
        }

        return nil
    }

    private func synthesizedClarificationRequest(
        from result: AnalysisResult,
        for storedAsset: StoredAsset,
        content: NormalizedContent,
        roundCount: Int
    ) -> ClarificationRequest? {
        guard result.needsReview,
              roundCount < maxClarificationRounds,
              storedAsset.sourceKind == .text,
              stableLinkFallbackAnalysis(storedAsset: storedAsset, content: content) == nil
        else {
            return nil
        }

        let trimmedText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedText.isEmpty else { return nil }

        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return ClarificationRequest(
                uncertaintySummary: "这段文字信息较少，暂时无法稳定判断最合适的入库方式。",
                impactExplanation: "如果不知道这段文字最重要的重点和用途，后续检索和问答会更难命中你真正想找的内容。",
                questions: [
                    ClarificationQuestion(
                        id: "q1",
                        title: "这段文字你最想保留的重点是什么？",
                        reason: "明确重点后，系统才能更稳定地整理标题、摘要和检索词。",
                        suggestedOptions: ["核心事实", "待办/约定", "参考资料"]
                    ),
                ]
            )
        case .english:
            return ClarificationRequest(
                uncertaintySummary: "This text snippet is too short to determine the best ingestion shape reliably.",
                impactExplanation: "Without knowing the main point and intended reuse, retrieval and later QA will be less reliable.",
                questions: [
                    ClarificationQuestion(
                        id: "q1",
                        title: "What is the main thing you want to preserve from this text?",
                        reason: "That lets the app build a stable title, summary, and search text.",
                        suggestedOptions: ["Key fact", "Todo / commitment", "Reference material"]
                    ),
                ]
            )
        }
    }

    private func stableLinkFallbackAnalysis(
        storedAsset: StoredAsset,
        content: NormalizedContent
    ) -> AnalysisResult? {
        guard storedAsset.sourceKind == .text,
              let rawText = content.rawText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawText.isEmpty
        else {
            return nil
        }

        let urls = detectedPublicURLs(in: rawText)
        guard !urls.isEmpty, containsOnlyURLs(in: rawText, urls: urls) else {
            return nil
        }

        let metadata = visibleFallbackMetadata(from: content)
        let title = preferredLinkTitle(from: metadata, urls: urls)
        let summary = linkSummary(title: title, urls: urls)
        let contentType = CasebasePromptCatalog.language == .simplifiedChinese ? "网页链接" : "Web link"
        let scene = CasebasePromptCatalog.language == .simplifiedChinese ? "网页资料留存与后续检索" : "Web reference storage and lookup"
        let purpose = CasebasePromptCatalog.language == .simplifiedChinese ? "保存网页入口与页面上下文，便于后续回看、搜索和引用" : "Preserve the webpage entry point and context for later lookup and reuse"
        let snippets = Array(urls.map(\.absoluteString).prefix(3))

        var structuredData: [String: StructuredFieldValue] = [
            "fileName": .string(storedAsset.fileName),
            "urlCount": .number(Double(urls.count)),
            "urls": .array(urls.map { .string($0.absoluteString) }),
        ]

        if let host = urls.first?.host, !host.isEmpty {
            structuredData["host"] = .string(host)
        }
        if let sourceAppName = metadata["sourceAppName"], !sourceAppName.isEmpty {
            structuredData["sourceAppName"] = .string(sourceAppName)
        }
        if let windowTitle = metadata["sourceWindowTitle"], !windowTitle.isEmpty {
            structuredData["sourceWindowTitle"] = .string(windowTitle)
        }

        let tags = makeStableLinkTags(urls: urls, mimeType: storedAsset.mimeType)
        let searchText = ([title, summary, contentType, scene, purpose] + snippets + tags)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AnalysisResult(
            contentType: contentType,
            scene: scene,
            purpose: purpose,
            title: title,
            shortSummary: summary,
            usefulSnippets: snippets,
            tags: tags,
            structuredData: structuredData,
            searchText: searchText,
            clarificationRequest: nil,
            needsReview: false
        )
    }

    private func detectedPublicURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var urls: [URL] = []
        var seen: Set<String> = []

        for match in matches {
            guard let url = match.url,
                  let normalizedURL = normalizedPublicHTTPURL(from: url)
            else {
                continue
            }

            let key = normalizedURL.absoluteString.lowercased()
            guard seen.insert(key).inserted else { continue }
            urls.append(normalizedURL)
        }

        return urls
    }

    private func containsOnlyURLs(in text: String, urls: [URL]) -> Bool {
        guard !urls.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else {
            return false
        }

        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: "")
        }
        let remainder = (mutable as String)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: ",，;；"))
        return remainder.isEmpty
    }

    private func preferredLinkTitle(from metadata: [String: String], urls: [URL]) -> String {
        if let windowTitle = metadata["sourceWindowTitle"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !windowTitle.isEmpty
        {
            return windowTitle
        }

        guard let firstURL = urls.first else {
            return CasebasePromptCatalog.language == .simplifiedChinese ? "网页链接" : "Web link"
        }

        if let host = firstURL.host, !host.isEmpty {
            let path = firstURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !path.isEmpty else { return host }
            return "\(host)/\(String(path.prefix(48)))"
        }

        return firstURL.absoluteString
    }

    private func linkSummary(title: String, urls: [URL]) -> String {
        let primaryURL = urls.first?.absoluteString ?? title
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "网页链接资料：\(title)。保存入口 \(primaryURL)，便于后续回看、搜索和引用。"
        case .english:
            return "Saved web link reference for \(title). Entry URL: \(primaryURL)."
        }
    }

    private func makeStableLinkTags(urls: [URL], mimeType: String?) -> [String] {
        var tags: [String] = [CasebasePromptCatalog.language == .simplifiedChinese ? "网页链接" : "web-link"]
        if let mimeType, !mimeType.isEmpty {
            tags.append(mimeType)
        }
        if let host = urls.first?.host, !host.isEmpty {
            tags.append(host.lowercased())
        }
        return Array(NSOrderedSet(array: tags)) as? [String] ?? tags
    }

    private func normalizedPublicHTTPURL(from url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              isPublicHost(host)
        else {
            return nil
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.fragment = nil
        return components.url
    }

    private func isPublicHost(_ host: String) -> Bool {
        guard !host.isEmpty,
              host != "localhost",
              !host.hasSuffix(".local")
        else {
            return false
        }

        if host.contains(":") {
            let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
            if normalized == "::1" || normalized.hasPrefix("fc") || normalized.hasPrefix("fd") || normalized.hasPrefix("fe80:") {
                return false
            }
            return true
        }

        let octets = host.split(separator: ".")
        if octets.count == 4, let first = Int(octets[0]), let second = Int(octets[1]) {
            if first == 10 || first == 127 || (first == 169 && second == 254) || (first == 192 && second == 168) {
                return false
            }
            if first == 172 && (16 ... 31).contains(second) {
                return false
            }
        }

        return host.contains(".")
    }

    private func ensureReviewableRecordCanBeStored(
        result: AnalysisResult,
        parseStatus: RecordParseStatus,
        analysisFailureDescription: String?,
        clarificationRequest: ClarificationRequest?,
        roundCount: Int
    ) throws {
        guard result.needsReview, clarificationRequest == nil else { return }

        if roundCount >= maxClarificationRounds {
            throw CasebaseError.analysisFailed(
                CasebasePromptCatalog.errors.clarificationExhaustedWithoutReliableResult
            )
        }

        if parseStatus == .partial {
            throw CasebaseError.analysisFailed(
                CasebasePromptCatalog.errors.analysisFallbackNeedsManualRetry(
                    reason: analysisFailureDescription
                )
            )
        }

        throw CasebaseError.analysisFailed(
            CasebasePromptCatalog.errors.analysisNeedsClarificationButProvidedNone
        )
    }

    private func measureImportStage<T>(
        _ stage: String,
        context: String,
        successSummary: ((T) -> String)? = nil,
        operation: () async throws -> T
    ) async throws -> T {
        let startedAt = Date()
        CasebaseDebugLogger.log("import \(stage) started \(context)")

        do {
            let result = try await operation()
            let summary: String?
            if let rawSummary = successSummary?(result) {
                let sanitizedSummary = sanitizedLogValue(rawSummary)
                summary = sanitizedSummary.isEmpty ? nil : sanitizedSummary
            } else {
                summary = nil
            }
            let summarySuffix = summary.map { " \($0)" } ?? ""
            CasebaseDebugLogger.log(
                "import \(stage) finished elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: startedAt)) \(context)\(summarySuffix)"
            )
            return result
        } catch {
            CasebaseDebugLogger.log(
                "import \(stage) failed elapsedMs=\(CasebaseDebugLogger.elapsedMilliseconds(since: startedAt)) \(context) error=\(sanitizedLogValue(normalizedFailureDescription(from: error)))"
            )
            throw error
        }
    }

    private func payloadLogContext(_ payload: ImportPayload) -> String {
        let fileName = quotedLogValue(payload.displayName)
        let sourceKind = payload.sourceKindHint?.rawValue ?? "unknown"
        let mimeType = payload.mimeType ?? "unknown"

        switch payload {
        case let .text(textPayload):
            return "file=\(fileName) sourceKind=\(sourceKind) mime=\(mimeType) textChars=\(textPayload.text.count)"
        case let .file(filePayload):
            let fileSize = FileMetadataReader.fileSizeBytes(for: filePayload.fileURL) ?? 0
            return "file=\(fileName) sourceKind=\(sourceKind) mime=\(mimeType) bytes=\(fileSize)"
        }
    }

    private func storedAssetLogContext(_ storedAsset: StoredAsset) -> String {
        "file=\(quotedLogValue(storedAsset.fileName)) sourceKind=\(storedAsset.sourceKind.rawValue) mime=\(storedAsset.mimeType ?? "unknown") bytes=\(storedAsset.fileSize) hash=\(String(storedAsset.assetHash.prefix(12)))"
    }

    private func organizedAssetLogSummary(_ storedAsset: StoredAsset) -> String {
        "assetPath=\(quotedLogValue(storedAsset.assetPath))"
    }

    private func normalizedContentLogSummary(_ content: NormalizedContent) -> String {
        let attachmentKinds = content.attachments
            .map(\.kind.rawValue)
            .joined(separator: ",")
        return "normalizedSourceKind=\(content.sourceKind.rawValue) rawTextChars=\(content.rawText?.count ?? 0) attachments=\(content.attachments.count) attachmentKinds=\(attachmentKinds.isEmpty ? "-" : attachmentKinds)"
    }

    private func analysisContextLogSummary(_ context: AnalysisContext) -> String {
        let clarificationCount = context.result.clarificationRequest?.questions.count ?? 0
        let failureDescription: String?
        if let rawFailureDescription = context.failureDescription {
            let sanitizedFailureDescription = sanitizedLogValue(rawFailureDescription)
            failureDescription = sanitizedFailureDescription.isEmpty ? nil : sanitizedFailureDescription
        } else {
            failureDescription = nil
        }
        let failureSuffix = failureDescription.map { " failure=\($0)" } ?? ""
        return "parseStatus=\(context.parseStatus.rawValue) needsReview=\(context.result.needsReview) tags=\(context.result.tags.count) snippets=\(context.result.usefulSnippets.count) clarificationQuestions=\(clarificationCount)\(failureSuffix)"
    }

    private func quotedLogValue(_ value: String) -> String {
        "\"\(sanitizedLogValue(value))\""
    }

    private func sanitizedLogValue(_ value: String, maxLength: Int = 200) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)) + "..."
    }

    private func normalizedFailureDescription(from error: Error) -> String {
        if let casebaseError = error as? CasebaseError {
            switch casebaseError {
            case let .analysisFailed(description),
                 let .answerFailed(description),
                 let .storageFailed(description),
                 let .normalizationFailed(description),
                 let .invalidPayload(description),
                 let .unsupportedPayload(description),
                 let .operationTimedOut(description):
                return description
            case let .missingConfiguration(name):
                return CasebasePromptCatalog.errors.missingConfiguration(name)
            case let .recordNotFound(id):
                return CasebasePromptCatalog.errors.recordNotFound(id)
            case .emptyQuery:
                return CasebasePromptCatalog.errors.emptyQuery
            case .emptyResponse:
                return CasebasePromptCatalog.errors.emptyResponse
            }
        }

        let localizedDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(describing: error) : trimmed
    }

    private func makeUpdatedClarificationHistory(
        existing: [ClarificationRound],
        roundCount: Int,
        answers: [ClarificationAnswer],
        skippedQuestionTitles: [String]
    ) -> [ClarificationRound] {
        guard !answers.isEmpty || !skippedQuestionTitles.isEmpty else { return existing }
        return existing + [
            ClarificationRound(
                roundIndex: roundCount,
                answers: answers,
                skippedQuestionTitles: skippedQuestionTitles
            )
        ]
    }

    private func combinedSupplement(from answers: [ClarificationAnswer]) -> String? {
        let lines = answers.map { "\($0.questionTitle): \($0.answer)" }
        let combined = lines.joined(separator: "\n")
        return trimmedSupplement(combined)
    }

    private func previousAnalysisBlock(from record: ImportRecord) -> String {
        var lines: [String] = [
            "title: \(record.title)",
            "contentType: \(record.contentType)",
            "scene: \(record.scene)",
            "purpose: \(record.purpose)",
            "shortSummary: \(record.shortSummary)"
        ]

        if !record.tags.isEmpty {
            lines.append("tags: \(record.tags.joined(separator: ", "))")
        }
        if !record.usefulSnippets.isEmpty {
            lines.append("usefulSnippets: \(record.usefulSnippets.joined(separator: " | "))")
        }
        if let clarificationRequest = record.clarificationRequest {
            lines.append("uncertainty: \(clarificationRequest.uncertaintySummary)")
            lines.append("impact: \(clarificationRequest.impactExplanation)")
        }

        return lines.joined(separator: "\n")
    }

    private func clarificationHistoryBlock(from history: [ClarificationRound]) -> String {
        history.map { round in
            let answersBlock = round.answers
                .map { "- \($0.questionTitle): \($0.answer)" }
                .joined(separator: "\n")
            let skippedBlock = round.skippedQuestionTitles
                .map { "- \($0)" }
                .joined(separator: "\n")

            var sections: [String] = ["round \(round.roundIndex):"]
            if !answersBlock.isEmpty {
                sections.append("answers:\n\(answersBlock)")
            }
            if !skippedBlock.isEmpty {
                sections.append("skipped questions:\n\(skippedBlock)")
            }
            return sections.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func skippedQuestionsBlock(from skippedQuestionTitles: [String]) -> String {
        skippedQuestionTitles
            .map { "- \($0)" }
            .joined(separator: "\n")
    }
}
