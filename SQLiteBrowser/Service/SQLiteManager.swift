//
//  SQLiteManager.swift
//  SQLiteBrowser
//
//  Created by Angelos Staboulis on 1/2/26.
//

import Foundation
import SQLite3
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteManager {

    private var db: OpaquePointer?

    // MARK: - Init / Deinit

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw sqliteError("Unable to open database")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Helpers

    private func normalizeSQL(_ sql: String) -> String {
        sql
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
    }

    private func bind(_ values: [Any?], to statement: OpaquePointer?) {
        for (index, value) in values.enumerated() {
            let idx = Int32(index + 1)

            switch value {
            case nil:
                sqlite3_bind_null(statement, idx)

            case let v as Int:
                sqlite3_bind_int64(statement, idx, Int64(v))

            case let v as Int64:
                sqlite3_bind_int64(statement, idx, v)

            case let v as Double:
                sqlite3_bind_double(statement, idx, v)

            case let v as String:
                sqlite3_bind_text(statement, idx, v, -1, SQLITE_TRANSIENT)

            default:
                sqlite3_bind_text(statement, idx, "\(value!)", -1, SQLITE_TRANSIENT)
            }
        }
    }

    private func sqliteError(_ message: String? = nil) -> NSError {
        let msg = message ?? String(cString: sqlite3_errmsg(db))
        return NSError(
            domain: "SQLite",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: msg]
        )
    }

    // MARK: - Schema / Tables

    func listTables() throws -> [String] {
        let sql = """
        SELECT name FROM sqlite_master
        WHERE type='table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        let (rows, _) = try query(sql)
        return rows.compactMap { $0.values.values.first as? String }
    }

    func schema(for table: String) throws -> String? {
        let sql = """
        SELECT sql FROM sqlite_master
        WHERE type='table' AND name = ?;
        """
        let (rows, _) = try query(sql, bindings: [table])
        return rows.first?.values.values.first as? String
    }

    // MARK: - Query (SELECT)

    func query(
        _ sql: String,
        bindings: [Any?] = []
    ) throws -> ([SQLiteRow], [String]) {

        let sql = normalizeSQL(sql)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError()
        }
        defer { sqlite3_finalize(statement) }

        bind(bindings, to: statement)

        let columnCount = sqlite3_column_count(statement)
        let columns = (0..<columnCount).compactMap {
            sqlite3_column_name(statement, $0).map { String(cString: $0) }
        }

        var rows: [SQLiteRow] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            var values: [String: Any?] = [:]
            var rowid: Int64?

            for i in 0..<columnCount {
                let name = columns[Int(i)]
                let type = sqlite3_column_type(statement, i)

                let value: Any?
                switch type {
                case SQLITE_INTEGER:
                    value = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    value = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    value = String(cString: sqlite3_column_text(statement, i))
                case SQLITE_NULL:
                    value = nil
                default:
                    value = nil
                }

                values[name] = value
                if name == "rowid" {
                    rowid = value as? Int64
                }
            }

            rows.append(SQLiteRow(rowid: rowid, values: values))
        }

        return (rows, columns)
    }

    // MARK: - Execute (INSERT / UPDATE / DELETE)

    func execute(
        _ sql: String,
        bindings: [Any?] = []
    ) throws {

        let sql = normalizeSQL(sql)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError()
        }
        defer { sqlite3_finalize(statement) }

        bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError()
        }
    }


}
