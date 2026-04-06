import Foundation

enum GeminiRuntimeDefaults {
    private static let geminiBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private static let defaultGenerationModel = "gemini-3.1-flash-lite-preview"
    private static let defaultEmbeddingModel = "gemini-embedding-001"

    static func resolvedBaseURL(from configured: URL) -> URL {
        if configured.host?.contains("generativelanguage.googleapis.com") == true {
            return configured
        }
        return geminiBaseURL
    }

    static func resolvedAnalysisModel(from configured: String) -> String {
        resolvedGenerationModel(from: configured)
    }

    static func resolvedAnswerModel(from configured: String) -> String {
        resolvedGenerationModel(from: configured)
    }

    static func resolvedEmbeddingModel(from configured: String) -> String {
        guard configured.hasPrefix("gemini-embedding") else {
            return defaultEmbeddingModel
        }
        return configured
    }

    private static func resolvedGenerationModel(from configured: String) -> String {
        if configured.hasPrefix("gemini-") {
            return configured
        }
        return defaultGenerationModel
    }
}
