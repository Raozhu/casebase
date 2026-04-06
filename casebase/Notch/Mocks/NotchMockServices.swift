import Foundation

@MainActor
final class MockImportCoordinator: ImportCoordinator {
    private var records: [UUID: ImportRecord] = [:]

    func importPayload(_ payload: ImportPayload, progress: ImportProgressHandler?) async throws -> ImportRecord {
        progress?(.preparing)
        try await Task.sleep(nanoseconds: 220_000_000)
        progress?(.recognizing)
        try await Task.sleep(nanoseconds: 420_000_000)
        progress?(.storing)
        try await Task.sleep(nanoseconds: 220_000_000)

        let record = buildRecord(for: payload)
        records[record.id] = record
        return record
    }

    func reanalyzeRecord(
        id: UUID,
        clarificationAnswers: [ClarificationAnswer],
        skippedQuestionTitles: [String],
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord {
        progress?(.preparing)
        try await Task.sleep(nanoseconds: 180_000_000)
        progress?(.recognizing)
        try await Task.sleep(nanoseconds: 320_000_000)

        guard var record = records[id] else {
            throw CasebaseError.recordNotFound(id)
        }

        let normalizedAnswers = clarificationAnswers.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let supplementText = normalizedAnswers
            .map { "\($0.questionTitle): \($0.answer)" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !supplementText.isEmpty || !skippedQuestionTitles.isEmpty {
            record.userSupplement = supplementText
            if !supplementText.isEmpty, !record.usefulSnippets.contains(supplementText) {
                record.usefulSnippets.append(supplementText)
            }
            let skippedBlock = skippedQuestionTitles.joined(separator: " ")
            record.searchText = [record.searchText, supplementText, skippedBlock]
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !supplementText.isEmpty {
                record.structuredData["userSupplement"] = .string(supplementText)
            }
            record.clarificationHistory.append(
                ClarificationRound(
                    roundIndex: record.clarificationRoundCount + 1,
                    answers: normalizedAnswers,
                    skippedQuestionTitles: skippedQuestionTitles
                )
            )
            record.clarificationRoundCount += 1
            record.clarificationRequest = nil
            record.needsReview = false
        }

        progress?(.storing)
        try await Task.sleep(nanoseconds: 180_000_000)
        record.updatedAt = Date()
        record.shortSummary += reanalyzedSuffix
        records[id] = record
        return record
    }

    private func buildRecord(for payload: ImportPayload) -> ImportRecord {
        let now = Date()
        let title: String
        let summary: String
        let snippets: [String]
        let tags: [String]
        let contentType: String
        let scene: String
        let purpose: String
        let structuredData: [String: StructuredFieldValue]
        let needsReview: Bool
        let sourceKind: ImportSourceKind
        let fileName: String
        let mimeType: String?
        let assetPath: String

        switch payload {
        case let .file(filePayload):
            sourceKind = filePayload.sourceKindHint ?? .binary
            fileName = filePayload.suggestedFileName ?? filePayload.fileURL.lastPathComponent
            mimeType = filePayload.mimeType
            assetPath = filePayload.fileURL.path

            if sourceKind == .image {
                title = fileName.lowercased().contains("toast") || fileName.contains("吐司")
                    ? mockToastTitle
                    : mockClientTitle
                if fileName.lowercased().contains("toast") || fileName.contains("吐司") {
                    summary = mockToastSummary
                    contentType = mockToastContentType
                    scene = mockToastScene
                    purpose = mockToastPurpose
                    snippets = [
                        mockToastSnippetOne,
                        mockToastSnippetTwo,
                        mockToastSnippetThree
                    ]
                    tags = mockToastTags
                    structuredData = mockToastStructuredData
                    needsReview = false
                } else {
                    summary = mockClientSummary
                    contentType = mockClientContentType
                    scene = mockClientScene
                    purpose = mockClientPurpose
                    snippets = [
                        mockClientSnippetOne,
                        mockClientSnippetTwo,
                        mockClientSnippetThree
                    ]
                    tags = mockClientTags
                    structuredData = mockClientStructuredData
                    needsReview = false
                }
            } else {
                title = archivedFileTitle
                summary = archivedFileSummary
                contentType = archivedFileContentType
                scene = archivedFileScene
                purpose = archivedFilePurpose
                snippets = [fileName]
                tags = archivedFileTags
                structuredData = ["fileName": .string(fileName)]
                needsReview = true
            }

        case let .text(textPayload):
            sourceKind = .text
            fileName = textPayload.suggestedFileName ?? CasebasePromptCatalog.ui.draggedTextFileName
            mimeType = textPayload.mimeType
            assetPath = "mock://dragged-text/\(UUID().uuidString)"
            title = draggedTextTitle
            let clippedText = textPayload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            summary = clippedText.isEmpty
                ? emptyDraggedTextSummary
                : String(clippedText.prefix(64))
            contentType = draggedTextContentType
            scene = draggedTextScene
            purpose = draggedTextPurpose
            snippets = clippedText
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.isEmpty }
                .prefix(2)
                .map { $0 }
            tags = draggedTextTags
            structuredData = ["excerpt": .string(String(clippedText.prefix(120)))]
            needsReview = clippedText.isEmpty
        }

        let searchText = ([title, summary, contentType, scene, purpose] + snippets + tags)
            .joined(separator: " ")

        return ImportRecord(
            assetPath: assetPath,
            assetHash: UUID().uuidString.lowercased(),
            fileName: fileName,
            mimeType: mimeType,
            sourceKind: sourceKind,
            contentType: contentType,
            scene: scene,
            purpose: purpose,
            title: title,
            shortSummary: summary,
            usefulSnippets: snippets,
            tags: tags,
            structuredData: structuredData,
            searchText: searchText,
            clarificationRequest: needsReview ? mockClarificationRequest : nil,
            needsReview: needsReview,
            embedding: [0.18, 0.42, 0.67],
            parseStatus: .ready,
            createdAt: now,
            updatedAt: now,
            importCount: 1
        )
    }
}

@MainActor
final class MockAnswerService: AnswerService {
    private var records: [ImportRecord] = []

