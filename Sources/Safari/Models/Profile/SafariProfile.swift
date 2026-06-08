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
        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
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

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let titlePointer = sqlite3_column_text(statement, 0),
                let identifierPointer = sqlite3_column_text(statement, 1)
            else {
                continue
            }

            profiles.append(
                SafariProfileRecord(
                    name: String(cString: titlePointer),
                    identifier: String(cString: identifierPointer)
                )
            )
        }

        return profiles
    }
}

public enum SafariProfileCommandError: Error, Equatable {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
}
