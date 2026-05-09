import AVFoundation
import Foundation

enum MeetingRecorderPermissionStatus: Equatable {
    case undetermined
    case granted
    case denied
}

struct MeetingRecordingSession: Equatable {
    let id: UUID
    let participantCount: Int
    let topic: String
    let fileURL: URL
    let startedAt: Date
    let elapsedDuration: TimeInterval
    let isPaused: Bool
}

struct CompletedMeetingRecording {
    let participantCount: Int
    let topic: String
    let fileURL: URL
    let startedAt: Date
    let duration: TimeInterval
}

@MainActor
final class CasebaseMeetingRecorder: NSObject, ObservableObject, @preconcurrency AVAudioRecorderDelegate {
    enum RecorderError: LocalizedError {
        case microphonePermissionDenied
        case sessionAlreadyRunning
        case noActiveSession
        case alreadyPaused
        case alreadyRecording
        case recordingStartFailed
        case failedToCreateRecorder

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return CasebasePromptCatalog.ui.meetingPermissionDeniedMessage
            case .sessionAlreadyRunning:
                return CasebasePromptCatalog.ui.meetingSessionAlreadyRunningMessage
            case .noActiveSession:
                return CasebasePromptCatalog.ui.meetingSessionMissingMessage
            case .alreadyPaused:
                return CasebasePromptCatalog.ui.meetingAlreadyPausedMessage
            case .alreadyRecording:
                return CasebasePromptCatalog.ui.meetingAlreadyRecordingMessage
            case .recordingStartFailed:
                return CasebasePromptCatalog.ui.meetingRecordingStartFailedMessage
            case .failedToCreateRecorder:
                return CasebasePromptCatalog.ui.meetingRecorderCreationFailedMessage
            }
        }
    }

    @Published private(set) var activeSession: MeetingRecordingSession?
    @Published private(set) var permissionStatus: MeetingRecorderPermissionStatus = .undetermined
    @Published private(set) var isBusy = false
    @Published private(set) var lastErrorMessage: String?

    private let fileManager: FileManager
    private let recordingsDirectory: URL
    private var recorder: AVAudioRecorder?
    private var sessionSeed: SessionSeed?
    private var tickerTask: Task<Void, Never>?

    private struct SessionSeed {
        let id: UUID
        let participantCount: Int
        let topic: String
        let fileURL: URL
        let startedAt: Date
    }

    init(
        fileManager: FileManager = .default,
        recordingsDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.recordingsDirectory = recordingsDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("casebase-meetings", isDirectory: true)
        super.init()
        refreshPermissionStatus()
    }

    func start(participantCount: Int, topic: String) async throws {
        guard recorder == nil, activeSession == nil else {
            throw RecorderError.sessionAlreadyRunning
        }

        lastErrorMessage = nil
        try await ensureMicrophonePermission()

        let normalizedParticipantCount = max(1, participantCount)
        let normalizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let startedAt = Date()
        let fileURL = try makeOutputURL(topic: normalizedTopic, startedAt: startedAt)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw RecorderError.recordingStartFailed
            }

            self.recorder = recorder
            sessionSeed = SessionSeed(
                id: UUID(),
                participantCount: normalizedParticipantCount,
                topic: normalizedTopic,
                fileURL: fileURL,
                startedAt: startedAt
            )
            publishSession(isPaused: false)
            startTicker()
        } catch {
            cleanupFileIfNeeded(at: fileURL)
            if error is RecorderError {
                throw error
            }
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            throw RecorderError.failedToCreateRecorder
        }
    }

    func pause() throws {
        guard let recorder else {
            throw RecorderError.noActiveSession
        }
        guard recorder.isRecording else {
            throw RecorderError.alreadyPaused
        }

        lastErrorMessage = nil
        recorder.pause()
        stopTicker()
        publishSession(isPaused: true)
    }

    func resume() throws {
        guard let recorder else {
            throw RecorderError.noActiveSession
        }
        guard !recorder.isRecording else {
            throw RecorderError.alreadyRecording
        }

        lastErrorMessage = nil
        guard recorder.record() else {
            throw RecorderError.recordingStartFailed
        }
        publishSession(isPaused: false)
        startTicker()
    }

    func discard() throws {
        guard let recorder, let sessionSeed else {
            throw RecorderError.noActiveSession
        }

        lastErrorMessage = nil
        stopTicker()
        recorder.stop()
        self.recorder = nil
        self.sessionSeed = nil
        activeSession = nil
        cleanupFileIfNeeded(at: sessionSeed.fileURL)
    }

    func finish() throws -> CompletedMeetingRecording {
        guard let recorder, let sessionSeed else {
            throw RecorderError.noActiveSession
        }

        lastErrorMessage = nil
        stopTicker()
        let duration = max(0, recorder.currentTime)
        recorder.stop()
        self.recorder = nil
        self.sessionSeed = nil
        activeSession = nil

        return CompletedMeetingRecording(
            participantCount: sessionSeed.participantCount,
            topic: sessionSeed.topic,
            fileURL: sessionSeed.fileURL,
            startedAt: sessionSeed.startedAt,
            duration: duration
        )
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        stopTicker()
        let failedFileURL = sessionSeed?.fileURL
        self.recorder = nil
        sessionSeed = nil
        activeSession = nil
        lastErrorMessage = (error as? LocalizedError)?.errorDescription
            ?? error?.localizedDescription
            ?? CasebasePromptCatalog.ui.meetingRecordingInterruptedMessage
        if let failedFileURL {
            cleanupFileIfNeeded(at: failedFileURL)
        }
    }

    private func publishSession(isPaused: Bool) {
        guard let sessionSeed, let recorder else {
            activeSession = nil
            return
        }

        activeSession = MeetingRecordingSession(
            id: sessionSeed.id,
            participantCount: sessionSeed.participantCount,
            topic: sessionSeed.topic,
            fileURL: sessionSeed.fileURL,
            startedAt: sessionSeed.startedAt,
            elapsedDuration: max(0, recorder.currentTime),
            isPaused: isPaused
        )
    }

    private func startTicker() {
        stopTicker()
        tickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.publishSession(isPaused: false)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func refreshPermissionStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionStatus = .granted
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .undetermined
        @unknown default:
            permissionStatus = .denied
        }
    }

    private func ensureMicrophonePermission() async throws {
        refreshPermissionStatus()

        switch permissionStatus {
        case .granted:
            return
        case .denied:
            throw RecorderError.microphonePermissionDenied
        case .undetermined:
            isBusy = true
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            isBusy = false
            refreshPermissionStatus()
            guard granted, permissionStatus == .granted else {
                throw RecorderError.microphonePermissionDenied
            }
        }
    }

    private func makeOutputURL(topic: String, startedAt: Date) throws -> URL {
        try fileManager.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let timestamp = Self.fileNameDateFormatter.string(from: startedAt)
        let topicSegment = sanitizedFileNameComponent(topic)
        let fileName = topicSegment.isEmpty
            ? "meeting-\(timestamp).wav"
            : "meeting-\(topicSegment)-\(timestamp).wav"
        return recordingsDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private func sanitizedFileNameComponent(_ rawValue: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.newlines)
        let normalized = rawValue
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "- ").union(.whitespaces))
        guard !normalized.isEmpty else { return "" }
        return String(normalized.prefix(36)).replacingOccurrences(of: " ", with: "-")
    }

    private func cleanupFileIfNeeded(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
