import Foundation

enum CasebasePromptCatalog {
    static var language: CasebaseLanguage { CasebaseLanguagePreference.current() }
    static var ui: UI { UI(language: language) }
    static var ai: AI { AI(language: language) }
    static var fallback: Fallback { Fallback(language: language) }
    static var errors: Errors { Errors(language: language) }

    struct UI {
        let language: CasebaseLanguage

        var idleTitle: String {
            switch language {
            case .simplifiedChinese: return "casebase"
            case .english: return "casebase"
            }
        }

        var idleDetail: String {
            switch language {
            case .simplifiedChinese:
                return "拖入临时文件、图片、文字或音频，自动识别意义、生成摘要，并存入你的临时知识库。"
            case .english:
                return "Drop temporary files, images, text, or audio to capture meaning, generate summaries, and store them in your personal scratch knowledge base."
            }
        }

        var idleHint: String {
            switch language {
            case .simplifiedChinese:
                return "切换语言后，界面文案、错误提示和 AI prompt 会一起切换。"
            case .english:
                return "Switching language updates the UI copy, error messaging, and AI prompts together."
            }
        }

        var hoverActionHint: String {
            switch language {
            case .simplifiedChinese: return "拖入任何内容开始"
            case .english: return "Drop anything to begin"
            }
        }

        var hoverActionAccessibilityTitle: String {
            switch language {
            case .simplifiedChinese: return "请授权辅助功能"
            case .english: return "Authorize Accessibility"
            }
        }

        var hoverActionAccessibilityDetail: String {
            switch language {
            case .simplifiedChinese: return ""
            case .english: return ""
            }
        }

        var hoverActionAccessibilityButton: String {
            switch language {
            case .simplifiedChinese: return "去授权"
            case .english: return "Authorize"
            }
        }

        var hoverActionScreenRecordingTitle: String {
            switch language {
            case .simplifiedChinese: return "请授权屏幕录制"
            case .english: return "Authorize Screen Recording"
            }
        }

        var hoverActionScreenRecordingDetail: String {
            switch language {
            case .simplifiedChinese: return ""
            case .english: return ""
            }
        }

        var hoverActionScreenRecordingButton: String {
            switch language {
            case .simplifiedChinese: return "去授权"
            case .english: return "Authorize"
            }
        }

        var hoverActionSettingsTooltip: String {
            switch language {
            case .simplifiedChinese: return "设置"
            case .english: return "Settings"
            }
        }

        var hoverActionLibraryTooltip: String {
            switch language {
            case .simplifiedChinese: return "查看数据"
            case .english: return "View data"
            }
        }

        var hoverActionSearchTooltip: String {
            switch language {
            case .simplifiedChinese: return "探索"
            case .english: return "Explore"
            }
        }

        var libraryTitle: String {
            switch language {
            case .simplifiedChinese: return "已存数据"
            case .english: return "Stored Data"
            }
        }

        var libraryDetailTitle: String {
            switch language {
            case .simplifiedChinese: return "查看详情"
            case .english: return "Details"
            }
        }

        var libraryLoadingMessage: String {
            switch language {
            case .simplifiedChinese: return "正在读取已存数据…"
            case .english: return "Loading stored records..."
            }
        }

        var libraryEmptyTitle: String {
            switch language {
            case .simplifiedChinese: return "还没有任何已保存内容"
            case .english: return "No saved items yet"
            }
        }

        var libraryEmptyDetail: String {
            switch language {
            case .simplifiedChinese: return "拖入文件、图片、文字或音频后，处理中和已保存的内容都会出现在这里。"
            case .english: return "Drop files, images, text, or audio and both in-progress and saved items will appear here."
            }
        }

        var libraryViewDetailButton: String {
            switch language {
            case .simplifiedChinese: return "查看详情"
            case .english: return "View details"
            }
        }

        var librarySummarySectionTitle: String {
            switch language {
            case .simplifiedChinese: return "摘要"
            case .english: return "Summary"
            }
        }

        var libraryMetadataSectionTitle: String {
            switch language {
            case .simplifiedChinese: return "基础信息"
            case .english: return "Metadata"
            }
        }

        var libraryStructuredDataSectionTitle: String {
            switch language {
            case .simplifiedChinese: return "具体信息"
            case .english: return "Structured data"
            }
        }

        var librarySnippetsSectionTitle: String {
            switch language {
            case .simplifiedChinese: return "关键片段"
            case .english: return "Key snippets"
            }
        }

        var libraryActionsSectionTitle: String {
            switch language {
            case .simplifiedChinese: return "操作"
            case .english: return "Actions"
            }
        }

