import Foundation

enum GeminiAnalysisPromptBuilder {
    static var instructions: String { CasebasePromptCatalog.ai.analysisInstructions }
    static var responseJSONSchema: GeminiJSONObject { CasebasePromptCatalog.ai.analysisResponseJSONSchema }
}
