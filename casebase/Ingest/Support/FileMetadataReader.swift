import Foundation
import UniformTypeIdentifiers

enum FileMetadataReader {
    static func basicMetadata(
        for fileURL: URL,
        mimeType: String?,
        utType: UTType?,
        fileManager: FileManager = .default
    ) -> [String: String] {
        var metadata: [String: String] = [
            "fileName": fileURL.lastPathComponent
        ]

        let fileExtension = fileURL.pathExtension.lowercased()
        if !fileExtension.isEmpty {
            metadata["fileExtension"] = fileExtension
        }

        if let mimeType {
            metadata["mimeType"] = mimeType
        }

        if let utType {
            metadata["uniformTypeIdentifier"] = utType.identifier
        }

        if isDirectory(fileURL, fileManager: fileManager) {
            metadata["isDirectory"] = "true"
        }

        if let fileSize = fileSizeBytes(for: fileURL, fileManager: fileManager) {
            metadata["fileSizeBytes"] = String(fileSize)
        }

        return metadata
    }

    static func fileSizeBytes(
        for fileURL: URL,
        fileManager _: FileManager = .default
    ) -> Int64? {
        do {
            let values = try fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ])
            if let allocatedSize = values.totalFileAllocatedSize {
                return Int64(allocatedSize)
            }
            if let fileSize = values.fileSize {
                return Int64(fileSize)
            }
        } catch {
            return nil
        }
        return nil
    }

    static func isDirectory(_ fileURL: URL, fileManager: FileManager = .default) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func directorySizeBytes(for directoryURL: URL, fileManager: FileManager = .default) -> Int64 {
        guard isDirectory(directoryURL, fileManager: fileManager) else {
            return fileSizeBytes(for: directoryURL, fileManager: fileManager) ?? 0
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileSizeKey,
            ]) else {
                continue
            }
            guard values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }
}
