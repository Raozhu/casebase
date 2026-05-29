import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import SwiftUI

enum NotchLibraryEntry: Identifiable, Equatable {
    case task(NotchIngestTask)
    case record(ImportRecord)

    var id: String {
        switch self {
        case let .task(task):
            return "task-\(task.id.uuidString)"
        case let .record(record):
            return "record-\(record.id.uuidString)"
        }
    }
}

@MainActor
final class NotchViewModel: ObservableObject {
    enum Status: Equatable {
        case collapsed
        case expanded
    }

    enum CollapsedIndicator {
        case warning
        case error
        case recording
        case paused
        case preparing
        case recognizing
        case storing
        case needsInput
        case success
    }

    private enum FailedAction: Equatable {
        case answerQuestion(String)
    }

    enum QuestionContext: Equatable {
        case globalSearch
        case savedRecord
    }

    let hoverInset: CGFloat = -16
    let hoverRange: CGFloat = 32
    let contentPadding: CGFloat = 16
    let idleExpandedPanelSize = CGSize(width: 420, height: 168)
    let hoverExpandedPanelSize = CGSize(width: 420, height: 150)
    let hoverExpandedPanelUnauthorizedMinHeight: CGFloat = 176
    let maxAdaptiveExpandedPanelHeight: CGFloat = 640
    let meetingPreferredPanelHeight: CGFloat = 312
    let meetingMaxPanelHeight: CGFloat = 408
    let libraryPreferredPanelHeight: CGFloat = 384
    let libraryMaxPanelHeight: CGFloat = 456
    let libraryDetailPreferredPanelHeight: CGFloat = 468
    let libraryDetailMaxPanelHeight: CGFloat = 548
    let savedPreviewPreferredPanelHeight: CGFloat = 404
    let savedPreviewMaxPanelHeight: CGFloat = 488
    let searchPreferredPanelHeight: CGFloat = 372
    let searchMaxPanelHeight: CGFloat = 540
    let taskPanelPreferredPanelHeight: CGFloat = 372
    let taskPanelMaxPanelHeight: CGFloat = 520
    let taskRailSpacing: CGFloat = 8
    let taskRailVerticalSpacing: CGFloat = 8
    let taskRailResultDurationNs: UInt64 = 2_000_000_000
    let intakeFeedbackDurationNs: UInt64 = 520_000_000
    let maxClarificationRounds = 3
    let importOperationTimeoutSeconds: TimeInterval = 90
    let meetingImportOperationTimeoutSeconds: TimeInterval = 600

    @Published private(set) var surfaceState: CasebaseSurfaceState = .idle
    @Published private(set) var isDropTargeted = false
    @Published private(set) var isPinnedExpanded = false
    @Published private(set) var activeRecord: ImportRecord?
    @Published private(set) var latestAnswer: AnswerResult?
    @Published private(set) var streamingAnswerText = ""
    @Published private(set) var answerThinkingText = "" {
        didSet {
            refreshAnswerThinkingPlaceholderState()
        }
    }
    @Published private(set) var isWaitingForAnswerStream = false
    @Published private(set) var questionContext: QuestionContext? {
        didSet {
            refreshAnswerThinkingPlaceholderState()
        }
    }
    @Published private(set) var libraryRecords: [ImportRecord] = []
    @Published private(set) var selectedLibraryRecord: ImportRecord?
    @Published private(set) var selectedLibraryTaskID: UUID?
    @Published private(set) var searchConversations: [NotchSearchConversation] = []
    @Published private(set) var activeSearchConversationID: UUID?
    @Published private(set) var searchConversationListVisible = true
    @Published var draftQuestion = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var libraryErrorMessage: String?
    @Published private(set) var noticeMessage: String?
    @Published private(set) var isBusy = false {
        didSet {
            refreshAnswerThinkingPlaceholderState()
        }
    }
    @Published private(set) var isLibraryLoading = false
    @Published private(set) var isDeletingLibraryRecord = false
    @Published private(set) var intakeFeedbackMessage: String?
    @Published private(set) var ingestTasks: [NotchIngestTask] = [] {
        didSet {
            refreshRecognizingPlaceholderState()
        }
    }
    @Published private(set) var feedbackScale: CGFloat = 1
    @Published private(set) var captureSinkProgress: CGFloat = 0
    @Published private(set) var selectionCaptureAuthorized = true
    @Published private(set) var screenshotCaptureAuthorized = true
    @Published private(set) var apiKeyConfigured = CasebaseAPIKeyStore.shared.isConfigured
    @Published private(set) var isDismissed = false
    @Published private(set) var isClearingStoredData = false
    @Published private(set) var selectedFailedTaskID: UUID?
    @Published private(set) var pendingClarificationCancellationTaskID: UUID?
    @Published private(set) var suppressHoverUntilMouseExit = false
    @Published private(set) var recognizingPlaceholderText = ""
    @Published private(set) var answerThinkingPlaceholderText = ""
    @Published var meetingParticipantCount = 2
    @Published var meetingTopic = ""
    @Published private(set) var activeMeetingSession: MeetingRecordingSession?
    @Published private(set) var meetingRecorderPermissionStatus: MeetingRecorderPermissionStatus = .undetermined
    @Published private(set) var isMeetingRecorderBusy = false
    @Published private(set) var meetingErrorMessage: String?

    @Published private(set) var status: Status = .collapsed
    @Published var displayCutoutRect: CGRect
    @Published var screenFrame: CGRect

    private let importCoordinator: ImportCoordinator?
    private let answerService: AnswerService?
    private let libraryService: LibraryService?
    private let dataResetService: DataResetService?
    private let meetingRecorder: CasebaseMeetingRecorder?
    private let storageRootDirectory: URL?
    private let demoModeEnabled: Bool
    private let startupErrorMessage: String?
    private let resultLimit = 6

    private var restoredSurfaceState: CasebaseSurfaceState = .idle
    private var restoredSurfaceStateBeforeSettings: CasebaseSurfaceState = .idle
    private var restoredStatusBeforeSettings: Status = .collapsed
    private var restoredPinnedStateBeforeSettings = false
    private var restoredSurfaceStateBeforeLibrary: CasebaseSurfaceState = .hoverActions
    private var restoredStatusBeforeLibrary: Status = .expanded
    private var restoredPinnedStateBeforeLibrary = false
    private var restoredSurfaceStateBeforeSearch: CasebaseSurfaceState = .hoverActions
    private var restoredStatusBeforeSearch: Status = .expanded
    private var restoredPinnedStateBeforeSearch = false
    private var restoredSurfaceStateBeforeMeeting: CasebaseSurfaceState = .hoverActions
    private var restoredStatusBeforeMeeting: Status = .expanded
    private var restoredPinnedStateBeforeMeeting = false
    private var restoredSurfaceStateBeforeTaskPanel: CasebaseSurfaceState = .idle
    private var restoredStatusBeforeTaskPanel: Status = .collapsed
    private var restoredPinnedStateBeforeTaskPanel = false
    private var lastSubmittedQuestion: String?
    private var lastFailedAction: FailedAction?
    private var queueProcessorTask: Task<Void, Never>?
    private var intakeFeedbackTask: Task<Void, Never>?
    private var finalSuccessTask: Task<Void, Never>?
    private var taskRailResultTask: Task<Void, Never>?
    private var recognizingPlaceholderTask: Task<Void, Never>?
    private var answerThinkingPlaceholderTask: Task<Void, Never>?
    private var finalSuccessVisible = false
    private var transientResultRailVisible = false
    private var measuredExpandedContentHeights: [CasebaseSurfaceState: CGFloat] = [:]
    private var meetingRecorderCancellables: Set<AnyCancellable> = []
    private var apiKeyStoreCancellables: Set<AnyCancellable> = []
    private let searchConversationStoreFileName = "explore_conversations.json"
    private static let chineseLibraryTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private static let englishLibraryTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(
        screenFrame: CGRect,
        displayCutoutRect: CGRect,
        importCoordinator: ImportCoordinator? = nil,
        answerService: AnswerService? = nil,
        libraryService: LibraryService? = nil,
        storageRootDirectory: URL? = nil,
        dataResetService: DataResetService? = nil,
        meetingRecorder: CasebaseMeetingRecorder? = nil,
        demoModeEnabled: Bool = true,
        startupErrorMessage: String? = nil
    ) {
        self.screenFrame = screenFrame
        self.displayCutoutRect = displayCutoutRect
        self.demoModeEnabled = demoModeEnabled
        self.startupErrorMessage = startupErrorMessage
        self.libraryService = libraryService
        self.storageRootDirectory = storageRootDirectory
        self.dataResetService = dataResetService
        self.meetingRecorder = meetingRecorder

        if let importCoordinator {
            self.importCoordinator = importCoordinator
        } else if demoModeEnabled {
            self.importCoordinator = MockImportCoordinator()
        } else {
            self.importCoordinator = nil
        }

        if let answerService {
            self.answerService = answerService
        } else if demoModeEnabled {
            self.answerService = MockAnswerService()
        } else {
            self.answerService = nil
        }

        refreshShortcutPermissions()
        bindAPIKeyStore()
        bindMeetingRecorder()
        loadSearchConversations()
    }

    var isExpanded: Bool {
        status == .expanded || (shouldRemainExpanded && !isDismissed)
    }

    var surfaceSize: CGSize {
        isExpanded
            ? CGSize(width: expandedPanelSize.width, height: expandedSurfaceHeight)
            : CGSize(
                width: max(0, displayCutoutRect.width) + collapsedLeadingExtensionWidth + collapsedTrailingExtensionWidth,
                height: max(0, displayCutoutRect.height + 1)
            )
    }

    var collapsedLeadingExtensionWidth: CGFloat {
        guard collapsedIndicator != nil, !isExpanded else { return 0 }
        return 34
    }

    var collapsedTrailingExtensionWidth: CGFloat {
        guard collapsedTrailingText != nil, !isExpanded else { return 0 }
        return 34
    }

    var surfaceHorizontalOffset: CGFloat {
        (collapsedTrailingExtensionWidth - collapsedLeadingExtensionWidth) / 2
    }

