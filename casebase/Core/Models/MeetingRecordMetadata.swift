import Foundation

enum MeetingRecordMetadata {
    static let sourceKey = "meetingSource"
    static let sourceValue = "notch-meeting"
    static let participantCountKey = "meetingParticipantCount"
    static let durationSecondsKey = "meetingDurationSeconds"
    static let startedAtKey = "meetingStartedAt"
    static let topicKey = "meetingTopic"
    static let transcriptionModelKey = "meetingTranscriptionModel"
    static let transcriptionLanguageKey = "meetingTranscriptionLanguage"
    static let transcriptionErrorKey = "meetingTranscriptionError"
    static let transcriptExcerptKey = "meetingTranscriptExcerpt"
    static let transcriptSegmentsKey = "meetingTranscriptSegments"
    static let linkedTranscriptRecordIDKey = "linkedTranscriptRecordID"
    static let sourceAudioRecordIDKey = "sourceAudioRecordID"
    static let sourceAudioAssetPathKey = "sourceAudioAssetPath"
    static let sourceAudioDeletedKey = "sourceAudioDeleted"
    static let transcriptionCreatedAtKey = "transcriptionCreatedAt"
    static let actionItemsKey = "meetingActionItems"
    static let actionItemExtractionErrorKey = "meetingActionItemExtractionError"

    static func isMeetingPayload(_ payload: ImportPayload) -> Bool {
        isMeetingMetadata(payload.contextMetadata)
    }

    static func isMeetingMetadata(_ metadata: [String: String]) -> Bool {
        metadata[sourceKey] == sourceValue
    }

    static func isMeetingRecord(_ record: ImportRecord) -> Bool {
        guard case let .string(sourceValue) = record.structuredData[sourceKey] else {
            return false
        }
        return sourceValue == self.sourceValue
    }

    static func linkedTranscriptRecordID(in record: ImportRecord) -> UUID? {
        uuidValue(for: linkedTranscriptRecordIDKey, in: record)
    }

    static func sourceAudioRecordID(in record: ImportRecord) -> UUID? {
        uuidValue(for: sourceAudioRecordIDKey, in: record)
    }

    static func isTranscriptRecord(_ record: ImportRecord) -> Bool {
        sourceAudioRecordID(in: record) != nil
    }

    static func actionItems(in record: ImportRecord) -> [MeetingActionItemCandidate] {
        guard case let .string(json) = record.structuredData[actionItemsKey],
              let data = json.data(using: .utf8)
        else { return [] }
        return (try? JSONDecoder().decode([MeetingActionItemCandidate].self, from: data)) ?? []
    }

    static func setActionItems(_ items: [MeetingActionItemCandidate], in record: inout ImportRecord) throws {
        let data = try JSONEncoder().encode(items)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CasebaseError.storageFailed("Could not encode meeting action items.")
        }
        record.structuredData[actionItemsKey] = .string(json)
    }

    private static func uuidValue(for key: String, in record: ImportRecord) -> UUID? {
        guard case let .string(rawValue) = record.structuredData[key] else { return nil }
        return UUID(uuidString: rawValue)
    }
}

extension StructuredFieldValue {
    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }
}
