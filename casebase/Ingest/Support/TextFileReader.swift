import Foundation

struct TextReadResult {
    let text: String
    let encodingName: String
}

enum TextFileReader {
    static func readText(from fileURL: URL) throws -> TextReadResult {
        var usedEncoding: UInt = 0
        if let string = try? NSString(contentsOf: fileURL, usedEncoding: &usedEncoding) {
            let encoding = String.Encoding(rawValue: usedEncoding)
            return TextReadResult(
                text: string as String,
                encodingName: encodingLabel(for: encoding)
            )
        }

        let data = try Data(contentsOf: fileURL)
        for encoding in fallbackEncodings {
            if let text = String(data: data, encoding: encoding) {
                return TextReadResult(text: text, encodingName: encodingLabel(for: encoding))
            }
        }

        throw CasebaseError.invalidPayload(
            CasebasePromptCatalog.errors.unableToDecodeTextFile(fileURL.lastPathComponent)
        )
    }

    private static func encodingLabel(for encoding: String.Encoding) -> String {
        let coreEncoding = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
        if let ianaName = CFStringConvertEncodingToIANACharSetName(coreEncoding) {
            return ianaName as String
        }
        return "string-encoding-\(encoding.rawValue)"
    }

    private static let fallbackEncodings: [String.Encoding] = [
        .utf8,
        .utf16,
        .utf16LittleEndian,
        .utf16BigEndian,
        .utf32,
        .ascii,
        .isoLatin1,
        .windowsCP1252
    ]
}
