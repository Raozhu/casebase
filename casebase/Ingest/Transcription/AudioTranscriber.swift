import Foundation

struct AudioTranscriptionSegment: Hashable {
    let start: Double?
    let end: Double?
    let speakerID: Int?
    let text: String
}

struct AudioTranscription {
    let text: String
    let language: String?
    let segments: [AudioTranscriptionSegment]

    init(
        text: String,
        language: String?,
        segments: [AudioTranscriptionSegment] = []
    ) {
        self.text = text
        self.language = language
        self.segments = segments
    }
}

protocol AudioTranscriber {
    func transcribe(fileURL: URL, mimeType: String?) async throws -> AudioTranscription
}
