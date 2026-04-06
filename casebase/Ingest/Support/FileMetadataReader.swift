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
}
