import Foundation

struct OfficeOpenXMLExtraction {
    let text: String
    let metadata: [String: String]
}

enum OfficeOpenXMLReader {
    static func extractText(from archiveURL: URL) throws -> OfficeOpenXMLExtraction? {
        let fileExtension = archiveURL.pathExtension.lowercased()

        switch fileExtension {
        case "docx":
            return try extractDOCX(from: archiveURL)
        case "xlsx":
            return try extractXLSX(from: archiveURL)
        case "pptx":
            return try extractPPTX(from: archiveURL)
        default:
            return nil
        }
    }

    private static func extractDOCX(from archiveURL: URL) throws -> OfficeOpenXMLExtraction? {
        let entries = try zipEntries(in: archiveURL)
        let interestingPaths = entries.filter {
            $0 == "word/document.xml"
                || $0.hasPrefix("word/header")
                || $0.hasPrefix("word/footer")
                || $0 == "word/footnotes.xml"
                || $0 == "word/endnotes.xml"
        }

        guard !interestingPaths.isEmpty else { return nil }

        let orderedPaths = interestingPaths.sorted { lhs, rhs in
            docxSortKey(for: lhs) < docxSortKey(for: rhs)
        }

        var sections: [String] = []
        for path in orderedPaths {
            guard let data = try zipEntryData(in: archiveURL, path: path) else { continue }
            let extracted = WordprocessingMLTextExtractor.extractText(from: data)
            if !extracted.isEmpty {
                sections.append(extracted)
            }
        }

        let text = normalizedJoinedText(from: sections)
        guard !text.isEmpty else { return nil }

        return OfficeOpenXMLExtraction(
            text: text,
            metadata: [
                "officeExtractionFormat": "docx-ooxml",
                "officeExtractionSections": String(sections.count),
            ]
        )
    }

    private static func extractXLSX(from archiveURL: URL) throws -> OfficeOpenXMLExtraction? {
        let entries = try zipEntries(in: archiveURL)
        let sharedStrings = try sharedStrings(in: archiveURL, entries: entries)
        let sheetNames = try workbookSheetNames(in: archiveURL, entries: entries)
        let worksheetPaths = entries
            .filter { $0.hasPrefix("xl/worksheets/sheet") && $0.hasSuffix(".xml") }
            .sorted { worksheetSortKey(for: $0) < worksheetSortKey(for: $1) }

        guard !worksheetPaths.isEmpty else { return nil }

        var sheets: [String] = []
        for (index, path) in worksheetPaths.enumerated() {
            guard let data = try zipEntryData(in: archiveURL, path: path) else { continue }
            let rows = XLSXWorksheetTextExtractor.extractRows(from: data, sharedStrings: sharedStrings)
            guard !rows.isEmpty else { continue }

            let title = index < sheetNames.count ? sheetNames[index] : "Sheet \(index + 1)"
            sheets.append(([title] + rows).joined(separator: "\n"))
        }

        let text = normalizedJoinedText(from: sheets)
        guard !text.isEmpty else { return nil }

        return OfficeOpenXMLExtraction(
            text: text,
            metadata: [
                "officeExtractionFormat": "xlsx-ooxml",
                "officeSheetCount": String(sheets.count),
            ]
        )
    }

    private static func extractPPTX(from archiveURL: URL) throws -> OfficeOpenXMLExtraction? {
        let entries = try zipEntries(in: archiveURL)
        let slidePaths = entries
            .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
            .sorted { worksheetSortKey(for: $0) < worksheetSortKey(for: $1) }

        guard !slidePaths.isEmpty else { return nil }

        var slides: [String] = []
        for (index, path) in slidePaths.enumerated() {
            guard let data = try zipEntryData(in: archiveURL, path: path) else { continue }
            let extracted = PresentationMLTextExtractor.extractText(from: data)
            guard !extracted.isEmpty else { continue }
            slides.append("Slide \(index + 1)\n\(extracted)")
        }

        let text = normalizedJoinedText(from: slides)
        guard !text.isEmpty else { return nil }

        return OfficeOpenXMLExtraction(
            text: text,
            metadata: [
                "officeExtractionFormat": "pptx-ooxml",
                "officeSlideCount": String(slides.count),
            ]
        )
    }

    private static func sharedStrings(in archiveURL: URL, entries: [String]) throws -> [String] {
        guard entries.contains("xl/sharedStrings.xml"),
              let data = try zipEntryData(in: archiveURL, path: "xl/sharedStrings.xml")
        else {
            return []
        }
        return XLSXSharedStringsExtractor.extractStrings(from: data)
    }

    private static func workbookSheetNames(in archiveURL: URL, entries: [String]) throws -> [String] {
        guard entries.contains("xl/workbook.xml"),
              let data = try zipEntryData(in: archiveURL, path: "xl/workbook.xml")
        else {
            return []
        }
        return XLSXWorkbookSheetNameExtractor.extractSheetNames(from: data)
    }

    private static func zipEntries(in archiveURL: URL) throws -> [String] {
        let result = try SystemCommandRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: ["-Z1", archiveURL.path]
        )
        return String(decoding: result.standardOutput, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    private static func zipEntryData(in archiveURL: URL, path: String) throws -> Data? {
        do {
            let result = try SystemCommandRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                arguments: ["-p", archiveURL.path, path]
            )
            return result.standardOutput.isEmpty ? nil : result.standardOutput
        } catch {
            return nil
        }
    }

