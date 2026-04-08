import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum Status: Equatable {
        case collapsed
        case expanded
    }

    enum CollapsedIndicator {
        case warning
        case error
    }

    private enum FailedAction: Equatable {
        case answerQuestion(String)
    }

    let hoverInset: CGFloat = -16
    let hoverRange: CGFloat = 32
    let contentPadding: CGFloat = 16
    let idleExpandedPanelSize = CGSize(width: 420, height: 168)
    let hoverExpandedPanelSize = CGSize(width: 420, height: 150)
    let hoverExpandedPanelUnauthorizedMinHeight: CGFloat = 176
    let maxAdaptiveExpandedPanelHeight: CGFloat = 640
    let taskRailSpacing: CGFloat = 8
    let taskRailVerticalSpacing: CGFloat = 8
    let intakeFeedbackDurationNs: UInt64 = 520_000_000
    let finalSuccessDurationNs: UInt64 = 1_450_000_000
    let maxClarificationRounds = 3

    @Published private(set) var surfaceState: CasebaseSurfaceState = .idle
    @Published private(set) var isDropTargeted = false
    @Published private(set) var isPinnedExpanded = false
    @Published private(set) var activeRecord: ImportRecord?
    @Published private(set) var latestAnswer: AnswerResult?
    @Published private(set) var libraryRecords: [ImportRecord] = []
    @Published private(set) var selectedLibraryRecord: ImportRecord?
    @Published var draftQuestion = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var libraryErrorMessage: String?
    @Published private(set) var noticeMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isLibraryLoading = false
    @Published private(set) var isDeletingLibraryRecord = false
    @Published private(set) var intakeFeedbackMessage: String?
    @Published private(set) var ingestTasks: [NotchIngestTask] = []
    @Published private(set) var feedbackScale: CGFloat = 1
    @Published private(set) var captureSinkProgress: CGFloat = 0
    @Published private(set) var selectionCaptureAuthorized = true
    @Published private(set) var screenshotCaptureAuthorized = true
    @Published private(set) var isDismissed = false
    @Published private(set) var isClearingStoredData = false
    @Published private(set) var selectedFailedTaskID: UUID?
    @Published private(set) var suppressHoverUntilMouseExit = false

    @Published private(set) var status: Status = .collapsed
    @Published var displayCutoutRect: CGRect
    @Published var screenFrame: CGRect

    private let importCoordinator: ImportCoordinator?
    private let answerService: AnswerService?
    private let libraryService: LibraryService?
    private let dataResetService: DataResetService?
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
    private var lastSubmittedQuestion: String?
    private var lastFailedAction: FailedAction?
    private var queueProcessorTask: Task<Void, Never>?
    private var intakeFeedbackTask: Task<Void, Never>?
    private var finalSuccessTask: Task<Void, Never>?
    private var finalSuccessVisible = false
    private var measuredExpandedContentHeights: [CasebaseSurfaceState: CGFloat] = [:]
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
        guard collapsedIndicator == .error, failedTasks.count > 1, !isExpanded else { return 0 }
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
                    minimum: selectionCaptureAuthorized
                        ? hoverExpandedPanelSize.height
                        : hoverExpandedPanelUnauthorizedMinHeight
                )
            )
        case .library:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .library, minimum: 220))
        case .libraryDetail:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .libraryDetail, minimum: 300))
        case .settings:
            return CGSize(width: 520, height: adaptiveExpandedHeight(for: .settings, minimum: 320))
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
        surfaceState == .savedPreview || surfaceState == .answerReady
    }

    var canOpenDataResetConfirmation: Bool {
        unfinishedTaskCount == 0 && !isBusy && !isClearingStoredData
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

    var firstNeedsInputTask: NotchIngestTask? {
        ingestTasks.first { task in
            if case .needsInput = task.status {
                return true
            }
            return false
        }
    }

    var showsTaskRail: Bool {
        guard status == .collapsed else {
            return false
        }
        guard surfaceState != .dropTarget, surfaceState != .intakeFeedback else {
            return false
        }
        return (unfinishedTaskCount > 0 || finalSuccessVisible) && failedTasks.isEmpty && errorMessage == nil
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

    var taskRailWidth: CGFloat {
        var width: CGFloat = taskRailState == .success || taskRailState == .needsInput ? 56 : 160
        if taskRailBadgeText != nil {
            width += 36
        }
        return width
    }

    var taskRailOffsetY: CGFloat {
        max(0, displayCutoutRect.height + taskRailVerticalSpacing)
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
            latestAnswer = nil
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
        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        presentIntakeFeedback(
            message: joiningExistingQueue
                ? CasebasePromptCatalog.ui.intakeQueuedFeedback
                : CasebasePromptCatalog.ui.intakeDigestingFeedback,
            expandsSurface: false
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let payloads = try await NotchDropPayloadLoader.loadPayloads(from: providers)
                await self.enqueue(payloads)
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
            surfaceState = .hoverActions
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
        guard surfaceState != .settings, surfaceState != .settingsDataResetConfirmation else { return }
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

        restoredSurfaceStateBeforeLibrary = surfaceState
        restoredStatusBeforeLibrary = status
        restoredPinnedStateBeforeLibrary = isPinnedExpanded

        isDismissed = false
        isPinnedExpanded = true
        selectedLibraryRecord = nil
        libraryErrorMessage = nil
        errorMessage = nil
        surfaceState = .library
        status = .expanded

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.reloadLibraryRecords(using: libraryService)
        }
    }

    func closeLibrary() {
        guard surfaceState == .library || surfaceState == .libraryDetail else { return }
        isDismissed = false
        selectedLibraryRecord = nil
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
        libraryErrorMessage = nil
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .libraryDetail
        status = .expanded
    }

    func closeLibraryDetail() {
        guard surfaceState == .libraryDetail else { return }
        selectedLibraryRecord = nil
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
        guard surfaceState == .settings || surfaceState == .settingsDataResetConfirmation else { return }
        isDismissed = false
        surfaceState = restoredSurfaceStateBeforeSettings
        status = restoredStatusBeforeSettings
        isPinnedExpanded = restoredPinnedStateBeforeSettings
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
        guard !ingestTasks.isEmpty else { return }
        intakeFeedbackTask?.cancel()
        isDismissed = false
        surfaceState = .taskPanel
        isPinnedExpanded = true
        status = .expanded
    }

    func closeTaskPanel() {
        surfaceState = .idle
        isPinnedExpanded = false
        isDismissed = false
        status = .collapsed

        if unfinishedTaskCount == 0, !finalSuccessVisible {
            pruneCompletedTasks()
        }
    }

    func backToHomeFromTaskPanel() {
        guard surfaceState == .taskPanel else { return }
        isDismissed = false
        isPinnedExpanded = true
        surfaceState = .hoverActions
        status = .expanded
    }

    func openTaskRecord(_ taskID: UUID) {
        guard let task = ingestTasks.first(where: { $0.id == taskID }),
              let record = task.record
        else { return }

        activeRecord = record
        latestAnswer = nil
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
        latestAnswer = nil
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
              let questions = task.record?.clarificationRequest?.questions,
              !questions.isEmpty
        else {
            return
        }

        let index = min(task.currentClarificationQuestionIndex, questions.count - 1)
        let currentQuestion = questions[index]

        updateTask(taskID) { task in
            task.clarificationAnswers.removeValue(forKey: currentQuestion.id)
            if !task.skippedClarificationQuestionIDs.contains(currentQuestion.id) {
                task.skippedClarificationQuestionIDs.append(currentQuestion.id)
            }
            task.clarificationValidationMessage = nil
            task.updatedAt = Date()
        }

        if index < questions.count - 1 {
            goToNextClarificationQuestion(taskID)
        } else {
            submitClarification(taskID, allowEmptyAnswers: true)
        }
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
            pendingTask.clarificationValidationMessage = nil
            pendingTask.updatedAt = Date()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let refreshedRecord = try await importCoordinator.reanalyzeRecord(
                    id: record.id,
                    clarificationAnswers: clarificationAnswers,
                    skippedQuestionTitles: skippedQuestionTitles
                ) { [weak self] phase in
                    Task { @MainActor [weak self] in
                        self?.applyProgressPhase(phase, to: taskID)
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
        queueProcessorTask = nil
        intakeFeedbackTask = nil
        finalSuccessTask = nil
        finalSuccessVisible = false

        activeRecord = nil
        latestAnswer = nil
        libraryRecords = []
        selectedLibraryRecord = nil
        draftQuestion = ""
        errorMessage = nil
        libraryErrorMessage = nil
        noticeMessage = nil
        intakeFeedbackMessage = nil
        isBusy = false
        isLibraryLoading = false
        isDeletingLibraryRecord = false
        isDropTargeted = false
        isPinnedExpanded = false
        lastFailedAction = nil
        lastSubmittedQuestion = nil
        restoredSurfaceState = .idle
        restoredSurfaceStateBeforeSettings = .idle
        restoredStatusBeforeSettings = .collapsed
        restoredPinnedStateBeforeSettings = false
        ingestTasks = []
        feedbackScale = 1
        isDismissed = false
        isClearingStoredData = false
        selectedFailedTaskID = nil
        surfaceState = .idle
        status = .collapsed
    }

    func handleStoredDataCleared() {
        clear()
    }

    func handleRecordDeleted(_ id: UUID) {
        removeLibraryRecord(id: id)
    }

    func libraryAssetURL(for record: ImportRecord) -> URL? {
        storageRootDirectory?.appendingPathComponent(record.assetPath, isDirectory: false)
    }

    func libraryKindLabel(for record: ImportRecord) -> String {
        switch inferredPreviewKind(for: record) {
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
        case .file:
            return localizedPreviewLabel(chinese: "文件", english: "File")
        }
    }

    func libraryKindDetail(for record: ImportRecord) -> String {
        switch inferredPreviewKind(for: record) {
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
        case .file:
            return localizedPreviewLabel(chinese: "通用文件", english: "General file")
        }
    }

    func libraryPreviewSystemImage(for record: ImportRecord) -> String {
        switch inferredPreviewKind(for: record) {
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
        let now = Date()
        let newTasks = payloads.map { payload in
            NotchIngestTask(
                payload: payload,
                sourceKind: payload.sourceKindHint ?? .binary,
                title: payload.displayName,
                status: .queued,
                createdAt: now,
                updatedAt: now
            )
        }

        ingestTasks.append(contentsOf: newTasks)
        finalSuccessVisible = false
        startQueueProcessorIfNeeded()
    }

    private func startQueueProcessorIfNeeded() {
        guard queueProcessorTask == nil, firstNeedsInputTask == nil else { return }

        queueProcessorTask = Task { @MainActor [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        defer { queueProcessorTask = nil }

        guard let importCoordinator else {
            presentImportError(
                startupIntegrationError(fallback: CasebasePromptCatalog.errors.importServiceName)
            )
            return
        }

        while let task = nextQueuedTask {
            updateTask(task.id) { pendingTask in
                pendingTask.status = .preparing
            }

            do {
                let record = try await importCoordinator.importPayload(task.payload) { [weak self] phase in
                    Task { @MainActor [weak self] in
                        self?.applyProgressPhase(phase, to: task.id)
                    }
                }

                finalizeImportedRecord(record, for: task.id)

                if firstNeedsInputTask != nil {
                    break
                }
            } catch {
                markTask(task.id, failedWith: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }

        if unfinishedTaskCount == 0 && hasSuccessfulTasks {
            showFinalSuccessRail()
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

    private func applyProgressPhase(_ phase: ImportProcessingPhase, to taskID: UUID) {
        updateTask(taskID) { task in
            switch phase {
            case .preparing:
                task.status = .preparing
            case .recognizing:
                task.status = .recognizing
            case .storing:
                task.status = .storing
            }
        }
    }

    private func finalizeImportedRecord(_ record: ImportRecord, for taskID: UUID) {
        activeRecord = record
        noticeMessage = nil
        latestAnswer = nil
        draftQuestion = ""

        updateTask(taskID) { task in
            task.title = record.title
            task.record = record
            task.supplementDraft = record.userSupplement ?? ""
            task.clarificationAnswers = [:]
            task.skippedClarificationQuestionIDs = []
            task.clarificationValidationMessage = nil
            task.currentClarificationQuestionIndex = 0
            task.updatedAt = Date()
            task.status = requiresSupplement(for: record) ? .needsInput : .succeeded
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

        if record.clarificationRoundCount >= maxClarificationRounds,
           record.needsReview,
           record.clarificationRequest == nil
        {
            noticeMessage = CasebasePromptCatalog.ui.taskClarificationMaxRoundsNotice
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
            task.updatedAt = Date()
        }
        if selectedFailedTaskID == nil {
            selectedFailedTaskID = taskID
        }
    }

    private func retryFailedTask(_ taskID: UUID) {
        guard let failedTask = ingestTasks.first(where: { $0.id == taskID }) else { return }
        removeFailedTask(taskID)
        let joiningExistingQueue = unfinishedTaskCount > 0 || finalSuccessVisible
        presentIntakeFeedback(message: joiningExistingQueue
            ? CasebasePromptCatalog.ui.intakeQueuedFeedback
            : CasebasePromptCatalog.ui.intakeDigestingFeedback)

        Task { [weak self] in
            await self?.enqueue([failedTask.payload])
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

    private func presentIntakeFeedback(message: String, expandsSurface: Bool = true) {
        intakeFeedbackTask?.cancel()
        errorMessage = nil
        noticeMessage = nil
        intakeFeedbackMessage = message
        isDropTargeted = false
        pulseFeedback()

        if expandsSurface {
            isPinnedExpanded = false
            isDismissed = false
            surfaceState = .intakeFeedback
            status = .expanded
        } else if surfaceState == .dropTarget || surfaceState == .intakeFeedback {
            isPinnedExpanded = false
            isDismissed = false
            surfaceState = .idle
            status = .collapsed
        }

        intakeFeedbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.intakeFeedbackDurationNs)
            self.intakeFeedbackMessage = nil
            guard expandsSurface, self.surfaceState == .intakeFeedback else { return }
            self.surfaceState = .idle
            self.status = .collapsed
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
        finalSuccessVisible = true

        finalSuccessTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.finalSuccessDurationNs)
            self.finalSuccessVisible = false

            if self.surfaceState != .taskPanel {
                self.pruneCompletedTasks()
            }
        }
    }

    private func pruneCompletedTasks() {
        ingestTasks.removeAll(where: \.isCompleted)
    }

    private func runAnswer(_ question: String) async {
        guard let answerService else {
            presentAnswerError(
                startupIntegrationError(fallback: CasebasePromptCatalog.errors.answerServiceName),
                question: question
            )
            return
        }

        lastSubmittedQuestion = question
        lastFailedAction = nil
        errorMessage = nil
        isPinnedExpanded = true
        isDismissed = false
        isBusy = true
        surfaceState = .answering
        status = .expanded

        do {
            let result = try await answerService.answer(question: question, limit: resultLimit)
            latestAnswer = result
            draftQuestion = ""
            isBusy = false
            surfaceState = .answerReady
            lastFailedAction = nil
        } catch {
            presentAnswerError(error, question: question)
        }
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
        surfaceState = .error
        status = .expanded
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func presentAnswerError(_ error: Error, question: String) {
        isBusy = false
        isPinnedExpanded = true
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
        let measuredHeight = measuredExpandedContentHeights[state] ?? minimum
        return min(max(measuredHeight, minimum), maxAdaptiveExpandedPanelHeight)
    }
}
