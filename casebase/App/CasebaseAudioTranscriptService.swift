import Foundation

final class CasebaseAudioTranscriptService: AudioTranscriptService {
    private let knowledgeStore: LocalKnowledgeStore
    private let assetVault: AssetVault
    private let transcriber: AudioTranscriber?
    private let visibleShortcutService: CasebaseVisibleShortcutService?
    private let actionItemExtractor: MeetingActionItemExtracting?

    init(
        knowledgeStore: LocalKnowledgeStore,
        assetVault: AssetVault,
        transcriber: AudioTranscriber?,
        visibleShortcutService: CasebaseVisibleShortcutService? = nil,
        actionItemExtractor: MeetingActionItemExtracting? = nil
    ) {
        self.knowledgeStore = knowledgeStore
        self.assetVault = assetVault
        self.transcriber = transcriber
        self.visibleShortcutService = visibleShortcutService
        self.actionItemExtractor = actionItemExtractor
    }

    func linkedTranscript(forAudioRecordID id: UUID) async throws -> ImportRecord? {
        guard var audioRecord = try await knowledgeStore.fetchRecord(id: id),
              let transcriptID = MeetingRecordMetadata.linkedTranscriptRecordID(in: audioRecord)
        else {
            return nil
        }
        if let transcript = try await knowledgeStore.fetchRecord(id: transcriptID) {
            return transcript
        }
        audioRecord.structuredData.removeValue(forKey: MeetingRecordMetadata.linkedTranscriptRecordIDKey)
        audioRecord.updatedAt = Date()
        try await knowledgeStore.update(audioRecord)
        return nil
    }

    func sourceAudio(forTranscriptRecordID id: UUID) async throws -> ImportRecord? {
        guard let transcriptRecord = try await knowledgeStore.fetchRecord(id: id),
              let audioID = MeetingRecordMetadata.sourceAudioRecordID(in: transcriptRecord)
        else {
            return nil
        }
        return try await knowledgeStore.fetchRecord(id: audioID)
    }

