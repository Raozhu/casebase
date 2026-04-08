import Foundation

actor CasebaseImportCoordinator: ImportCoordinator {
    private let userSupplementMetadataKey = CasebasePromptCatalog.ai.userSupplementMetadataKey
    private let previousAnalysisMetadataKey = "__casebase_previousAnalysis"
    private let clarificationHistoryMetadataKey = "__casebase_clarificationHistory"
    private let skippedClarificationQuestionsMetadataKey = "__casebase_skippedClarificationQuestions"
    private let maxClarificationRounds = 3
    private let extractor: Extractor
    private let knowledgeStore: KnowledgeStore
    private let aiClient: AIClient
    private let assetVault: AssetVault

    init(
        extractor: Extractor,
        knowledgeStore: KnowledgeStore,
        aiClient: AIClient,
        assetVault: AssetVault
    ) {
        self.extractor = extractor
        self.knowledgeStore = knowledgeStore
        self.aiClient = aiClient
        self.assetVault = assetVault
    }

    func importPayload(_ payload: ImportPayload, progress: ImportProgressHandler?) async throws -> ImportRecord {
        progress?(ImportProgressUpdate(phase: .preparing))
        let storedAsset = try await assetVault.store(payload)

        if var existingRecord = try await knowledgeStore.findRecord(byAssetHash: storedAsset.assetHash) {
            progress?(ImportProgressUpdate(phase: .storing))
            existingRecord.assetPath = storedAsset.assetPath
            existingRecord.fileName = storedAsset.fileName
            existingRecord.mimeType = storedAsset.mimeType
            existingRecord.sourceKind = storedAsset.sourceKind
            existingRecord.registerReimport()
            try await knowledgeStore.update(existingRecord)
            return existingRecord
        }

        let canonicalPayload = await canonicalPayload(for: storedAsset)
        progress?(ImportProgressUpdate(phase: .recognizing))
        let normalizedContent = try await extractor.normalize(canonicalPayload)
        let analysisContext = try await analyze(storedAsset: storedAsset, content: normalizedContent)
        if let thoughtSummary = analysisContext.result.aiThoughtSummary, !thoughtSummary.isEmpty {
            progress?(ImportProgressUpdate(phase: .recognizing, thoughtText: thoughtSummary))
        }
        let embedding = try await aiClient.embed(text: analysisContext.result.searchText)
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: normalizedContent,
            roundCount: 0
        )

        let record = ImportRecord(
            assetPath: storedAsset.assetPath,
            assetHash: storedAsset.assetHash,
            fileName: storedAsset.fileName,
            mimeType: storedAsset.mimeType,
            sourceKind: storedAsset.sourceKind,
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

        progress?(ImportProgressUpdate(phase: .storing))
        try await knowledgeStore.save(record)
        return record
    }

    func reanalyzeRecord(
        id: UUID,
        clarificationAnswers: [ClarificationAnswer],
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord {
        progress?(ImportProgressUpdate(phase: .preparing))
        guard var existingRecord = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }

        let storedAsset = StoredAsset(
            assetPath: existingRecord.assetPath,
            assetHash: existingRecord.assetHash,
            fileName: existingRecord.fileName,
            mimeType: existingRecord.mimeType,
            sourceKind: existingRecord.sourceKind,
            fileSize: 0,
            contextMetadata: [:]
        )

        let canonicalPayload = await canonicalPayload(for: storedAsset)
        progress?(ImportProgressUpdate(phase: .recognizing))
        let normalizedContent = try await extractor.normalize(canonicalPayload)
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
        let analysisContext = try await analyze(
            storedAsset: storedAsset,
            content: augmentedContent
        )
        if let thoughtSummary = analysisContext.result.aiThoughtSummary, !thoughtSummary.isEmpty {
            progress?(ImportProgressUpdate(phase: .recognizing, thoughtText: thoughtSummary))
        }
        let embedding = try await aiClient.embed(text: analysisContext.result.searchText)
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: augmentedContent,
            roundCount: nextRoundCount
        )

        progress?(ImportProgressUpdate(phase: .storing))
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

        try await knowledgeStore.update(existingRecord)
        return existingRecord
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
        content: NormalizedContent
    ) async throws -> (result: AnalysisResult, parseStatus: RecordParseStatus) {
        if canUseAIAnalysis(for: content) {
            do {
                return (try await aiClient.analyze(content: content), .ready)
            } catch {
                let fallback = makeFallbackAnalysis(storedAsset: storedAsset, content: content)
                return (fallback, .partial)
            }
        }

        return (makeFallbackAnalysis(storedAsset: storedAsset, content: content), .partial)
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
            attachment.kind == .imagePreview || attachment.kind == .pagePreview
        }
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
        roundCount: Int
    ) -> ClarificationRequest? {
        guard roundCount < maxClarificationRounds else {
            return nil
        }

        if let request = result.clarificationRequest, !request.questions.isEmpty {
            return request
        }

        return nil
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