    func replaceContext(records: [ImportRecord]) {
        self.records = records
    }

    func answer(question: String, limit _: Int) async throws -> AnswerResult {
        try await Task.sleep(nanoseconds: 850_000_000)

        guard let record = records.first else {
            return AnswerResult(
                answerText: emptyKnowledgeAnswer,
                citedRecordIDs: [],
                citations: [],
                usedModelSupplement: false
            )
        }

        let lowercasedQuestion = question.lowercased()
        let answerText: String

        if isClientInfoRecord(record) {
            if lowercasedQuestion.contains("电话") {
                answerText = clientPhoneAnswer
            } else if lowercasedQuestion.contains("邮箱") || lowercasedQuestion.contains("email") {
                answerText = clientEmailAnswer
            } else {
                answerText = clientGeneralAnswer
            }
        } else if isToastNutritionRecord(record) {
            if lowercasedQuestion.contains("几片") || lowercasedQuestion.contains("热量") {
                answerText = toastCaloriesAnswer
            } else {
                answerText = toastGeneralAnswer
            }
        } else {
            answerText = genericSavedRecordAnswer
        }

        let citation = AnswerCitation(
            id: record.id,
            title: record.title,
            shortSummary: record.shortSummary,
            relevantSnippet: record.usefulSnippets.first
        )

        return AnswerResult(
            answerText: answerText,
            citedRecordIDs: [record.id],
            citations: [citation],
            usedModelSupplement: false
        )
    }

