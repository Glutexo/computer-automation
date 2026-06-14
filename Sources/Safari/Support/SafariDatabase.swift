import Foundation
import SQLite3

enum SafariDatabase {
    static let busyTimeoutMilliseconds: Int32 = 250

    static func openReadOnly(databasePath: String) throws -> OpaquePointer {
        try open(databasePath: databasePath, flags: SQLITE_OPEN_READONLY)
    }

    static func openReadWrite(databasePath: String) throws -> OpaquePointer {
        try open(databasePath: databasePath, flags: SQLITE_OPEN_READWRITE)
    }

    static func stepRows(
        _ statement: OpaquePointer?,
        rowHandler: () -> Void
    ) throws {
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            rowHandler()
            result = sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw SafariDatabaseError.queryExecutionFailed
        }
    }

    private static func open(databasePath: String, flags: Int32) throws -> OpaquePointer {
        guard FileManager.default.fileExists(atPath: databasePath),
              FileManager.default.isReadableFile(atPath: databasePath)
        else {
            throw SafariDatabaseError.openFailed(path: databasePath)
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, flags, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            throw SafariDatabaseError.openFailed(path: databasePath)
        }

        sqlite3_busy_timeout(database, busyTimeoutMilliseconds)
        return database
    }
}

enum SafariDatabaseError: Error, Equatable, CustomStringConvertible {
    case openFailed(path: String)
    case queryExecutionFailed

    var description: String {
        switch self {
        case .openFailed(let path):
            "Could not open SafariTabs.db at \(path). Grant Full Disk Access to the terminal or app running computer-automation, make sure the file exists, and retry."
        case .queryExecutionFailed:
            "Could not finish a SafariTabs.db query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        }
    }
}
