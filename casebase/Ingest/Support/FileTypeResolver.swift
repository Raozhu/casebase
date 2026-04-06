import Foundation
import UniformTypeIdentifiers

enum FileTypeResolver {
    struct Resolution {
        let sourceKind: ImportSourceKind?
        let mimeType: String?
        let utType: UTType?
        let fileExtension: String?
    }

    static func resolve(_ payload: ImportPayload) -> Resolution {
        switch payload {
        case let .text(textPayload):
            return Resolution(
                sourceKind: .text,
                mimeType: textPayload.mimeType ?? "text/plain",
                utType: .plainText,
                fileExtension: nil
            )
        case let .file(filePayload):
            let fileExtension = normalizedFileExtension(for: filePayload.fileURL)
            let preferredMimeType = normalizedMimeType(filePayload.mimeType)
            let preferredUTType = preferredMimeType.flatMap { UTType(mimeType: $0) }

            if let sourceKindHint = filePayload.sourceKindHint {
                return Resolution(
                    sourceKind: sourceKindHint,
                    mimeType: preferredMimeType ?? preferredUTType?.preferredMIMEType,
                    utType: preferredUTType ?? fileExtension.flatMap { UTType(filenameExtension: $0) },
                    fileExtension: fileExtension
                )
            }

            if let preferredUTType, let sourceKind = sourceKind(for: preferredUTType) {
                return Resolution(
                    sourceKind: sourceKind,
                    mimeType: preferredMimeType ?? preferredUTType.preferredMIMEType,
                    utType: preferredUTType,
                    fileExtension: fileExtension
                )
            }

            if let preferredMimeType, let sourceKind = sourceKind(forMimeType: preferredMimeType) {
                return Resolution(
                    sourceKind: sourceKind,
                    mimeType: preferredMimeType,
                    utType: preferredUTType,
                    fileExtension: fileExtension
                )
            }

            if let fileExtension {
                let extensionUTType = UTType(filenameExtension: fileExtension)
                if let extensionUTType, let sourceKind = sourceKind(for: extensionUTType) {
                    return Resolution(
                        sourceKind: sourceKind,
                        mimeType: preferredMimeType ?? extensionUTType.preferredMIMEType,
                        utType: extensionUTType,
                        fileExtension: fileExtension
                    )
                }

                if let sourceKind = sourceKind(forFileExtension: fileExtension) {
                    return Resolution(
                        sourceKind: sourceKind,
                        mimeType: preferredMimeType ?? extensionUTType?.preferredMIMEType,
                        utType: extensionUTType,
                        fileExtension: fileExtension
                    )
                }
            }

            return Resolution(
                sourceKind: nil,
                mimeType: preferredMimeType ?? preferredUTType?.preferredMIMEType,
                utType: preferredUTType,
                fileExtension: fileExtension
            )
        }
    }

    private static func normalizedMimeType(_ mimeType: String?) -> String? {
        guard let mimeType else { return nil }
        let trimmed = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedFileExtension(for url: URL) -> String? {
        let fileExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return fileExtension.isEmpty ? nil : fileExtension
    }

    private static func sourceKind(for utType: UTType) -> ImportSourceKind? {
        if utType.conforms(to: .image) {
            return .image
        }
        if utType.conforms(to: .pdf) {
            return .pdf
        }
        if utType.conforms(to: .audio) {
            return .audio
        }
        if utType.conforms(to: .plainText) || utType.conforms(to: .text) {
            return .text
        }
        return nil
    }

    private static func sourceKind(forMimeType mimeType: String) -> ImportSourceKind? {
        if mimeType.hasPrefix("image/") {
            return .image
        }
        if mimeType == "application/pdf" {
            return .pdf
        }
        if mimeType.hasPrefix("audio/") {
            return .audio
        }
        if mimeType.hasPrefix("text/") || textMimeTypes.contains(mimeType) {
            return .text
        }
        return nil
    }

    private static func sourceKind(forFileExtension fileExtension: String) -> ImportSourceKind? {
        if textFileExtensions.contains(fileExtension) {
            return .text
        }
        if imageFileExtensions.contains(fileExtension) {
            return .image
        }
        if pdfFileExtensions.contains(fileExtension) {
            return .pdf
        }
        if audioFileExtensions.contains(fileExtension) {
            return .audio
        }
        return nil
    }

    private static let textMimeTypes: Set<String> = [
        "application/json",
        "application/ld+json",
        "application/xml",
        "application/x-yaml",
        "application/yaml",
        "application/toml"
    ]

    private static let textFileExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "jsonl", "xml", "yaml", "yml",
        "csv", "tsv", "log", "rtf", "html", "htm", "css", "js", "ts",
        "swift", "py", "rb", "go", "java", "c", "cc", "cpp", "h", "hpp",
        "m", "mm", "sh", "zsh", "bash", "toml"
    ]

    private static let imageFileExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "gif", "tif", "tiff", "bmp", "webp"
    ]

    private static let pdfFileExtensions: Set<String> = ["pdf"]

    private static let audioFileExtensions: Set<String> = [
        "m4a", "mp3", "wav", "aiff", "aif", "caf", "aac", "flac"
    ]
}
