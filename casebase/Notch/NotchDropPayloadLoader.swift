import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum NotchDropPayloadLoader {
    static func loadPayloads(from providers: [NSItemProvider]) async throws -> [ImportPayload] {
        var payloads: [ImportPayload] = []

        for provider in providers {
            if let payload = try await loadPayload(from: provider) {
                payloads.append(payload)
            }
        }

        guard !payloads.isEmpty else {
            throw CasebaseError.unsupportedPayload(
                CasebasePromptCatalog.errors.onlyFileURLsAndPlainTextAreSupported
            )
        }

        return payloads
    }

    static func loadFirstPayload(from provider: NSItemProvider) async throws -> ImportPayload {
        if let payload = try await loadPayload(from: provider) {
            return payload
        }

        throw CasebaseError.unsupportedPayload(
            CasebasePromptCatalog.errors.onlyFileURLsAndPlainTextAreSupported
        )
    }

    private static func loadPayload(from provider: NSItemProvider) async throws -> ImportPayload? {
        if let filePayload = try await loadFilePayload(from: provider) {
            return filePayload
        }

        if let imagePayload = try await loadImagePayload(from: provider) {
            return imagePayload
        }

        if let textPayload = try await loadTextPayload(from: provider) {
            return textPayload
        }

        return nil
    }

    private static func loadFilePayload(from provider: NSItemProvider) async throws -> ImportPayload? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }

        let fileURL = try await provider.loadFileURL()
        let type = UTType(filenameExtension: fileURL.pathExtension)
        return .file(
            FileImportPayload(
                fileURL: fileURL,
                suggestedFileName: fileURL.lastPathComponent,
                mimeType: type?.preferredMIMEType,
                sourceKindHint: inferSourceKind(from: fileURL, type: type)
            )
        )
    }

    private static func loadImagePayload(from provider: NSItemProvider) async throws -> ImportPayload? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        let resolvedType = preferredImageType(from: provider.registeredTypeIdentifiers)
        let imageData = try await provider.loadDataRepresentation(forTypeIdentifier: resolvedType.identifier)
        let imageURL = try makeTemporaryDropFile(data: imageData, type: resolvedType, fallbackExtension: "png")

        return .file(
            FileImportPayload(
                fileURL: imageURL,
                suggestedFileName: imageURL.lastPathComponent,
                mimeType: resolvedType.preferredMIMEType ?? "image/png",
                sourceKindHint: .image
            )
        )
    }

    private static func loadTextPayload(from provider: NSItemProvider) async throws -> ImportPayload? {
        guard provider.canLoadObject(ofClass: NSString.self) else {
            return nil
        }

        let text = try await provider.loadText()
        return .text(
            TextImportPayload(
                text: text,
                suggestedFileName: CasebasePromptCatalog.ui.draggedTextFileName,
                mimeType: "text/plain"
            )
        )
    }

    private static func inferSourceKind(from fileURL: URL, type: UTType?) -> ImportSourceKind {
        if let type {
            if type.conforms(to: .image) {
                return .image
            }
            if type.conforms(to: .pdf) {
                return .pdf
            }
            if type.conforms(to: .audio) {
                return .audio
            }
            if type.conforms(to: .plainText) || type.conforms(to: .text) {
                return .text
            }
        }

        let extensionName = fileURL.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "webp", "gif", "bmp", "tiff"].contains(extensionName) {
            return .image
        }
        if extensionName == "pdf" {
            return .pdf
        }
        if ["mp3", "wav", "m4a", "aac", "aiff", "caf"].contains(extensionName) {
            return .audio
        }
        if ["txt", "md", "rtf", "json", "csv"].contains(extensionName) {
            return .text
        }
        return .binary
    }

    private static func preferredImageType(from typeIdentifiers: [String]) -> UTType {
        let preferredTypes: [UTType] = [.png, .jpeg, .tiff, .gif, .bmp, .webP, .heic, .image]

        for preferredType in preferredTypes {
            if typeIdentifiers.contains(where: { identifier in
                guard let registeredType = UTType(identifier) else { return false }
                return registeredType.conforms(to: preferredType)
            }) {
                return preferredType
            }
        }

        return .image
    }

    private static func makeTemporaryDropFile(
        data: Data,
        type: UTType,
        fallbackExtension: String
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("casebase-drop", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let pathExtension = type.preferredFilenameExtension ?? fallbackExtension
        let fileURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(pathExtension)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

private extension NSItemProvider {
    func loadFileURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                    return
                }

                if let data = item as? Data,
                   let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                    continuation.resume(returning: url)
                    return
                }

                if let string = item as? String,
                   let url = URL(string: string) {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(
                    throwing: CasebaseError.invalidPayload(
                        CasebasePromptCatalog.errors.failedToDecodeDroppedFileURL
                    )
                )
            }
        }
    }

    func loadText() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: NSString.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let string = object as? String {
                    continuation.resume(returning: string)
                    return
                }

                if let string = object as? NSString {
                    continuation.resume(returning: string as String)
                    return
                }

                continuation.resume(
                    throwing: CasebaseError.invalidPayload(
                        CasebasePromptCatalog.errors.failedToDecodeDroppedText
                    )
                )
            }
        }
    }

    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data {
                    continuation.resume(returning: data)
                    return
                }

                continuation.resume(
                    throwing: CasebaseError.invalidPayload(
                        CasebasePromptCatalog.errors.failedToDecodeDroppedFileURL
                    )
                )
            }
        }
    }
}
