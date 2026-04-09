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
        try ensurePayloadWithinSizeLimit(payload)
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
        let analysisContext = try await analyze(
            storedAsset: storedAsset,
            content: normalizedContent,
            progress: progress
        )
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: normalizedContent,
            roundCount: 0
        )
        try ensureReviewableRecordCanBeStored(
            result: analysisContext.result,
            parseStatus: analysisContext.parseStatus,
            clarificationRequest: clarificationRequest,
            roundCount: 0
        )
        let embedding = try await aiClient.embed(text: analysisContext.result.searchText)

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
            content: augmentedContent,
            progress: progress
        )
        let clarificationRequest = clarificationRequest(
            from: analysisContext.result,
            storedAsset: storedAsset,
            content: augmentedContent,
            roundCount: nextRoundCount
        )
        try ensureReviewableRecordCanBeStored(
            result: analysisContext.result,
            parseStatus: analysisContext.parseStatus,
            clarificationRequest: clarificationRequest,
            roundCount: nextRoundCount
        )
        let embedding = try await aiClient.embed(text: analysisContext.result.searchText)

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
        content: NormalizedContent,
        progress: ImportProgressHandler?
    ) async throws -> (result: AnalysisResult, parseStatus: RecordParseStatus) {
        let stableLinkFallback = stableLinkFallbackAnalysis(
            storedAsset: storedAsset,
            content: content
        )
        if canUseAIAnalysis(for: content) {
            do {
                let analyzed = try await aiClient.analyze(content: content) { thoughtText in
                        progress?(ImportProgressUpdate(phase: .recognizing, thoughtText: thoughtText))
                    }

                if let stableLinkFallback,
                   analyzed.needsReview,
                   analyzed.clarificationRequest == nil
                {
                    return (stableLinkFallback, .ready)
                }

                return (analyzed, .ready)
            } catch {
                if let stableLinkFallback {
                    return (stableLinkFallback, .ready)
                }
                let fallback = makeFallbackAnalysis(storedAsset: storedAsset, content: content)
                return (fallback, .partial)
            }
        }

        if let stableLinkFallback {
            return (stableLinkFallback, .ready)
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
        roundCount: Int
    ) -> ClarificationRequest? {
        guard roundCount < maxClarificationRounds else {
            return nil
        }

        if let request = result.clarificationRequest, !request.questions.isEmpty {
            return request
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
                CasebasePromptCatalog.errors.analysisFallbackNeedsManualRetry
            )
        }

        throw CasebaseError.analysisFailed(
            CasebasePromptCatalog.errors.analysisNeedsClarificationButProvidedNone
        )
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
