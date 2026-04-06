import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CompressedImagePreview {
    let fileURL: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
}

final class TemporaryPreviewWriter {
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let maxImagePreviewLongEdge = 1600
    private let maxImagePreviewBytes = 500_000

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheDirectory = cachesDirectory
                .appendingPathComponent("casebase", isDirectory: true)
                .appendingPathComponent("ingest-temp", isDirectory: true)
        } else {
            cacheDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/casebase/ingest-temp", isDirectory: true)
        }
    }

    func writePNG(image: NSImage, prefix: String) throws -> URL {
        try ensureCacheDirectory()

        guard
            let tiffRepresentation = image.tiffRepresentation,
            let bitmapRepresentation = NSBitmapImageRep(data: tiffRepresentation),
            let pngData = bitmapRepresentation.representation(using: .png, properties: [:])
        else {
            throw CasebaseError.normalizationFailed(
                CasebasePromptCatalog.errors.failedToEncodePreviewImageAsPNG
            )
        }

        let sanitizedPrefix = sanitize(prefix)
        let destinationURL = cacheDirectory.appendingPathComponent(
            "\(sanitizedPrefix)-\(UUID().uuidString).png",
            isDirectory: false
        )
        try pngData.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    func writeCompressedImagePreview(from sourceURL: URL, prefix: String) throws -> CompressedImagePreview {
        try ensureCacheDirectory()

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CasebaseError.normalizationFailed(
                CasebasePromptCatalog.errors.failedToPrepareImagePreviewForAnalysis
            )
        }

        let originalPixelSize = pixelSize(from: imageSource)
        let startingLongEdge = max(
            1,
            min(Int(max(originalPixelSize.width, originalPixelSize.height).rounded(.up)), maxImagePreviewLongEdge)
        )

        for candidateLongEdge in candidateLongEdges(startingAt: startingLongEdge) {
            guard let previewImage = makeThumbnail(from: imageSource, maxPixelSize: candidateLongEdge) else {
                continue
            }

            for compressionQuality in compressionQualities {
                guard let encodedData = jpegData(for: previewImage, compressionQuality: compressionQuality),
                      encodedData.count <= maxImagePreviewBytes
                else {
                    continue
                }

                let destinationURL = cacheDirectory.appendingPathComponent(
                    "\(sanitize(prefix))-\(UUID().uuidString).jpg",
                    isDirectory: false
                )
                try encodedData.write(to: destinationURL, options: .atomic)

                return CompressedImagePreview(
                    fileURL: destinationURL,
                    pixelWidth: previewImage.width,
                    pixelHeight: previewImage.height,
                    byteCount: encodedData.count
                )
            }
        }

        throw CasebaseError.normalizationFailed(
            CasebasePromptCatalog.errors.failedToPrepareImagePreviewForAnalysis
        )
    }

    private func ensureCacheDirectory() throws {
        try fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    private func pixelSize(from imageSource: CGImageSource) -> CGSize {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
            let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return CGSize(width: maxImagePreviewLongEdge, height: maxImagePreviewLongEdge)
        }

        return CGSize(width: pixelWidth, height: pixelHeight)
    }

    private func candidateLongEdges(startingAt startingLongEdge: Int) -> [Int] {
        var candidates: [Int] = []
        var current = startingLongEdge

        while current >= 480 {
            candidates.append(current)
            let next = Int((Double(current) * 0.84).rounded(.down))
            if next >= current {
                break
            }
            current = next
        }

        if candidates.last != 480 {
            candidates.append(480)
        }

        var seen = Set<Int>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private func makeThumbnail(from imageSource: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    private func jpegData(for image: CGImage, compressionQuality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }

    private var compressionQualities: [CGFloat] {
        [0.82, 0.72, 0.62, 0.52, 0.42, 0.32]
    }

    private func sanitize(_ value: String) -> String {
        let invalidCharacters = CharacterSet.alphanumerics.inverted
        let components = value.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }
        return components.isEmpty ? "preview" : components.joined(separator: "-")
    }
}

extension TemporaryPreviewWriter {
    static func clearAllCachedPreviews(fileManager: FileManager = .default) throws {
        let cacheDirectory: URL
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheDirectory = cachesDirectory
                .appendingPathComponent("casebase", isDirectory: true)
                .appendingPathComponent("ingest-temp", isDirectory: true)
        } else {
            cacheDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/casebase/ingest-temp", isDirectory: true)
        }

        guard fileManager.fileExists(atPath: cacheDirectory.path) else { return }
        try fileManager.removeItem(at: cacheDirectory)
    }
}
