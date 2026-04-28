import Foundation

enum GeminiRuntimeDefaults {
    private static let geminiBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private static let defaultAnalysisModel = "gemini-2.5-flash-lite"
    private static let defaultAnswerModel = "gemini-3.1-pro-preview"
    private static let defaultEmbeddingModel = "gemini-embedding-001"

    static func resolvedBaseURL(from configured: URL) -> URL {
        if configured.host?.contains("api.openai.com") == true {
            return geminiBaseURL
        }

        if configured.host?.isEmpty == false {
            return configured
        }

        return geminiBaseURL
    }

    static func resolvedAnalysisModel(from configured: String) -> String {
        resolvedAnalysisModels(from: configured).first ?? defaultAnalysisModel
    }

    static func resolvedAnalysisModels(from configured: String) -> [String] {
        let models = configured
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { resolvedGenerationModel(from: $0, fallback: defaultAnalysisModel) }
            .filter { !$0.isEmpty }

        let uniqueModels = models.reduce(into: [String]()) { result, model in
            if !result.contains(model) {
                result.append(model)
            }
        }

        return uniqueModels.isEmpty ? [defaultAnalysisModel] : uniqueModels
    }

    static func resolvedAnswerModel(from configured: String) -> String {
        resolvedGenerationModel(from: configured, fallback: defaultAnswerModel)
    }

    static func resolvedEmbeddingModel(from configured: String) -> String {
        guard configured.hasPrefix("gemini-embedding") else {
            return defaultEmbeddingModel
        }
        return configured
    }

    private static func resolvedGenerationModel(from configured: String, fallback: String) -> String {
        if configured.hasPrefix("gemini-") {
            return configured
        }
        return fallback
    }
}
