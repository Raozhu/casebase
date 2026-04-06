import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        let result = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK, let handle else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close_v2(handle)
            throw CasebaseError.storageFailed(message)
        }

        self.handle = handle

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    func execute(_ sql: String) throws {
        guard let handle else {
            throw CasebaseError.storageFailed(
                CasebasePromptCatalog.errors.sqliteDatabaseHandleIsUnavailable
            )
        }

        let result = sqlite3_exec(handle, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw CasebaseError.storageFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        guard let handle else {
            throw CasebaseError.storageFailed(
                CasebasePromptCatalog.errors.sqliteDatabaseHandleIsUnavailable
            )
        }

        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw CasebaseError.storageFailed(String(cString: sqlite3_errmsg(handle)))
        }
        return statement
    }

    func step(_ statement: OpaquePointer) throws -> Int32 {
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_DONE, SQLITE_ROW:
            return result
        default:
            throw CasebaseError.storageFailed(lastErrorMessage())
        }
    }

    func finalize(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    func reset(_ statement: OpaquePointer?) {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    func beginTransaction() throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
    }

    func commitTransaction() throws {
        try execute("COMMIT TRANSACTION;")
    }

    func rollbackTransaction() {
        try? execute("ROLLBACK TRANSACTION;")
    }

    func lastInsertRowID() -> Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    func bind(_ value: String?, at index: Int32, in statement: OpaquePointer?) throws {
        let result: Int32
        if let value {
            result = sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else {
            throw CasebaseError.storageFailed(lastErrorMessage())
        }
    }

    func bind(_ value: Int, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw CasebaseError.storageFailed(lastErrorMessage())
        }
    }

    func bind(_ value: Double, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw CasebaseError.storageFailed(lastErrorMessage())
        }
    }

    func bind(_ value: UUID, at index: Int32, in statement: OpaquePointer?) throws {
        try bind(value.uuidString.lowercased(), at: index, in: statement)
    }

    func string(at index: Int32, in statement: OpaquePointer?) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: cString)
    }

    func double(at index: Int32, in statement: OpaquePointer?) -> Double {
        sqlite3_column_double(statement, index)
    }

    func int(at index: Int32, in statement: OpaquePointer?) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    private func lastErrorMessage() -> String {
        guard let handle else {
            return "Unknown SQLite error."
        }
        return String(cString: sqlite3_errmsg(handle))
    }
}
