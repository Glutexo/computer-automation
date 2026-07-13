import Testing
import Foundation
import ApplicationServices
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

func openDatabase(at path: String) -> OpaquePointer? {
    var database: OpaquePointer?
    let result = sqlite3_open(path, &database)
    if result != SQLITE_OK {
        sqlite3_close(database)
        return nil
    }
    return database
}

func makeTemporaryDatabase() throws -> String {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let databasePath = temporaryDirectory.appendingPathComponent("Test.db").path
    let database = try #require(openDatabase(at: databasePath))
    sqlite3_close(database)
    return databasePath
}

func executeSQL(_ sql: String, at databasePath: String) throws {
    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK)
}

func makeIndexTitleList(_ rows: [(Int, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

func makeShortcutList(_ rows: [(Int, String, String, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

func makeSidebarList(_ rows: [(Int, String, String, String, Bool)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        item.insert(NSAppleEventDescriptor(string: row.4 ? "true" : "false"), at: 5)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

func makeTabList(_ rows: [(Int, Int, Int, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        listDescriptor.insert(
            NSAppleEventDescriptor(string: "\(row.0)|\(row.1)|\(row.2)|\(row.3)"),
            at: offset + 1
        )
    }

    return listDescriptor
}

func makeStructuredTabList(_ rows: [(Int, Int, Int, String, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: String(row.1)), at: 2)
        item.insert(NSAppleEventDescriptor(string: String(row.2)), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        item.insert(NSAppleEventDescriptor(string: row.4), at: 5)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

func jsonObject(_ value: String) throws -> [String: Any] {
    let data = Data(value.utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

func emptyToNil(_ value: String) -> String? {
    value.isEmpty ? nil : value
}

func normalizedShortcut(_ value: String) -> String? {
    value.isEmpty || value == "missing value" ? nil : value
}

final class MockAppleScriptExecutor: SafariAppleScriptExecuting {
    enum Result {
        case none
        case string(String)
        case descriptor(NSAppleEventDescriptor)
    }

    var executedScripts: [String] = []
    private var results: [Result]
    private let error: Error?

    init(results: [Result] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func execute(script: String) throws -> NSAppleEventDescriptor? {
        executedScripts.append(script)

        if let error {
            throw error
        }

        guard !results.isEmpty else {
            return nil
        }

        let nextResult = results.removeFirst()
        switch nextResult {
        case .none:
            return nil
        case .string(let value):
            return NSAppleEventDescriptor(string: value)
        case .descriptor(let descriptor):
            return descriptor
        }
    }
}

final class FakeRunningApplication: SafariApplicationTerminating {
    private(set) var didTerminate = false

    func terminate() -> Bool {
        didTerminate = true
        return true
    }
}
