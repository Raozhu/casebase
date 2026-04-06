import Foundation

struct StoredAsset: Hashable {
    let assetPath: String
    let assetHash: String
    let fileName: String
    let mimeType: String?
    let sourceKind: ImportSourceKind
    let fileSize: Int64
    let contextMetadata: [String: String]

    func resolvedURL(relativeTo rootDirectory: URL) -> URL {
        rootDirectory.appendingPathComponent(assetPath, isDirectory: false)
    }
}
