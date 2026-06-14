import Foundation
import AutomationFoundation
import SQLite3

public struct SafariProfileRecord: Equatable, Sendable {
    public let name: String
    public let identifier: String

    public init(name: String, identifier: String) {
        self.name = name
        self.identifier = identifier
    }
}

public enum SafariProfile: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "profile",
        abstract: "Safari profiles available to the application.",
        commands: [
            SafariProfileListCommand.descriptor
        ]
    )

    static func databasePath(
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        "\(homeDirectory)/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db"
    }

    static func listAvailableProfiles(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariProfileRecord] {
        let database: OpaquePointer
        do {
            database = try SafariDatabase.openReadOnly(databasePath: databasePath)
        } catch SafariDatabaseError.openFailed {
            throw SafariProfileCommandError.databaseOpenFailed(path: databasePath)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT title, external_uuid
        FROM bookmarks
        WHERE parent = 0 AND type = 1 AND subtype = 2
        ORDER BY id;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariProfileCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        var profiles: [SafariProfileRecord] = []

        do {
            try SafariDatabase.stepRows(statement) {
                guard
                    let titlePointer = sqlite3_column_text(statement, 0),
                    let identifierPointer = sqlite3_column_text(statement, 1)
                else {
                    return
                }

                profiles.append(
                    SafariProfileRecord(
                        name: String(cString: titlePointer),
                        identifier: String(cString: identifierPointer)
                    )
                )
            }
        } catch SafariDatabaseError.queryExecutionFailed {
            throw SafariProfileCommandError.queryExecutionFailed
        }

        return profiles
    }
}

public enum SafariProfileCommandError: Error, Equatable, LocalizedError {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case queryExecutionFailed

    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let path):
            "Could not open SafariTabs.db at \(path). Grant Full Disk Access to the terminal or app running computer-automation, make sure the file exists, and retry."
        case .queryPreparationFailed:
            "Could not prepare the Safari profile query. The Safari database schema may have changed."
        case .queryExecutionFailed:
            "Could not finish the Safari profile query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        }
    }
}
