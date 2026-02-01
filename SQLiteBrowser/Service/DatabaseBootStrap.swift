//
//  DatabaseBootStrap.swift
//  SQLiteBrowser
//
//  Created by Angelos Staboulis on 1/2/26.
//

import Foundation
import SQLite3

struct DatabaseBootstrap {
    static func databaseURL() throws -> URL {
        try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("browser.sqlite")
    }

    static func ensureDatabaseExists() throws -> URL {
        let url = try databaseURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try createFreshDatabase(at: url)
        }
        return url
    }

    private static func createFreshDatabase(at url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to create database"
            ])
        }
        defer { sqlite3_close(db) }

        func exec(_ sql: String) throws {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "SQLite", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: msg
                ])
            }
        }

        // Demo tables
        try exec("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE,
            created_at TEXT
        );
        """)

        try exec("""
        CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            created_at TEXT
        );
        """)

        // Seed some data
        try exec("""
        INSERT INTO users (name, email, created_at) VALUES
        ('Angelos', 'angelos@example.com', datetime('now')),
        ('Ada Lovelace', 'ada@example.com', datetime('now'));
        """)

        try exec("""
        INSERT INTO notes (title, body, created_at) VALUES
        ('First note', 'This is a demo note', datetime('now')),
        ('Second note', 'SQLite browser test data', datetime('now'));
        """)

    }
}