    func transcribeAudioRecord(
        id: UUID,
        progress: ImportProgressHandler?
    ) async throws -> ImportRecord {
        guard var audioRecord = try await knowledgeStore.fetchRecord(id: id) else {
            throw CasebaseError.recordNotFound(id)
        }
        guard audioRecord.sourceKind == .audio else {
            throw CasebaseError.unsupportedPayload(localized(chinese: "只有音频文件可以转为逐字稿。", english: "Only audio records can be transcribed."))
        }

        if let existingTranscript = try await linkedTranscript(forAudioRecordID: id) {
            return existingTranscript
        }

        let audioURL = await assetVault.url(for: audioRecord.assetPath)
        guard await assetVault.assetExists(at: audioRecord.assetPath) else {
            throw CasebaseError.storageFailed(audioRecord.fileName)
        }

        progress?(ImportProgressUpdate(
            phase: .recognizing,
            detailText: localized(chinese: "正在使用 oMLX 本地转写录音", english: "Transcribing locally with oMLX")
        ))

        let transcription: AudioTranscription
        if let existingText = audioRecord.userSupplement?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existingText.isEmpty
        {
            transcription = AudioTranscription(
                text: existingText,
                language: audioRecord.structuredData[MeetingRecordMetadata.transcriptionLanguageKey]?.stringValue,
                segments: decodedSegments(from: audioRecord)
            )
        } else {
            guard let resolvedTranscriber = transcriber ?? (try? OMLXAudioTranscriber()) else {
                throw CasebaseError.missingConfiguration("oMLX local meeting transcription")
            }
            transcription = try await resolvedTranscriber.transcribe(
                fileURL: audioURL,
                mimeType: audioRecord.mimeType
            )
        }
        try Task.checkCancellation()

        let transcriptText = formattedTranscript(from: transcription)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcriptText.isEmpty else {
            throw CasebaseError.emptyResponse
        }

        progress?(ImportProgressUpdate(
            phase: .storing,
            detailText: localized(chinese: "正在保存逐字稿并关联原录音", english: "Saving and linking the transcript")
        ))

        let transcriptTitle = transcriptTitle(for: audioRecord)
        let transcriptFileName = transcriptFileName(for: audioRecord)
        let storedAsset = try await assetVault.store(.text(TextImportPayload(
            text: transcriptText,
            suggestedFileName: transcriptFileName,
            mimeType: "text/plain",
            contextMetadata: [
                MeetingRecordMetadata.sourceAudioRecordIDKey: audioRecord.id.uuidString,
                MeetingRecordMetadata.sourceAudioAssetPathKey: audioRecord.assetPath,
            ]
        )))
        let organizedAsset = try await assetVault.relocate(
            storedAsset,
            intoPurposeFolder: purposeFolderName(from: audioRecord.assetPath),
            preferredDisplayName: transcriptTitle
        )
        do {
            try Task.checkCancellation()
        } catch {
            try? await assetVault.discardTemporaryAsset(organizedAsset, preservingAssetPath: "")
            throw error
        }

        let now = Date()
        let excerpt = normalizedExcerpt(from: transcriptText, limit: 220)
        let snippets = transcriptSnippets(from: transcription, fallbackText: transcriptText)
        var actionItems: [MeetingActionItemCandidate] = []
        var actionItemExtractionError: String?
        if let actionItemExtractor {
            progress?(ImportProgressUpdate(
                phase: .recognizing,
                detailText: localized(chinese: "正在识别会议行动项", english: "Extracting meeting action items")
            ))
            do {
                actionItems = try await actionItemExtractor.extractActionItems(
                    transcript: transcriptText,
                    meetingTitle: audioRecord.title,
                    referenceDate: audioRecord.createdAt
                )
            } catch {
                actionItemExtractionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
        var structuredData: [String: StructuredFieldValue] = [
            MeetingRecordMetadata.sourceAudioRecordIDKey: .string(audioRecord.id.uuidString),
            MeetingRecordMetadata.sourceAudioAssetPathKey: .string(audioRecord.assetPath),
            MeetingRecordMetadata.transcriptionModelKey: .string("VibeVoice-ASR-4bit"),
            MeetingRecordMetadata.transcriptionCreatedAtKey: .string(Self.dateFormatter.string(from: now)),
        ]
        copyMeetingMetadata(from: audioRecord, into: &structuredData)
        if let language = transcription.language?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty
        {
            structuredData[MeetingRecordMetadata.transcriptionLanguageKey] = .string(language)
        }
        if let excerpt {
            structuredData[MeetingRecordMetadata.transcriptExcerptKey] = .string(excerpt)
        }
        let segmentValues = structuredValues(for: transcription.segments)
        if !segmentValues.isEmpty {
            structuredData[MeetingRecordMetadata.transcriptSegmentsKey] = .array(segmentValues)
        }
        if let data = try? JSONEncoder().encode(actionItems),
           let json = String(data: data, encoding: .utf8)
        {
            structuredData[MeetingRecordMetadata.actionItemsKey] = .string(json)
        }
        if let actionItemExtractionError {
            structuredData[MeetingRecordMetadata.actionItemExtractionErrorKey] = .string(actionItemExtractionError)
        }

        var tags = audioRecord.tags.filter { !$0.isEmpty }
        tags.append(contentsOf: [
            localized(chinese: "逐字稿", english: "transcript"),
            localized(chinese: "本地转写", english: "local-asr"),
        ])
        var seenTags: Set<String> = []
        tags = tags.filter { seenTags.insert($0).inserted }

        let transcriptRecord = ImportRecord(
            assetPath: organizedAsset.assetPath,
            assetHash: organizedAsset.assetHash,
            fileName: organizedAsset.fileName,
            mimeType: organizedAsset.mimeType,
            sourceKind: .text,
            contentType: localized(chinese: "会议逐字稿", english: "Meeting Transcript"),
            scene: audioRecord.scene,
            purpose: audioRecord.purpose,
            title: transcriptTitle,
            shortSummary: transcriptSummary(audioRecord: audioRecord, excerpt: excerpt),
            usefulSnippets: snippets,
            tags: tags,
            structuredData: structuredData,
            searchText: [transcriptTitle, audioRecord.title, tags.joined(separator: " "), transcriptText]
                .joined(separator: "\n"),
            userSupplement: transcriptText,
            needsReview: false,
            embedding: [],
            parseStatus: .ready,
            createdAt: now,
            updatedAt: now
        )

        do {
            try await knowledgeStore.save(transcriptRecord)

            audioRecord.structuredData[MeetingRecordMetadata.linkedTranscriptRecordIDKey] = .string(transcriptRecord.id.uuidString)
            audioRecord.structuredData[MeetingRecordMetadata.transcriptionCreatedAtKey] = .string(Self.dateFormatter.string(from: now))
            audioRecord.structuredData[MeetingRecordMetadata.transcriptionModelKey] = .string("VibeVoice-ASR-4bit")
            audioRecord.structuredData.removeValue(forKey: MeetingRecordMetadata.transcriptionErrorKey)
            if let excerpt {
                audioRecord.structuredData[MeetingRecordMetadata.transcriptExcerptKey] = .string(excerpt)
            }
            if !segmentValues.isEmpty {
                audioRecord.structuredData[MeetingRecordMetadata.transcriptSegmentsKey] = .array(segmentValues)
            }
            audioRecord.parseStatus = .ready
            audioRecord.needsReview = false
            audioRecord.updatedAt = now
            try await knowledgeStore.update(audioRecord)
        } catch {
            try? await knowledgeStore.deleteRecord(id: transcriptRecord.id)
            try? await assetVault.discardTemporaryAsset(organizedAsset, preservingAssetPath: "")
            throw error
        }

        if let visibleShortcutService {
            _ = try? await visibleShortcutService.syncShortcut(for: transcriptRecord)
        }
        NotificationCenter.default.post(name: .casebaseRecordsChanged, object: nil)
        return transcriptRecord
    }

    private func transcriptTitle(for audioRecord: ImportRecord) -> String {
        let suffix = localized(chinese: "逐字稿", english: "Transcript")
        return audioRecord.title.hasSuffix(suffix) ? audioRecord.title : "\(audioRecord.title) · \(suffix)"
    }

    private func transcriptFileName(for audioRecord: ImportRecord) -> String {
        let baseName = URL(fileURLWithPath: audioRecord.fileName)
            .deletingPathExtension()
            .lastPathComponent
        return "\(baseName)_\(localized(chinese: "逐字稿", english: "Transcript")).txt"
    }

    private func transcriptSummary(audioRecord: ImportRecord, excerpt: String?) -> String {
        let lead = localized(
            chinese: "由《\(audioRecord.title)》通过 oMLX 本地转写生成。",
            english: "Generated locally from \"\(audioRecord.title)\" with oMLX."
        )
        guard let excerpt, !excerpt.isEmpty else { return lead }
        return "\(lead) \(excerpt)"
    }

    private func formattedTranscript(from transcription: AudioTranscription) -> String {
        guard !transcription.segments.isEmpty else { return transcription.text }
        return transcription.segments.map { segment in
            var prefixParts: [String] = []
            if let start = segment.start {
                prefixParts.append("[\(formattedTimestamp(start))]")
            }
            if let speakerID = segment.speakerID {
                prefixParts.append(localized(chinese: "说话人 \(speakerID + 1)：", english: "Speaker \(speakerID + 1):"))
            }
            let prefix = prefixParts.joined(separator: " ")
            return prefix.isEmpty ? segment.text : "\(prefix) \(segment.text)"
        }.joined(separator: "\n")
    }

    private func formattedTimestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }

    private func transcriptSnippets(from transcription: AudioTranscription, fallbackText: String) -> [String] {
        let lines = transcription.segments.isEmpty
            ? fallbackText.components(separatedBy: .newlines)
            : transcription.segments.map(\.text)
        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map { String($0.prefix(220)) }
    }

    private func normalizedExcerpt(from text: String, limit: Int) -> String? {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return normalized.count <= limit ? normalized : String(normalized.prefix(limit)) + "…"
    }

    private func purposeFolderName(from assetPath: String) -> String {
        let components = assetPath.split(separator: "/").map(String.init)
        if components.count >= 3, components.first == "assets", !components[1].isEmpty {
            return components[1]
        }
        return localized(chinese: "会议记录", english: "Meeting Notes")
    }

    private func copyMeetingMetadata(
        from audioRecord: ImportRecord,
        into structuredData: inout [String: StructuredFieldValue]
    ) {
        let keys = [
            MeetingRecordMetadata.participantCountKey,
            MeetingRecordMetadata.durationSecondsKey,
            MeetingRecordMetadata.startedAtKey,
            MeetingRecordMetadata.topicKey,
        ]
        for key in keys {
            if let value = audioRecord.structuredData[key] {
                structuredData[key] = value
            }
        }
    }

    private func structuredValues(for segments: [AudioTranscriptionSegment]) -> [StructuredFieldValue] {
        segments.map { segment in
            var value: [String: StructuredFieldValue] = ["text": .string(segment.text)]
            if let start = segment.start { value["start"] = .number(start) }
            if let end = segment.end { value["end"] = .number(end) }
            if let speakerID = segment.speakerID { value["speakerID"] = .number(Double(speakerID)) }
            return .object(value)
        }
    }

    private func decodedSegments(from record: ImportRecord) -> [AudioTranscriptionSegment] {
        guard case let .array(values) = record.structuredData[MeetingRecordMetadata.transcriptSegmentsKey] else {
            return []
        }
        return values.compactMap { value in
            guard case let .object(object) = value,
                  case let .string(text) = object["text"]
            else { return nil }
            let start: Double? = if case let .number(value)? = object["start"] { value } else { nil }
            let end: Double? = if case let .number(value)? = object["end"] { value } else { nil }
            let speakerID: Int? = if case let .number(value)? = object["speakerID"] { Int(value) } else { nil }
            return AudioTranscriptionSegment(start: start, end: end, speakerID: speakerID, text: text)
        }
    }

    private func localized(chinese: String, english: String) -> String {
        CasebasePromptCatalog.language == .simplifiedChinese ? chinese : english
    }

    private static let dateFormatter = ISO8601DateFormatter()
}
