import AutomationFoundation
import SQLite3

public struct SafariTabGroupRecord: Equatable, Sendable {
    public let identifier: Int
    public let profileName: String
    public let name: String

    public init(identifier: Int, profileName: String, name: String) {
        self.identifier = identifier
        self.profileName = profileName
        self.name = name
    }
}

public enum SafariTabGroup: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab-group",
        abstract: "Saved Safari tab groups.",
        commands: [
            SafariTabGroupListCommand.descriptor
        ]
    )

    static func list(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariTabGroupRecord] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw SafariTabGroupCommandError.databaseOpenFailed(path: databasePath)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT g.id, p.title, g.title
        FROM bookmarks g
        JOIN bookmarks p ON p.id = g.parent
        WHERE g.type = 1
          AND g.subtype = 0
          AND p.parent = 0
          AND p.type = 1
          AND p.subtype = 2
          AND EXISTS (
              SELECT 1
              FROM bookmarks child
              WHERE child.parent = g.id
                AND child.type = 1
                AND child.subtype = 1
          )
        ORDER BY g.id;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariTabGroupCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        var groups: [SafariTabGroupRecord] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let rawProfileName = sqlite3_column_text(statement, 1),
                let rawName = sqlite3_column_text(statement, 2)
            else {
                continue
            }

            groups.append(
                SafariTabGroupRecord(
                    identifier: Int(sqlite3_column_int(statement, 0)),
                    profileName: String(cString: rawProfileName),
                    name: String(cString: rawName)
                )
            )
        }

        return groups
    }
}

enum SafariTabGroupCommandError: Error, Equatable {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
}