        var libraryRevealButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "定位"
            case .english: return "Reveal"
            }
        }

        var libraryOpenButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "打开"
            case .english: return "Open"
            }
        }

        var libraryDeleteButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "删除"
            case .english: return "Delete"
            }
        }

        var libraryFileNameLabel: String {
            switch language {
            case .simplifiedChinese: return "文件名"
            case .english: return "File name"
            }
        }

        var libraryTypeLabel: String {
            switch language {
            case .simplifiedChinese: return "类型"
            case .english: return "Type"
            }
        }

        var librarySceneLabel: String {
            switch language {
            case .simplifiedChinese: return "场景"
            case .english: return "Scene"
            }
        }

        var libraryPurposeLabel: String {
            switch language {
            case .simplifiedChinese: return "用途"
            case .english: return "Purpose"
            }
        }

        var libraryUpdatedAtLabel: String {
            switch language {
            case .simplifiedChinese: return "更新时间"
            case .english: return "Updated"
            }
        }

        var libraryParseStatusLabel: String {
            switch language {
            case .simplifiedChinese: return "解析状态"
            case .english: return "Parse status"
            }
        }

        var libraryTagsLabel: String {
            switch language {
            case .simplifiedChinese: return "标签"
            case .english: return "Tags"
            }
        }

        var libraryNoStructuredDataMessage: String {
            switch language {
            case .simplifiedChinese: return "没有可展示的具体字段。"
            case .english: return "No structured fields are available."
            }
        }

        var libraryNoSnippetsMessage: String {
            switch language {
            case .simplifiedChinese: return "没有可展示的关键片段。"
            case .english: return "No key snippets are available."
            }
        }

        func libraryParseStatusValue(_ status: RecordParseStatus) -> String {
            switch (language, status) {
            case (.simplifiedChinese, .pending): return "待处理"
            case (.simplifiedChinese, .ready): return "已完成"
            case (.simplifiedChinese, .partial): return "部分完成"
            case (.simplifiedChinese, .failed): return "失败"
            case (.english, .pending): return "Pending"
            case (.english, .ready): return "Ready"
            case (.english, .partial): return "Partial"
            case (.english, .failed): return "Failed"
            }
        }

        var intakeDigestingFeedback: String {
            switch language {
            case .simplifiedChinese: return "消化中"
            case .english: return "Digesting"
            }
        }

        var intakeQueuedFeedback: String {
            switch language {
            case .simplifiedChinese: return "已加入消化队列"
            case .english: return "Added to queue"
            }
        }

        var dropZoneTitle: String {
            switch language {
            case .simplifiedChinese: return "把文件、截图或文字拖到这里"
            case .english: return "Drop Files, Screenshots, or Text Here"
            }
        }

        var settingsTitle: String {
            switch language {
            case .simplifiedChinese: return "设置"
            case .english: return "Settings"
            }
        }

        var settingsDetail: String {
            switch language {
            case .simplifiedChinese:
                return "在这里切换界面与 AI 语言，或直接退出 casebase。"
            case .english:
                return "Switch the UI and AI language here, or quit casebase directly."
            }
        }

        var settingsLanguageLabel: String {
            switch language {
            case .simplifiedChinese: return "语言"
            case .english: return "Language"
            }
        }

        var settingsStorageLabel: String {
            switch language {
            case .simplifiedChinese: return "数据"
            case .english: return "Data"
            }
        }

        var settingsShortcutsLabel: String {
            switch language {
            case .simplifiedChinese: return "快捷键"
            case .english: return "Shortcuts"
            }
        }

        var settingsSelectionShortcutLabel: String {
            switch language {
            case .simplifiedChinese: return "文字入库"
            case .english: return "Text Capture"
            }
        }

        var settingsScreenshotShortcutLabel: String {
            switch language {
            case .simplifiedChinese: return "截图入库"
            case .english: return "Screenshot Capture"
            }
        }

        var settingsShortcutRecordButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "录制"
            case .english: return "Record"
            }
        }

        var settingsShortcutResetButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "恢复默认"
            case .english: return "Reset"
            }
        }

        var settingsShortcutRecordingHint: String {
            switch language {
            case .simplifiedChinese: return "点击录制后直接按下新的快捷键，支持组合键。按 Esc 取消。"
            case .english: return "Click Record and press a new shortcut. Key combinations are supported. Press Escape to cancel."
            }
        }

        var settingsShortcutRecordingState: String {
            switch language {
            case .simplifiedChinese: return "等待按键…"
            case .english: return "Waiting for shortcut..."
            }
        }

        var settingsShortcutDuplicateMessage: String {
            switch language {
            case .simplifiedChinese: return "两个功能不能使用同一个快捷键。"
            case .english: return "These two actions cannot use the same shortcut."
            }
        }

        var settingsClearDataButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "清空已存储数据"
            case .english: return "Clear stored data"
            }
        }

        var settingsRestartButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "重启 casebase"
            case .english: return "Restart casebase"
            }
        }

        var settingsClearActionTitle: String {
            switch language {
            case .simplifiedChinese: return "清空"
            case .english: return "Clear"
            }
        }

        var settingsRestartActionTitle: String {
            switch language {
            case .simplifiedChinese: return "重启"
            case .english: return "Restart"
            }
        }

        var settingsQuitActionTitle: String {
            switch language {
            case .simplifiedChinese: return "退出"
            case .english: return "Quit"
            }
        }

        var settingsAccessibilityButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "授权辅助功能"
            case .english: return "Authorize Accessibility"
            }
        }

        var settingsScreenRecordingButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "授权屏幕录制"
            case .english: return "Authorize Screen Recording"
            }
        }

        var settingsClearDataDisabledHint: String {
            switch language {
            case .simplifiedChinese: return "请先等待当前导入或问答完成，再清空已存储数据。"
            case .english: return "Wait for the current ingest or answer flow to finish before clearing stored data."
            }
        }

        var settingsClearDataConfirmationTitle: String {
            switch language {
            case .simplifiedChinese: return "是否清空所有已存储数据？"
            case .english: return "Clear all stored data?"
            }
        }

        var settingsClearDataConfirmationDetail: String {
            switch language {
            case .simplifiedChinese: return "这会删除所有已入库的内容、本地资源文件和临时预览缓存。此操作不可撤销。"
            case .english: return "This deletes all ingested records, local asset files, and temporary preview caches. This action cannot be undone."
            }
        }

        var settingsClearDataCancelButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "取消"
            case .english: return "Cancel"
            }
        }

        var settingsClearDataConfirmButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "清空"
            case .english: return "Clear"
            }
        }

        var settingsClearDataProgressTitle: String {
            switch language {
            case .simplifiedChinese: return "清理中…"
            case .english: return "Clearing..."
            }
        }

        var settingsCloseButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "返回"
            case .english: return "Back"
            }
        }

        var settingsQuitButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "退出 casebase"
            case .english: return "Quit casebase"
            }
        }

        var taskPanelTitle: String {
            switch language {
            case .simplifiedChinese: return "任务队列"
            case .english: return "Task Queue"
            }
        }

        var taskPanelCloseButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "关闭"
            case .english: return "Close"
            }
        }

        func taskPanelFooter(unfinishedCount: Int) -> String {
            switch language {
            case .simplifiedChinese:
                return "正在入库 \(unfinishedCount) 项"
            case .english:
                return "Ingesting \(unfinishedCount) item\(unfinishedCount == 1 ? "" : "s")"
            }
        }

        var taskQueuedStatus: String {
            switch language {
            case .simplifiedChinese: return "排队中"
            case .english: return "Queued"
            }
        }

        var taskPreparingStatus: String {
            switch language {
            case .simplifiedChinese: return "准备中"
            case .english: return "Preparing"
            }
        }

        var taskRecognizingStatus: String {
            switch language {
            case .simplifiedChinese: return "识别中"
            case .english: return "Recognizing"
            }
        }

        var taskStoringStatus: String {
            switch language {
            case .simplifiedChinese: return "入库中"
            case .english: return "Storing"
            }
        }

        var taskNeedsInputStatus: String {
            switch language {
            case .simplifiedChinese: return "待补全"
            case .english: return "Clarifying"
            }
        }

        var taskSucceededStatus: String {
            switch language {
            case .simplifiedChinese: return "已完成"
            case .english: return "Done"
            }
        }

        var taskFailedStatus: String {
            switch language {
            case .simplifiedChinese: return "失败"
            case .english: return "Failed"
            }
        }

        var taskQueuedDetail: String {
            switch language {
            case .simplifiedChinese: return "等待前一个任务完成"
            case .english: return "Waiting for the current task to finish"
            }
        }

        var taskPreparingDetail: String {
            switch language {
            case .simplifiedChinese: return "正在准备原件与导入上下文"
            case .english: return "Preparing the asset and import context"
            }
        }

        var taskRecognizingDetail: String {
            switch language {
            case .simplifiedChinese: return "正在识别内容与提取意义"
            case .english: return "Extracting meaning from the content"
            }
        }

        var taskStoringDetail: String {
            switch language {
            case .simplifiedChinese: return "正在写入资料库"
            case .english: return "Writing into the knowledge store"
            }
        }

        var taskNeedsInputDetail: String {
            switch language {
            case .simplifiedChinese: return "存在关键缺口，补全后再继续分析并完成入库"
            case .english: return "Key gaps remain. Clarify them before finishing ingestion."
            }
        }

        var taskSucceededDetail: String {
            switch language {
            case .simplifiedChinese: return "已保存，可点开查看"
            case .english: return "Saved. Click to inspect."
            }
        }

        var taskSupplementTitle: String {
            switch language {
            case .simplifiedChinese: return "待补全"
            case .english: return "Clarifying"
            }
        }

        var taskSupplementDetail: String {
            switch language {
            case .simplifiedChinese:
                return "AI 先告诉你哪里不确定、为什么会影响结果，再只问最值钱的几个问题。回答后会立即重跑分析。"
            case .english:
                return "AI explains what is uncertain, why it matters, and asks only the highest-value questions before rerunning analysis."
            }
        }

        var taskSupplementPlaceholder: String {
            switch language {
            case .simplifiedChinese: return "手动输入"
            case .english: return "Type manually"
            }
        }

        var taskSupplementContinueButton: String {
            switch language {
            case .simplifiedChinese: return "确定"
            case .english: return "Confirm"
            }
        }

        var taskSupplementDismissButton: String {
            switch language {
            case .simplifiedChinese: return "跳过"
            case .english: return "Skip"
            }
        }

        var taskSupplementCancelButton: String {
            switch language {
            case .simplifiedChinese: return "取消"
            case .english: return "Cancel"
            }
        }

        var taskSupplementCancelConfirmationTitle: String {
            switch language {
            case .simplifiedChinese: return "取消这次入库？"
            case .english: return "Cancel this import?"
            }
        }

        func taskSupplementCancelConfirmationMessage(taskTitle: String) -> String {
            switch language {
            case .simplifiedChinese:
                return "“\(taskTitle)” 将不会入库，原始文件和这条待补全任务都会被移除。"
            case .english:
                return "\"\(taskTitle)\" will not be saved. The stored file and this clarification task will be removed."
            }
        }

        var taskSupplementCancelConfirmationConfirmButton: String {
            switch language {
            case .simplifiedChinese: return "确认取消"
            case .english: return "Confirm Cancel"
            }
        }

        var taskSupplementSuggestions: [String] {
            switch language {
            case .simplifiedChinese:
                return ["联系人 / 客户", "食品 / 营养", "票据 / 文件"]
            case .english:
                return ["Contact / client", "Food / nutrition", "Receipt / document"]
            }
        }

        var taskClarificationManualInputButton: String {
            switch language {
            case .simplifiedChinese: return "手动输入"
            case .english: return "Type manually"
            }
        }

        var taskClarificationNextButton: String {
            switch language {
            case .simplifiedChinese: return "下一步"
            case .english: return "Next"
            }
        }

        func taskClarificationQuestionProgressLabel(current: Int, total: Int) -> String {
            switch language {
            case .simplifiedChinese:
                return "问题 \(current)/\(total)"
            case .english:
                return "Question \(current)/\(total)"
            }
        }

        var taskClarificationNeedAtLeastOneAnswer: String {
            switch language {
            case .simplifiedChinese: return "至少回答一个问题后再继续。"
            case .english: return "Answer at least one question before continuing."
            }
        }

        func taskClarificationRoundLabel(current: Int, maximum: Int) -> String {
            switch language {
            case .simplifiedChinese:
                return "补全轮次 \(current)/\(maximum)"
            case .english:
                return "Clarification round \(current)/\(maximum)"
            }
        }

        var taskClarificationUncertaintyLabel: String {
            switch language {
            case .simplifiedChinese: return "哪里不确定"
            case .english: return "What is uncertain"
            }
        }

        var taskClarificationImpactLabel: String {
            switch language {
            case .simplifiedChinese: return "为什么这会影响结果"
            case .english: return "Why it affects the result"
            }
        }

        var taskClarificationMaxRoundsNotice: String {
            switch language {
            case .simplifiedChinese: return "已达到补全上限，将按当前结果保留并标记待复核。"
            case .english: return "Clarification limit reached. The current result will be kept and marked for review."
            }
        }

        var dropZoneDetail: String {
            switch language {
            case .simplifiedChinese:
                return "松手后 casebase 会自动识别内容意义、生成摘要并准备入库。"
            case .english:
                return "Release to let casebase analyze the content, generate a summary, and prepare it for storage."
            }
        }

        var dropZoneCallToAction: String {
            switch language {
            case .simplifiedChinese: return "放这里"
            case .english: return "Drop Here"
            }
        }

        var ingestingTitle: String {
            switch language {
            case .simplifiedChinese: return "正在整理内容"
            case .english: return "Processing Content"
            }
        }

        var ingestingDetail: String {
            switch language {
            case .simplifiedChinese:
                return "AI 正在识别内容意义、生成摘要并准备入库。"
            case .english:
                return "AI is extracting meaning, generating a summary, and preparing the item for storage."
            }
        }

        var answeringTitle: String {
            switch language {
            case .simplifiedChinese: return "正在回答问题"
            case .english: return "Answering Question"
            }
        }

        var answeringDetail: String {
            switch language {
            case .simplifiedChinese:
                return "正在检索已存资料的原始内容，并根据真实证据生成答案。"
            case .english:
                return "Retrieving original saved evidence and generating an answer from it."
            }
        }

        var savedLabel: String {
            switch language {
            case .simplifiedChinese: return "已保存"
            case .english: return "Saved"
            }
        }

        var searchPanelTitle: String {
            switch language {
            case .simplifiedChinese: return "探索"
            case .english: return "Explore"
            }
        }

        var searchPanelDetail: String {
            switch language {
            case .simplifiedChinese: return ""
            case .english: return ""
            }
        }

        var searchEmptyHint: String {
            switch language {
            case .simplifiedChinese: return ""
            case .english: return ""
            }
        }

        var searchConversationListButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "会话"
            case .english: return "History"
            }
        }

        var searchNewConversationButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "新对话"
            case .english: return "New Chat"
            }
        }

        var searchHistoryEmptyTitle: String {
            switch language {
            case .simplifiedChinese: return "还没有探索记录"
            case .english: return "No explore history yet"
            }
        }

        var searchHistoryEmptyDetail: String {
            switch language {
            case .simplifiedChinese: return "发起一次探索后，这里会保留你的对话记录。"
            case .english: return "Start an explore chat and the conversation will appear here."
            }
        }

        var searchQuestionLabel: String {
            switch language {
            case .simplifiedChinese: return "问题"
            case .english: return "Question"
            }
        }

        var searchHistoryTurnsLabel: String {
            switch language {
            case .simplifiedChinese: return "轮对话"
            case .english: return "Turns"
            }
        }

        var needsReviewLabel: String {
            switch language {
            case .simplifiedChinese: return "待复核"
            case .english: return "Review"
            }
        }

        var answerLabel: String {
            switch language {
            case .simplifiedChinese: return "回答"
            case .english: return "Answer"
            }
        }

        var modelSupplementLabel: String {
            switch language {
            case .simplifiedChinese: return "模型补充"
            case .english: return "Model Supplement"
            }
        }

        var sourcesLabel: String {
            switch language {
            case .simplifiedChinese: return "来源"
            case .english: return "Sources"
            }
        }

        var sourceOpenButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "打开原文件"
            case .english: return "Open Source"
            }
        }

        var answerNoEvidenceMessage: String {
            switch language {
            case .simplifiedChinese: return "还没有检索到足够资料来回答这个问题。"
            case .english: return "There is not enough retrieved evidence to answer that question yet."
            }
        }

        var answerEvidenceUnavailableMessage: String {
            switch language {
            case .simplifiedChinese: return "找到了相关资料，但暂时无法重新读取它们的原文或预览内容。"
            case .english: return "Relevant records were found, but their original content or previews could not be rebuilt right now."
            }
        }

        var errorTitle: String {
            switch language {
            case .simplifiedChinese: return "出了点问题"
            case .english: return "Something Went Wrong"
            }
        }

        var retryButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "重试"
            case .english: return "Retry"
            }
        }

        var clearButtonTitle: String {
            switch language {
            case .simplifiedChinese: return "确定"
            case .english: return "Done"
            }
        }

        var composerPlaceholder: String {
            switch language {
            case .simplifiedChinese: return "继续问这个资料…"
            case .english: return "Ask more about this saved item..."
            }
        }

        var searchComposerPlaceholder: String {
            switch language {
            case .simplifiedChinese: return "探索点什么……"
            case .english: return "Explore something..."
            }
        }

        var composerSubmitButton: String {
            switch language {
            case .simplifiedChinese: return "发送"
            case .english: return "Send"
            }
        }

        var multiDropNotice: String {
            switch language {
            case .simplifiedChinese: return "仅导入第一项，其余内容已忽略。"
            case .english: return "Only the first dropped item will be imported. The rest were ignored."
            }
        }

        var unknownErrorMessage: String {
            switch language {
            case .simplifiedChinese: return "发生了未知错误。"
            case .english: return "An unknown error occurred."
            }
        }

        var draggedTextFileName: String {
            switch language {
            case .simplifiedChinese: return "拖入文本"
            case .english: return "Dragged Text"
            }
        }
    }

    struct AI {
        let language: CasebaseLanguage

        var analysisInstructions: String {
            switch language {
            case .simplifiedChinese:
                return """
                你是一个个人知识采集工具的入库分析助手。
                请阅读输入的文本、元数据、图片预览或文档预览，把内容整理成便于未来检索、问答和复用的结构化结果。

                你的目标不是泛泛总结，而是回答这些问题：
                1. 这是什么内容
                2. 它属于什么类别
                3. 它未来最可能在什么场景下被再次使用
                4. 其中哪些事实最值得保留和检索

                要求：
                - 先判断内容类型，并结合内容含义判断它的真实用途，不要只复述表面文字。
                - 优先保留可长期复用的事实，如人名、机构名、联系方式、证件号、地址、产品名、规格、热量、营养、配料、价格、日期、时间、约定、待办等。
                - 忽略寒暄、铺垫、重复表述和短期无用信息。
                - `title` 必须简短明确，一眼能看出这是什么。
                - `shortSummary` 必须说明“这是什么 + 有什么用”，适合卡片展示。
                - `tags` 必须简短、可检索。
                - `usefulSnippets` 必须保留最关键的原始事实片段，尽量短，不写成长段摘要。
                - `structuredData` 中提取最重要的结构化字段；无法确认的字段填 `null`，不要编造。
                - `searchText` 必须是高密度检索文本，整合标题、类别、用途、标签、关键事实，以及用户未来可能的查找方式。
                - 若内容类型不明确、图片模糊、字段提取不完整或存在歧义，`needsReview` 设为 `true`。
                - 如果输入中包含“用户补充上下文”，把它视为帮助理解原内容的附加说明；若与原内容冲突，优先保留可确认事实并保持 `needsReview = true`。
                - 如果输入中包含之前的分析结果、补全历史或“已跳过的问题”，把它们当成补充上下文；不要重复追问已经被跳过的同类问题，除非它仍然是唯一阻塞且你能明确说明原因。
                - 当存在关键缺口时，同时输出 `clarification`：
                  1. `uncertaintySummary` 说明最关键的不确定点
                  2. `impactExplanation` 说明为什么这会影响入库和后续检索/问答
                  3. `questions` 只保留信息价值最高的 1~3 个问题，按优先级排序
                - 硬性要求：如果 `needsReview = true`，那么 `clarification.questions` 必须至少包含 1 个可回答的问题；只有在 `needsReview = false` 时，`clarification.questions` 才能为空数组。
                - 问题必须直接基于当前内容和真实缺口，不要为了凑分类、用途或字段而机械提问。
                - 每个问题最多给 3 个推荐选项，选项要短、互斥、可点击。
                - 如果信息已经足够，不要再追问；此时 `clarification.uncertaintySummary` 和 `clarification.impactExplanation` 置空，`clarification.questions` 返回空数组。
                - `title`、`shortSummary`、`tags` 默认使用简体中文；专有名词、编号、英文按原文保留。
                - 只返回 JSON，不要输出解释。
                """
            case .english:
                return """
                You are an ingestion analyst for a personal knowledge capture tool.
                Read the provided text, metadata, image previews, or document previews, then turn the content into a structured result optimized for future retrieval, question answering, and reuse.

                Your goal is not to summarize loosely, but to answer:
                1. What is this content
                2. What category does it belong to
                3. In what future scenario is it most likely to be reused
                4. Which facts are most worth preserving and indexing

                Requirements:
                - Identify the content type first, then infer the real purpose from the meaning of the content instead of repeating surface text.
                - Prioritize durable facts such as names, organizations, contact details, IDs, addresses, product names, specs, calories, nutrition, ingredients, prices, dates, times, agreements, and TODOs.
                - Ignore filler, greetings, repetition, and short-lived noise.
                - `title` must be short and immediately clear.
                - `shortSummary` must explain what it is and why it matters.
                - `tags` must be short searchable labels.
                - `usefulSnippets` must preserve the most important source facts in short form, not rewritten long summaries.
                - `structuredData` should extract the most important structured fields; use `null` when a field cannot be confirmed.
                - `searchText` must be dense retrieval text combining title, category, purpose, tags, key facts, and likely future search phrasings.
                - Set `needsReview` to `true` when the content type is ambiguous, the image is blurry, extraction is incomplete, or key fields remain uncertain.
                - If a "user supplement" block is present, treat it as extra context for disambiguation. If it conflicts with the source, prefer confirmed facts and keep `needsReview = true`.
                - If previous analysis, clarification history, or skipped-question blocks are present, treat them as extra context. Do not repeat the same kind of skipped question unless it is still the only blocking gap and you can clearly justify asking it again.
                - When key gaps remain, also populate `clarification`:
                  1. `uncertaintySummary` should name the most important uncertainty
                  2. `impactExplanation` should explain why it blocks reliable ingestion, retrieval, or QA
                  3. `questions` should contain only the top 1 to 3 highest-value questions in priority order
                - Hard rule: if `needsReview = true`, then `clarification.questions` must contain at least 1 answerable question. `clarification.questions` may be empty only when `needsReview = false`.
                - Each question must be grounded in the actual source and the remaining gaps. Do not ask mechanical category/use/field questions unless the content truly requires them.
                - Each question may include at most 3 short mutually exclusive suggested options.
                - If the item is already usable, do not ask anything else. In that case return empty strings for `clarification.uncertaintySummary` and `clarification.impactExplanation`, and an empty `clarification.questions` array.
                - Default `title`, `shortSummary`, and `tags` to English unless exact source terms should remain in their original language.
                - Return JSON only with no explanation.
                """
            }
        }

        var normalizedTextLabel: String {
            switch language {
            case .simplifiedChinese: return "标准化文本"
            case .english: return "Normalized text"
            }
        }

        var fallbackMetadataLabel: String {
            switch language {
            case .simplifiedChinese: return "补充元数据"
            case .english: return "Fallback metadata"
            }
        }

        var userSupplementLabel: String {
            switch language {
            case .simplifiedChinese: return "用户补充上下文"
            case .english: return "User supplement"
            }
        }

        var urlContextLabel: String {
            switch language {
            case .simplifiedChinese: return "提取到的网页链接"
            case .english: return "Detected web links"
            }
        }

        var urlContextInstruction: String {
            switch language {
            case .simplifiedChinese:
                return "请使用 URL Context 读取这些网页，把网页正文里的关键信息也纳入分析。若网页内容与链接周围的零散文本不一致，优先采用网页中可确认的事实。"
            case .english:
                return "Use URL Context to read these pages and fold the page content into the analysis. If the fetched page conflicts with loose surrounding text, prefer verifiable facts from the page itself."
            }
        }

        var userSupplementMetadataKey: String { "__casebase_userSupplement" }

        var clarificationRepairInstruction: String {
            switch language {
            case .simplifiedChinese:
                return "上一个结果里出现了 `needsReview = true` 但没有给出可补全问题。这是不允许的。请重新生成完整 JSON：如果仍然需要复核，必须在 `clarification.questions` 中给出 1 到 3 个具体可回答的问题；如果确实不需要追问，就把 `needsReview` 改成 false。"
            case .english:
                return "The previous result set `needsReview = true` without providing any clarification questions. That is invalid. Regenerate the full JSON so that if review is still needed, `clarification.questions` contains 1 to 3 concrete answerable questions. If no follow-up is needed, set `needsReview` to false."
            }
        }

        var analysisResponseJSONSchema: [String: Any] {
            [
                "type": "object",
                "properties": [
                    "contentType": [
                        "type": "string",
                        "description": analysisContentTypeDescription,
                    ],
                    "scene": [
                        "type": "string",
                        "description": analysisSceneDescription,
                    ],
                    "purpose": [
                        "type": "string",
                        "description": analysisPurposeDescription,
                    ],
                    "title": [
                        "type": "string",
                        "description": analysisTitleDescription,
                    ],
                    "shortSummary": [
                        "type": "string",
                        "description": analysisSummaryDescription,
                    ],
                    "usefulSnippets": [
                        "type": "array",
                        "description": analysisSnippetsDescription,
                        "items": [
                            "type": "string",
                        ],
                    ],
                    "tags": [
                        "type": "array",
                        "description": analysisTagsDescription,
                        "items": [
                            "type": "string",
                        ],
                    ],
                    "structuredData": [
                        "type": "object",
                        "description": analysisStructuredDataDescription,
                        "additionalProperties": true,
                    ],
                    "searchText": [
                        "type": "string",
                        "description": analysisSearchTextDescription,
                    ],
                    "needsReview": [
                        "type": "boolean",
                        "description": analysisNeedsReviewDescription,
                    ],
                    "clarification": clarificationSchema,
                ],
                "required": [
                    "contentType",
                    "scene",
                    "purpose",
                    "title",
                    "shortSummary",
                    "tags",
                    "usefulSnippets",
                    "structuredData",
                    "searchText",
                    "needsReview",
                    "clarification",
                ],
                "additionalProperties": false,
            ]
        }

        var answerAppPreamble: String {
            switch language {
            case .simplifiedChinese: return "你正在个人知识应用中回答用户的问题。"
            case .english: return "You are answering a user inside a personal knowledge app."
            }
        }

        var answerNoHitsDetail: String {
            switch language {
            case .simplifiedChinese: return "这次提问没有检索到已保存的资料。"
            case .english: return "No stored records were retrieved for this question."
            }
        }

        var answerNoHitsInstruction: String {
            switch language {
            case .simplifiedChinese: return "明确说明当前资料不足，不要用资料库之外的知识补齐答案。不要提到引用、记录 ID 或内部检索过程。默认使用简体中文。"
            case .english: return "State plainly that the saved evidence is insufficient. Do not fill the gap with outside knowledge. Do not mention citations, record IDs, or internal retrieval steps. Default to English."
            }
        }

        var answerGuardrails: String {
            switch language {
            case .simplifiedChinese:
                return """
                不要编造与资料冲突的精确事实。
                不要输出引用语法、记录 ID 或方括号编号。
                默认使用简体中文给出简洁、直接的回答。
                """
            case .english:
                return """
                Do not fabricate exact facts that conflict with the provided records.
                Do not output citation syntax, IDs, or bracket numbers.
                Give a concise direct answer in English.
                """
            }
        }

        var attributionLead: String {
            switch language {
            case .simplifiedChinese:
                return """
                判断哪些检索结果直接支持最终答案。
                只返回 JSON。
                规则：
                - `citations` 中的 `index` 必须填写 1-based 的资料序号，且这些资料要对最终答案有实质支撑。
                - 只有在资料确实被使用，或明确支持某个事实时，才能把它加入 `citations`。
                - `supportNote` 要简短说明这条资料支持了答案的哪一部分。对于图片，可以说明图中可见的事实。
                - 如果答案中有任何部分依赖记录之外的推理或知识，`usedModelSupplement` 必须为 true。
                """
            case .english:
                return """
                Decide which retrieved records directly support the answer.
                Return JSON only.
                Rules:
                - Each `citations[index]` must use a 1-based source index that materially supports the final answer.
                - Only include sources that were actually used or clearly support a specific factual claim.
                - `supportNote` should briefly explain what part of the answer each source supports. For images, describe the visible evidence.
                - `usedModelSupplement` must be true if any part of the answer relies on reasoning or knowledge not directly supported by the records.
                """
            }
        }

        var userQuestionLabel: String {
            switch language {
            case .simplifiedChinese: return "用户问题"
            case .english: return "User question"
            }
        }

        var finalAnswerLabel: String {
            switch language {
            case .simplifiedChinese: return "最终回答"
            case .english: return "Final answer"
            }
        }

        var retrievedRecordsLabel: String {
            switch language {
            case .simplifiedChinese: return "检索到的资料"
            case .english: return "Retrieved records"
            }
        }

        var recordTitleLabel: String {
            switch language {
            case .simplifiedChinese: return "标题"
            case .english: return "Title"
            }
        }

        var recordSummaryLabel: String {
            switch language {
            case .simplifiedChinese: return "摘要"
            case .english: return "Summary"
            }
        }

        var recordTypePromptLabel: String {
            switch language {
            case .simplifiedChinese: return "来源类型"
            case .english: return "Source type"
            }
        }

        var recordScenePromptLabel: String {
            switch language {
            case .simplifiedChinese: return "场景"
            case .english: return "Scene"
            }
        }

        var recordPurposePromptLabel: String {
            switch language {
            case .simplifiedChinese: return "用途"
            case .english: return "Purpose"
            }
        }

        var recordTagsLabel: String {
            switch language {
            case .simplifiedChinese: return "标签"
            case .english: return "Tags"
            }
        }

        var recordSnippetsLabel: String {
            switch language {
            case .simplifiedChinese: return "片段"
            case .english: return "Snippets"
            }
        }

        var recordEvidencePromptLabel: String {
            switch language {
            case .simplifiedChinese: return "证据摘录"
            case .english: return "Evidence excerpt"
            }
        }

        var recordSourceTextPromptLabel: String {
            switch language {
            case .simplifiedChinese: return "原始内容"
            case .english: return "Original content"
            }
        }

        var attributionJSONSchema: [String: Any] {
            [
                "type": "object",
                "properties": [
                    "citations": [
                        "type": "array",
                        "description": attributionCitedIndexesDescription,
                        "items": [
                            "type": "object",
                            "properties": [
                                "index": [
                                    "type": "integer",
                                    "description": attributionCitedIndexesDescription,
                                ],
                                "supportNote": [
                                    "type": "string",
                                    "description": attributionSupportNoteDescription,
                                ],
                            ],
                            "required": [
                                "index",
                                "supportNote",
                            ],
                            "additionalProperties": false,
                        ],
                    ],
                    "usedModelSupplement": [
                        "type": "boolean",
                        "description": attributionModelSupplementDescription,
                    ],
                ],
                "required": [
                    "citations",
                    "usedModelSupplement",
                ],
                "additionalProperties": false,
            ]
        }

        func answerInstruction(for scope: AnswerScope) -> String {
            switch language {
            case .simplifiedChinese:
                switch scope {
                case .knowledgeOnly:
                    return "只能根据提供的资料回答；如果资料不够，就直接说明。"
                case .knowledgeFirst:
                    return "优先根据提供的资料回答；如果资料不够，先说明缺口，再补充少量模型常识。"
                case .openEnded:
                    return "优先利用提供的资料；如果资料不够，也可以自由回答。"
                }
            case .english:
                switch scope {
                case .knowledgeOnly:
                    return "Answer only from the provided records. If they are insufficient, say so plainly."
                case .knowledgeFirst:
                    return "Prefer the provided records. If they are insufficient, state the gap before adding limited model knowledge."
                case .openEnded:
                    return "Prefer the provided records when they help, but you may answer freely if they are insufficient."
                }
            }
        }

        func answerPrompt(question: String, sources: [AnswerEvidencePacket], policy: AnswerPolicy) -> String {
            if sources.isEmpty {
                return """
                \(answerAppPreamble)
                \(answerNoHitsDetail)
                \(answerNoHitsInstruction)

                \(userQuestionLabel):
                \(question)
                """
            }

            return """
            \(answerAppPreamble)
            \(answerInstruction(for: policy.scope))
            \(answerGuardrails)

            \(userQuestionLabel):
            \(question)

            \(retrievedRecordsLabel):
            \(numberedRecordContext(from: sources))
            """
        }

        func attributionPrompt(question: String, answerText: String, sources: [AnswerEvidencePacket]) -> String {
            """
            \(attributionLead)

            \(userQuestionLabel):
            \(question)

            \(finalAnswerLabel):
            \(answerText)

            \(retrievedRecordsLabel):
            \(numberedRecordContext(from: sources))
            """
        }

        private func numberedRecordContext(from sources: [AnswerEvidencePacket]) -> String {
            sources.enumerated().map { offset, source in
                let record = source.record
                let tags = record.tags.joined(separator: ", ")
                let evidenceExcerpt = source.evidenceExcerpt ?? ""
                let sourceText = source.modelTextContext ?? ""

                return """
                [\(offset + 1)]
                \(recordTitleLabel): \(record.title)
                \(recordTypePromptLabel): \(record.sourceKind.rawValue)
                \(recordScenePromptLabel): \(record.scene)
                \(recordPurposePromptLabel): \(record.purpose)
                \(recordSummaryLabel): \(record.shortSummary)
                \(recordTagsLabel): \(tags)
                \(recordEvidencePromptLabel): \(evidenceExcerpt)
                \(recordSourceTextPromptLabel): \(sourceText)
                """
            }
            .joined(separator: "\n\n")
        }

        private var analysisTitleDescription: String {
            switch language {
            case .simplifiedChinese: return "该条资料的简短可读标题。"
            case .english: return "Short human-readable title for the captured item."
            }
        }

        private var analysisContentTypeDescription: String {
            switch language {
            case .simplifiedChinese: return "内容类型或资料类别，例如客户资料、营养成分表、账单、合同、聊天截图。"
            case .english: return "The inferred content type or record category, such as client info, nutrition facts, invoice, contract, or chat screenshot."
            }
        }

        private var analysisSceneDescription: String {
            switch language {
            case .simplifiedChinese: return "未来最可能复用它的场景，例如工作跟进、饮食记录、报销查找、身份核验。"
            case .english: return "The future scenario where this is most likely to be reused, such as follow-up work, diet tracking, reimbursement lookup, or identity verification."
            }
        }

        private var analysisPurposeDescription: String {
            switch language {
            case .simplifiedChinese: return "这条内容的真实用途，说明它为什么值得保存。"
            case .english: return "The real purpose of this content and why it is worth saving."
            }
        }

        private var analysisSummaryDescription: String {
            switch language {
            case .simplifiedChinese: return "适合浏览和检索的一句短摘要。"
            case .english: return "One short summary line for browsing and retrieval."
            }
        }

        private var attributionSupportNoteDescription: String {
            switch language {
            case .simplifiedChinese: return "简短说明这条资料具体支持了答案的哪一部分。"
            case .english: return "Briefly explain which part of the answer this source supports."
            }
        }

        private var analysisSnippetsDescription: String {
            switch language {
            case .simplifiedChinese: return "值得长期保留的原始事实或短原文片段。"
            case .english: return "Reusable raw facts or short source snippets worth preserving."
            }
        }

        private var analysisTagsDescription: String {
            switch language {
            case .simplifiedChinese: return "简短、可搜索的标签。"
            case .english: return "Short search labels."
            }
        }

        private var analysisStructuredDataDescription: String {
            switch language {
            case .simplifiedChinese: return "最重要的结构化字段集合；未知字段可填 null。"
            case .english: return "The most important structured fields for this item; unknown fields may be null."
            }
        }

        private var analysisSearchTextDescription: String {
            switch language {
            case .simplifiedChinese: return "用于检索的高密度文本，组合标题、类别、用途、标签、关键事实与未来可能的查询方式。"
            case .english: return "Dense retrieval text combining title, category, purpose, tags, key facts, and likely future search phrasings."
            }
        }

        private var analysisNeedsReviewDescription: String {
            switch language {
            case .simplifiedChinese: return "当内容模糊、字段不完整或存在歧义时为 true；若为 true，必须同时提供至少 1 个 clarification 问题。"
            case .english: return "True when the item remains blurry, incomplete, or ambiguous and should be reviewed; when true, you must also provide at least 1 clarification question."
            }
        }

        private var clarificationSchema: [String: Any] {
            [
                "type": "object",
                "properties": [
                    "uncertaintySummary": [
                        "type": "string",
                        "description": clarificationUncertaintyDescription,
                    ],
                    "impactExplanation": [
                        "type": "string",
                        "description": clarificationImpactDescription,
                    ],
                    "questions": [
                        "type": "array",
                        "description": clarificationQuestionsDescription,
                        "items": [
                            "type": "object",
                            "properties": [
                                "title": [
                                    "type": "string",
                                    "description": clarificationQuestionTitleDescription,
                                ],
                                "reason": [
                                    "type": "string",
                                    "description": clarificationQuestionReasonDescription,
                                ],
                                "suggestedOptions": [
                                    "type": "array",
                                    "description": clarificationQuestionOptionsDescription,
                                    "items": [
                                        "type": "string",
                                    ],
                                ],
                            ],
                            "required": [
                                "title",
                                "reason",
                                "suggestedOptions",
                            ],
                            "additionalProperties": false,
                        ],
                    ],
                ],
                "required": [
                    "uncertaintySummary",
                    "impactExplanation",
                    "questions",
                ],
                "additionalProperties": false,
            ]
        }

        private var clarificationUncertaintyDescription: String {
            switch language {
            case .simplifiedChinese: return "最关键的不确定点；如果不需要继续追问，返回空字符串。"
            case .english: return "The most important uncertainty. Return an empty string when no clarification is needed."
            }
        }

        private var clarificationImpactDescription: String {
            switch language {
            case .simplifiedChinese: return "为什么这个不确定点会影响可靠理解、入库、检索或后续问答；如果不需要继续追问，返回空字符串。"
            case .english: return "Why that uncertainty affects reliable understanding, ingestion, retrieval, or later QA. Return an empty string when no clarification is needed."
            }
        }

        private var clarificationQuestionsDescription: String {
            switch language {
            case .simplifiedChinese: return "按信息价值排序的 1 到 3 个澄清问题；当 needsReview 为 true 时这里不能为空，只有信息已经足够且 needsReview 为 false 时才返回空数组。"
            case .english: return "1 to 3 clarification questions sorted by information value. This must be non-empty when needsReview is true, and may be empty only when the item is already usable and needsReview is false."
            }
        }

        private var clarificationQuestionTitleDescription: String {
            switch language {
            case .simplifiedChinese: return "要问用户的短问题。"
            case .english: return "Short question to ask the user."
            }
        }

        private var clarificationQuestionReasonDescription: String {
            switch language {
            case .simplifiedChinese: return "为什么要问这个问题。"
            case .english: return "Why this question matters."
            }
        }

        private var clarificationQuestionOptionsDescription: String {
            switch language {
            case .simplifiedChinese: return "最多 3 个简短、互斥、可点击的推荐答案。"
            case .english: return "Up to 3 short mutually exclusive suggested answers."
            }
        }

        private var attributionCitedIndexesDescription: String {
            switch language {
            case .simplifiedChinese: return "直接支持答案的检索记录序号，使用 1-based 索引。"
            case .english: return "1-based indexes of retrieved records that directly support the answer."
            }
        }

        private var attributionModelSupplementDescription: String {
            switch language {
            case .simplifiedChinese: return "当答案中包含记录之外的推理或知识时为 true。"
            case .english: return "True when the answer includes reasoning or knowledge not directly backed by the provided records."
            }
        }
    }

    struct Fallback {
        let language: CasebaseLanguage

        func contentType(for sourceKind: ImportSourceKind) -> String {
            switch (language, sourceKind) {
            case (.simplifiedChinese, .image):
                return "图片资料"
            case (.simplifiedChinese, .text):
                return "文本资料"
            case (.simplifiedChinese, .pdf):
                return "PDF 文档"
            case (.simplifiedChinese, .audio):
                return "音频资料"
            case (.simplifiedChinese, .binary):
                return "文件资料"
            case (.english, .image):
                return "Image capture"
            case (.english, .text):
                return "Text capture"
            case (.english, .pdf):
                return "PDF document"
            case (.english, .audio):
                return "Audio capture"
            case (.english, .binary):
                return "File capture"
            }
        }

        func scene(for sourceKind: ImportSourceKind, fileName: String, rawText: String?) -> String {
            if let rawText, containsNutritionHints(in: rawText) {
                return language == .simplifiedChinese ? "饮食记录与营养查找" : "Diet tracking and nutrition lookup"
            }
            if let rawText, containsContactHints(in: rawText) {
                return language == .simplifiedChinese ? "工作跟进与联系人查找" : "Work follow-up and contact lookup"
            }

            switch (language, sourceKind) {
            case (.simplifiedChinese, .image), (.simplifiedChinese, .pdf), (.simplifiedChinese, .text):
                return "后续检索与问答"
            case (.simplifiedChinese, .audio), (.simplifiedChinese, .binary):
                return "资料留存与后续检索"
            case (.english, .image), (.english, .pdf), (.english, .text):
                return "Future lookup and question answering"
            case (.english, .audio), (.english, .binary):
                return "Reference storage and later lookup"
            }
        }

        func purpose(for sourceKind: ImportSourceKind, fileName: String, rawText: String?) -> String {
            if let rawText, containsNutritionHints(in: rawText) {
                return language == .simplifiedChinese ? "保留食品营养与配料信息，便于后续热量计算与饮食决策" : "Preserve nutrition and ingredient facts for later calorie math and food decisions"
            }
            if let rawText, containsContactHints(in: rawText) {
                return language == .simplifiedChinese ? "保留联系人与关键约定，便于后续跟进" : "Preserve contact facts and key commitments for follow-up"
            }

            switch (language, sourceKind) {
            case (.simplifiedChinese, .image), (.simplifiedChinese, .pdf), (.simplifiedChinese, .text):
                return "保留关键信息，便于未来搜索、比对和引用"
            case (.simplifiedChinese, .audio), (.simplifiedChinese, .binary):
                return "留存原始资料，供未来检索与复用"
            case (.english, .image), (.english, .pdf), (.english, .text):
                return "Preserve key facts for future search, comparison, and reuse"
            case (.english, .audio), (.english, .binary):
                return "Keep the source material available for later lookup and reuse"
            }
        }

        func title(for sourceKind: ImportSourceKind, fileName: String) -> String {
            switch (language, sourceKind) {
            case (.simplifiedChinese, .image):
                return "图片资料：\(fileName)"
            case (.simplifiedChinese, .text):
                return "文本资料：\(fileName)"
            case (.simplifiedChinese, .pdf):
                return "PDF 资料：\(fileName)"
            case (.simplifiedChinese, .audio):
                return "音频资料：\(fileName)"
            case (.simplifiedChinese, .binary):
                return "文件资料：\(fileName)"
            case (.english, .image):
                return "Image Capture: \(fileName)"
            case (.english, .text):
                return "Text Capture: \(fileName)"
            case (.english, .pdf):
                return "PDF Capture: \(fileName)"
            case (.english, .audio):
                return "Audio Capture: \(fileName)"
            case (.english, .binary):
                return "File Capture: \(fileName)"
            }
        }

        func summary(fileName: String, rawText: String?, metadata: [String: String]) -> String {
            let metadataSummary = metadata
                .sorted { $0.key < $1.key }
                .prefix(3)
                .map { "\($0.key): \($0.value)" }
                .joined(separator: language == .simplifiedChinese ? "，" : ", ")

            if let rawText, !rawText.isEmpty {
                return String(rawText.prefix(120))
            }

            if !metadataSummary.isEmpty {
                switch language {
                case .simplifiedChinese:
                    return "已保存 \(fileName)。\(metadataSummary)"
                case .english:
                    return "Saved \(fileName). \(metadataSummary)"
                }
            }

            switch language {
            case .simplifiedChinese:
                return "已保存 \(fileName)，后续可用于检索和问答。"
            case .english:
                return "Saved \(fileName). It can now be retrieved and used for question answering."
            }
        }

        func structuredData(fileName: String, rawText: String?, metadata: [String: String]) -> [String: StructuredFieldValue] {
            var result: [String: StructuredFieldValue] = [
                "fileName": .string(fileName),
            ]

            if let rawText, !rawText.isEmpty {
                result["excerpt"] = .string(String(rawText.prefix(160)))
            }

            for (key, value) in metadata.sorted(by: { $0.key < $1.key }).prefix(6) {
                result[key] = .string(value)
            }

            return result
        }

        func snippets(rawText: String?, metadata: [String: String]) -> [String] {
            if let rawText, !rawText.isEmpty {
                return rawText
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .prefix(3)
                    .map { String($0.prefix(180)) }
            }

            return metadata
                .sorted { $0.key < $1.key }
                .prefix(3)
                .map { "\($0.key): \($0.value)" }
        }

        func tags(
            sourceKind: ImportSourceKind,
            mimeType: String?,
            fileName: String,
            hasParsedText: Bool
        ) -> [String] {
            var tags = [sourceKindLabel(for: sourceKind)]
            if let mimeType, !mimeType.isEmpty {
                tags.append(mimeType)
            }
            let fileExtension = URL(fileURLWithPath: fileName).pathExtension
            if !fileExtension.isEmpty {
                tags.append(fileExtension.lowercased())
            }
            tags.append(hasParsedText ? parsedLabel : partialLabel)
            return Array(NSOrderedSet(array: tags)) as? [String] ?? tags
        }

        private func sourceKindLabel(for sourceKind: ImportSourceKind) -> String {
            switch (language, sourceKind) {
            case (.simplifiedChinese, .image):
                return "图片"
            case (.simplifiedChinese, .text):
                return "文本"
            case (.simplifiedChinese, .pdf):
                return "PDF"
            case (.simplifiedChinese, .audio):
                return "音频"
            case (.simplifiedChinese, .binary):
                return "文件"
            case (.english, .image):
                return "image"
            case (.english, .text):
                return "text"
            case (.english, .pdf):
                return "pdf"
            case (.english, .audio):
                return "audio"
            case (.english, .binary):
                return "file"
            }
        }

        private var parsedLabel: String {
            switch language {
            case .simplifiedChinese: return "已解析"
            case .english: return "parsed"
            }
        }

        private var partialLabel: String {
            switch language {
            case .simplifiedChinese: return "部分解析"
            case .english: return "partial"
            }
        }

        private func containsNutritionHints(in text: String) -> Bool {
            let lowered = text.lowercased()
            return lowered.contains("热量")
                || lowered.contains("营养")
                || lowered.contains("配料")
                || lowered.contains("kcal")
                || lowered.contains("protein")
                || lowered.contains("fat")
                || lowered.contains("carb")
        }

        private func containsContactHints(in text: String) -> Bool {
            let lowered = text.lowercased()
            return lowered.contains("电话")
                || lowered.contains("邮箱")
                || lowered.contains("email")
                || lowered.contains("身份证")
                || lowered.contains("contact")
                || lowered.contains("客户")
        }
    }

    struct Errors {
        let language: CasebaseLanguage

        func missingConfiguration(_ name: String) -> String {
            switch language {
            case .simplifiedChinese: return "缺少必要配置：\(name)"
            case .english: return "Missing required configuration: \(name)"
            }
        }

        func unsupportedPayload(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "不支持的导入内容：\(description)"
            case .english: return "Unsupported import payload: \(description)"
            }
        }

        func invalidPayload(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "无效的导入内容：\(description)"
            case .english: return "Invalid import payload: \(description)"
            }
        }

        func normalizationFailed(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "内容标准化失败：\(description)"
            case .english: return "Failed to normalize content: \(description)"
            }
        }

        func analysisFailed(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "内容分析失败：\(description)"
            case .english: return "Failed to analyze content: \(description)"
            }
        }

        func storageFailed(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "知识库访问失败：\(description)"
            case .english: return "Failed to access knowledge store: \(description)"
            }
        }

        func answerFailed(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "回答问题失败：\(description)"
            case .english: return "Failed to answer question: \(description)"
            }
        }

        func operationTimedOut(_ description: String) -> String {
            switch language {
            case .simplifiedChinese: return "处理超时：\(description)"
            case .english: return "Operation timed out: \(description)"
            }
        }

        func recordNotFound(_ id: UUID) -> String {
            switch language {
            case .simplifiedChinese:
                return "未找到对应记录：\(id.uuidString)"
            case .english:
                return "Could not find a stored record for id \(id.uuidString)."
            }
        }

        var emptyQuery: String {
            switch language {
            case .simplifiedChinese: return "问题不能为空。"
            case .english: return "Question cannot be empty."
            }
        }

        var emptyResponse: String {
            switch language {
            case .simplifiedChinese: return "AI 返回了空结果。"
            case .english: return "AI returned an empty response."
            }
        }

        var onlyFileURLsAndPlainTextAreSupported: String {
            switch language {
            case .simplifiedChinese: return "当前只支持拖入文件、直接图片和纯文本。"
            case .english: return "Only files, direct image drops, and plain text are supported."
            }
        }

        var failedToDecodeDroppedFileURL: String {
            switch language {
            case .simplifiedChinese: return "无法解析拖入的文件 URL。"
            case .english: return "Failed to decode dropped file URL."
            }
        }

        var failedToDecodeDroppedText: String {
            switch language {
            case .simplifiedChinese: return "无法解析拖入的文本。"
            case .english: return "Failed to decode dropped text."
            }
        }

        var noRawTextOrPreviewAttachmentsAvailableForAnalysis: String {
            switch language {
            case .simplifiedChinese: return "没有可用于分析的文本或预览附件。"
            case .english: return "No raw text or preview attachments available for analysis."
            }
        }

        func importPayloadExceedsSizeLimit(
            fileName: String,
            sizeDescription: String,
            limitDescription: String
        ) -> String {
            switch language {
            case .simplifiedChinese:
                return "“\(fileName)”大小为 \(sizeDescription)，超过当前可分析上限 \(limitDescription)。请压缩、拆分，或调整大小上限后重试。"
            case .english:
                return "\"\(fileName)\" is \(sizeDescription), which exceeds the current analysis limit of \(limitDescription). Compress it, split it, or raise the limit and try again."
            }
        }

        var cannotEmbedEmptyText: String {
            switch language {
            case .simplifiedChinese: return "无法为一段空文本生成向量。"
            case .english: return "Cannot embed empty text."
            }
        }

        var importStageSavingAsset: String {
            switch language {
            case .simplifiedChinese: return "保存原始文件"
            case .english: return "saving the source asset"
            }
        }

        var importStageExtractingContent: String {
            switch language {
            case .simplifiedChinese: return "提取内容"
            case .english: return "extracting content"
            }
        }

        var importStageAnalyzingContent: String {
            switch language {
            case .simplifiedChinese: return "AI 分析"
            case .english: return "running AI analysis"
            }
        }

        var importStageGeneratingEmbedding: String {
            switch language {
            case .simplifiedChinese: return "生成检索向量"
            case .english: return "generating the embedding"
            }
        }

        var importStageSavingRecord: String {
            switch language {
            case .simplifiedChinese: return "写入知识库"
            case .english: return "saving the record"
            }
        }

        var importStageUpdatingExistingRecord: String {
            switch language {
            case .simplifiedChinese: return "更新已存在记录"
            case .english: return "updating an existing record"
            }
        }

        var geminiReturnedEmptyRequiredFields: String {
            switch language {
            case .simplifiedChinese: return "模型返回了空的必填字段。"
            case .english: return "Gemini returned empty required fields."
            }
        }

        var invalidAIRequestBody: String {
            switch language {
            case .simplifiedChinese: return "模型请求体无效。"
            case .english: return "The model request body was invalid."
            }
        }

        var invalidAIResponse: String {
            switch language {
            case .simplifiedChinese: return "模型返回了无效或损坏的响应。"
            case .english: return "The model returned a malformed or invalid response."
            }
        }

        func httpStatus(_ statusCode: Int, message: String) -> String {
            switch language {
            case .simplifiedChinese: return "HTTP \(statusCode)：\(message)"
            case .english: return "HTTP \(statusCode): \(message)"
            }
        }

        func importTaskTimedOut(seconds: Int, stageDescription: String? = nil) -> String {
            let normalizedStage = stageDescription?.trimmingCharacters(in: .whitespacesAndNewlines)

            switch language {
            case .simplifiedChinese:
                if let normalizedStage, !normalizedStage.isEmpty {
                    return "这次入库在“\(normalizedStage)”阶段超过 \(seconds) 秒仍未完成，已自动停止。请查看 /tmp/casebase-debug.log 确认卡住阶段；如果卡在 AI 分析，再检查代理或网络状态。"
                }
                return "这次入库超过 \(seconds) 秒仍未完成，已自动停止。请查看 /tmp/casebase-debug.log 确认卡住阶段；如果卡在 AI 分析，再检查代理或网络状态。"
            case .english:
                if let normalizedStage, !normalizedStage.isEmpty {
                    return "This import was still in \(normalizedStage) after \(seconds) seconds and was stopped automatically. Check /tmp/casebase-debug.log for the stalled stage; if it is AI analysis, then verify the proxy or network."
                }
                return "This import did not finish within \(seconds) seconds and was stopped automatically. Check /tmp/casebase-debug.log for the stalled stage; if it is AI analysis, then verify the proxy or network."
            }
        }

        func clarificationTaskTimedOut(seconds: Int) -> String {
            switch language {
            case .simplifiedChinese:
                return "这次补全分析超过 \(seconds) 秒仍未完成，已自动停止。请检查代理或网络状态后重试。"
            case .english:
                return "This clarification run did not finish within \(seconds) seconds and was stopped automatically. Check the proxy or network and try again."
            }
        }

        func failedToDecodeAIResponse(_ preview: String) -> String {
            switch language {
            case .simplifiedChinese: return "无法解析模型响应：\(preview)"
            case .english: return "Failed to decode model response: \(preview)"
            }
        }

        func analysisFallbackNeedsManualRetry(reason: String? = nil) -> String {
            let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            switch language {
            case .simplifiedChinese:
                let base = "AI 未能稳定解析这份内容，系统也没有生成可补全的问题，请检查内容清晰度或换一种更完整的输入后重试。"
                guard !trimmedReason.isEmpty else { return base }
                return "\(base) 原因：\(trimmedReason)"
            case .english:
                let base = "AI could not reliably analyze this item and no clarification questions were generated. Please retry with clearer or more complete input."
                guard !trimmedReason.isEmpty else { return base }
                return "\(base) Cause: \(trimmedReason)"
            }
        }

        var analysisNeedsClarificationButProvidedNone: String {
            switch language {
            case .simplifiedChinese:
                return "AI 判断这份内容仍有关键不确定点，但没有生成可补全的问题，因此本次不入库。"
            case .english:
                return "AI marked this item as uncertain but did not provide clarification questions, so it was not saved."
            }
        }

        var clarificationExhaustedWithoutReliableResult: String {
            switch language {
            case .simplifiedChinese:
                return "补全次数已用完，系统仍无法得到可靠结果，因此本次不入库。"
            case .english:
                return "Clarification attempts were exhausted and the result is still not reliable, so the item was not saved."
            }
        }

        var audioExtractionRequiresFileBackedPayload: String {
            switch language {
            case .simplifiedChinese: return "音频提取只能处理文件型导入内容。"
            case .english: return "Audio extraction requires a file-backed payload."
            }
        }

        var payloadIsNotASupportedAudioFile: String {
            switch language {
            case .simplifiedChinese: return "当前导入内容不是受支持的音频文件。"
            case .english: return "Payload is not a supported audio file."
            }
        }

        var fallbackExtractionOnlyAcceptsFileBackedPayloads: String {
            switch language {
            case .simplifiedChinese: return "兜底提取器只能处理文件型导入内容。"
            case .english: return "Fallback extraction only accepts file-backed payloads."
            }
        }

        var imageExtractionRequiresFileBackedPayload: String {
            switch language {
            case .simplifiedChinese: return "图片提取只能处理文件型导入内容。"
            case .english: return "Image extraction requires a file-backed payload."
            }
        }

        var payloadIsNotASupportedImageFile: String {
            switch language {
            case .simplifiedChinese: return "当前导入内容不是受支持的图片文件。"
            case .english: return "Payload is not a supported image file."
            }
        }

        var pdfExtractionRequiresFileBackedPayload: String {
            switch language {
            case .simplifiedChinese: return "PDF 提取只能处理文件型导入内容。"
            case .english: return "PDF extraction requires a file-backed payload."
            }
        }

        var officeExtractionRequiresFileBackedPayload: String {
            switch language {
            case .simplifiedChinese: return "Office 文档提取只能处理文件型导入内容。"
            case .english: return "Office extraction requires a file-backed payload."
            }
        }

        var payloadIsNotASupportedPDFFile: String {
            switch language {
            case .simplifiedChinese: return "当前导入内容不是受支持的 PDF 文件。"
            case .english: return "Payload is not a supported PDF file."
            }
        }

        var payloadIsNotASupportedOfficeFile: String {
            switch language {
            case .simplifiedChinese: return "当前导入内容不是受支持的 Office 文件。"
            case .english: return "Payload is not a supported Office file."
            }
        }

        func unableToOpenPDF(_ fileName: String) -> String {
            switch language {
            case .simplifiedChinese: return "无法打开 PDF：\(fileName)。"
            case .english: return "Unable to open PDF \(fileName)."
            }
        }

        var payloadIsNotASupportedTextFile: String {
            switch language {
            case .simplifiedChinese: return "当前导入内容不是受支持的文本文件。"
            case .english: return "Payload is not a supported text file."
            }
        }

        var failedToEncodePreviewImageAsPNG: String {
            switch language {
            case .simplifiedChinese: return "无法将预览图编码为 PNG。"
            case .english: return "Failed to encode preview image as PNG."
            }
        }

        var failedToPrepareImagePreviewForAnalysis: String {
            switch language {
            case .simplifiedChinese: return "无法为图片生成用于 AI 分析的压缩预览。"
            case .english: return "Failed to prepare a compressed image preview for AI analysis."
            }
        }

        var failedToGenerateDocumentPreview: String {
            switch language {
            case .simplifiedChinese: return "无法为文档生成用于 AI 分析的预览图。"
            case .english: return "Failed to generate a document preview for AI analysis."
            }
        }

        func unableToDecodeTextFile(_ fileName: String) -> String {
            switch language {
            case .simplifiedChinese: return "无法解析文本文件：\(fileName)。"
            case .english: return "Unable to decode text file \(fileName)."
            }
        }

        func audioTranscriptionRequestFailed(_ responseText: String) -> String {
            switch language {
            case .simplifiedChinese: return "音频转写请求失败：\(responseText)"
            case .english: return "Audio transcription request failed: \(responseText)"
            }
        }

        var draggedTextCouldNotBeEncodedAsUTF8: String {
            switch language {
            case .simplifiedChinese: return "拖入文本无法编码为 UTF-8。"
            case .english: return "Dragged text could not be encoded as UTF-8."
            }
        }

        var failedToDecodeAKnowledgeRecordRow: String {
            switch language {
            case .simplifiedChinese: return "无法解析知识库记录。"
            case .english: return "Failed to decode a knowledge record row."
            }
        }

        var failedToEncodeJSONString: String {
            switch language {
            case .simplifiedChinese: return "无法编码 JSON 字符串。"
            case .english: return "Failed to encode JSON string."
            }
        }

        var selectionCapturePermissionRequired: String {
            switch language {
            case .simplifiedChinese: return "需要授予辅助功能权限后，才能通过快捷键读取选中文本。"
            case .english: return "Accessibility permission is required before the shortcut can read selected text."
            }
        }

        var selectionCaptureInputMonitoringPermissionRequired: String {
            switch language {
            case .simplifiedChinese: return "F1 读取选中文本还需要授予输入监听权限，请在系统设置的“隐私与安全性 > 输入监听”中允许 casebase。"
            case .english: return "Using F1 to read selected text also requires Input Monitoring permission. Allow casebase in Privacy & Security > Input Monitoring."
            }
        }

        var selectionCaptureHotKeyRegistrationFailed: String {
            switch language {
            case .simplifiedChinese: return "选中文本快捷键注册失败，可能被系统或其他应用占用。"
            case .english: return "The selected-text shortcut could not be registered. It may already be in use by macOS or another app."
            }
        }

        var selectionCaptureCopyFailed: String {
            switch language {
            case .simplifiedChinese: return "没有成功复制到当前选中的文本。"
            case .english: return "Failed to copy the currently selected text."
            }
        }

        var selectionCaptureNoTextFound: String {
            switch language {
            case .simplifiedChinese: return "当前没有检测到可入库的选中文本。"
            case .english: return "No selected text was detected for import."
            }
        }

        var screenCapturePermissionRequired: String {
            switch language {
            case .simplifiedChinese: return "需要授予屏幕录制权限后，才能通过快捷键截图。"
            case .english: return "Screen Recording permission is required before the screenshot shortcut can run."
            }
        }

        var screenCaptureHotKeyRegistrationFailed: String {
            switch language {
            case .simplifiedChinese: return "截图快捷键注册失败，可能被系统或其他应用占用。"
            case .english: return "The screenshot shortcut could not be registered. It may already be in use by macOS or another app."
            }
        }

        var screenCaptureNoActiveScreen: String {
            switch language {
            case .simplifiedChinese: return "当前没有可用的截图屏幕。"
            case .english: return "No available screen was found for screenshot capture."
            }
        }

        var screenCaptureFailed: String {
            switch language {
            case .simplifiedChinese: return "截图没有成功完成。"
            case .english: return "The screenshot could not be completed."
            }
        }

        var sqliteDatabaseHandleIsUnavailable: String {
            switch language {
            case .simplifiedChinese: return "SQLite 数据库句柄不可用。"
            case .english: return "SQLite database handle is unavailable."
            }
        }

        var importServiceName: String {
            switch language {
            case .simplifiedChinese: return "导入服务"
            case .english: return "Import service"
            }
        }

        var answerServiceName: String {
            switch language {
            case .simplifiedChinese: return "问答服务"
            case .english: return "Answer service"
            }
        }

        var dataResetServiceName: String {
            switch language {
            case .simplifiedChinese: return "数据清理服务"
            case .english: return "Data reset service"
            }
        }

        var libraryServiceName: String {
            switch language {
            case .simplifiedChinese: return "资料库服务"
            case .english: return "Library service"
            }
        }
    }
}
