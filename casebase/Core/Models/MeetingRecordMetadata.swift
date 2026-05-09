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
}

extension StructuredFieldValue {
    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }
}
