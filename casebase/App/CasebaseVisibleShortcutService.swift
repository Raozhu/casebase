import Darwin
import Foundation

actor CasebaseVisibleShortcutService {
    private let configuration: StorageConfiguration
    private let fileManager: FileManager
    private let finderTagsAttribute = "com.apple.metadata:_kMDItemUserTags"
    private let recordIDAttribute = "com.casebase.recordID"
    private let categoryAttribute = "com.casebase.category"
    private let targetPathAttribute = "com.casebase.targetPath"

    init(configuration: StorageConfiguration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    func prepareRootDirectory() throws {
        try ensureDirectory(at: configuration.visibleShortcutDirectory)
    }

    @discardableResult
    func syncShortcut(for record: ImportRecord) throws -> Bool {
        let targetURL = configuration.rootDirectory.appendingPathComponent(record.assetPath, isDirectory: false)
        guard itemExists(at: targetURL) else {
            try removeShortcuts(forRecordID: record.id.uuidString)
            return true
        }

        let category = purposeFolderName(from: record.assetPath)
            ?? (CasebasePromptCatalog.language == .simplifiedChinese ? "通用资料" : "General")
        var changed = false

        try removeShortcuts(forRecordID: record.id.uuidString)
        try ensureDirectory(at: configuration.visibleShortcutDirectory)
        let categoryURL = configuration.visibleShortcutDirectory.appendingPathComponent(category, isDirectory: true)
        if !itemExists(at: categoryURL) {
            changed = true
        }
        try ensureDirectory(at: categoryURL)
        try applyFinderTag(category, to: categoryURL, noFollow: false)

        let displayFileName = URL(fileURLWithPath: record.assetPath).lastPathComponent
        let shortcutURL = availableShortcutURL(
            preferredFileName: displayFileName.isEmpty ? record.fileName : displayFileName,
            in: categoryURL
        )
        let bookmarkData = try targetURL.bookmarkData(
            options: [.suitableForBookmarkFile],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try URL.writeBookmarkData(bookmarkData, to: shortcutURL)
        try writeUTF8ExtendedAttribute(record.id.uuidString, name: recordIDAttribute, to: shortcutURL, noFollow: false)
        try writeUTF8ExtendedAttribute(category, name: categoryAttribute, to: shortcutURL, noFollow: false)
        try writeUTF8ExtendedAttribute(targetURL.path, name: targetPathAttribute, to: shortcutURL, noFollow: false)
        try applyFinderTag(category, to: shortcutURL, noFollow: false)
        changed = true
        return changed
    }

    func removeShortcut(for record: ImportRecord) throws {
        try removeShortcuts(forRecordID: record.id.uuidString)
    }

    func removeAllShortcuts() throws {
        guard itemExists(at: configuration.visibleShortcutDirectory) else { return }
        try fileManager.removeItem(at: configuration.visibleShortcutDirectory)
    }

    private func ensureDirectory(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw CasebaseError.storageFailed(url.path)
            }
            return
        }

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func purposeFolderName(from assetPath: String) -> String? {
        let components = assetPath.split(separator: "/").map(String.init)
        guard components.count >= 3, components.first == "assets" else {
            return nil
        }

        let folderName = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return folderName.isEmpty ? nil : folderName
    }

    private func availableShortcutURL(preferredFileName: String, in folderURL: URL) -> URL {
        let cleanedFileName = sanitizedFileName(preferredFileName)
        let baseURL = URL(fileURLWithPath: cleanedFileName)
        let pathExtension = baseURL.pathExtension
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        var candidate = folderURL.appendingPathComponent(cleanedFileName, isDirectory: false)
        var suffix = 2

        while itemExists(at: candidate) {
            let candidateName = pathExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(pathExtension)"
            candidate = folderURL.appendingPathComponent(candidateName, isDirectory: false)
            suffix += 1
        }

        return candidate
    }

    private func sanitizedFileName(_ fileName: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = fileName
            .components(separatedBy: illegalCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return cleaned.isEmpty
            ? (CasebasePromptCatalog.language == .simplifiedChinese ? "资料" : "Document")
            : cleaned
    }

    private func removeShortcuts(forRecordID recordID: String) throws {
        for shortcutURL in shortcutURLs(forRecordID: recordID) {
            try? fileManager.removeItem(at: shortcutURL)
            try removeCategoryFolderIfEmpty(for: shortcutURL)
        }
    }

    private func shortcutURLs(forRecordID recordID: String) -> [URL] {
        guard itemExists(at: configuration.visibleShortcutDirectory),
              let enumerator = fileManager.enumerator(
                  at: configuration.visibleShortcutDirectory,
                  includingPropertiesForKeys: [.isSymbolicLinkKey],
                  options: [.skipsHiddenFiles, .skipsPackageDescendants]
              )
        else {
            return []
        }

        var matches: [URL] = []
        for case let url as URL in enumerator {
            let storedRecordID = (try? readUTF8ExtendedAttribute(
                name: recordIDAttribute,
                from: url,
                noFollow: false
            )) ?? (try? readUTF8ExtendedAttribute(
                name: recordIDAttribute,
                from: url,
                noFollow: true
            ))
            guard let storedRecordID else {
                continue
            }

            if storedRecordID == recordID {
                matches.append(url)
            }
        }
        return matches
    }

    private func removeCategoryFolderIfEmpty(for shortcutURL: URL) throws {
        let categoryURL = shortcutURL.deletingLastPathComponent()
        guard categoryURL.deletingLastPathComponent().path == configuration.visibleShortcutDirectory.path else {
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: categoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        let removableContents = contents.filter { $0.lastPathComponent == ".DS_Store" }
        guard contents.count == removableContents.count else { return }

        for url in removableContents {
            try? fileManager.removeItem(at: url)
        }
        try? fileManager.removeItem(at: categoryURL)
    }

    private func applyFinderTag(_ tag: String, to url: URL, noFollow: Bool) throws {
        let tagEntry = "\(tag)\n0"
        let data = try PropertyListSerialization.data(
            fromPropertyList: [tagEntry],
            format: .binary,
            options: 0
        )
        try writeExtendedAttribute(data, name: finderTagsAttribute, to: url, noFollow: noFollow)
    }

    private func writeUTF8ExtendedAttribute(
        _ value: String,
        name: String,
        to url: URL,
        noFollow: Bool
    ) throws {
        let data = Data(value.utf8)
        try writeExtendedAttribute(data, name: name, to: url, noFollow: noFollow)
    }

    private func readUTF8ExtendedAttribute(
        name: String,
        from url: URL,
        noFollow: Bool
    ) throws -> String? {
        guard let data = try readExtendedAttribute(name: name, from: url, noFollow: noFollow) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func writeExtendedAttribute(
        _ data: Data,
        name: String,
        to url: URL,
        noFollow: Bool
    ) throws {
        let result = data.withUnsafeBytes { buffer in
            url.withUnsafeFileSystemRepresentation { path -> Int32 in
                guard let path, let baseAddress = buffer.baseAddress else {
                    errno = EINVAL
                    return -1
                }
                return setxattr(
                    path,
                    name,
                    baseAddress,
                    buffer.count,
                    0,
                    noFollow ? XATTR_NOFOLLOW : 0
                )
            }
        }

        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private func readExtendedAttribute(
        name: String,
        from url: URL,
        noFollow: Bool
    ) throws -> Data? {
        let flags = noFollow ? XATTR_NOFOLLOW : 0
        let length = url.withUnsafeFileSystemRepresentation { path -> Int in
            guard let path else {
                errno = EINVAL
                return -1
            }
            return getxattr(path, name, nil, 0, 0, flags)
        }

        if length < 0 {
            if errno == ENOATTR || errno == ENOENT {
                return nil
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var data = Data(count: length)
        let readLength = data.withUnsafeMutableBytes { buffer in
            url.withUnsafeFileSystemRepresentation { path -> Int in
                guard let path, let baseAddress = buffer.baseAddress else {
                    errno = EINVAL
                    return -1
                }
                return getxattr(path, name, baseAddress, length, 0, flags)
            }
        }

        if readLength < 0 {
            if errno == ENOATTR || errno == ENOENT {
                return nil
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return data
    }

    private func itemExists(at url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            var info = stat()
            return lstat(path, &info) == 0
        }
    }
}