    var expandedPanelSize: CGSize {
        switch surfaceState {
        case .idle:
            return idleExpandedPanelSize
        case .hoverActions:
            return CGSize(
                width: hoverExpandedPanelSize.width,
                height: adaptiveExpandedHeight(
                    for: .hoverActions,
                    minimum: hasHoverActionPrompt
                        ? hoverExpandedPanelUnauthorizedMinHeight
                        : hoverExpandedPanelSize.height
                )
            )
        case .meeting:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .meeting, minimum: 248))
        case .meetingDiscardConfirmation:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .meetingDiscardConfirmation, minimum: 248))
        case .meetingFinishConfirmation:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .meetingFinishConfirmation, minimum: 248))
        case .library:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .library, minimum: 220))
        case .libraryDetail:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .libraryDetail, minimum: 300))
        case .settings:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .settings, minimum: 320))
        case .settingsAPIKeys:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .settingsAPIKeys, minimum: 360))
        case .settingsDataResetConfirmation:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .settingsDataResetConfirmation, minimum: 280))
        case .dropTarget:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .dropTarget, minimum: 220))
        case .intakeFeedback:
            return CGSize(width: 250, height: adaptiveExpandedHeight(for: .intakeFeedback, minimum: 92))
        case .taskPanel:
            return CGSize(width: 620, height: adaptiveExpandedHeight(for: .taskPanel, minimum: 260))
        case .ingesting, .error:
            let minimumHeight: CGFloat = surfaceState == .error ? 220 : 220
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: surfaceState, minimum: minimumHeight))
        case .savedPreview:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .savedPreview, minimum: 260))
        case .search:
            return CGSize(width: 560, height: adaptiveExpandedHeight(for: .search, minimum: 320))
        case .answering:
            return CGSize(width: 560, height: adaptiveExpandedHeight(for: .answering, minimum: 320))
        case .answerReady:
            return CGSize(width: 560, height: adaptiveExpandedHeight(for: .answerReady, minimum: 340))
        }
    }

    var expandedContentTopInset: CGFloat {
        max(0, displayCutoutRect.height - contentPadding + 1)
    }

    var expandedSurfaceHeight: CGFloat {
        expandedPanelSize.height + expandedContentTopInset + (contentPadding * 2)
    }

    var surfaceRect: CGRect {
        CGRect(
            x: screenFrame.origin.x + (screenFrame.width - surfaceSize.width) / 2 + surfaceHorizontalOffset,
            y: screenFrame.origin.y + screenFrame.height - surfaceSize.height,
            width: surfaceSize.width,
            height: surfaceSize.height
        )
    }

    var hoverRect: CGRect {
        surfaceRect.insetBy(dx: hoverInset, dy: hoverInset)
    }

    var cornerRadius: CGFloat {
        isExpanded ? 32 : 8
    }

    var allowsQuestionInput: Bool {
        surfaceState == .savedPreview || surfaceState == .search || surfaceState == .answerReady
    }

    var answerComposerPlaceholder: String {
        switch questionContext {
        case .globalSearch:
            return CasebasePromptCatalog.ui.searchComposerPlaceholder
        case .savedRecord, .none:
            return CasebasePromptCatalog.ui.composerPlaceholder
        }
    }

    var answerPanelTitle: String {
        switch questionContext {
        case .globalSearch:
            return CasebasePromptCatalog.ui.searchPanelTitle
        case .savedRecord:
            return activeRecord?.title ?? CasebasePromptCatalog.ui.savedLabel
        case .none:
            return CasebasePromptCatalog.ui.answerLabel
        }
    }

    var answerPanelDetail: String {
        switch questionContext {
        case .globalSearch:
            return ""
        case .savedRecord:
            return activeRecord?.shortSummary ?? ""
        case .none:
            return ""
        }
    }

    var answerPanelMetaLine: String? {
        guard questionContext == .savedRecord, let activeRecord else {
            return nil
        }
        return "\(activeRecord.scene) · \(activeRecord.purpose)"
    }

    var answerPanelShowsBackButton: Bool {
        questionContext != nil
    }

    var activeSearchConversation: NotchSearchConversation? {
        guard let activeSearchConversationID else { return nil }
        return searchConversations.first(where: { $0.id == activeSearchConversationID })
    }

    var orderedSearchConversations: [NotchSearchConversation] {
        searchConversations.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var activeSearchConversationTurns: [NotchSearchConversationTurn] {
        activeSearchConversation?.turns ?? []
    }

    var activeSearchConversationSummary: String? {
        guard let conversation = activeSearchConversation else { return nil }
        return conversation.title
    }

    var activeSearchConversationTags: [String] {
        guard questionContext == .globalSearch,
              !searchConversationListVisible,
              let conversation = activeSearchConversation
        else {
            return []
        }

        return topTags(for: conversation)
    }

    var activeSearchAnswer: AnswerResult? {
        if let latestAnswer {
            return latestAnswer
        }
        return activeSearchConversation?.turns.last?.answer
    }

    var activeSearchPendingQuestion: String? {
        guard questionContext == .globalSearch, isBusy else { return nil }
        let trimmed = (lastSubmittedQuestion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var showsSearchConversationList: Bool {
        questionContext == .globalSearch && searchConversationListVisible
    }

    var showsSearchConversationDeleteButton: Bool {
        questionContext == .globalSearch && !searchConversationListVisible && activeSearchConversation != nil
    }

    var showsSearchConversationListButton: Bool {
        questionContext == .globalSearch && !searchConversationListVisible && !orderedSearchConversations.isEmpty
    }

    var answerDisplayText: String? {
        if questionContext == .globalSearch,
           !isBusy,
           let answerText = activeSearchConversation?.turns.last?.answer.answerText,
           !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return answerText
        }

        if let latestAnswer {
            return latestAnswer.answerText
        }

        let trimmedStreaming = streamingAnswerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStreaming.isEmpty {
            return trimmedStreaming
        }

        return nil
    }

    var answerThinkingDisplayText: String {
        let trimmed = answerThinkingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !answerThinkingPlaceholderText.isEmpty {
            return answerThinkingPlaceholderText
        }
        return localizedPreviewLabel(chinese: "正在思考中…", english: "Thinking…")
    }

    var canOpenDataResetConfirmation: Bool {
        unfinishedTaskCount == 0 && !isBusy && !isClearingStoredData
    }

    var meetingPanelTitle: String {
        if activeMeetingSession?.isPaused == true {
            return CasebasePromptCatalog.ui.meetingPausedTitle
        }
        if activeMeetingSession != nil {
            return CasebasePromptCatalog.ui.meetingRecordingTitle
        }
        return CasebasePromptCatalog.ui.meetingDraftTitle
    }

    var meetingElapsedDurationText: String {
        formatDuration(activeMeetingSession?.elapsedDuration ?? 0)
    }

    var meetingParticipantValueText: String {
        CasebasePromptCatalog.ui.meetingParticipantValue(activeMeetingSession?.participantCount ?? meetingParticipantCount)
    }

    var meetingTopicValueText: String {
        let topic = (activeMeetingSession?.topic ?? meetingTopic).trimmingCharacters(in: .whitespacesAndNewlines)
        return topic.isEmpty ? CasebasePromptCatalog.ui.meetingTopicEmptyValue : topic
    }

    var hasActiveMeetingSession: Bool {
        activeMeetingSession != nil
    }

    var isMeetingPaused: Bool {
        activeMeetingSession?.isPaused == true
    }

    var meetingDiscardConfirmationTitle: String {
        CasebasePromptCatalog.ui.meetingDiscardConfirmationTitle
    }

    var meetingDiscardConfirmationDetail: String {
        CasebasePromptCatalog.ui.meetingDiscardConfirmationDetail(durationText: meetingElapsedDurationText)
    }

    var meetingDiscardConfirmationConfirmTitle: String {
        CasebasePromptCatalog.ui.meetingDiscardConfirmationConfirmTitle
    }

    var meetingFinishConfirmationTitle: String {
        CasebasePromptCatalog.ui.meetingFinishConfirmationTitle
    }

    var meetingFinishConfirmationDetail: String {
        CasebasePromptCatalog.ui.meetingFinishConfirmationDetail(durationText: meetingElapsedDurationText)
    }

    var meetingFinishConfirmationConfirmTitle: String {
        CasebasePromptCatalog.ui.meetingFinishConfirmationConfirmTitle
    }

    var hasMissingShortcutPermissions: Bool {
        !selectionCaptureAuthorized || !screenshotCaptureAuthorized
    }

    var failedTasks: [NotchIngestTask] {
        ingestTasks.filter { task in
            if case .failed = task.status {
                return true
            }
            return false
        }
    }

    var selectedFailedTask: NotchIngestTask? {
        if let selectedFailedTaskID,
           let task = failedTasks.first(where: { $0.id == selectedFailedTaskID }) {
            return task
        }
        return failedTasks.first
    }

    var hasMultipleFailedTasks: Bool {
        failedTasks.count > 1
    }

    var collapsedIndicator: CollapsedIndicator? {
        if !failedTasks.isEmpty || (surfaceState == .error && errorMessage != nil) {
            return .error
        }
        if let meetingIndicator = currentMeetingCollapsedIndicator {
            return meetingIndicator
        }
        if isAnswerRailActive {
            return .recognizing
        }
        if let taskIndicator = currentCollapsedTaskIndicator {
            return taskIndicator
        }
        if hasMissingShortcutPermissions {
            return .warning
        }
        return nil
    }

    var shouldRemainExpanded: Bool {
        surfaceState.keepsExpandedPresentation || isPinnedExpanded || isDropTargeted
    }

    var unfinishedTaskCount: Int {
        ingestTasks.filter(\.isPending).count
    }

    var taskPanelTasks: [NotchIngestTask] {
        ingestTasks.sorted { lhs, rhs in
            taskSortKey(lhs.status) < taskSortKey(rhs.status)
        }
    }

    var libraryEntries: [NotchLibraryEntry] {
        pendingLibraryTasks.map(NotchLibraryEntry.task) + libraryRecords.map(NotchLibraryEntry.record)
    }

    var selectedLibraryTask: NotchIngestTask? {
        guard let selectedLibraryTaskID else { return nil }
        return ingestTasks.first(where: { $0.id == selectedLibraryTaskID })
    }

    var firstNeedsInputTask: NotchIngestTask? {
        ingestTasks.first { task in
            if case .needsInput = task.status {
                return true
            }
            return false
        }
    }

    private var isAnswerRailActive: Bool {
        questionContext != nil
            && isBusy
            && isWaitingForAnswerStream
            && errorMessage == nil
    }

    var showsTaskRail: Bool {
        guard status == .collapsed else {
            return false
        }
        guard surfaceState != .dropTarget, surfaceState != .intakeFeedback else {
            return false
        }
        if isAnswerRailActive {
            return true
        }
        guard (unfinishedTaskCount > 0 || finalSuccessVisible) && failedTasks.isEmpty && errorMessage == nil else {
            return false
        }

        switch taskRailState {
        case .preparing, .recognizing, .storing:
            return true
        case .needsInput, .success:
            return transientResultRailVisible
        }
    }

    private var hasSuccessfulTasks: Bool {
        ingestTasks.contains { task in
            if case .succeeded = task.status {
                return true
            }
            return false
        }
    }

    var taskRailState: NotchTaskRailState {
        if isAnswerRailActive {
            return .recognizing
        }

        if finalSuccessVisible, unfinishedTaskCount == 0 {
            return .success
        }

        if firstNeedsInputTask != nil {
            return .needsInput
        }

        if ingestTasks.contains(where: { $0.status == .recognizing }) {
            return .recognizing
        }

        if ingestTasks.contains(where: { $0.status == .storing }) {
            return .storing
        }

        return .preparing
    }

    var taskRailBadgeText: String? {
        let count = unfinishedTaskCount
        guard count > 1 else { return nil }
        return count >= 10 ? "9+" : "\(count)"
    }

    var collapsedTrailingText: String? {
        if !failedTasks.isEmpty, collapsedIndicator == .error, failedTasks.count > 1 {
            return failedTasks.count >= 10 ? "9+" : "\(failedTasks.count)"
        }

        if activeMeetingSession != nil {
            return nil
        }

        if isAnswerRailActive {
            return nil
        }

        guard showsTaskRail else { return nil }
        switch taskRailState {
        case .preparing, .recognizing, .storing:
            return taskRailBadgeText
        case .needsInput, .success:
            return nil
        }
    }

    var taskRailDisplayText: String {
        if isAnswerRailActive {
            if let condensed = condensedThinkingText(from: answerThinkingText) {
                return condensed
            }
            if !answerThinkingPlaceholderText.isEmpty {
                return answerThinkingPlaceholderText
            }
            return localizedPreviewLabel(chinese: "正在思考中…", english: "Thinking…")
        }

        if finalSuccessVisible, unfinishedTaskCount == 0 {
            return localizedPreviewLabel(chinese: "已完成入库", english: "Saved to casebase")
        }

        guard let railTask = currentRailTask else {
            return CasebasePromptCatalog.ui.taskRecognizingDetail
        }

        if railTask.status == .recognizing,
           let thinkingText = condensedThinkingText(for: railTask),
           !thinkingText.isEmpty
        {
            return thinkingText
        }

        switch railTask.status {
        case .queued, .preparing:
            return CasebasePromptCatalog.ui.taskPreparingDetail
        case .recognizing:
            return recognizingPlaceholderText.isEmpty
                ? localizedPreviewLabel(chinese: "正在思考中…", english: "Thinking…")
                : recognizingPlaceholderText
        case .storing:
            return CasebasePromptCatalog.ui.taskStoringDetail
        case .needsInput:
            return localizedPreviewLabel(chinese: "还差一点关键信息", english: "One key detail is still missing")
        case .succeeded:
            return CasebasePromptCatalog.ui.taskSucceededDetail
        case let .failed(message):
            return message
        }
    }

    var taskRailShowsShimmer: Bool {
        if isAnswerRailActive {
            return true
        }

        switch taskRailState {
        case .recognizing:
            return true
        case .preparing, .storing, .needsInput, .success:
            return false
        }
    }

    var taskRailOffsetY: CGFloat {
        max(0, displayCutoutRect.height + taskRailVerticalSpacing)
    }

    private var currentRailTask: NotchIngestTask? {
        if let task = firstNeedsInputTask {
            return task
        }
        if let task = ingestTasks.first(where: { $0.status == .recognizing }) {
            return task
        }
        if let task = ingestTasks.first(where: { $0.status == .storing }) {
            return task
        }
        if let task = ingestTasks.first(where: { $0.status == .preparing }) {
            return task
        }
        if let task = ingestTasks.first(where: { $0.status == .queued }) {
            return task
        }
        return ingestTasks.first(where: { $0.status == .succeeded })
    }

    private var currentCollapsedTaskIndicator: CollapsedIndicator? {
        if finalSuccessVisible, unfinishedTaskCount == 0 {
            return .success
        }

        if firstNeedsInputTask != nil {
            return .needsInput
        }

        if ingestTasks.contains(where: { $0.status == .recognizing }) {
            return .recognizing
        }

        if ingestTasks.contains(where: { $0.status == .storing }) {
            return .storing
        }

        if ingestTasks.contains(where: { $0.status == .preparing || $0.status == .queued }) {
            return .preparing
        }

        return nil
    }

    private var currentMeetingCollapsedIndicator: CollapsedIndicator? {
        guard activeMeetingSession != nil else { return nil }
        return activeMeetingSession?.isPaused == true ? .paused : .recording
    }

    private func condensedThinkingText(for task: NotchIngestTask) -> String? {
        guard task.status == .recognizing,
              let rawText = task.thinkingText,
              !rawText.isEmpty
        else {
            return nil
        }

        return condensedThinkingText(from: rawText)
    }

    private func condensedThinkingText(from rawText: String) -> String? {
        let normalized = rawText
            .replacingOccurrences(of: #"[*`_>#-]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        let limit = 38
        if normalized.count <= limit {
            return normalized
        }
        return String(normalized.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private var needsRecognizingPlaceholder: Bool {
        guard let railTask = currentRailTask,
              railTask.status == .recognizing
        else {
            return false
        }
        return condensedThinkingText(for: railTask) == nil
    }

    private func refreshRecognizingPlaceholderState() {
        guard needsRecognizingPlaceholder else {
            stopRecognizingPlaceholder(resetText: true)
            return
        }

        if recognizingPlaceholderText.isEmpty {
            recognizingPlaceholderText = nextRecognizingPlaceholder(excluding: nil)
        }

        guard recognizingPlaceholderTask == nil else { return }
        recognizingPlaceholderTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let delay = UInt64.random(in: 1_000_000_000 ... 3_000_000_000)
                try? await Task.sleep(nanoseconds: delay)

                guard !Task.isCancelled else { return }
                guard self.needsRecognizingPlaceholder else {
                    self.stopRecognizingPlaceholder(resetText: true)
                    return
                }

                self.recognizingPlaceholderText = self.nextRecognizingPlaceholder(
                    excluding: self.recognizingPlaceholderText
                )
            }
        }
    }

    private func stopRecognizingPlaceholder(resetText: Bool) {
        recognizingPlaceholderTask?.cancel()
        recognizingPlaceholderTask = nil
        if resetText {
            recognizingPlaceholderText = ""
        }
    }

    private var needsAnswerThinkingPlaceholder: Bool {
        guard questionContext != nil, isBusy else { return false }
        return condensedThinkingText(from: answerThinkingText) == nil
    }

    private func refreshAnswerThinkingPlaceholderState() {
        guard needsAnswerThinkingPlaceholder else {
            stopAnswerThinkingPlaceholder(resetText: true)
            return
        }

        if answerThinkingPlaceholderText.isEmpty {
            answerThinkingPlaceholderText = nextRecognizingPlaceholder(excluding: nil)
        }

        guard answerThinkingPlaceholderTask == nil else { return }
        answerThinkingPlaceholderTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let delay = UInt64.random(in: 1_000_000_000 ... 3_000_000_000)
                try? await Task.sleep(nanoseconds: delay)

                guard !Task.isCancelled else { return }
                guard self.needsAnswerThinkingPlaceholder else {
                    self.stopAnswerThinkingPlaceholder(resetText: true)
                    return
                }

                self.answerThinkingPlaceholderText = self.nextRecognizingPlaceholder(
                    excluding: self.answerThinkingPlaceholderText
                )
            }
        }
    }

    private func stopAnswerThinkingPlaceholder(resetText: Bool) {
        answerThinkingPlaceholderTask?.cancel()
        answerThinkingPlaceholderTask = nil
        if resetText {
            answerThinkingPlaceholderText = ""
        }
    }

    private func nextRecognizingPlaceholder(excluding current: String?) -> String {
        let candidates = recognizingPlaceholderPool.filter { $0 != current }
        return candidates.randomElement() ?? recognizingPlaceholderPool.first ?? localizedPreviewLabel(
            chinese: "正在思考中…",
            english: "Thinking…"
        )
    }

    private var recognizingPlaceholderPool: [String] {
        switch CasebasePromptCatalog.language {
        case .simplifiedChinese:
            return [
                "梳理线索中…", "比对上下文中…", "归拢重点中…", "提炼事实中…", "抽取字段中…",
                "整合页面中…", "拼接片段中…", "校对细节中…", "收束重点中…", "捕捉意图中…",
                "对齐语义中…", "拆解结构中…", "映射关系中…", "归纳主题中…", "检视缺口中…",
                "压缩噪声中…", "筛出重点中…", "标记实体中…", "串联证据中…", "整理脉络中…",
                "核对来源中…", "合并信息中…", "补齐上下文中…", "判断用途中…", "锚定标题中…",
                "生成摘要中…", "构建索引中…", "推敲表达中…", "定位关键信息中…", "准备入库中…"
            ]
        case .english:
            return [
                "Tracing clues…", "Comparing context…", "Gathering signals…", "Extracting facts…", "Pulling fields…",
                "Blending fragments…", "Checking details…", "Condensing noise…", "Finding intent…", "Aligning meaning…",
                "Parsing structure…", "Mapping relations…", "Spotting gaps…", "Tagging entities…", "Linking evidence…",
                "Organizing threads…", "Verifying sources…", "Merging context…", "Choosing labels…", "Shaping summary…",
                "Building index…", "Narrowing focus…", "Weighing hints…", "Reading between lines…", "Assembling context…",
                "Sorting priorities…", "Refining meaning…", "Grounding facts…", "Preparing record…", "Getting it ready…"
            ]
        }
    }

    func updateScreenFrame(_ frame: CGRect) {
        screenFrame = frame
    }

    func updateMeasuredExpandedContentHeight(_ height: CGFloat, for state: CasebaseSurfaceState) {
        guard state.usesAdaptiveExpandedHeight else { return }
        let normalizedHeight = ceil(height)
        guard normalizedHeight > 0 else { return }
        measuredExpandedContentHeights[state] = normalizedHeight
    }

    func expand() {
        refreshShortcutPermissions()
        isDismissed = false
        if surfaceState == .idle {
            if !failedTasks.isEmpty || errorMessage != nil {
                surfaceState = .error
            } else {
                guard canEnterHoverActions else { return }
                surfaceState = .hoverActions
            }
        }
        status = .expanded
    }

    func collapse() {
        guard !shouldRemainExpanded else { return }
        if surfaceState == .hoverActions {
            surfaceState = .idle
        }
        isDismissed = false
        status = .collapsed
    }

    func dismissPreservingState() {
        guard surfaceState != .idle else {
            collapse()
            return
        }

        isDropTargeted = false
        isPinnedExpanded = false
        intakeFeedbackTask?.cancel()
        intakeFeedbackMessage = nil

        if surfaceState == .hoverActions {
            surfaceState = .idle
            isDismissed = false
        } else {
            isDismissed = true
        }

        status = .collapsed
    }

    func updateDropTargeted(_ targeted: Bool) {
        guard targeted != isDropTargeted else { return }
        isDropTargeted = targeted

        if targeted {
            isDismissed = false
            restoredSurfaceState = surfaceState
            noticeMessage = nil
            errorMessage = nil
            resetAnswerTransientState()
            intakeFeedbackMessage = nil
            isPinnedExpanded = true
            surfaceState = .dropTarget
            status = .expanded
        } else if surfaceState == .dropTarget {
            restoreAfterDropExit()
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        suppressHoverUntilMouseExit = true
        collapseAfterDropSubmission()
        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        presentIntakeFeedback(message: joiningExistingQueue
            ? CasebasePromptCatalog.ui.intakeQueuedFeedback
            : CasebasePromptCatalog.ui.intakeDigestingFeedback)

        Task { [weak self] in
            guard let self else { return }
            do {
                let payloads = try await NotchDropPayloadLoader.loadPayloads(from: providers)
                await self.enqueue(payloads, prefersAutomaticExpansion: false)
            } catch {
                self.presentImportError(error)
            }
        }
        return true
    }

    func restoreHoverAfterMouseExit() {
        suppressHoverUntilMouseExit = false
    }

    func ingestCapturedSelection(_ capture: GlobalSelectionCaptureContext) {
        let payload = ImportPayload.text(
            TextImportPayload(
                text: capture.text,
                suggestedFileName: capture.suggestedFileName,
                mimeType: "text/plain",
                contextMetadata: capture.metadata
            )
        )

        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        animateCaptureSink()
        presentIntakeFeedback(message: joiningExistingQueue
            ? CasebasePromptCatalog.ui.intakeQueuedFeedback
            : CasebasePromptCatalog.ui.intakeDigestingFeedback)

        Task { [weak self] in
            await self?.enqueue([payload])
        }
    }

    func ingestCapturedScreenshot(_ capture: GlobalScreenshotCaptureContext) {
        let payload = ImportPayload.file(
            FileImportPayload(
                fileURL: capture.fileURL,
                suggestedFileName: capture.suggestedFileName,
                mimeType: "image/png",
                sourceKindHint: .image,
                contextMetadata: capture.metadata
            )
        )

        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        animateCaptureSink()
        presentIntakeFeedback(message: joiningExistingQueue
            ? CasebasePromptCatalog.ui.intakeQueuedFeedback
            : CasebasePromptCatalog.ui.intakeDigestingFeedback)

        Task { [weak self] in
            await self?.enqueue([payload])
        }
    }

    func handleSelectionCaptureError(_ error: Error) {
        presentImportError(error)
    }

    func handleScreenshotCaptureError(_ error: Error) {
        presentImportError(error)
    }

    func refreshSelectionCaptureAuthorization() {
        selectionCaptureAuthorized = AXIsProcessTrusted()
    }

    func refreshScreenshotCaptureAuthorization() {
        screenshotCaptureAuthorized = CGPreflightScreenCaptureAccess()
    }

    func refreshShortcutPermissions() {
        refreshSelectionCaptureAuthorization()
        refreshScreenshotCaptureAuthorization()
    }

    func openSelectionCaptureAccessibilitySettings() {
        refreshShortcutPermissions()
        guard !selectionCaptureAuthorized else { return }

        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ].compactMap(URL.init(string:))

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }
    }

    func openScreenRecordingSettings() {
        refreshShortcutPermissions()
        guard !screenshotCaptureAuthorized else { return }

        _ = CGRequestScreenCaptureAccess()
        refreshScreenshotCaptureAuthorization()

        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ]

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func openMicrophoneSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"
        ]

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func bindAPIKeyStore() {
        let store = CasebaseAPIKeyStore.shared
        apiKeyConfigured = store.isConfigured
        store.$isConfigured
            .receive(on: RunLoop.main)
            .sink { [weak self] isConfigured in
                self?.apiKeyConfigured = isConfigured
            }
            .store(in: &apiKeyStoreCancellables)
    }

    private func bindMeetingRecorder() {
        guard let meetingRecorder else { return }

        meetingRecorder.$activeSession
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                self.activeMeetingSession = session
                if let session {
                    self.setMeetingDraft(from: session)
                }
            }
            .store(in: &meetingRecorderCancellables)

        meetingRecorder.$permissionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] permissionStatus in
                self?.meetingRecorderPermissionStatus = permissionStatus
            }
            .store(in: &meetingRecorderCancellables)

        meetingRecorder.$isBusy
            .receive(on: RunLoop.main)
            .sink { [weak self] isBusy in
                self?.isMeetingRecorderBusy = isBusy
            }
            .store(in: &meetingRecorderCancellables)

        meetingRecorder.$lastErrorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self, let message, !message.isEmpty else { return }
                self.meetingErrorMessage = message
            }
            .store(in: &meetingRecorderCancellables)
    }

    func submitQuestion() {
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            await self.runAnswer(question)
        }
    }

    func retryLastAction() {
        guard let lastFailedAction else { return }

        Task { [weak self] in
            guard let self else { return }
            switch lastFailedAction {
            case let .answerQuestion(question):
                self.draftQuestion = question
                await self.runAnswer(question)
            }
        }
    }

    func selectPreviousFailedTask() {
        guard hasMultipleFailedTasks, let selected = selectedFailedTask else { return }
        guard let currentIndex = failedTasks.firstIndex(where: { $0.id == selected.id }) else { return }
        let nextIndex = currentIndex == 0 ? failedTasks.index(before: failedTasks.endIndex) : failedTasks.index(before: currentIndex)
        selectedFailedTaskID = failedTasks[nextIndex].id
    }

    func selectNextFailedTask() {
        guard hasMultipleFailedTasks, let selected = selectedFailedTask else { return }
        guard let currentIndex = failedTasks.firstIndex(where: { $0.id == selected.id }) else { return }
        let nextIndex = failedTasks.index(after: currentIndex)
        let resolvedIndex = nextIndex == failedTasks.endIndex ? failedTasks.startIndex : nextIndex
        selectedFailedTaskID = failedTasks[resolvedIndex].id
    }

    func retryCurrentError() {
        if let failedTask = selectedFailedTask {
            retryFailedTask(failedTask.id)
            return
        }
        retryLastAction()
    }

    func dismissCurrentError() {
        if let failedTask = selectedFailedTask {
            dismissFailedTask(failedTask.id)
            return
        }

        errorMessage = nil
        lastFailedAction = nil
        if surfaceState == .error {
            switch questionContext {
            case .globalSearch:
                surfaceState = searchConversationListVisible || activeSearchConversationID == nil
                    ? .search
                    : .answerReady
            case .savedRecord:
                surfaceState = .savedPreview
            case .none:
                surfaceState = .hoverActions
            }
        }
    }

    var currentErrorTitle: String {
        if let failedTask = selectedFailedTask {
            return failedTask.title
        }
        return CasebasePromptCatalog.ui.errorTitle
    }

    var currentErrorMessage: String {
        if let failedTask = selectedFailedTask,
           case let .failed(message) = failedTask.status {
            return message
        }
        return errorMessage ?? CasebasePromptCatalog.ui.unknownErrorMessage
    }

    var currentErrorCopyText: String {
        "\(currentErrorTitle)\n\(currentErrorMessage)"
    }

    var currentErrorIndexLabel: String? {
        guard hasMultipleFailedTasks,
              let selected = selectedFailedTask,
              let currentIndex = failedTasks.firstIndex(where: { $0.id == selected.id })
        else { return nil }
        return "\(currentIndex + 1)/\(failedTasks.count)"
    }

    func openSettings() {
        refreshShortcutPermissions()
        measuredExpandedContentHeights[.settings] = max(
            measuredExpandedContentHeights[.settings] ?? 0,
            NotchSettingsView.measuredContentHeight(
                showsSelectionCaptureAccess: !selectionCaptureAuthorized,
                showsScreenRecordingAccess: !screenshotCaptureAuthorized,
                canClearData: canOpenDataResetConfirmation
            )
        )
        guard surfaceState != .settings, surfaceState != .settingsAPIKeys, surfaceState != .settingsDataResetConfirmation else { return }
        isDismissed = false
        restoredSurfaceStateBeforeSettings = surfaceState
        restoredStatusBeforeSettings = status
        restoredPinnedStateBeforeSettings = isPinnedExpanded
        isPinnedExpanded = true
        surfaceState = .settings
        status = .expanded
    }

    func openLibrary() {
        guard let libraryService else {
            presentImportError(startupIntegrationError(fallback: CasebasePromptCatalog.errors.libraryServiceName))
            return
        }

        if surfaceState == .library || surfaceState == .libraryDetail {
            isDismissed = false
            isPinnedExpanded = true
            status = .expanded

            if surfaceState == .libraryDetail,
               selectedLibraryRecord == nil,
               selectedLibraryTaskID == nil {
                surfaceState = .library
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.reloadLibraryRecords(using: libraryService)
            }
            return
        }

        restoredSurfaceStateBeforeLibrary = surfaceState
        restoredStatusBeforeLibrary = status
        restoredPinnedStateBeforeLibrary = isPinnedExpanded

        isDismissed = false
        isPinnedExpanded = true
        selectedLibraryRecord = nil
        selectedLibraryTaskID = nil
        libraryErrorMessage = nil
        errorMessage = nil
        surfaceState = .library
        status = .expanded

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.reloadLibraryRecords(using: libraryService)
        }
    }

    func openSearch() {
        if questionContext == .globalSearch,
           surfaceState == .search || surfaceState == .answerReady || surfaceState == .answering
        {
            isDismissed = false
            isPinnedExpanded = true
            status = .expanded
            return
        }

        restoredSurfaceStateBeforeSearch = surfaceState
        restoredStatusBeforeSearch = status
        restoredPinnedStateBeforeSearch = isPinnedExpanded

        isDismissed = false
        isPinnedExpanded = true
        activeRecord = nil
        resetAnswerTransientState()
        questionContext = .globalSearch
        searchConversationListVisible = true
        draftQuestion = ""
        errorMessage = nil
        noticeMessage = nil
        surfaceState = .search
        status = .expanded
    }

    func closeSearch() {
        guard questionContext == .globalSearch else { return }

        isDismissed = false
        isPinnedExpanded = restoredPinnedStateBeforeSearch
        resetAnswerTransientState()
        activeRecord = nil
        questionContext = nil
        searchConversationListVisible = true
        draftQuestion = ""
        errorMessage = nil
        noticeMessage = nil
        surfaceState = restoredSurfaceStateBeforeSearch
        status = restoredStatusBeforeSearch

        if surfaceState == .hoverActions {
            status = .expanded
            isPinnedExpanded = true
        }
    }

    func openMeeting() {
        guard meetingRecorder != nil else {
            meetingErrorMessage = CasebasePromptCatalog.ui.meetingRecorderCreationFailedMessage
            return
        }

        if surfaceState != .meeting,
           surfaceState != .meetingDiscardConfirmation,
           surfaceState != .meetingFinishConfirmation
        {
            restoredSurfaceStateBeforeMeeting = surfaceState
            restoredStatusBeforeMeeting = status
            restoredPinnedStateBeforeMeeting = isPinnedExpanded
        }

        meetingErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .meeting
        status = .expanded
    }

    func closeMeeting() {
        guard surfaceState == .meeting
            || surfaceState == .meetingDiscardConfirmation
            || surfaceState == .meetingFinishConfirmation
        else { return }

        meetingErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = restoredPinnedStateBeforeMeeting
        surfaceState = restoredSurfaceStateBeforeMeeting
        status = restoredStatusBeforeMeeting

        if surfaceState == .hoverActions {
            status = .expanded
            isPinnedExpanded = true
        }
    }

    func startMeetingRecording() {
        guard let meetingRecorder else {
            meetingErrorMessage = CasebasePromptCatalog.ui.meetingRecorderCreationFailedMessage
            return
        }

        meetingErrorMessage = nil
        let participantCount = max(1, meetingParticipantCount)
        let topic = meetingTopic

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await meetingRecorder.start(participantCount: participantCount, topic: topic)
                self.collapseMeetingAfterStart()
            } catch {
                self.meetingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.surfaceState = .meeting
                self.status = .expanded
                self.isPinnedExpanded = true
                self.isDismissed = false
            }
        }
    }

    func toggleMeetingPauseResume() {
        guard let meetingRecorder else { return }

        meetingErrorMessage = nil
        do {
            if activeMeetingSession?.isPaused == true {
                try meetingRecorder.resume()
            } else {
                try meetingRecorder.pause()
            }
            surfaceState = .meeting
            status = .expanded
            isPinnedExpanded = true
            isDismissed = false
        } catch {
            meetingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func requestMeetingDiscard() {
        guard hasActiveMeetingSession else { return }
        meetingErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .meetingDiscardConfirmation
        status = .expanded
    }

    func dismissMeetingDiscardConfirmation() {
        guard surfaceState == .meetingDiscardConfirmation else { return }
        surfaceState = .meeting
        status = .expanded
        isPinnedExpanded = true
        isDismissed = false
    }

    func confirmMeetingDiscard() {
        guard let meetingRecorder else { return }

        do {
            try meetingRecorder.discard()
            meetingErrorMessage = nil
            surfaceState = .meeting
            status = .expanded
            isPinnedExpanded = true
            isDismissed = false
        } catch {
            meetingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            surfaceState = .meeting
            status = .expanded
            isPinnedExpanded = true
            isDismissed = false
        }
    }

    func requestMeetingFinish() {
        guard hasActiveMeetingSession else { return }
        meetingErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .meetingFinishConfirmation
        status = .expanded
    }

    func dismissMeetingFinishConfirmation() {
        guard surfaceState == .meetingFinishConfirmation else { return }
        surfaceState = .meeting
        status = .expanded
        isPinnedExpanded = true
        isDismissed = false
    }

    func confirmMeetingFinish() {
        guard let meetingRecorder else { return }

        do {
            let recording = try meetingRecorder.finish()
            setMeetingDraft(from: recording)
            meetingErrorMessage = nil
            dismissMeetingSurfaceAfterCompletion()

            let payload = meetingImportPayload(for: recording)
            let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
            pulseFeedback()
            presentIntakeFeedback(message: joiningExistingQueue
                ? CasebasePromptCatalog.ui.intakeQueuedFeedback
                : CasebasePromptCatalog.ui.intakeDigestingFeedback)

            Task { [weak self] in
                await self?.enqueue([payload], prefersAutomaticExpansion: false)
            }
        } catch {
            meetingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            surfaceState = .meeting
            status = .expanded
            isPinnedExpanded = true
            isDismissed = false
        }
    }

    func showSearchConversationList() {
        guard questionContext == .globalSearch else { return }
        resetAnswerTransientState(clearDraft: true)
        errorMessage = nil
        noticeMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        searchConversationListVisible = true
        surfaceState = .search
        status = .expanded
    }

    func startNewSearchConversation() {
        guard questionContext == .globalSearch else { return }
        resetAnswerTransientState(clearDraft: true)
        activeSearchConversationID = nil
        errorMessage = nil
        noticeMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        searchConversationListVisible = false
        surfaceState = .search
        status = .expanded
    }

    func openSearchConversation(_ conversationID: UUID) {
        guard let conversation = searchConversations.first(where: { $0.id == conversationID }) else { return }
        activeSearchConversationID = conversation.id
        resetAnswerTransientState(clearDraft: true)
        latestAnswer = conversation.turns.last?.answer
        errorMessage = nil
        noticeMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        searchConversationListVisible = false
        surfaceState = conversation.turns.isEmpty ? .search : .answerReady
        status = .expanded
    }

    func deleteActiveSearchConversation() {
        guard let conversationID = activeSearchConversationID else { return }

        resetAnswerTransientState(clearDraft: true)
        removeSearchConversation(id: conversationID)
        lastSubmittedQuestion = nil
        errorMessage = nil
        noticeMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        searchConversationListVisible = true
        surfaceState = .search
        status = .expanded
    }

    func closeLibrary() {
        guard surfaceState == .library || surfaceState == .libraryDetail else { return }
        isDismissed = false
        selectedLibraryRecord = nil
        selectedLibraryTaskID = nil
        libraryErrorMessage = nil
        surfaceState = restoredSurfaceStateBeforeLibrary
        status = restoredStatusBeforeLibrary
        isPinnedExpanded = restoredPinnedStateBeforeLibrary

        // When returning to hover actions, keep expanded for this transition so it behaves
        // like "back to previous layer" instead of collapsing immediately due to hit-test shrink.
        if surfaceState == .hoverActions {
            status = .expanded
            isPinnedExpanded = true
        }
    }

    func openLibraryRecord(_ recordID: UUID) {
        guard let record = libraryRecords.first(where: { $0.id == recordID }) else { return }
        selectedLibraryRecord = record
        selectedLibraryTaskID = nil
        libraryErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .libraryDetail
        status = .expanded
    }

    func openLibraryTask(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }) else { return }

        if case .needsInput = task.status {
            selectedLibraryTaskID = nil
            selectedLibraryRecord = nil
            openTaskPanel()
            return
        }

        guard task.isPending else {
            if let record = task.record {
                openLibraryRecord(record.id)
            }
            return
        }

        selectedLibraryTaskID = taskID
        selectedLibraryRecord = nil
        libraryErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .libraryDetail
        status = .expanded
    }

    func closeLibraryDetail() {
        guard surfaceState == .libraryDetail else { return }
        selectedLibraryRecord = nil
        selectedLibraryTaskID = nil
        libraryErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .library
        status = .expanded
    }

    func revealSelectedLibraryRecord() {
        guard let record = selectedLibraryRecord else { return }
        guard let libraryService else {
            presentImportError(startupIntegrationError(fallback: CasebasePromptCatalog.errors.libraryServiceName))
            return
        }

        libraryErrorMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await libraryService.revealInFinder(record: record)
            } catch {
                self.libraryErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func openSelectedLibraryRecord() {
        guard let record = selectedLibraryRecord else { return }
        guard let libraryService else {
            presentImportError(startupIntegrationError(fallback: CasebasePromptCatalog.errors.libraryServiceName))
            return
        }

        libraryErrorMessage = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await libraryService.open(record: record)
            } catch {
                self.libraryErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func openCitationSource(_ citation: AnswerCitation) {
        let candidateURL: URL
        if citation.openTarget.hasPrefix("/") {
            candidateURL = URL(fileURLWithPath: citation.openTarget)
        } else if let storageRootDirectory {
            candidateURL = storageRootDirectory.appendingPathComponent(citation.openTarget, isDirectory: false)
        } else {
            candidateURL = URL(fileURLWithPath: citation.openTarget)
        }

        guard FileManager.default.fileExists(atPath: candidateURL.path) else {
            return
        }

        NSWorkspace.shared.open(candidateURL)
    }

    func deleteSelectedLibraryRecord() {
        guard let record = selectedLibraryRecord else { return }
        guard let libraryService else {
            presentImportError(startupIntegrationError(fallback: CasebasePromptCatalog.errors.libraryServiceName))
            return
        }
        guard !isDeletingLibraryRecord else { return }

        isDeletingLibraryRecord = true
        libraryErrorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isDeletingLibraryRecord = false }

            do {
                try await libraryService.deleteRecord(id: record.id)
                self.removeLibraryRecord(id: record.id)
                self.surfaceState = .library
                self.status = .expanded
            } catch {
                self.libraryErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func closeSettings() {
        guard surfaceState == .settings || surfaceState == .settingsAPIKeys || surfaceState == .settingsDataResetConfirmation else { return }
        isDismissed = false
        surfaceState = restoredSurfaceStateBeforeSettings
        status = restoredStatusBeforeSettings
        isPinnedExpanded = restoredPinnedStateBeforeSettings
    }

    func openAPIKeySettings() {
        measuredExpandedContentHeights[.settingsAPIKeys] = max(
            measuredExpandedContentHeights[.settingsAPIKeys] ?? 0,
            NotchAPIKeySettingsView.measuredContentHeight()
        )
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .settingsAPIKeys
        status = .expanded
    }

    func closeAPIKeySettings() {
        guard surfaceState == .settingsAPIKeys else { return }
        isDismissed = false
        surfaceState = .settings
        status = .expanded
    }

    func openDataResetConfirmation() {
        guard canOpenDataResetConfirmation else { return }
        measuredExpandedContentHeights[.settingsDataResetConfirmation] = max(
            measuredExpandedContentHeights[.settingsDataResetConfirmation] ?? 0,
            NotchSettingsDataResetConfirmationView.measuredContentHeight(isClearing: isClearingStoredData)
        )
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .settingsDataResetConfirmation
        status = .expanded
    }

    func closeDataResetConfirmation() {
        guard surfaceState == .settingsDataResetConfirmation else { return }
        isDismissed = false
        surfaceState = .settings
        status = .expanded
    }

    func confirmDataReset() {
        guard !isClearingStoredData else { return }
        guard canOpenDataResetConfirmation || surfaceState == .settingsDataResetConfirmation else { return }
        guard let dataResetService else {
            presentImportError(startupIntegrationError(fallback: CasebasePromptCatalog.errors.dataResetServiceName))
            return
        }

        isClearingStoredData = true
        errorMessage = nil
        noticeMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await dataResetService.clearAllStoredData()
                NotificationCenter.default.post(name: .casebaseStoredDataCleared, object: nil)
            } catch {
                self.isClearingStoredData = false
                self.presentImportError(error)
            }
        }
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }

    func restartApplication() {
        let bundleURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            NSApp.terminate(nil)
        }
    }

    func openTaskPanel() {
        guard firstNeedsInputTask != nil else {
            openLibrary()
            return
        }
        intakeFeedbackTask?.cancel()
        isDismissed = false
        storeTaskPanelRestoreState()
        surfaceState = .taskPanel
        isPinnedExpanded = true
        status = .expanded
    }

    func handleTaskRailTap() {
        if questionContext != nil,
           surfaceState == .answering || surfaceState == .answerReady || surfaceState == .search
        {
            isDismissed = false
            isPinnedExpanded = true
            status = .expanded
            return
        }

        if firstNeedsInputTask != nil {
            openTaskPanel()
            return
        }

        openLibrary()
    }

    func closeTaskPanel() {
        restoreAfterTaskPanel()

        if unfinishedTaskCount == 0, !finalSuccessVisible {
            pruneCompletedTasks()
        }
    }

    func backToHomeFromTaskPanel() {
        guard surfaceState == .taskPanel else { return }
        restoreAfterTaskPanel()
    }

    func openTaskRecord(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let record = task.record
        else { return }

        activeRecord = record
        resetAnswerTransientState()
        questionContext = .savedRecord
        draftQuestion = ""
        errorMessage = nil
        noticeMessage = nil
        isDismissed = false
        surfaceState = .savedPreview
        isPinnedExpanded = true
        status = .expanded
    }

    func backFromSavedPreviewToTaskPanel() {
        guard surfaceState == .savedPreview else { return }
        isDismissed = false
        errorMessage = nil
        resetAnswerTransientState()
        activeRecord = nil
        questionContext = nil
        draftQuestion = ""
        if ingestTasks.isEmpty {
            isPinnedExpanded = true
            surfaceState = .hoverActions
            status = .expanded
            return
        }
        isPinnedExpanded = true
        surfaceState = .taskPanel
        status = .expanded
    }

    func backFromAnswerPanel() {
        switch questionContext {
        case .globalSearch:
            if !searchConversationListVisible, activeSearchConversation != nil {
                showSearchConversationList()
            } else {
                closeSearch()
            }
        case .savedRecord:
            guard activeRecord != nil else {
                resetAnswerTransientState()
                questionContext = nil
                surfaceState = .hoverActions
                status = .expanded
                isPinnedExpanded = true
                return
            }

            isDismissed = false
            isPinnedExpanded = true
            resetAnswerTransientState()
            errorMessage = nil
            surfaceState = .savedPreview
            status = .expanded
        case .none:
            break
        }
    }

    func bindingForTaskSupplement(_ taskID: UUID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.ingestTasks.first(where: { $0.id == taskID })?.supplementDraft ?? ""
            },
            set: { [weak self] newValue in
                self?.updateTaskSupplement(taskID: taskID, value: newValue)
            }
        )
    }

    func applyTaskSupplementSuggestion(_ suggestion: String, to taskID: UUID) {
        updateTaskSupplement(taskID: taskID, value: suggestion)
    }

    func clarificationRequest(for taskID: UUID) -> ClarificationRequest? {
        ingestTasks.first(where: { $0.id == taskID })?.record?.clarificationRequest
    }

    func bindingForClarificationAnswer(taskID: UUID, questionID: String) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.ingestTasks.first(where: { $0.id == taskID })?.clarificationAnswers[questionID] ?? ""
            },
            set: { [weak self] newValue in
                self?.updateClarificationAnswer(taskID: taskID, questionID: questionID, value: newValue)
            }
        )
    }

    func applyClarificationOption(_ option: String, to taskID: UUID, questionID: String) {
        updateClarificationAnswer(taskID: taskID, questionID: questionID, value: option)
    }

    func clarificationValidationMessage(for taskID: UUID) -> String? {
        ingestTasks.first(where: { $0.id == taskID })?.clarificationValidationMessage
    }

    var clarificationCancellationTaskTitle: String? {
        guard let pendingClarificationCancellationTaskID else { return nil }
        return ingestTasks.first(where: { $0.id == pendingClarificationCancellationTaskID })?.title
    }

    func currentClarificationQuestion(for taskID: UUID) -> ClarificationQuestion? {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let questions = task.record?.clarificationRequest?.questions,
              !questions.isEmpty
        else {
            return nil
        }

        let index = min(task.currentClarificationQuestionIndex, questions.count - 1)
        return questions[index]
    }

    func clarificationQuestionProgress(for taskID: UUID) -> (current: Int, total: Int)? {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let total = task.record?.clarificationRequest?.questions.count,
              total > 0
        else {
            return nil
        }

        let current = min(task.currentClarificationQuestionIndex + 1, total)
        return (current, total)
    }

    func isLastClarificationQuestion(for taskID: UUID) -> Bool {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let questions = task.record?.clarificationRequest?.questions,
              !questions.isEmpty
        else {
            return true
        }

        return task.currentClarificationQuestionIndex >= questions.count - 1
    }

    func goToNextClarificationQuestion(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let questions = task.record?.clarificationRequest?.questions,
              !questions.isEmpty
        else {
            return
        }

        updateTask(taskID) { task in
            task.currentClarificationQuestionIndex = min(task.currentClarificationQuestionIndex + 1, questions.count - 1)
            task.clarificationValidationMessage = nil
            task.updatedAt = Date()
        }
    }

    func skipClarificationQuestion(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let record = task.record
        else {
            return
        }

        guard let importCoordinator else {
            markTask(
                taskID,
                failedWith: startupIntegrationError(fallback: CasebasePromptCatalog.errors.importServiceName).localizedDescription
            )
            startQueueProcessorIfNeeded()
            return
        }

        let skippedQuestionTitles = unresolvedClarificationQuestionTitles(for: taskID)

        errorMessage = nil
        noticeMessage = nil

        updateTask(taskID) { task in
            task.status = .storing
            task.thinkingText = nil
            task.clarificationValidationMessage = nil
            task.updatedAt = Date()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let finalizedRecord = try await withTaskTimeout(
                    seconds: importOperationTimeoutSeconds,
                    timeoutError: CasebaseError.operationTimedOut(
                        CasebasePromptCatalog.errors.clarificationTaskTimedOut(
                            seconds: Int(importOperationTimeoutSeconds)
                        )
                    )
                ) {
                    try await importCoordinator.finalizeRecordWithoutClarification(
                        id: record.id,
                        skippedQuestionTitles: skippedQuestionTitles
                    ) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.applyProgressUpdate(progress, to: taskID)
                        }
                    }
                }

                self.finalizeReanalyzedRecord(finalizedRecord, for: taskID)

                guard self.firstNeedsInputTask == nil else { return }
                self.startQueueProcessorIfNeeded()

                if self.unfinishedTaskCount == 0 && self.hasSuccessfulTasks {
                    self.showFinalSuccessRail()
                }
            } catch {
                self.markTask(
                    taskID,
                    failedWith: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
                self.startQueueProcessorIfNeeded()
            }
        }
    }

    func requestClarificationCancellation(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }) else { return }
        guard case .needsInput = task.status else { return }
        pendingClarificationCancellationTaskID = taskID
        CasebaseDebugLogger.log("clarification cancellation requested taskID=\(taskID.uuidString)")
    }

    func dismissClarificationCancellation() {
        pendingClarificationCancellationTaskID = nil
    }

    func confirmClarificationCancellation() {
        guard let taskID = pendingClarificationCancellationTaskID else { return }
        pendingClarificationCancellationTaskID = nil
        cancelClarificationTask(taskID)
    }

    func confirmClarificationCancellation(_ taskID: UUID) {
        pendingClarificationCancellationTaskID = nil
        CasebaseDebugLogger.log("clarification cancellation confirmed taskID=\(taskID.uuidString)")
        cancelClarificationTask(taskID)
    }

    func continueTaskAfterLowConfidence(_ taskID: UUID) {
        submitClarification(taskID)
    }

    func submitClarification(_ taskID: UUID, allowEmptyAnswers: Bool = false) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let record = task.record
        else { return }

        guard let importCoordinator else {
            markTask(
                taskID,
                failedWith: startupIntegrationError(fallback: CasebasePromptCatalog.errors.importServiceName).localizedDescription
            )
            startQueueProcessorIfNeeded()
            return
        }

        guard let clarificationAnswers = normalizedClarificationAnswers(for: taskID, allowEmptyAnswers: allowEmptyAnswers) else {
            return
        }
        let skippedQuestionTitles = skippedClarificationQuestionTitles(for: taskID)

        errorMessage = nil
        noticeMessage = nil

        updateTask(taskID) { pendingTask in
            pendingTask.status = .preparing
            pendingTask.thinkingText = nil
            pendingTask.clarificationValidationMessage = nil
            pendingTask.updatedAt = Date()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let refreshedRecord = try await withTaskTimeout(
                    seconds: importOperationTimeoutSeconds,
                    timeoutError: CasebaseError.operationTimedOut(
                        CasebasePromptCatalog.errors.clarificationTaskTimedOut(
                            seconds: Int(importOperationTimeoutSeconds)
                        )
                    )
                ) {
                    try await importCoordinator.reanalyzeRecord(
                        id: record.id,
                        clarificationAnswers: clarificationAnswers,
                        skippedQuestionTitles: skippedQuestionTitles
                    ) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.applyProgressUpdate(progress, to: taskID)
                        }
                    }
                }

                self.finalizeReanalyzedRecord(refreshedRecord, for: taskID)

                guard self.firstNeedsInputTask == nil else { return }
                self.startQueueProcessorIfNeeded()

                if self.unfinishedTaskCount == 0 && self.hasSuccessfulTasks {
                    self.showFinalSuccessRail()
                }
            } catch {
                self.markTask(
                    taskID,
                    failedWith: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
                self.startQueueProcessorIfNeeded()
            }
        }
    }

    func clear() {
        queueProcessorTask?.cancel()
        intakeFeedbackTask?.cancel()
        finalSuccessTask?.cancel()
        taskRailResultTask?.cancel()
        queueProcessorTask = nil
        intakeFeedbackTask = nil
        finalSuccessTask = nil
        taskRailResultTask = nil
        finalSuccessVisible = false
        transientResultRailVisible = false

        activeRecord = nil
        resetAnswerTransientState()
        questionContext = nil
        searchConversations = []
        activeSearchConversationID = nil
        searchConversationListVisible = true
        libraryRecords = []
        selectedLibraryRecord = nil
        selectedLibraryTaskID = nil
        draftQuestion = ""
        errorMessage = nil
        libraryErrorMessage = nil
        noticeMessage = nil
        intakeFeedbackMessage = nil
        isBusy = false
        isLibraryLoading = false
        isDeletingLibraryRecord = false
        pendingClarificationCancellationTaskID = nil
        isDropTargeted = false
        isPinnedExpanded = false
        lastFailedAction = nil
        lastSubmittedQuestion = nil
        restoredSurfaceState = .idle
        restoredSurfaceStateBeforeSettings = .idle
        restoredStatusBeforeSettings = .collapsed
        restoredPinnedStateBeforeSettings = false
        restoredSurfaceStateBeforeTaskPanel = .idle
        restoredStatusBeforeTaskPanel = .collapsed
        restoredPinnedStateBeforeTaskPanel = false
        ingestTasks = []
        feedbackScale = 1
        isDismissed = false
        isClearingStoredData = false
        selectedFailedTaskID = nil
        surfaceState = .idle
        status = .collapsed
        deletePersistedSearchConversations()
    }

    func handleStoredDataCleared() {
        clear()
    }

    func handleRecordDeleted(_ id: UUID) {
        removeLibraryRecord(id: id)
    }

    func handleRecordsReorganized() {
        guard let libraryService else { return }
        guard surfaceState == .library || surfaceState == .libraryDetail else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.reloadLibraryRecords(using: libraryService)
        }
    }

    func libraryAssetURL(for record: ImportRecord) -> URL? {
        storageRootDirectory?.appendingPathComponent(record.assetPath, isDirectory: false)
    }

    func libraryKindLabel(for record: ImportRecord) -> String {
        libraryKindLabel(forPreviewKind: inferredPreviewKind(for: record))
    }

    func libraryKindLabel(for sourceKind: ImportSourceKind) -> String {
        switch sourceKind {
        case .image:
            return localizedPreviewLabel(chinese: "图片", english: "Image")
        case .pdf:
            return "PDF"
        case .text:
            return localizedPreviewLabel(chinese: "文本", english: "Text")
        case .audio:
            return localizedPreviewLabel(chinese: "音频", english: "Audio")
        case .folder:
            return localizedPreviewLabel(chinese: "文件夹", english: "Folder")
        case .binary:
            return localizedPreviewLabel(chinese: "文件", english: "File")
        }
    }

    private func libraryKindLabel(forPreviewKind previewKind: LibraryPreviewKind) -> String {
        switch previewKind {
        case .image:
            return localizedPreviewLabel(chinese: "图片", english: "Image")
        case .pdf:
            return "PDF"
        case .text:
            return localizedPreviewLabel(chinese: "文本", english: "Text")
        case .audio:
            return localizedPreviewLabel(chinese: "音频", english: "Audio")
        case .video:
            return localizedPreviewLabel(chinese: "视频", english: "Video")
        case .folder:
            return localizedPreviewLabel(chinese: "文件夹", english: "Folder")
        case .file:
            return localizedPreviewLabel(chinese: "文件", english: "File")
        }
    }

    func libraryKindDetail(for record: ImportRecord) -> String {
        libraryKindDetail(forPreviewKind: inferredPreviewKind(for: record))
    }

    private func libraryKindDetail(forPreviewKind previewKind: LibraryPreviewKind) -> String {
        switch previewKind {
        case .image:
            return localizedPreviewLabel(chinese: "图片缩略图", english: "Image preview")
        case .pdf:
            return localizedPreviewLabel(chinese: "PDF 文档", english: "PDF document")
        case .text:
            return localizedPreviewLabel(chinese: "文本内容", english: "Text content")
        case .audio:
            return localizedPreviewLabel(chinese: "音频内容", english: "Audio content")
        case .video:
            return localizedPreviewLabel(chinese: "视频内容", english: "Video content")
        case .folder:
            return localizedPreviewLabel(chinese: "文件夹内容", english: "Folder contents")
        case .file:
            return localizedPreviewLabel(chinese: "通用文件", english: "General file")
        }
    }

    func libraryPreviewSystemImage(for record: ImportRecord) -> String {
        libraryPreviewSystemImage(forPreviewKind: inferredPreviewKind(for: record))
    }

    func libraryPreviewSystemImage(for sourceKind: ImportSourceKind) -> String {
        switch sourceKind {
        case .image:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .text:
            return "text.alignleft"
        case .audio:
            return "waveform"
        case .folder:
            return "folder"
        case .binary:
            return "doc"
        }
    }

    private func libraryPreviewSystemImage(forPreviewKind previewKind: LibraryPreviewKind) -> String {
        switch previewKind {
        case .image:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .text:
            return "text.alignleft"
        case .audio:
            return "waveform"
        case .video:
            return "film"
        case .folder:
            return "folder"
        case .file:
            return "doc"
        }
    }

    func formattedLibraryTimestamp(for date: Date) -> String {
        let formatter: DateFormatter = CasebasePromptCatalog.language == .simplifiedChinese
            ? Self.chineseLibraryTimestampFormatter
            : Self.englishLibraryTimestampFormatter
        return formatter.string(from: date)
    }

    func formattedLibraryValue(_ value: StructuredFieldValue) -> String {
        switch value {
        case let .string(string):
            return string
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(bool):
            return bool
                ? localizedPreviewLabel(chinese: "是", english: "Yes")
                : localizedPreviewLabel(chinese: "否", english: "No")
        case let .array(values):
            return values.map(formattedLibraryValue).joined(separator: " · ")
        case let .object(dictionary):
            return dictionary
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(formattedLibraryValue($0.value))" }
                .joined(separator: "\n")
        case .null:
            return localizedPreviewLabel(chinese: "未知", english: "Unknown")
        }
    }

    func statusText(for task: NotchIngestTask) -> String {
        switch task.status {
        case .queued:
            return CasebasePromptCatalog.ui.taskQueuedStatus
        case .preparing:
            return CasebasePromptCatalog.ui.taskPreparingStatus
        case .recognizing:
            return CasebasePromptCatalog.ui.taskRecognizingStatus
        case .storing:
            return CasebasePromptCatalog.ui.taskStoringStatus
        case .needsInput:
            return CasebasePromptCatalog.ui.taskNeedsInputStatus
        case .succeeded:
            return CasebasePromptCatalog.ui.taskSucceededStatus
        case .failed:
            return CasebasePromptCatalog.ui.taskFailedStatus
        }
    }

    func detailText(for task: NotchIngestTask) -> String {
        switch task.status {
        case .queued:
            return CasebasePromptCatalog.ui.taskQueuedDetail
        case .preparing:
            return CasebasePromptCatalog.ui.taskPreparingDetail
        case .recognizing:
            return CasebasePromptCatalog.ui.taskRecognizingDetail
        case .storing:
            return CasebasePromptCatalog.ui.taskStoringDetail
        case .needsInput:
            return CasebasePromptCatalog.ui.taskNeedsInputDetail
        case .succeeded:
            return task.record?.shortSummary ?? CasebasePromptCatalog.ui.taskSucceededDetail
        case let .failed(message):
            return message
        }
    }

    private var canEnterHoverActions: Bool {
        unfinishedTaskCount == 0 && !finalSuccessVisible
    }

    private func enqueue(_ payloads: [ImportPayload]) async {
        await enqueue(payloads, prefersAutomaticExpansion: true)
    }

    private func enqueue(_ payloads: [ImportPayload], prefersAutomaticExpansion: Bool) async {
        let now = Date()
        let newTasks = payloads.map { payload in
            NotchIngestTask(
                payload: payload,
                sourceKind: payload.sourceKindHint ?? .binary,
                title: payload.displayName,
                status: .queued,
                prefersAutomaticExpansion: prefersAutomaticExpansion,
                createdAt: now,
                updatedAt: now
            )
        }

        ingestTasks.append(contentsOf: newTasks)
        for task in newTasks {
            CasebaseDebugLogger.log(
                "import enqueued \(importTaskLogContext(task)) queueSize=\(unfinishedTaskCount)"
            )
        }
        finalSuccessVisible = false
        transientResultRailVisible = false
        taskRailResultTask?.cancel()
        startQueueProcessorIfNeeded()
    }

    private func startQueueProcessorIfNeeded() {
        guard queueProcessorTask == nil else { return }
        if let firstNeedsInputTask {
            CasebaseDebugLogger.log(
                "import queue paused reason=awaiting-clarification blockingTask=\(importTaskLogContext(firstNeedsInputTask)) queuedTasks=\(ingestTasks.filter { if case .queued = $0.status { return true } else { return false } }.count)"
            )
            return
        }

        queueProcessorTask = Task { @MainActor [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        defer {
            CasebaseDebugLogger.log("import queue drained unfinishedTasks=\(unfinishedTaskCount)")
            queueProcessorTask = nil
        }

        guard let importCoordinator else {
            presentImportError(
                startupIntegrationError(fallback: CasebasePromptCatalog.errors.importServiceName)
            )
            return
        }

        CasebaseDebugLogger.log("import queue started queuedTasks=\(ingestTasks.filter { if case .queued = $0.status { return true } else { return false } }.count)")

        while let task = nextQueuedTask {
            updateTask(task.id) { pendingTask in
                pendingTask.status = .preparing
                pendingTask.progressDetail = CasebasePromptCatalog.errors.importStageSavingAsset
            }
            CasebaseDebugLogger.log("import dequeued \(importTaskLogContext(task))")

            do {
                let timeoutSeconds = timeoutSeconds(for: task.payload)
                let record = try await withTaskTimeout(
                    seconds: timeoutSeconds,
                    timeoutError: CasebaseError.operationTimedOut(
                        CasebasePromptCatalog.errors.importTaskTimedOut(
                            seconds: Int(timeoutSeconds)
                        )
                    ),
                    timeoutLabel: "task=\(task.id.uuidString) file=\(sanitizedImportLogValue(task.payload.displayName))",
                    onTimeout: { [weak self] in
                        await self?.recordImportTimeout(taskID: task.id, seconds: timeoutSeconds)
                    }
                ) {
                    try await importCoordinator.importPayload(task.payload) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.applyProgressUpdate(progress, to: task.id)
                        }
                    }
                }

                finalizeImportedRecord(record, for: task.id)
                CasebaseDebugLogger.log(
                    "import completed \(importTaskLogContext(task)) recordID=\(record.id.uuidString)"
                )

                if firstNeedsInputTask != nil {
                    break
                }
            } catch {
                let failureMessage = resolvedImportFailureMessage(error, for: task.id)
                CasebaseDebugLogger.log(
                    "import failed \(importTaskLogContext(task)) stage=\(currentImportStageDescription(for: task.id) ?? "unknown") error=\(sanitizedImportLogValue(failureMessage))"
                )
                markTask(task.id, failedWith: failureMessage)
            }
        }

        if unfinishedTaskCount == 0 && hasSuccessfulTasks {
            showFinalSuccessRail()
        }
    }

    private func withTaskTimeout<T>(
        seconds: TimeInterval,
        timeoutError: Error,
        timeoutLabel: String? = nil,
        onTimeout: (@Sendable () async -> Void)? = nil,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                let duration = UInt64(max(seconds, 0) * 1_000_000_000)
                try await Task.sleep(nanoseconds: duration)
                if let timeoutLabel {
                    CasebaseDebugLogger.log(
                        "task timeout fired afterSeconds=\(Int(seconds.rounded())) \(timeoutLabel)"
                    )
                }
                await onTimeout?()
                throw timeoutError
            }

            let result = try await group.next()
            group.cancelAll()
            guard let result else {
                throw timeoutError
            }
            return result
        }
    }

    private var nextQueuedTask: NotchIngestTask? {
        ingestTasks.first(where: { task in
            if case .queued = task.status {
                return true
            }
            return false
        })
    }

    private func applyProgressUpdate(_ progress: ImportProgressUpdate, to taskID: UUID) {
        guard let index = ingestTasks.firstIndex(where: { $0.id == taskID }) else { return }
        let previousDetail = ingestTasks[index].progressDetail

        switch progress.phase {
        case .preparing:
            ingestTasks[index].status = .preparing
            ingestTasks[index].thinkingText = nil
        case .recognizing:
            ingestTasks[index].status = .recognizing
            if let thoughtText = progress.thoughtText, !thoughtText.isEmpty {
                ingestTasks[index].thinkingText = thoughtText
            }
        case .storing:
            ingestTasks[index].status = .storing
            ingestTasks[index].thinkingText = nil
        }

        if let detailText = progress.detailText, !detailText.isEmpty {
            ingestTasks[index].progressDetail = detailText
        }
        ingestTasks[index].updatedAt = Date()

        if let detailText = progress.detailText,
           !detailText.isEmpty,
           detailText != previousDetail
        {
            CasebaseDebugLogger.log(
                "import progress \(importTaskLogContext(ingestTasks[index])) phase=\(progress.phase.rawValue) detail=\(sanitizedImportLogValue(detailText))"
            )
        }
    }

    private func finalizeImportedRecord(_ record: ImportRecord, for taskID: UUID) {
        activeRecord = record
        noticeMessage = nil
        resetAnswerTransientState(clearDraft: true)
        draftQuestion = ""
        let needsClarification = requiresSupplement(for: record)

        updateTask(taskID) { task in
            task.title = record.title
            task.record = record
            task.thinkingText = nil
            task.progressDetail = nil
            task.supplementDraft = record.userSupplement ?? ""
            task.clarificationAnswers = [:]
            task.skippedClarificationQuestionIDs = []
            task.clarificationValidationMessage = nil
            task.currentClarificationQuestionIndex = 0
            task.updatedAt = Date()
            task.status = needsClarification ? .needsInput : .succeeded
        }

        if needsClarification {
            showTransientResultRail()
            presentClarificationPanel()
        }

        if let mockAnswerService = answerService as? MockAnswerService {
            mockAnswerService.replaceContext(records: [record])
        }
    }

    private func finalizeReanalyzedRecord(_ record: ImportRecord, for taskID: UUID) {
        finalizeImportedRecord(record, for: taskID)

        updateTask(taskID) { task in
            task.supplementDraft = record.userSupplement ?? ""
            if !requiresSupplement(for: record) {
                task.updatedAt = Date()
            }
        }
    }

    private func requiresSupplement(for record: ImportRecord) -> Bool {
        record.needsReview
            && record.clarificationRoundCount < maxClarificationRounds
            && !(record.clarificationRequest?.questions.isEmpty ?? true)
    }

    private func markTask(_ taskID: UUID, failedWith message: String) {
        updateTask(taskID) { task in
            task.status = .failed(message)
            task.thinkingText = nil
            task.updatedAt = Date()
        }
        if selectedFailedTaskID == nil {
            selectedFailedTaskID = taskID
        }
    }

    private func recordImportTimeout(taskID: UUID, seconds: TimeInterval) {
        let stageDescription = currentImportStageDescription(for: taskID) ?? "unknown"
        guard let task = ingestTasks.first(where: { $0.id == taskID }) else {
            CasebaseDebugLogger.log(
                "import timeout state missing taskID=\(taskID.uuidString) afterSeconds=\(Int(seconds.rounded())) stage=\(stageDescription)"
            )
            return
        }

        CasebaseDebugLogger.log(
            "import timeout context \(importTaskLogContext(task)) afterSeconds=\(Int(seconds.rounded())) stage=\(sanitizedImportLogValue(stageDescription))"
        )
    }

    private func resolvedImportFailureMessage(_ error: Error, for taskID: UUID) -> String {
        if let casebaseError = error as? CasebaseError,
           case .operationTimedOut = casebaseError
        {
            let timeoutSecondsValue = ingestTasks
                .first(where: { $0.id == taskID })
                .map { timeoutSeconds(for: $0.payload) }
                ?? importOperationTimeoutSeconds
            let timeoutMessage = CasebasePromptCatalog.errors.importTaskTimedOut(
                seconds: Int(timeoutSecondsValue),
                stageDescription: currentImportStageDescription(for: taskID)
            )
            let timeoutError = CasebaseError.operationTimedOut(timeoutMessage)
            return (timeoutError as LocalizedError).errorDescription ?? timeoutError.localizedDescription
        }

        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func currentImportStageDescription(for taskID: UUID) -> String? {
        guard let task = ingestTasks.first(where: { $0.id == taskID }) else { return nil }
        return currentImportStageDescription(for: task)
    }

    private func currentImportStageDescription(for task: NotchIngestTask) -> String? {
        if let progressDetail = task.progressDetail, !progressDetail.isEmpty {
            return progressDetail
        }

        switch task.status {
        case .queued:
            return nil
        case .preparing:
            return CasebasePromptCatalog.errors.importStageSavingAsset
        case .recognizing:
            return CasebasePromptCatalog.errors.importStageExtractingContent
        case .storing, .needsInput:
            return CasebasePromptCatalog.errors.importStageSavingRecord
        case .succeeded, .failed:
            return nil
        }
    }

    private func timeoutSeconds(for payload: ImportPayload) -> TimeInterval {
        MeetingRecordMetadata.isMeetingPayload(payload)
            ? meetingImportOperationTimeoutSeconds
            : importOperationTimeoutSeconds
    }

    private func importTaskLogContext(_ task: NotchIngestTask) -> String {
        "taskID=\(task.id.uuidString) file=\(quotedImportLogValue(task.payload.displayName)) sourceKind=\(task.sourceKind.rawValue) status=\(importTaskStatusLabel(task.status))"
    }

    private func importTaskStatusLabel(_ status: NotchIngestTaskStatus) -> String {
        switch status {
        case .queued:
            return "queued"
        case .preparing:
            return "preparing"
        case .recognizing:
            return "recognizing"
        case .storing:
            return "storing"
        case .needsInput:
            return "needs-input"
        case .succeeded:
            return "succeeded"
        case .failed:
            return "failed"
        }
    }

    private func quotedImportLogValue(_ value: String) -> String {
        "\"\(sanitizedImportLogValue(value))\""
    }

    private func sanitizedImportLogValue(_ value: String, maxLength: Int = 200) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)) + "..."
    }

    private func presentClarificationPanel() {
        intakeFeedbackTask?.cancel()
        intakeFeedbackMessage = nil
        isDropTargeted = false
        isDismissed = false
        storeTaskPanelRestoreState()
        isPinnedExpanded = true
        surfaceState = .taskPanel
        status = .expanded
    }

    private func retryFailedTask(_ taskID: UUID) {
        guard let failedTask = ingestTasks.first(where: { $0.id == taskID }) else { return }
        removeFailedTask(taskID)
        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        presentIntakeFeedback(message: joiningExistingQueue
            ? CasebasePromptCatalog.ui.intakeQueuedFeedback
            : CasebasePromptCatalog.ui.intakeDigestingFeedback)

        Task { [weak self] in
            await self?.enqueue([failedTask.payload], prefersAutomaticExpansion: failedTask.prefersAutomaticExpansion)
        }
    }

    private func dismissFailedTask(_ taskID: UUID) {
        removeFailedTask(taskID)
        if failedTasks.isEmpty, surfaceState == .error {
            surfaceState = .hoverActions
        }
    }

    private func removeFailedTask(_ taskID: UUID) {
        ingestTasks.removeAll { $0.id == taskID }
        syncSelectedFailedTask()
    }

    private func syncSelectedFailedTask() {
        if let selectedFailedTaskID,
           failedTasks.contains(where: { $0.id == selectedFailedTaskID }) {
            return
        }
        selectedFailedTaskID = failedTasks.first?.id
    }

    private func updateTask(_ taskID: UUID, update: (inout NotchIngestTask) -> Void) {
        guard let index = ingestTasks.firstIndex(where: { $0.id == taskID }) else { return }
        update(&ingestTasks[index])
    }

    private var pendingLibraryTasks: [NotchIngestTask] {
        taskPanelTasks.filter { task in
            switch task.status {
            case .queued, .preparing, .recognizing, .storing, .needsInput:
                return true
            case .succeeded, .failed:
                return false
            }
        }
    }

    private func storeTaskPanelRestoreState() {
        guard surfaceState != .taskPanel else { return }
        restoredSurfaceStateBeforeTaskPanel = surfaceState
        restoredStatusBeforeTaskPanel = status
        restoredPinnedStateBeforeTaskPanel = isPinnedExpanded
    }

    private func restoreAfterTaskPanel() {
        isDismissed = false
        surfaceState = restoredSurfaceStateBeforeTaskPanel
        status = restoredStatusBeforeTaskPanel
        isPinnedExpanded = restoredPinnedStateBeforeTaskPanel

        if surfaceState == .hoverActions {
            status = .expanded
            isPinnedExpanded = true
        }
    }

    private func removeLibraryRecord(id: UUID) {
        libraryRecords.removeAll { $0.id == id }

        if selectedLibraryRecord?.id == id {
            selectedLibraryRecord = nil
            if surfaceState == .libraryDetail {
                surfaceState = .library
                status = .expanded
            }
        } else if let selected = selectedLibraryRecord,
                  let refreshedRecord = libraryRecords.first(where: { $0.id == selected.id }) {
            selectedLibraryRecord = refreshedRecord
        }
    }

    private func setMeetingDraft(from session: MeetingRecordingSession) {
        meetingParticipantCount = session.participantCount
        meetingTopic = session.topic
    }

    private func setMeetingDraft(from recording: CompletedMeetingRecording) {
        meetingParticipantCount = recording.participantCount
        meetingTopic = recording.topic
    }

    private func collapseMeetingAfterStart() {
        isDropTargeted = false
        isPinnedExpanded = false
        intakeFeedbackTask?.cancel()
        intakeFeedbackMessage = nil
        isDismissed = true
        status = .collapsed
    }

    private func dismissMeetingSurfaceAfterCompletion() {
        isDropTargeted = false
        isPinnedExpanded = false
        isDismissed = false
        surfaceState = .idle
        status = .collapsed
    }

    private func meetingImportPayload(for recording: CompletedMeetingRecording) -> ImportPayload {
        var metadata: [String: String] = [
            MeetingRecordMetadata.participantCountKey: "\(recording.participantCount)",
            MeetingRecordMetadata.durationSecondsKey: String(format: "%.3f", recording.duration),
            MeetingRecordMetadata.startedAtKey: Self.meetingMetadataDateFormatter.string(from: recording.startedAt),
            MeetingRecordMetadata.sourceKey: MeetingRecordMetadata.sourceValue,
        ]
        if !recording.topic.isEmpty {
            metadata[MeetingRecordMetadata.topicKey] = recording.topic
        }

        return .file(
            FileImportPayload(
                fileURL: recording.fileURL,
                suggestedFileName: meetingSuggestedFileName(for: recording),
                mimeType: "audio/wav",
                sourceKindHint: .audio,
                contextMetadata: metadata
            )
        )
    }

    private func meetingSuggestedFileName(for recording: CompletedMeetingRecording) -> String {
        let timestamp = Self.meetingFileNameDateFormatter.string(from: recording.startedAt)
        let trimmedTopic = recording.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTopic.isEmpty {
            return "会议录音 \(timestamp).wav"
        }
        return "会议录音 \(trimmedTopic) \(timestamp).wav"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func reloadLibraryRecords(using service: LibraryService) async {
        isLibraryLoading = true
        defer { isLibraryLoading = false }

        do {
            let records = try await service.recentRecords(limit: 200)
            libraryRecords = records
            libraryErrorMessage = nil

            if let selected = selectedLibraryRecord {
                selectedLibraryRecord = records.first(where: { $0.id == selected.id })
                if selectedLibraryRecord == nil, surfaceState == .libraryDetail {
                    surfaceState = .library
                }
            }
        } catch {
            libraryErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func updateTaskSupplement(taskID: UUID, value: String) {
        updateTask(taskID) { task in
            task.supplementDraft = value
            task.updatedAt = Date()
        }
    }

    private func updateClarificationAnswer(taskID: UUID, questionID: String, value: String) {
        updateTask(taskID) { task in
            task.clarificationAnswers[questionID] = value
            task.skippedClarificationQuestionIDs.removeAll { $0 == questionID }
            task.clarificationValidationMessage = nil
            task.updatedAt = Date()
        }
    }

    private func skippedClarificationQuestionTitles(for taskID: UUID) -> [String] {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let clarificationRequest = task.record?.clarificationRequest
        else {
            return []
        }

        return clarificationRequest.questions.compactMap { question in
            task.skippedClarificationQuestionIDs.contains(question.id) ? question.title : nil
        }
    }

    private func unresolvedClarificationQuestionTitles(for taskID: UUID) -> [String] {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let clarificationRequest = task.record?.clarificationRequest
        else {
            return []
        }

        return clarificationRequest.questions.compactMap { question in
            let answer = task.clarificationAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return answer.isEmpty ? question.title : nil
        }
    }

    private func cancelClarificationTask(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }) else { return }
        let recordID = task.record?.id
        CasebaseDebugLogger.log(
            "clarification cancellation started taskID=\(taskID.uuidString) hasRecordID=\(recordID != nil) unfinishedBefore=\(unfinishedTaskCount)"
        )

        guard let recordID else {
            removeCancelledTask(taskID)
            return
        }

        guard let libraryService else {
            markTask(
                taskID,
                failedWith: startupIntegrationError(fallback: CasebasePromptCatalog.errors.libraryServiceName).localizedDescription
            )
            return
        }

        errorMessage = nil
        noticeMessage = nil

        removeCancelledTask(taskID)
        startQueueProcessorIfNeeded()

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await libraryService.deleteRecord(id: recordID)
                self.removeLibraryRecord(id: recordID)
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                CasebaseDebugLogger.log(
                    "import clarification cancellation cleanup failed taskID=\(taskID.uuidString) recordID=\(recordID.uuidString) error=\(self.sanitizedImportLogValue(self.errorMessage ?? error.localizedDescription))"
                )
            }
        }
    }

    private func removeCancelledTask(_ taskID: UUID) {
        ingestTasks.removeAll { $0.id == taskID }
        if selectedLibraryTaskID == taskID {
            selectedLibraryTaskID = nil
        }
        if pendingClarificationCancellationTaskID == taskID {
            pendingClarificationCancellationTaskID = nil
        }
        CasebaseDebugLogger.log(
            "clarification cancellation removed taskID=\(taskID.uuidString) unfinishedAfter=\(unfinishedTaskCount) needsInputRemaining=\(firstNeedsInputTask != nil)"
        )
        reconcileAfterCancelledTaskRemoval()
    }

    private func reconcileAfterCancelledTaskRemoval() {
        if firstNeedsInputTask != nil {
            CasebaseDebugLogger.log("clarification cancellation reconcile outcome=show-next-needs-input")
            if surfaceState == .taskPanel {
                isDismissed = false
                isPinnedExpanded = true
                status = .expanded
            }
            return
        }

        if unfinishedTaskCount > 0 {
            CasebaseDebugLogger.log("clarification cancellation reconcile outcome=resume-queue unfinished=\(unfinishedTaskCount)")
            if surfaceState == .taskPanel {
                restoreAfterTaskPanel()
            }
            return
        }

        finalSuccessTask?.cancel()
        taskRailResultTask?.cancel()
        finalSuccessTask = nil
        taskRailResultTask = nil
        finalSuccessVisible = false
        transientResultRailVisible = false
        pruneCompletedTasks()

        if surfaceState == .taskPanel {
            CasebaseDebugLogger.log("clarification cancellation reconcile outcome=collapse-idle")
            isDismissed = false
            isPinnedExpanded = false
            restoredSurfaceState = .idle
            restoredSurfaceStateBeforeTaskPanel = .idle
            restoredStatusBeforeTaskPanel = .collapsed
            restoredPinnedStateBeforeTaskPanel = false
            surfaceState = .idle
            status = .collapsed
        }
    }

    private func normalizedClarificationAnswers(for taskID: UUID, allowEmptyAnswers: Bool) -> [ClarificationAnswer]? {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let clarificationRequest = task.record?.clarificationRequest
        else {
            return []
        }

        let answers = clarificationRequest.questions.compactMap { question -> ClarificationAnswer? in
            guard let answer = task.clarificationAnswers[question.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !answer.isEmpty
            else {
                return nil
            }

            return ClarificationAnswer(
                questionID: question.id,
                questionTitle: question.title,
                answer: answer
            )
        }

        guard !answers.isEmpty || allowEmptyAnswers else {
            updateTask(taskID) { task in
                task.clarificationValidationMessage = CasebasePromptCatalog.ui.taskClarificationNeedAtLeastOneAnswer
                task.updatedAt = Date()
            }
            return nil
        }

        return answers
    }

    private enum LibraryPreviewKind {
        case image
        case pdf
        case text
        case audio
        case video
        case folder
        case file
    }

    private func inferredPreviewKind(for record: ImportRecord) -> LibraryPreviewKind {
        if record.sourceKind == .image {
            return .image
        }
        if record.sourceKind == .pdf {
            return .pdf
        }
        if record.sourceKind == .text {
            return .text
        }
        if record.sourceKind == .audio {
            return .audio
        }
        if record.sourceKind == .folder {
            return .folder
        }

        let loweredMime = record.mimeType?.lowercased() ?? ""
        if loweredMime.hasPrefix("video/") {
            return .video
        }

        let ext = URL(fileURLWithPath: record.fileName).pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext) {
            return .video
        }
        return .file
    }

    private func localizedPreviewLabel(chinese: String, english: String) -> String {
        CasebasePromptCatalog.language == .simplifiedChinese ? chinese : english
    }

    private func presentIntakeFeedback(message: String) {
        intakeFeedbackTask?.cancel()
        errorMessage = nil
        noticeMessage = nil
        intakeFeedbackMessage = message
        pulseFeedback()

        if suppressHoverUntilMouseExit {
            collapseAfterDropSubmission()
        } else if surfaceState == .dropTarget || surfaceState == .intakeFeedback {
            isDropTargeted = false
            isPinnedExpanded = false
            isDismissed = false
            surfaceState = .idle
            status = .collapsed
        }

        intakeFeedbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.intakeFeedbackDurationNs)
            self.intakeFeedbackMessage = nil
        }
    }

    private func pulseFeedback() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.68)) {
            feedbackScale = 1.035
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                self?.feedbackScale = 1
            }
        }
    }

    private func collapseAfterDropSubmission() {
        isDropTargeted = false
        isPinnedExpanded = false
        isDismissed = false
        restoredSurfaceState = .idle
        surfaceState = .idle
        status = .collapsed
    }

    private func animateCaptureSink() {
        captureSinkProgress = 0

        Task { @MainActor [weak self] in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.62)) {
                self?.captureSinkProgress = 1
            }

            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.easeOut(duration: 0.56)) {
                self?.captureSinkProgress = 0
            }
        }
    }

    private func showFinalSuccessRail() {
        finalSuccessTask?.cancel()
        taskRailResultTask?.cancel()
        finalSuccessVisible = true
        transientResultRailVisible = true

        finalSuccessTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.taskRailResultDurationNs)
            self.transientResultRailVisible = false
            self.finalSuccessVisible = false

            if self.surfaceState != .taskPanel {
                self.pruneCompletedTasks()
            }
        }
    }

    private func showTransientResultRail() {
        taskRailResultTask?.cancel()
        transientResultRailVisible = true

        taskRailResultTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.taskRailResultDurationNs)
            self.transientResultRailVisible = false
        }
    }

    private func pruneCompletedTasks() {
        ingestTasks.removeAll(where: \.isCompleted)
    }

    private func resetAnswerTransientState(clearDraft: Bool = false) {
        latestAnswer = nil
        streamingAnswerText = ""
        answerThinkingText = ""
        isWaitingForAnswerStream = false
        if clearDraft {
            draftQuestion = ""
        }
    }

    private func revealAnswerPanelForStreamingIfNeeded() {
        guard isWaitingForAnswerStream || isDismissed || status == .collapsed else { return }
        isWaitingForAnswerStream = false
        isDismissed = false
        isPinnedExpanded = true
        status = .expanded
    }

    private func runAnswer(_ question: String) async {
        guard let answerService else {
            presentAnswerError(
                startupIntegrationError(fallback: CasebasePromptCatalog.errors.answerServiceName),
                question: question
            )
            return
        }

        let answerScope: AnswerQueryScope
        let activeSearchConversationIDForAnswer: UUID?
        switch questionContext {
        case .savedRecord:
            guard let activeRecord else {
                presentAnswerError(CasebaseError.emptyQuery, question: question)
                return
            }
            answerScope = .recordIDs([activeRecord.id])
            activeSearchConversationIDForAnswer = nil
        case .globalSearch, .none:
            answerScope = .global
            activeSearchConversationIDForAnswer = prepareSearchConversationIfNeeded(for: question)
        }

        lastSubmittedQuestion = question
        lastFailedAction = nil
        errorMessage = nil
        resetAnswerTransientState()
        isPinnedExpanded = false
        isDismissed = true
        isBusy = true
        isWaitingForAnswerStream = true
        surfaceState = .answering
        status = .collapsed

        do {
            let result = try await answerService.answer(
                question: question,
                scope: answerScope,
                limit: resultLimit,
                streamHandler: { [weak self] partialText in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if !partialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.revealAnswerPanelForStreamingIfNeeded()
                        }
                        self.streamingAnswerText = partialText
                    }
                },
                thoughtHandler: { [weak self] thoughtText in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.answerThinkingText = thoughtText
                    }
                }
            )
            latestAnswer = result
            streamingAnswerText = result.answerText
            answerThinkingText = ""
            isWaitingForAnswerStream = false
            if let activeSearchConversationIDForAnswer {
                appendSearchConversationTurn(
                    question: question,
                    answer: result,
                    to: activeSearchConversationIDForAnswer
                )
            }
            draftQuestion = ""
            isBusy = false
            isDismissed = false
            isPinnedExpanded = true
            surfaceState = .answerReady
            status = .expanded
            lastFailedAction = nil
        } catch {
            presentAnswerError(error, question: question)
        }
    }

    private var searchConversationStoreURL: URL? {
        storageRootDirectory?.appendingPathComponent(searchConversationStoreFileName, isDirectory: false)
    }

    private func loadSearchConversations() {
        guard
            let url = searchConversationStoreURL,
            let data = try? Data(contentsOf: url)
        else {
            searchConversations = []
            return
        }

        do {
            let decoder = JSONDecoder()
            searchConversations = try decoder.decode([NotchSearchConversation].self, from: data)
        } catch {
            searchConversations = []
        }
    }

    private func persistSearchConversations() {
        guard let url = searchConversationStoreURL else { return }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(searchConversations)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private func deletePersistedSearchConversations() {
        guard let url = searchConversationStoreURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func prepareSearchConversationIfNeeded(for question: String) -> UUID? {
        guard questionContext == .globalSearch else { return nil }
        searchConversationListVisible = false

        if let activeSearchConversationID,
           searchConversations.contains(where: { $0.id == activeSearchConversationID })
        {
            return activeSearchConversationID
        }

        let now = Date()
        let conversation = NotchSearchConversation(
            title: searchConversationTitle(for: question),
            createdAt: now,
            updatedAt: now
        )
        searchConversations.insert(conversation, at: 0)
        activeSearchConversationID = conversation.id
        persistSearchConversations()
        return conversation.id
    }

    private func appendSearchConversationTurn(
        question: String,
        answer: AnswerResult,
        to conversationID: UUID
    ) {
        guard let index = searchConversations.firstIndex(where: { $0.id == conversationID }) else { return }

        let turn = NotchSearchConversationTurn(question: question, answer: answer)
        var conversation = searchConversations.remove(at: index)
        conversation.turns.append(turn)
        conversation.updatedAt = turn.createdAt
        if conversation.turns.count == 1 {
            conversation.title = searchConversationTitle(for: question)
        }

        searchConversations.insert(conversation, at: 0)
        activeSearchConversationID = conversation.id
        persistSearchConversations()
    }

    private func searchConversationTitle(for question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CasebasePromptCatalog.ui.searchPanelTitle
        }

        let limit = CasebasePromptCatalog.language == .simplifiedChinese ? 18 : 28
        if trimmed.count <= limit {
            return trimmed
        }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func topTags(for conversation: NotchSearchConversation) -> [String] {
        var counts: [String: Int] = [:]
        var firstSeenOrder: [String: Int] = [:]
        var nextOrder = 0

        for turn in conversation.turns {
            for citation in turn.answer.citations {
                for rawTag in citation.sourceTags {
                    let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !tag.isEmpty else { continue }
                    counts[tag, default: 0] += 1
                    if firstSeenOrder[tag] == nil {
                        firstSeenOrder[tag] = nextOrder
                        nextOrder += 1
                    }
                }
            }
        }

        return counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs] ?? 0
            let rhsCount = counts[rhs] ?? 0
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return (firstSeenOrder[lhs] ?? 0) < (firstSeenOrder[rhs] ?? 0)
        }
        .prefix(3)
        .map { $0 }
    }

    private func removeSearchConversation(id: UUID) {
        searchConversations.removeAll { $0.id == id }

        if activeSearchConversationID == id {
            activeSearchConversationID = nil
        }

        persistSearchConversations()
    }

    private func restoreAfterDropExit() {
        isDropTargeted = false
        noticeMessage = nil

        switch restoredSurfaceState {
        case .idle:
            isPinnedExpanded = false
            isDismissed = false
            surfaceState = .idle
            status = .collapsed
        case .hoverActions:
            if canEnterHoverActions {
                isPinnedExpanded = false
                isDismissed = false
                surfaceState = .hoverActions
                status = .expanded
            } else {
                surfaceState = .idle
                status = .collapsed
            }
        default:
            surfaceState = restoredSurfaceState
            isPinnedExpanded = true
            isDismissed = false
            status = .expanded
        }
    }

    private func presentImportError(_ error: Error) {
        isBusy = false
        isDropTargeted = false
        isPinnedExpanded = true
        intakeFeedbackMessage = nil
        resetAnswerTransientState()
        surfaceState = .error
        status = .expanded
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func presentAnswerError(_ error: Error, question: String) {
        isBusy = false
        isPinnedExpanded = true
        resetAnswerTransientState()
        isDismissed = false
        surfaceState = .error
        status = .expanded
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastFailedAction = .answerQuestion(question)
    }

    private func startupIntegrationError(fallback: String) -> Error {
        if let startupErrorMessage, !startupErrorMessage.isEmpty {
            return CasebaseError.missingConfiguration(startupErrorMessage)
        }
        return CasebaseError.missingConfiguration(fallback)
    }

    private func taskSortKey(_ status: NotchIngestTaskStatus) -> Int {
        switch status {
        case .recognizing:
            return 0
        case .storing:
            return 1
        case .preparing:
            return 2
        case .queued:
            return 3
        case .needsInput:
            return 4
        case .succeeded:
            return 5
        case .failed:
            return 6
        }
    }

    private func adaptiveExpandedHeight(for state: CasebaseSurfaceState, minimum: CGFloat) -> CGFloat {
        guard state.usesAdaptiveExpandedHeight else { return minimum }
        let preferredHeight = preferredAdaptiveExpandedHeight(for: state, minimum: minimum)
        let measuredHeight = measuredExpandedContentHeights[state] ?? preferredHeight
        let maximumHeight = maximumAdaptiveExpandedHeight(for: state)
        return min(max(max(measuredHeight, preferredHeight), minimum), maximumHeight)
    }

    private func preferredAdaptiveExpandedHeight(for state: CasebaseSurfaceState, minimum: CGFloat) -> CGFloat {
        switch state {
        case .hoverActions:
            return hasHoverActionPrompt
                ? hoverExpandedPanelUnauthorizedMinHeight
                : hoverExpandedPanelSize.height
        case .settingsAPIKeys:
            return NotchAPIKeySettingsView.measuredContentHeight()
        case .meeting:
            return meetingPreferredPanelHeight
        case .library:
            return libraryPreferredPanelHeight
        case .libraryDetail:
            return libraryDetailPreferredPanelHeight
        case .savedPreview:
            return savedPreviewPreferredPanelHeight
        case .search:
            return searchPreferredPanelHeight
        case .taskPanel:
            return taskPanelPreferredPanelHeight
        default:
            return minimum
        }
    }

    private var hasHoverActionPrompt: Bool {
        !selectionCaptureAuthorized || !screenshotCaptureAuthorized || !apiKeyConfigured
    }

    private func maximumAdaptiveExpandedHeight(for state: CasebaseSurfaceState) -> CGFloat {
        switch state {
        case .meeting:
            return meetingMaxPanelHeight
        case .library:
            return libraryMaxPanelHeight
        case .libraryDetail:
            return libraryDetailMaxPanelHeight
        case .savedPreview:
            return savedPreviewMaxPanelHeight
        case .search:
            return searchMaxPanelHeight
        case .taskPanel:
            return taskPanelMaxPanelHeight
        default:
            return maxAdaptiveExpandedPanelHeight
        }
    }

    private static let meetingMetadataDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let meetingFileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()
}
