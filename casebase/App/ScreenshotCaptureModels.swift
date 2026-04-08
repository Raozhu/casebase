import CoreGraphics
import Foundation

struct GlobalScreenshotCaptureContext: Sendable {
    let fileURL: URL
    let sourceAppName: String?
    let windowTitle: String?
    let capturedAt: Date
    let sourceRect: CGRect

    var sourcePoint: CGPoint {
        CGPoint(x: sourceRect.midX, y: sourceRect.midY)
    }

    var metadata: [String: String] {
        var metadata: [String: String] = [
            "__casebase_capture_method": "global-screenshot-shortcut",
            "capturedAt": Self.timestampFormatter.string(from: capturedAt),
            "captureRegionWidth": String(Int(sourceRect.width.rounded())),
            "captureRegionHeight": String(Int(sourceRect.height.rounded()))
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
        let prefix = (base?.isEmpty == false ? base! : "Screenshot")
        return "\(prefix) Screenshot.png"
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum GlobalScreenshotCaptureError: LocalizedError {
    case permissionRequired
    case hotKeyRegistrationFailed
    case noActiveScreen
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return CasebasePromptCatalog.errors.screenCapturePermissionRequired
        case .hotKeyRegistrationFailed:
            return CasebasePromptCatalog.errors.screenCaptureHotKeyRegistrationFailed
        case .noActiveScreen:
            return CasebasePromptCatalog.errors.screenCaptureNoActiveScreen
        case .captureFailed:
            return CasebasePromptCatalog.errors.screenCaptureFailed
        }
    }
}
