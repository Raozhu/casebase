import Foundation
import SQLite3

actor LocalKnowledgeStore: KnowledgeStore {
    private let configuration: StorageConfiguration
    private let database: SQLiteDatabase
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: StorageConfiguration, fileManager: FileManager = .default) throws {
        self.configuration = configuration
        self.fileManager = fileManager
        self.database = try SQLiteDatabase(url: configuration.databaseURL)
        try Self.prepareDirectories(using: fileManager, configuration: configuration)
        try Self.migrate(database: database)
    }

    private static func prepareDirectories(using fileManager: FileManager, configuration: StorageConfiguration) throws {
        try fileManager.createDirectory(at: configuration.rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.assetsDirectory, withIntermediateDirectories: true)
    }

    func findRecord(byAssetHash assetHash: String) async throws -> ImportRecord? {
        let statement = try database.prepare("""
            SELECT
                id,
                asset_path,
                asset_hash,
                file_name,
                mime_type,
                source_kind,
                content_type,
                scene,
                purpose,
                title,
                short_summary,
                useful_snippets_json,
                tags_json,
                structured_data_json,
                search_text,
                user_supplement,
                clarification_request_json,
                clarification_history_json,
                clarification_round_count,
                needs_review,
                embedding_json,
                parse_status,
                created_at,
                updated_at,
                import_count
            FROM records
            WHERE asset_hash = ?
            LIMIT 1;
            """)
        defer { database.finalize(statement) }

        try database.bind(assetHash, at: 1, in: statement)
        let result = try database.step(statement)
        guard result == SQLITE_ROW else {
            return nil
        }

        return try decodeRecord(from: statement)
    }

    func save(_ record: ImportRecord) async throws {
        try write(record, requiresExisting: false)
    }

    func update(_ record: ImportRecord) async throws {
        try write(record, requiresExisting: true)
    }

    func fetchRecord(id: UUID) async throws -> ImportRecord? {
        let records = try await fetchRecords(ids: [id])
        return records.first
    }

    func recentRecords(limit: Int) async throws -> [ImportRecord] {
        let statement = try database.prepare("""
            SELECT
                id,
                asset_path,
                asset_hash,
                file_name,
                mime_type,
                source_kind,
                content_type,
                scene,
                purpose,
                title,
                short_summary,
                useful_snippets_json,
                tags_json,
                structured_data_json,
                search_text,
                user_supplement,
                clarification_request_json,
                clarification_history_json,
                clarification_round_count,
                needs_review,
                embedding_json,
                parse_status,
                created_at,
                updated_at,
                import_count
            FROM records
            ORDER BY updated_at DESC
            LIMIT ?;
            """)
        defer { database.finalize(statement) }

        try database.bind(max(limit, 1), at: 1, in: statement)

        var records: [ImportRecord] = []
        while try database.step(statement) == SQLITE_ROW {
            records.append(try decodeRecord(from: statement))
        }
        return records
    }

    func listRecords(
        limit: Int = RecordCatalogPaging.defaultLimit,
        offset: Int = 0,
        filters: RecordCatalogFilters = RecordCatalogFilters()
    ) async throws -> RecordCatalogPage {
        let normalizedLimit = RecordCatalogPaging.normalizedLimit(limit)
        let normalizedOffset = RecordCatalogPaging.normalizedOffset(offset)
        let filterClauses = catalogFilterClauses(for: filters, recordAlias: nil)
        let whereSQL = catalogWhereSQL(from: filterClauses)

        let statement = try database.prepare("""
            SELECT
                \(catalogRecordSelectionSQL())
            FROM records
            \(whereSQL)
            ORDER BY updated_at DESC
            LIMIT ? OFFSET ?;
            """)
        defer { database.finalize(statement) }

        var index: Int32 = 1
        try bindCatalogFilters(filters, startingAt: &index, in: statement)
        try database.bind(normalizedLimit + 1, at: index, in: statement)
        index += 1
        try database.bind(normalizedOffset, at: index, in: statement)

        var records: [ImportRecord] = []
        while try database.step(statement) == SQLITE_ROW {
            records.append(try decodeRecord(from: statement))
        }

        let hasMore = records.count > normalizedLimit
        if hasMore {
            records = Array(records.prefix(normalizedLimit))
        }

        return RecordCatalogPage(
            items: records,
            limit: normalizedLimit,
            offset: normalizedOffset,
            hasMore: hasMore
        )
    }

    func searchRecords(
        query: String,
        limit: Int = RecordCatalogPaging.defaultLimit,
        offset: Int = 0,
        filters: RecordCatalogFilters = RecordCatalogFilters()
    ) async throws -> RecordCatalogPage {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            throw CasebaseError.emptyQuery
        }

        let normalizedLimit = RecordCatalogPaging.normalizedLimit(limit)
        let normalizedOffset = RecordCatalogPaging.normalizedOffset(offset)
        let tokens = tokenize(normalizedQuery)

        if !tokens.isEmpty {
            return try searchRecordsUsingFTS(
                queryTokens: tokens,
                limit: normalizedLimit,
                offset: normalizedOffset,
                filters: filters
            )
        }

        return try searchRecordsUsingLike(
            query: normalizedQuery,
            limit: normalizedLimit,
            offset: normalizedOffset,
            filters: filters
        )
    }

    func fetchRecords(ids: [UUID]) async throws -> [ImportRecord] {
        guard !ids.isEmpty else {
            return []
        }

        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        let statement = try database.prepare("""
            SELECT
                id,
                asset_path,
                asset_hash,
                file_name,
                mime_type,
                source_kind,
                content_type,
                scene,
                purpose,
                title,
                short_summary,
                useful_snippets_json,
                tags_json,
                structured_data_json,
                search_text,
                user_supplement,
                clarification_request_json,
                clarification_history_json,
                clarification_round_count,
                needs_review,
                embedding_json,
                parse_status,
                created_at,
                updated_at,
                import_count
            FROM records
            WHERE id IN (\(placeholders));
            """)
        defer { database.finalize(statement) }

        for (offset, id) in ids.enumerated() {
            try database.bind(id, at: Int32(offset + 1), in: statement)
        }

        var recordsByID: [UUID: ImportRecord] = [:]
        while try database.step(statement) == SQLITE_ROW {
            let record = try decodeRecord(from: statement)
            recordsByID[record.id] = record
        }

        return ids.compactMap { recordsByID[$0] }
    }

    func search(query: String, embedding: [Float], limit: Int, scope: AnswerQueryScope) async throws -> [SearchHit] {
        let cappedLimit = max(1, limit)
        let tokens = tokenize(query)

        let candidates: [ImportRecord]

        switch scope {
        case .global:
            candidates = try globalCandidates(tokens: tokens, limit: cappedLimit)
        case let .recordIDs(ids):
            guard !ids.isEmpty else {
                return []
            }
            candidates = try await fetchRecords(ids: ids)
        }

        let scored = candidates.map { record -> SearchHit in
            let textScore = keywordScore(for: record, tokens: tokens)
            let vectorScore = cosineSimilarity(lhs: embedding, rhs: record.embedding)
            let effectiveScore: Double
            if tokens.isEmpty {
                effectiveScore = vectorScore
            } else if embedding.isEmpty {
                effectiveScore = textScore
            } else {
                effectiveScore = (textScore * 0.65) + (vectorScore * 0.35)
            }
            return SearchHit(
                record: record,
                score: effectiveScore,
                matchedSnippets: matchedSnippets(for: record, tokens: tokens)
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.record.updatedAt > rhs.record.updatedAt
            }
            return lhs.score > rhs.score
        }

        return Array(scored.prefix(cappedLimit))
    }

    private func globalCandidates(tokens: [String], limit: Int) throws -> [ImportRecord] {
        var candidates: [ImportRecord] = []
        var seenIDs = Set<UUID>()

        if !tokens.isEmpty {
            let ftsQuery = tokens.map { "\($0)*" }.joined(separator: " OR ")
            let statement = try database.prepare("""
                SELECT
                    r.id,
                    r.asset_path,
                    r.asset_hash,
                    r.file_name,
                    r.mime_type,
                    r.source_kind,
                    r.content_type,
                    r.scene,
                    r.purpose,
                    r.title,
                    r.short_summary,
                    r.useful_snippets_json,
                    r.tags_json,
                    r.structured_data_json,
                    r.search_text,
                    r.user_supplement,
                    r.clarification_request_json,
                    r.clarification_history_json,
                    r.clarification_round_count,
                    r.needs_review,
                    r.embedding_json,
                    r.parse_status,
                    r.created_at,
                    r.updated_at,
                    r.import_count
                FROM records_fts f
                JOIN records r ON r.id = f.id
                WHERE records_fts MATCH ?
                LIMIT ?;
                """)
            defer { database.finalize(statement) }

            try database.bind(ftsQuery, at: 1, in: statement)
            try database.bind(max(limit * 8, 24), at: 2, in: statement)

            while try database.step(statement) == SQLITE_ROW {
                let record = try decodeRecord(from: statement)
                if seenIDs.insert(record.id).inserted {
                    candidates.append(record)
                }
            }
        }

        if candidates.isEmpty {
            let statement = try database.prepare("""
                SELECT
                    id,
                    asset_path,
                    asset_hash,
                    file_name,
                    mime_type,
                    source_kind,
                    content_type,
                    scene,
                    purpose,
                    title,
                    short_summary,
                    useful_snippets_json,
                    tags_json,
                    structured_data_json,
                    search_text,
                    user_supplement,
                    clarification_request_json,
                    clarification_history_json,
                    clarification_round_count,
                    needs_review,
                    embedding_json,
                    parse_status,
                    created_at,
                    updated_at,
                    import_count
                FROM records
                ORDER BY updated_at DESC
                LIMIT ?;
                """)
            defer { database.finalize(statement) }

            try database.bind(max(limit * 12, 48), at: 1, in: statement)

            while try database.step(statement) == SQLITE_ROW {
                let record = try decodeRecord(from: statement)
                if seenIDs.insert(record.id).inserted {
                    candidates.append(record)
                }
            }
        }

        return candidates
    }

    func deleteAllRecords() async throws {
        do {
            try database.beginTransaction()
            try database.execute("DELETE FROM records;")
            try database.execute("DELETE FROM records_fts;")
            try database.commitTransaction()
        } catch {
            database.rollbackTransaction()
            throw error
        }
    }

    func deleteRecord(id: UUID) async throws {
        let deleteRecordStatement = try database.prepare("DELETE FROM records WHERE id = ?;")
        let deleteFTSStatement = try database.prepare("DELETE FROM records_fts WHERE id = ?;")
        defer {
            database.finalize(deleteRecordStatement)
            database.finalize(deleteFTSStatement)
        }

        try database.bind(id, at: 1, in: deleteRecordStatement)
        try database.bind(id, at: 1, in: deleteFTSStatement)

        do {
            try database.beginTransaction()
            _ = try database.step(deleteRecordStatement)
            _ = try database.step(deleteFTSStatement)
            try database.commitTransaction()
        } catch {
            database.rollbackTransaction()
            throw error
        }
    }

    private static func migrate(database: SQLiteDatabase) throws {
        try database.execute("""
            CREATE TABLE IF NOT EXISTS records (
                id TEXT PRIMARY KEY NOT NULL,
                asset_path TEXT NOT NULL,
                asset_hash TEXT NOT NULL UNIQUE,
                file_name TEXT NOT NULL,
                mime_type TEXT,
                source_kind TEXT NOT NULL,
                content_type TEXT NOT NULL DEFAULT '',
                scene TEXT NOT NULL DEFAULT '',
                purpose TEXT NOT NULL DEFAULT '',
                title TEXT NOT NULL,
                short_summary TEXT NOT NULL,
                useful_snippets_json TEXT NOT NULL,
                tags_json TEXT NOT NULL,
                structured_data_json TEXT NOT NULL DEFAULT '{}',
                search_text TEXT NOT NULL,
                user_supplement TEXT,
                clarification_request_json TEXT,
                clarification_history_json TEXT NOT NULL DEFAULT '[]',
                clarification_round_count INTEGER NOT NULL DEFAULT 0,
                needs_review INTEGER NOT NULL DEFAULT 0,
                embedding_json TEXT NOT NULL,
                parse_status TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                import_count INTEGER NOT NULL
            );
            """)

        try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_records_asset_hash ON records(asset_hash);
            """)

        try database.execute("""
            CREATE INDEX IF NOT EXISTS idx_records_updated_at ON records(updated_at DESC);
            """)

        try database.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS records_fts USING fts5(
                id UNINDEXED,
                title,
                short_summary,
                search_text,
                tags
            );
            """)

        try ensureColumnExists(
            database: database,
            table: "records",
            column: "content_type",
            definition: "TEXT NOT NULL DEFAULT ''"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "scene",
            definition: "TEXT NOT NULL DEFAULT ''"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "purpose",
            definition: "TEXT NOT NULL DEFAULT ''"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "structured_data_json",
            definition: "TEXT NOT NULL DEFAULT '{}'"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "user_supplement",
            definition: "TEXT"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "clarification_request_json",
            definition: "TEXT"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "clarification_history_json",
            definition: "TEXT NOT NULL DEFAULT '[]'"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "clarification_round_count",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
        try ensureColumnExists(
            database: database,
            table: "records",
            column: "needs_review",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )
    }

    private func write(_ record: ImportRecord, requiresExisting: Bool) throws {
        if requiresExisting, try fetchRecordSync(id: record.id) == nil {
            throw CasebaseError.recordNotFound(record.id)
        }

        let statement = try database.prepare("""
            INSERT INTO records (
                id,
                asset_path,
                asset_hash,
                file_name,
                mime_type,
                source_kind,
                content_type,
                scene,
                purpose,
                title,
                short_summary,
                useful_snippets_json,
                tags_json,
                structured_data_json,
                search_text,
                user_supplement,
                clarification_request_json,
                clarification_history_json,
                clarification_round_count,
                needs_review,
                embedding_json,
                parse_status,
                created_at,
                updated_at,
                import_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                asset_path = excluded.asset_path,
                asset_hash = excluded.asset_hash,
                file_name = excluded.file_name,
                mime_type = excluded.mime_type,
                source_kind = excluded.source_kind,
                content_type = excluded.content_type,
                scene = excluded.scene,
                purpose = excluded.purpose,
                title = excluded.title,
                short_summary = excluded.short_summary,
                useful_snippets_json = excluded.useful_snippets_json,
                tags_json = excluded.tags_json,
                structured_data_json = excluded.structured_data_json,
                search_text = excluded.search_text,
                user_supplement = excluded.user_supplement,
                clarification_request_json = excluded.clarification_request_json,
                clarification_history_json = excluded.clarification_history_json,
                clarification_round_count = excluded.clarification_round_count,
                needs_review = excluded.needs_review,
                embedding_json = excluded.embedding_json,
                parse_status = excluded.parse_status,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                import_count = excluded.import_count;
            """)
        defer { database.finalize(statement) }

        try bind(record: record, into: statement)

        do {
            try database.beginTransaction()
            _ = try database.step(statement)
            try upsertFTS(record: record)
            try database.commitTransaction()
        } catch {
            database.rollbackTransaction()
            throw error
        }
    }

    private func upsertFTS(record: ImportRecord) throws {
        let deleteStatement = try database.prepare("DELETE FROM records_fts WHERE id = ?;")
        defer { database.finalize(deleteStatement) }
        try database.bind(record.id, at: 1, in: deleteStatement)
        _ = try database.step(deleteStatement)

        let insertStatement = try database.prepare("""
            INSERT INTO records_fts (id, title, short_summary, search_text, tags)
            VALUES (?, ?, ?, ?, ?);
            """)
        defer { database.finalize(insertStatement) }

        try database.bind(record.id, at: 1, in: insertStatement)
        try database.bind(record.title, at: 2, in: insertStatement)
        try database.bind(record.shortSummary, at: 3, in: insertStatement)
        try database.bind(record.searchText, at: 4, in: insertStatement)
        try database.bind(record.tags.joined(separator: " "), at: 5, in: insertStatement)
        _ = try database.step(insertStatement)
    }

    private func bind(record: ImportRecord, into statement: OpaquePointer?) throws {
        try database.bind(record.id, at: 1, in: statement)
        try database.bind(record.assetPath, at: 2, in: statement)
        try database.bind(record.assetHash, at: 3, in: statement)
        try database.bind(record.fileName, at: 4, in: statement)
        try database.bind(record.mimeType, at: 5, in: statement)
        try database.bind(record.sourceKind.rawValue, at: 6, in: statement)
        try database.bind(record.contentType, at: 7, in: statement)
        try database.bind(record.scene, at: 8, in: statement)
        try database.bind(record.purpose, at: 9, in: statement)
        try database.bind(record.title, at: 10, in: statement)
        try database.bind(record.shortSummary, at: 11, in: statement)
        try database.bind(try encodeJSON(record.usefulSnippets), at: 12, in: statement)
        try database.bind(try encodeJSON(record.tags), at: 13, in: statement)
        try database.bind(try encodeJSON(record.structuredData), at: 14, in: statement)
        try database.bind(record.searchText, at: 15, in: statement)
        try database.bind(record.userSupplement, at: 16, in: statement)
        try database.bind(try encodeOptionalJSON(record.clarificationRequest), at: 17, in: statement)
        try database.bind(try encodeJSON(record.clarificationHistory), at: 18, in: statement)
        try database.bind(record.clarificationRoundCount, at: 19, in: statement)
        try database.bind(record.needsReview ? 1 : 0, at: 20, in: statement)
        try database.bind(try encodeJSON(record.embedding), at: 21, in: statement)
        try database.bind(record.parseStatus.rawValue, at: 22, in: statement)
        try database.bind(record.createdAt.timeIntervalSince1970, at: 23, in: statement)
        try database.bind(record.updatedAt.timeIntervalSince1970, at: 24, in: statement)
        try database.bind(record.importCount, at: 25, in: statement)
    }

    private func decodeRecord(from statement: OpaquePointer?) throws -> ImportRecord {
        guard
            let idString = database.string(at: 0, in: statement),
            let id = UUID(uuidString: idString),
            let assetPath = database.string(at: 1, in: statement),
            let assetHash = database.string(at: 2, in: statement),
            let fileName = database.string(at: 3, in: statement),
            let sourceKindValue = database.string(at: 5, in: statement),
            let sourceKind = ImportSourceKind(rawValue: sourceKindValue),
            let contentType = database.string(at: 6, in: statement),
            let scene = database.string(at: 7, in: statement),
            let purpose = database.string(at: 8, in: statement),
            let title = database.string(at: 9, in: statement),
            let shortSummary = database.string(at: 10, in: statement),
            let usefulSnippetsJSON = database.string(at: 11, in: statement),
            let tagsJSON = database.string(at: 12, in: statement),
            let structuredDataJSON = database.string(at: 13, in: statement),
            let searchText = database.string(at: 14, in: statement),
            let clarificationHistoryJSON = database.string(at: 17, in: statement),
            let embeddingJSON = database.string(at: 20, in: statement),
            let parseStatusValue = database.string(at: 21, in: statement),
            let parseStatus = RecordParseStatus(rawValue: parseStatusValue)
        else {
            throw CasebaseError.storageFailed(
                CasebasePromptCatalog.errors.failedToDecodeAKnowledgeRecordRow
            )
        }

        return ImportRecord(
            id: id,
            assetPath: assetPath,
            assetHash: assetHash,
            fileName: fileName,
            mimeType: database.string(at: 4, in: statement),
            sourceKind: sourceKind,
            contentType: contentType,
            scene: scene,
            purpose: purpose,
            title: title,
            shortSummary: shortSummary,
            usefulSnippets: try decodeJSONStringArray(usefulSnippetsJSON),
            tags: try decodeJSONStringArray(tagsJSON),
            structuredData: try decodeStructuredData(structuredDataJSON),
            searchText: searchText,
            userSupplement: database.string(at: 15, in: statement),
            clarificationRequest: try decodeOptionalJSON(database.string(at: 16, in: statement), as: ClarificationRequest.self),
            clarificationHistory: try decodeJSONValue(clarificationHistoryJSON, as: [ClarificationRound].self),
            clarificationRoundCount: database.int(at: 18, in: statement),
            needsReview: database.int(at: 19, in: statement) != 0,
            embedding: try decodeFloatArray(embeddingJSON),
            parseStatus: parseStatus,
            createdAt: Date(timeIntervalSince1970: database.double(at: 22, in: statement)),
            updatedAt: Date(timeIntervalSince1970: database.double(at: 23, in: statement)),
            importCount: database.int(at: 24, in: statement)
        )
    }

    private func fetchRecordSync(id: UUID) throws -> ImportRecord? {
        let statement = try database.prepare("""
            SELECT
                id,
                asset_path,
                asset_hash,
                file_name,
                mime_type,
                source_kind,
                content_type,
                scene,
                purpose,
                title,
                short_summary,
                useful_snippets_json,
                tags_json,
                structured_data_json,
                search_text,
                user_supplement,
                clarification_request_json,
                clarification_history_json,
                clarification_round_count,
                needs_review,
                embedding_json,
                parse_status,
                created_at,
                updated_at,
                import_count
            FROM records
            WHERE id = ?
            LIMIT 1;
            """)
        defer { database.finalize(statement) }

        try database.bind(id, at: 1, in: statement)
        let result = try database.step(statement)
        guard result == SQLITE_ROW else {
            return nil
        }
        return try decodeRecord(from: statement)
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CasebaseError.storageFailed(
                CasebasePromptCatalog.errors.failedToEncodeJSONString
            )
        }
        return json
    }

    private func encodeOptionalJSON<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        return try encodeJSON(value)
    }

    private func decodeJSONValue<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        let data = Data(json.utf8)
        return try decoder.decode(type, from: data)
    }

    private func decodeOptionalJSON<T: Decodable>(_ json: String?, as type: T.Type) throws -> T? {
        guard let json else { return nil }
        return try decodeJSONValue(json, as: type)
    }

    private func decodeJSONStringArray(_ json: String) throws -> [String] {
        try decodeJSONValue(json, as: [String].self)
    }

    private func decodeFloatArray(_ json: String) throws -> [Float] {
        try decodeJSONValue(json, as: [Float].self)
    }

    private func decodeStructuredData(_ json: String) throws -> [String: StructuredFieldValue] {
        try decodeJSONValue(json, as: [String: StructuredFieldValue].self)
    }

    private func searchRecordsUsingFTS(
        queryTokens: [String],
        limit: Int,
        offset: Int,
        filters: RecordCatalogFilters
    ) throws -> RecordCatalogPage {
        let filterClauses = catalogFilterClauses(for: filters, recordAlias: "r")
        let whereClauses = ["records_fts MATCH ?"] + filterClauses
        let whereSQL = catalogWhereSQL(from: whereClauses)
        let ftsQuery = queryTokens.map { "\($0)*" }.joined(separator: " OR ")

        let statement = try database.prepare("""
            SELECT
                \(catalogRecordSelectionSQL(alias: "r"))
            FROM records_fts
            JOIN records r ON r.id = records_fts.id
            \(whereSQL)
            ORDER BY bm25(records_fts), r.updated_at DESC
            LIMIT ? OFFSET ?;
            """)
        defer { database.finalize(statement) }

        var index: Int32 = 1
        try database.bind(ftsQuery, at: index, in: statement)
        index += 1
        try bindCatalogFilters(filters, startingAt: &index, in: statement)
        try database.bind(limit + 1, at: index, in: statement)
        index += 1
        try database.bind(offset, at: index, in: statement)

        var records: [ImportRecord] = []
        while try database.step(statement) == SQLITE_ROW {
            records.append(try decodeRecord(from: statement))
        }

        let hasMore = records.count > limit
        if hasMore {
            records = Array(records.prefix(limit))
        }

        return RecordCatalogPage(items: records, limit: limit, offset: offset, hasMore: hasMore)
    }

    private func searchRecordsUsingLike(
        query: String,
        limit: Int,
        offset: Int,
        filters: RecordCatalogFilters
    ) throws -> RecordCatalogPage {
        let filterClauses = catalogFilterClauses(for: filters, recordAlias: "r")
        let whereClauses = [
            """
            (
                r.title LIKE ? COLLATE NOCASE OR
                r.short_summary LIKE ? COLLATE NOCASE OR
                r.search_text LIKE ? COLLATE NOCASE OR
                r.tags_json LIKE ? COLLATE NOCASE
            )
            """
        ] + filterClauses
        let whereSQL = catalogWhereSQL(from: whereClauses)
        let pattern = "%\(query)%"

        let statement = try database.prepare("""
            SELECT
                \(catalogRecordSelectionSQL(alias: "r"))
            FROM records r
            \(whereSQL)
            ORDER BY r.updated_at DESC
            LIMIT ? OFFSET ?;
            """)
        defer { database.finalize(statement) }

        var index: Int32 = 1
        try database.bind(pattern, at: index, in: statement)
        index += 1
        try database.bind(pattern, at: index, in: statement)
        index += 1
        try database.bind(pattern, at: index, in: statement)
        index += 1
        try database.bind(pattern, at: index, in: statement)
        index += 1
        try bindCatalogFilters(filters, startingAt: &index, in: statement)
        try database.bind(limit + 1, at: index, in: statement)
        index += 1
        try database.bind(offset, at: index, in: statement)

        var records: [ImportRecord] = []
        while try database.step(statement) == SQLITE_ROW {
            records.append(try decodeRecord(from: statement))
        }

        let hasMore = records.count > limit
        if hasMore {
            records = Array(records.prefix(limit))
        }

        return RecordCatalogPage(items: records, limit: limit, offset: offset, hasMore: hasMore)
    }

    private func catalogRecordSelectionSQL(alias: String? = nil) -> String {
        let prefix = alias.map { "\($0)." } ?? ""
        return """
        \(prefix)id,
        \(prefix)asset_path,
        \(prefix)asset_hash,
        \(prefix)file_name,
        \(prefix)mime_type,
        \(prefix)source_kind,
        \(prefix)content_type,
        \(prefix)scene,
        \(prefix)purpose,
        \(prefix)title,
        \(prefix)short_summary,
        \(prefix)useful_snippets_json,
        \(prefix)tags_json,
        \(prefix)structured_data_json,
        \(prefix)search_text,
        \(prefix)user_supplement,
        \(prefix)clarification_request_json,
        \(prefix)clarification_history_json,
        \(prefix)clarification_round_count,
        \(prefix)needs_review,
        \(prefix)embedding_json,
        \(prefix)parse_status,
        \(prefix)created_at,
        \(prefix)updated_at,
        \(prefix)import_count
        """
    }

    private func catalogFilterClauses(
        for filters: RecordCatalogFilters,
        recordAlias: String?
    ) -> [String] {
        let prefix = recordAlias.map { "\($0)." } ?? ""
        var clauses: [String] = []

        if filters.purpose != nil {
            clauses.append("\(prefix)purpose = ?")
        }

        if filters.needsReview != nil {
            clauses.append("\(prefix)needs_review = ?")
        }

        if !filters.sourceKinds.isEmpty {
            let placeholders = Array(repeating: "?", count: filters.sourceKinds.count).joined(separator: ", ")
            clauses.append("\(prefix)source_kind IN (\(placeholders))")
        }

        if !filters.tagsAny.isEmpty {
            let placeholders = Array(repeating: "?", count: filters.tagsAny.count).joined(separator: ", ")
            clauses.append(
                "EXISTS (SELECT 1 FROM json_each(\(prefix)tags_json) AS tag WHERE tag.value IN (\(placeholders)))"
            )
        }

        return clauses
    }

    private func catalogWhereSQL(from clauses: [String]) -> String {
        guard !clauses.isEmpty else { return "" }
        return "WHERE " + clauses.joined(separator: " AND ")
    }

    private func bindCatalogFilters(
        _ filters: RecordCatalogFilters,
        startingAt index: inout Int32,
        in statement: OpaquePointer?
    ) throws {
        if let purpose = filters.purpose {
            try database.bind(purpose, at: index, in: statement)
            index += 1
        }

        if let needsReview = filters.needsReview {
            try database.bind(needsReview ? 1 : 0, at: index, in: statement)
            index += 1
        }

        for sourceKind in filters.sourceKinds {
            try database.bind(sourceKind.rawValue, at: index, in: statement)
            index += 1
        }

        for tag in filters.tagsAny {
            try database.bind(tag, at: index, in: statement)
            index += 1
        }
    }

    private func tokenize(_ query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    private func keywordScore(for record: ImportRecord, tokens: [String]) -> Double {
        guard !tokens.isEmpty else {
            return 0
        }

        let haystack = [
            record.title,
            record.shortSummary,
            record.searchText,
            record.tags.joined(separator: " "),
            record.usefulSnippets.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        let hitCount = tokens.reduce(into: 0) { partialResult, token in
            if haystack.contains(token) {
                partialResult += 1
            }
        }

        return Double(hitCount) / Double(tokens.count)
    }

    private func matchedSnippets(for record: ImportRecord, tokens: [String]) -> [String] {
        guard !tokens.isEmpty else {
            return Array(record.usefulSnippets.prefix(2))
        }

        let matched = record.usefulSnippets.filter { snippet in
            let lowered = snippet.lowercased()
            return tokens.contains { lowered.contains($0) }
        }

        if !matched.isEmpty {
            return Array(matched.prefix(3))
        }

        return [record.shortSummary]
    }

    private func cosineSimilarity(lhs: [Float], rhs: [Float]) -> Double {
        guard !lhs.isEmpty, lhs.count == rhs.count else {
            return 0
        }

        var dotProduct: Double = 0
        var lhsMagnitude: Double = 0
        var rhsMagnitude: Double = 0

        for index in lhs.indices {
            let lhsValue = Double(lhs[index])
            let rhsValue = Double(rhs[index])
            dotProduct += lhsValue * rhsValue
            lhsMagnitude += lhsValue * lhsValue
            rhsMagnitude += rhsValue * rhsValue
        }

        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            return 0
        }

        return dotProduct / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }

    private static func ensureColumnExists(
        database: SQLiteDatabase,
        table: String,
        column: String,
        definition: String
    ) throws {
        let statement = try database.prepare("PRAGMA table_info(\(table));")
        defer { database.finalize(statement) }

        var existingColumns = Set<String>()
        while try database.step(statement) == SQLITE_ROW {
            if let name = database.string(at: 1, in: statement) {
                existingColumns.insert(name)
            }
        }

        guard !existingColumns.contains(column) else {
            return
        }

        try database.execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }
}