    private var emptyKnowledgeAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "资料库里还没有可以引用的内容。"
        case .english:
            return "There is no saved knowledge to cite yet."
        }
    }

    private var clientPhoneAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "甲客户电话是 138-0013-8000。"
        case .english:
            return "The client phone number is 138-0013-8000."
        }
    }

    private var clientEmailAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "甲客户邮箱是 client-a@example.com。"
        case .english:
            return "The client email is client-a@example.com."
        }
    }

    private var clientGeneralAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "这条资料记录的是甲客户的联系方式和基础身份信息，可直接用于后续跟进。"
        case .english:
            return "This saved item contains the client's contact details and basic identity information for follow-up work."
        }
    }

    private var toastCaloriesAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "按每片约 110 kcal 估算，你还可以吃大约 7 片这个吐司。"
        case .english:
            return "At about 110 kcal per slice, you could still eat roughly 7 slices of this toast."
        }
    }

    private var toastGeneralAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "这条资料记录的是吐司营养信息，包括热量、克重和主要配料。"
        case .english:
            return "This saved item captures the toast nutrition facts, including calories, serving weight, and key ingredients."
        }
    }

    private var genericSavedRecordAnswer: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "这条资料已经保存，可根据标题、摘要和关键片段继续追问。"
        case .english:
            return "This item is saved. You can keep asking based on its title, summary, and key snippets."
        }
    }

    private func isClientInfoRecord(_ record: ImportRecord) -> Bool {
        record.title == "甲客户信息"
            || record.title == "Client Information"
            || record.usefulSnippets.contains { $0.contains("client-a@example.com") || $0.contains("138-0013-8000") }
    }

    private func isToastNutritionRecord(_ record: ImportRecord) -> Bool {
        record.title == "吐司营养表"
            || record.title == "Toast Nutrition Facts"
            || record.usefulSnippets.contains { $0.contains("110 kcal") || $0.contains("220 kcal") }
    }

}

private extension MockImportCoordinator {
    var mockClarificationRequest: ClarificationRequest {
        ClarificationRequest(
            uncertaintySummary: CasebasePromptCatalog.language == .simplifiedChinese
                ? "当前还不能稳定判断这条资料的类型和用途。"
                : "The record type and intended use are still not stable enough.",
            impactExplanation: CasebasePromptCatalog.language == .simplifiedChinese
                ? "这会影响分类、摘要和后续问答时的优先字段。"
                : "This affects categorization, summarization, and which fields are prioritized later.",
            questions: [
                ClarificationQuestion(
                    id: "q1",
                    title: CasebasePromptCatalog.language == .simplifiedChinese ? "这更像哪类资料？" : "What kind of record is this?",
                    reason: CasebasePromptCatalog.language == .simplifiedChinese ? "先确认分类。" : "The item should be classified first.",
                    suggestedOptions: CasebasePromptCatalog.language == .simplifiedChinese
                        ? ["客户资料", "聊天截图", "食品信息"]
                        : ["Client info", "Chat screenshot", "Food info"]
                )
            ]
        )
    }

