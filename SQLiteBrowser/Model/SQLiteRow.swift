//
//  SQLiteRow.swift
//  SQLiteBrowser
//
//  Created by Angelos Staboulis on 1/2/26.
//

import Foundation
struct SQLiteRow:Identifiable {
    /// Row ID from SQLite, optional because new rows may not have one yet
    var rowid: Int64?

    /// Column values
    var values: [String: Any?]

    /// Conforms to Identifiable
    var id: String {
        // Use rowid if available, else fallback to UUID string
        if let rid = rowid {
            return String(rid)
        } else {
            return uuid
        }
    }

    /// Internal UUID for rows without rowid
    private let uuid: String = UUID().uuidString
}