    private static func normalizedJoinedText(from sections: [String]) -> String {
        sections
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func docxSortKey(for path: String) -> (Int, String) {
        if path == "word/document.xml" { return (0, path) }
        if path.hasPrefix("word/header") { return (1, path) }
        if path.hasPrefix("word/footnotes") { return (2, path) }
        if path.hasPrefix("word/endnotes") { return (3, path) }
        return (4, path)
    }

    private static func worksheetSortKey(for path: String) -> Int {
        let number = path
            .split(separator: "/")
            .last?
            .drop { !$0.isNumber }
            .prefix { $0.isNumber }
        return Int(number ?? "") ?? .max
    }
}

private final class WordprocessingMLTextExtractor: NSObject, XMLParserDelegate {
    private var paragraphs: [String] = []
    private var currentParagraph = ""
    private var isCollectingText = false
    private var currentText = ""

    static func extractText(from data: Data) -> String {
        let parser = WordprocessingMLTextExtractor()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        parser.flushParagraph()
        return parser.paragraphs.joined(separator: "\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "w:t":
            isCollectingText = true
            currentText = ""
        case "w:tab":
            currentParagraph.append("\t")
        case "w:br", "w:cr":
            currentParagraph.append("\n")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollectingText else { return }
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "w:t":
            currentParagraph.append(currentText)
            currentText = ""
            isCollectingText = false
        case "w:tc":
            currentParagraph.append("\t")
        case "w:tr":
            flushParagraph()
        case "w:p":
            flushParagraph()
        default:
            break
        }
    }

    private func flushParagraph() {
        let trimmed = currentParagraph
            .replacingOccurrences(of: "\t\t", with: "\t")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            paragraphs.append(trimmed)
        }
        currentParagraph.removeAll(keepingCapacity: true)
    }
}

private final class XLSXWorkbookSheetNameExtractor: NSObject, XMLParserDelegate {
    private var sheetNames: [String] = []

    static func extractSheetNames(from data: Data) -> [String] {
        let parser = XLSXWorkbookSheetNameExtractor()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.sheetNames
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName == "sheet", let name = attributeDict["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return
        }
        sheetNames.append(name)
    }
}

private final class XLSXSharedStringsExtractor: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentItemSegments: [String] = []
    private var isCollectingText = false
    private var currentText = ""

    static func extractStrings(from data: Data) -> [String] {
        let parser = XLSXSharedStringsExtractor()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "si":
            currentItemSegments.removeAll(keepingCapacity: true)
        case "t":
            isCollectingText = true
            currentText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollectingText else { return }
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "t":
            currentItemSegments.append(currentText)
            currentText = ""
            isCollectingText = false
        case "si":
            strings.append(currentItemSegments.joined())
        default:
            break
        }
    }
}

private final class XLSXWorksheetTextExtractor: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [String] = []
    private var currentRow: [String] = []
    private var currentCellType: String?
    private var currentValue = ""
    private var inlineSegments: [String] = []
    private var isCollectingValue = false
    private var isCollectingInlineText = false
    private var currentText = ""

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    static func extractRows(from data: Data, sharedStrings: [String]) -> [String] {
        let parser = XLSXWorksheetTextExtractor(sharedStrings: sharedStrings)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "row":
            currentRow.removeAll(keepingCapacity: true)
        case "c":
            currentCellType = attributeDict["t"]
            currentValue = ""
            inlineSegments.removeAll(keepingCapacity: true)
        case "v":
            isCollectingValue = true
            currentText = ""
        case "t":
            if currentCellType == "inlineStr" {
                isCollectingInlineText = true
                currentText = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isCollectingValue || isCollectingInlineText {
            currentText.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "v":
            currentValue = currentText
            currentText = ""
            isCollectingValue = false
        case "t":
            if isCollectingInlineText {
                inlineSegments.append(currentText)
                currentText = ""
                isCollectingInlineText = false
            }
        case "c":
            let value = resolvedCellValue()
            if !value.isEmpty {
                currentRow.append(value)
            }
        case "row":
            let rowText = currentRow
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\t")
            if !rowText.isEmpty {
                rows.append(rowText)
            }
        default:
            break
        }
    }

    private func resolvedCellValue() -> String {
        switch currentCellType {
        case "s":
            guard let index = Int(currentValue), sharedStrings.indices.contains(index) else {
                return currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return sharedStrings[index].trimmingCharacters(in: .whitespacesAndNewlines)
        case "inlineStr":
            return inlineSegments.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

private final class PresentationMLTextExtractor: NSObject, XMLParserDelegate {
    private var paragraphs: [String] = []
    private var currentParagraph = ""
    private var isCollectingText = false
    private var currentText = ""

    static func extractText(from data: Data) -> String {
        let parser = PresentationMLTextExtractor()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        parser.flushParagraph()
        return parser.paragraphs.joined(separator: "\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "a:t":
            isCollectingText = true
            currentText = ""
        case "a:br":
            currentParagraph.append("\n")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollectingText else { return }
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "a:t":
            currentParagraph.append(currentText)
            currentText = ""
            isCollectingText = false
        case "a:p":
            flushParagraph()
        default:
            break
        }
    }

    private func flushParagraph() {
        let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            paragraphs.append(trimmed)
        }
        currentParagraph.removeAll(keepingCapacity: true)
    }
}
