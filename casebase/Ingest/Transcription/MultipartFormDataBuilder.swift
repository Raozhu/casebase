import Foundation

struct MultipartFormDataBuilder {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var data = Data()

    var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(named name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(named name: String, fileURL: URL, mimeType: String) throws {
        let fileData = try Data(contentsOf: fileURL)
        append("--\(boundary)\r\n")
        append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
        )
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    func build() -> Data {
        var finalData = data
        finalData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalData
    }

    private mutating func append(_ string: String) {
        data.append(string.data(using: .utf8)!)
    }
}
