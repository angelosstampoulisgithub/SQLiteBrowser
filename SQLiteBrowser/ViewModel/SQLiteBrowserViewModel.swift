//
//  SQLiteBrowserViewModel.swift
//  SQLiteBrowser
//
//  Created by Angelos Staboulis on 1/2/26.
//

import Foundation
import SwiftUI

enum BrowserMode {
    case table
    case sql
    case schema
    case search
}

@MainActor
final class SQLiteBrowserViewModel: ObservableObject {
    @Published var tables: [String] = []
    @Published var selectedTable: String?
    @Published var columns: [String] = []
    @Published var rows: [SQLiteRow] = []

    @Published var sqlQuery: String = ""
    @Published var sqlError: String?

    @Published var schemaText: String = ""
    @Published var searchText: String = ""

    @Published var mode: BrowserMode = .table

    // Editing
    @Published var editingRow: SQLiteRow?
    @Published var isEditingPresented = false
    @Published var newRowValues: [String: String] = [:]

    private var db: SQLiteManager?

    func openDatabase(at url: URL) {
        do {
            db = try SQLiteManager(path: url.path)
            tables = try db?.listTables() ?? []
        } catch {
            sqlError = error.localizedDescription
        }
    }

    func selectTable(_ table: String) {
        selectedTable = table
        mode = .table
        loadTable()
        loadSchema()
    }

    func loadTable() {
        guard let db, let table = selectedTable else { return }
        do {
            let (r, c) = try db.query("SELECT rowid, * FROM \"\(table)\" LIMIT 200")
            rows = r
            columns = c
        } catch {
            sqlError = error.localizedDescription
        }
    }

    func loadSchema() {
        guard let db, let table = selectedTable else { return }
        do {
            schemaText = try db.schema(for: table) ?? "-- No schema"
        } catch {
            schemaText = "-- Error: \(error.localizedDescription)"
        }
    }

    func runSQL() {
        guard let db else { return }
        do {
            let trimmed = sqlQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if trimmed.hasPrefix("insert")
                || trimmed.hasPrefix("update")
                || trimmed.hasPrefix("delete") {

                try db.execute(sqlQuery)
                if let table = selectedTable {
                    loadTable()
                    mode = .table
                }
                sqlError = nil
                return
            }

            // SELECT queries
            let (r, c) = try db.query(sqlQuery)
            rows = r
            columns = c
            mode = .sql
            sqlError = nil

        } catch {
            sqlError = error.localizedDescription
        }
    }


    

    // MARK: - Editing

    func startEditing(row: SQLiteRow) {
        editingRow = row
        newRowValues = [:]
        for (k, v) in row.values {
            newRowValues[k] = v.map { "\($0)" } ?? ""
        }
        isEditingPresented = true
    }

    func saveEdit() {
        guard let db, let table = selectedTable, let row = editingRow, let rowid = row.rowid else { return }

        let cols = newRowValues.keys.sorted()
        let assignments = cols.map { "\"\($0)\" = ?" }.joined(separator: ", ")
        let sql = "UPDATE \"\(table)\" SET \(assignments) WHERE rowid = ?"

        var bindings: [Any?] = cols.map { newRowValues[$0] }
        bindings.append(rowid)

        do {
            try db.execute(sql, bindings: bindings)
            isEditingPresented = false
            loadTable()
        } catch {
            sqlError = error.localizedDescription
        }
    }

    func insertRow() {
        guard let db, let table = selectedTable else { return }

        let cols = newRowValues.keys.sorted()
        let placeholders = Array(repeating: "?", count: cols.count).joined(separator: ", ")
        let sql = "INSERT INTO \"\(table)\" (\(cols.map { "\"\($0)\"" }.joined(separator: ", "))) VALUES (\(placeholders))"

        let bindings: [Any?] = cols.map { newRowValues[$0] }

        do {
            try db.execute(sql, bindings: bindings)
            isEditingPresented = false
            loadTable()
        } catch {
            sqlError = error.localizedDescription
        }
    }
}
