import Foundation
import SQLite3

public enum SafariTabsDatabase {
    static let busyTimeoutMilliseconds: Int32 = 250

    public static func databasePath(
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        "\(homeDirectory)/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db"
    }

    static func openReadOnly(databasePath: String) throws -> OpaquePointer {
        try open(databasePath: databasePath, flags: SQLITE_OPEN_READONLY)
    }

    static func openReadWrite(databasePath: String) throws -> OpaquePointer {
        try open(databasePath: databasePath, flags: SQLITE_OPEN_READWRITE)
    }

    static func stepRows(
        _ statement: OpaquePointer?,
        modelName: String,
        rowHandler: () -> Void
    ) throws {
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            rowHandler()
            result = sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw SafariDatabaseError.queryExecutionFailed(modelName: modelName)
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

public enum SafariDatabaseError: Error, Equatable, LocalizedError {
    case openFailed(path: String)
    case queryPreparationFailed(modelName: String)
    case queryExecutionFailed(modelName: String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let path):
            "Could not open SafariTabs.db at \(path). Grant Full Disk Access to the terminal or app running computer-automation, make sure the file exists, and retry."
        case .queryPreparationFailed(let modelName):
            "Could not prepare the Safari database \(modelName) query. The Safari database schema may have changed."
        case .queryExecutionFailed(let modelName):
            "Could not finish the Safari database \(modelName) query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        }
    }
}
