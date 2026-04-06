import CryptoKit
import Foundation

actor AssetVault {
    private let configuration: StorageConfiguration
    private let fileManager: FileManager

    init(configuration: StorageConfiguration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    func prepareDirectories() throws {
        try fileManager.createDirectory(at: configuration.rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.assetsDirectory, withIntermediateDirectories: true)
    }

    func store(_ payload: ImportPayload) throws -> StoredAsset {
        try prepareDirectories()

        switch payload {
        case let .file(filePayload):
            return try storeFilePayload(filePayload)
        case let .text(textPayload):
            return try storeTextPayload(textPayload)
        }
    }

    func url(for assetPath: String) -> URL {
        configuration.rootDirectory.appendingPathComponent(assetPath, isDirectory: false)
    }

    func deleteAllStoredAssets() throws {
        if fileManager.fileExists(atPath: configuration.assetsDirectory.path) {
            let assetURLs = try fileManager.contentsOfDirectory(
                at: configuration.assetsDirectory,
                includingPropertiesForKeys: nil
            )
            for assetURL in assetURLs {
                try fileManager.removeItem(at: assetURL)
            }
        }

        try prepareDirectories()
    }

    private func storeFilePayload(_ payload: FileImportPayload) throws -> StoredAsset {
        let sourceURL = payload.fileURL
        let data = try Data(contentsOf: sourceURL)
        let assetHash = sha256Hex(for: data)
        let fileName = payload.suggestedFileName ?? sourceURL.lastPathComponent
        let destinationFileName = hashedFileName(hash: assetHash, preferredName: fileName)
        let relativePath = "assets/\(destinationFileName)"
        let destinationURL = configuration.rootDirectory.appendingPathComponent(relativePath, isDirectory: false)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        return StoredAsset(
            assetPath: relativePath,
            assetHash: assetHash,
            fileName: fileName,
            mimeType: payload.mimeType,
            sourceKind: inferSourceKind(from: payload.sourceKindHint, fileName: fileName, mimeType: payload.mimeType),
            fileSize: Int64(data.count),
            contextMetadata: payload.contextMetadata
        )
    }

    private func storeTextPayload(_ payload: TextImportPayload) throws -> StoredAsset {
        guard let data = payload.text.data(using: .utf8) else {
            throw CasebaseError.invalidPayload(
                CasebasePromptCatalog.errors.draggedTextCouldNotBeEncodedAsUTF8
            )
        }

        let assetHash = sha256Hex(for: data)
        let preferredName = payload.suggestedFileName ?? "Dragged Text.txt"
        let normalizedName = preferredName.contains(".") ? preferredName : preferredName + ".txt"
        let destinationFileName = hashedFileName(hash: assetHash, preferredName: normalizedName)
        let relativePath = "assets/\(destinationFileName)"
        let destinationURL = configuration.rootDirectory.appendingPathComponent(relativePath, isDirectory: false)

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        return StoredAsset(
            assetPath: relativePath,
            assetHash: assetHash,
            fileName: normalizedName,
            mimeType: payload.mimeType,
            sourceKind: .text,
            fileSize: Int64(data.count),
            contextMetadata: payload.contextMetadata
        )
    }

    private func inferSourceKind(
        from hint: ImportSourceKind?,
        fileName: String,
        mimeType: String?
    ) -> ImportSourceKind {
        if let hint {
            return hint
        }

        let loweredMime = mimeType?.lowercased() ?? ""
        if loweredMime.hasPrefix("image/") {
            return .image
        }
        if loweredMime == "application/pdf" {
            return .pdf
        }
        if loweredMime.hasPrefix("audio/") {
            return .audio
        }
        if loweredMime.hasPrefix("text/") {
            return .text
        }

        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "webp", "heic", "gif", "tiff", "bmp":
            return .image
        case "pdf":
            return .pdf
        case "txt", "md", "json", "csv", "xml", "yaml", "yml", "rtf":
            return .text
        case "wav", "mp3", "m4a", "aac", "flac":
            return .audio
        default:
            return .binary
        }
    }

    private func hashedFileName(hash: String, preferredName: String) -> String {
        let pathExtension = URL(fileURLWithPath: preferredName).pathExtension
        guard !pathExtension.isEmpty else {
            return hash
        }
        return "\(hash).\(pathExtension.lowercased())"
    }

    private func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
