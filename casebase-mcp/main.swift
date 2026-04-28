import Foundation

do {
    let runtime = try CasebaseCatalogRuntime.bootstrap()
    let server = CasebaseMCPServer(runtime: runtime)
    try await server.run()
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    if let data = "casebase-mcp failed: \(message)\n".data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
    exit(1)
}
