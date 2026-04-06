import Foundation

struct AudioTranscription {
    let text: String
    let language: String?
}

protocol AudioTranscriber {
    func transcribe(fileURL: URL, mimeType: String?) async throws -> AudioTranscription
}
