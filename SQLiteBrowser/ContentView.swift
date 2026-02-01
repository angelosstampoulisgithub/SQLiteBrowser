//
//  ContentView.swift
//  SQLiteBrowser
//
//  Created by Angelos Staboulis on 1/2/26.
//

import SwiftUI


struct ContentView: View {
    @StateObject private var vm = SQLiteBrowserViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                modeSwitcher
                Divider()
                content
                Divider()
                sqlConsole
            }
            .navigationTitle(vm.selectedTable ?? "SQLite Browser")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if let url = try? DatabaseBootstrap.ensureDatabaseExists() {
                vm.openDatabase(at: url)
            }
        }
        .alert("SQL Error", isPresented: .constant(vm.sqlError != nil)) {
            Button("OK") { vm.sqlError = nil }
        } message: {
            Text(vm.sqlError ?? "")
        }
        .sheet(isPresented: $vm.isEditingPresented) {
            editSheet
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(vm.tables, id: \.self, selection: $vm.selectedTable) { table in
            Text(table)
        }
        .onChange(of: vm.selectedTable) { table in
            if let table {
                vm.selectTable(table)
            }
        }
        .navigationTitle("SQLiteBrowser")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        Picker("Mode", selection: $vm.mode) {
            Text("Table").tag(BrowserMode.table)
            Text("Schema").tag(BrowserMode.schema)
            Text("Search").tag(BrowserMode.search)
            Text("SQL Result").tag(BrowserMode.sql)
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.mode {
        case .table, .sql, .search:
            tableContent
        case .schema:
            ScrollView {
                Text(vm.schemaText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }

    // MARK: - Table View

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {

                // Rows
                Section {
                    ForEach(Array(vm.rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack {
                            ForEach(vm.columns.indices, id: \.self) { colIndex in
                                let col = vm.columns[colIndex]
                                Text(stringValue(row.values[col] ?? nil))
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(minWidth: 100, alignment: .leading)
                            }

                            Spacer()

                            Button {
                                vm.startEditing(row: row)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(4)
                        .background(rowIndex.isMultiple(of: 2)
                                    ? Color(.secondarySystemBackground)
                                    : .clear)
                    }
                } header: {

                    // Header
                    HStack {
                        ForEach(vm.columns.indices, id: \.self) { i in
                            Text(vm.columns[i])
                                .font(.caption.bold())
                                .frame(minWidth: 100, alignment: .leading)
                        }

                        Spacer()

                        Text("Edit")
                            .font(.caption.bold())
                            .frame(width: 40)
                    }
                    .padding(4)
                    .background(.thinMaterial)
                }
            }
        }
    }

    // MARK: - SQL Console

    private var sqlConsole: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SQL Console")
                    .font(.headline)

                Spacer()

                if vm.selectedTable != nil {
                    Button("Insert Row") {
                        vm.editingRow = nil
                        vm.newRowValues = [:]
                        vm.isEditingPresented = true
                    }
                }
            }

            TextEditor(text: $vm.sqlQuery)
                .frame(height: 120)
                .border(Color.gray.opacity(0.3))
                .font(.system(.body, design: .monospaced))

            Button("Run SQL") {
                vm.runSQL()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        let editableColumns = vm.columns.filter { $0 != "rowid" }

        return NavigationStack {
            Form {
                ForEach(editableColumns.indices, id: \.self) { i in
                    let col = editableColumns[i]

                    Section(col) {
                        TextField(
                            col,
                            text: Binding(
                                get: { vm.newRowValues[col] ?? "" },
                                set: { vm.newRowValues[col] = $0 }
                            )
                        ).textInputAutocapitalization(.never)
                    }
                }
            }
            .navigationTitle(vm.editingRow == nil ? "Insert Row" : "Edit Row")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.isEditingPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if vm.editingRow == nil {
                            vm.insertRow()
                        } else {
                            vm.saveEdit()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func stringValue(_ value: Any?) -> String {
        value.map { "\($0)" } ?? "NULL"
    }
}

#Preview {
    ContentView()
}
