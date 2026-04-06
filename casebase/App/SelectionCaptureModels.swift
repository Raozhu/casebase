import CoreGraphics
import Foundation

struct GlobalSelectionCaptureContext: Sendable {
    let text: String
    let sourceAppName: String?
    let windowTitle: String?
    let capturedAt: Date
    let sourceRect: CGRect?
    let fallbackOriginPoint: CGPoint?

    var sourcePoint: CGPoint? {
        if let sourceRect, !sourceRect.isEmpty {
            return CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        }
        return fallbackOriginPoint
    }

    var previewText: String {
        let condensed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard condensed.count > 20 else { return condensed }
        return String(condensed.prefix(20)) + "..."
    }

    var metadata: [String: String] {
        var metadata: [String: String] = [
            "__casebase_capture_method": "global-selection-shortcut",
            "capturedAt": Self.timestampFormatter.string(from: capturedAt)
        ]

        if let sourceAppName, !sourceAppName.isEmpty {
            metadata["sourceAppName"] = sourceAppName
        }
        if let windowTitle, !windowTitle.isEmpty {
            metadata["sourceWindowTitle"] = windowTitle
        }

        return metadata
    }

    var suggestedFileName: String {
        let base = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let base, !base.isEmpty {
            return "\(base) Selection"
        }
        return CasebasePromptCatalog.ui.draggedTextFileName
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum GlobalSelectionCaptureError: LocalizedError {
    case accessibilityPermissionRequired
    case copyFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return CasebasePromptCatalog.errors.selectionCapturePermissionRequired
        case .copyFailed:
            return CasebasePromptCatalog.errors.selectionCaptureCopyFailed
        case .noTextFound:
            return CasebasePromptCatalog.errors.selectionCaptureNoTextFound
        }
    }
}