    var reanalyzedSuffix: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "（已重新分析）"
        case .english:
            return " (reanalyzed)"
        }
    }

    var mockToastTitle: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "吐司营养表"
        case .english:
            return "Toast Nutrition Facts"
        }
    }

    var mockClientTitle: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "甲客户信息"
        case .english:
            return "Client Information"
        }
    }

    var mockToastSummary: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "吐司营养截图，记录了热量、克重与主要营养成分。"
        case .english:
            return "A toast nutrition screenshot capturing calories, weight, and the main nutrition facts."
        }
    }

    var mockToastContentType: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "营养成分表"
        case .english: return "Nutrition facts"
        }
    }

    var mockToastScene: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "饮食记录与热量计算"
        case .english: return "Diet tracking and calorie math"
        }
    }

    var mockToastPurpose: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "保留吐司的热量、营养和配料信息，便于后续饮食决策"
        case .english: return "Keep toast calories, nutrition, and ingredients for later food decisions"
        }
    }

    var mockToastStructuredData: [String: StructuredFieldValue] {
        [
            "calories_per_two_slices": .number(220),
            "calories_per_slice": .number(110),
            "net_weight_g": .number(460),
        ]
    }

    var mockToastSnippetOne: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "每 2 片 220 kcal"
        case .english:
            return "220 kcal per 2 slices"
        }
    }

    var mockToastSnippetTwo: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "每片约 110 kcal，净含量 460 g"
        case .english:
            return "About 110 kcal per slice, net weight 460 g"
        }
    }

    var mockToastSnippetThree: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "主要配料：小麦粉、黄油、糖、酵母"
        case .english:
            return "Main ingredients: wheat flour, butter, sugar, yeast"
        }
    }

    var mockToastTags: [String] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return ["吐司", "营养", "食品"]
        case .english:
            return ["toast", "nutrition", "food"]
        }
    }

    var mockClientSummary: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "客户聊天截图，包含联系人资料与关键信息。"
        case .english:
            return "A client chat screenshot containing contact details and key identity information."
        }
    }

    var mockClientContentType: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "客户信息"
        case .english: return "Client information"
        }
    }

    var mockClientScene: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "工作跟进与联系人查找"
        case .english: return "Work follow-up and contact lookup"
        }
    }

    var mockClientPurpose: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "保存客户联系方式和身份信息，便于后续跟进与核对"
        case .english: return "Save client contact and identity facts for follow-up and verification"
        }
    }

    var mockClientStructuredData: [String: StructuredFieldValue] {
        [
            "phone": .string("138-0013-8000"),
            "email": .string("client-a@example.com"),
            "id_number": .string("110101199001011234"),
        ]
    }

    var mockClientSnippetOne: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "客户名称：甲客户"
        case .english:
            return "Client name: Client A"
        }
    }

    var mockClientSnippetTwo: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "电话：138-0013-8000"
        case .english:
            return "Phone: 138-0013-8000"
        }
    }

    var mockClientSnippetThree: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "邮箱：client-a@example.com"
        case .english:
            return "Email: client-a@example.com"
        }
    }

    var mockClientTags: [String] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return ["客户", "联系方式", "工作"]
        case .english:
            return ["client", "contact", "work"]
        }
    }

    var archivedFileTitle: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "文件已归档"
        case .english:
            return "File Archived"
        }
    }

    var archivedFileSummary: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "文件原件已保存，可在后续接入解析器后补充理解。"
        case .english:
            return "The original file has been saved and can be understood more deeply once a parser is added."
        }
    }

    var archivedFileContentType: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "通用文件"
        case .english: return "Generic file"
        }
    }

    var archivedFileScene: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "资料留存与后续检索"
        case .english: return "Reference storage and later lookup"
        }
    }

    var archivedFilePurpose: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "保留文件本体，便于未来查找与复用"
        case .english: return "Preserve the file for future lookup and reuse"
        }
    }

    var archivedFileTags: [String] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return ["文件", "归档"]
        case .english:
            return ["file", "archive"]
        }
    }

    var draggedTextTitle: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "拖入文本摘要"
        case .english:
            return "Dragged Text Summary"
        }
    }

    var draggedTextContentType: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "临时文本"
        case .english: return "Temporary text"
        }
    }

    var draggedTextScene: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "临时记录与后续检索"
        case .english: return "Temporary capture and later lookup"
        }
    }

    var draggedTextPurpose: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese: return "保留拖入文本中的关键事实，便于后续检索与问答"
        case .english: return "Preserve key facts from the dropped text for later retrieval and QA"
        }
    }

    var emptyDraggedTextSummary: String {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return "已保存一段临时文本。"
        case .english:
            return "A temporary text snippet has been saved."
        }
    }

    var draggedTextTags: [String] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return ["文本", "临时资料"]
        case .english:
            return ["text", "temporary"]
        }
    }
}
