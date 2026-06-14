import AutomationFoundation
import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

public struct SafariTabGroupTabRecord: Equatable, Sendable {
    public let tabGroupIdentifier: Int
    public let index: Int
    public let url: String

    public init(tabGroupIdentifier: Int, index: Int, url: String) {
        self.tabGroupIdentifier = tabGroupIdentifier
        self.index = index
        self.url = url
    }
}

public enum SafariTabGroup: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab-group",
        abstract: "Saved Safari tab groups.",
        commands: [
            SafariTabGroupCreateCommand.descriptor,
            SafariTabGroupListCommand.descriptor,
            SafariTabGroupListTabsCommand.descriptor,
            SafariTabGroupDeleteCommand.descriptor
        ]
    )

    static func format(_ group: SafariTabGroupRecord) -> String {
        "\(group.identifier)|\(group.profileName)|\(group.name)"
    }

    static func list(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariTabGroupRecord] {
        let database: OpaquePointer
        do {
            database = try SafariDatabase.openReadOnly(databasePath: databasePath)
        } catch SafariDatabaseError.openFailed {
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

        do {
            try SafariDatabase.stepRows(statement) {
                guard
                    let rawProfileName = sqlite3_column_text(statement, 1),
                    let rawName = sqlite3_column_text(statement, 2)
                else {
                    return
                }

                groups.append(
                    SafariTabGroupRecord(
                        identifier: Int(sqlite3_column_int(statement, 0)),
                        profileName: String(cString: rawProfileName),
                        name: String(cString: rawName)
                    )
                )
            }
        } catch SafariDatabaseError.queryExecutionFailed {
            throw SafariTabGroupCommandError.queryExecutionFailed
        }

        return groups
    }

    static func listTabs(
        tabGroupIdentifier: Int,
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariTabGroupTabRecord] {
        let database: OpaquePointer
        do {
            database = try SafariDatabase.openReadOnly(databasePath: databasePath)
        } catch SafariDatabaseError.openFailed {
            throw SafariTabGroupCommandError.databaseOpenFailed(path: databasePath)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT COALESCE(child.url, '')
        FROM bookmarks g
        JOIN bookmarks child ON child.parent = g.id
        WHERE g.id = ?
          AND g.type = 1
          AND g.subtype = 0
          AND EXISTS (
              SELECT 1
              FROM bookmarks p
              WHERE p.id = g.parent
                AND p.parent = 0
                AND p.type = 1
                AND p.subtype = 2
          )
          AND EXISTS (
              SELECT 1
              FROM bookmarks scope
              WHERE scope.parent = g.id
                AND scope.type = 1
                AND scope.subtype = 1
          )
          AND child.type = 0
        ORDER BY child.order_index, child.id;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariTabGroupCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(tabGroupIdentifier))

        var tabs: [SafariTabGroupTabRecord] = []

        do {
            try SafariDatabase.stepRows(statement) {
                let index = tabs.count + 1
                let url = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                tabs.append(SafariTabGroupTabRecord(tabGroupIdentifier: tabGroupIdentifier, index: index, url: url))
            }
        } catch SafariDatabaseError.queryExecutionFailed {
            throw SafariTabGroupCommandError.queryExecutionFailed
        }

        return tabs
    }

    static func delete(
        tabGroupIdentifier: Int,
        databasePath: String = SafariProfile.databasePath()
    ) throws -> SafariTabGroupRecord {
        let groups = try list(databasePath: databasePath)
        guard let group = groups.first(where: { $0.identifier == tabGroupIdentifier }) else {
            throw SafariTabGroupCommandError.tabGroupNotFound(tabGroupIdentifier)
        }

        let database: OpaquePointer
        do {
            database = try SafariDatabase.openReadWrite(databasePath: databasePath)
        } catch SafariDatabaseError.openFailed {
            throw SafariTabGroupCommandError.databaseOpenFailed(path: databasePath)
        }
        defer { sqlite3_close(database) }

        let query = """
        WITH RECURSIVE descendants(id) AS (
            SELECT id
            FROM bookmarks
            WHERE id = ?
            UNION ALL
            SELECT child.id
            FROM bookmarks child
            JOIN descendants parentDescendant ON child.parent = parentDescendant.id
        )
        DELETE FROM bookmarks
        WHERE id IN descendants;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariTabGroupCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(tabGroupIdentifier))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SafariTabGroupCommandError.queryExecutionFailed
        }

        return group
    }
}

enum SafariTabGroupCommandError: Error, Equatable, LocalizedError {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case queryExecutionFailed
    case missingWindowIndex
    case invalidWindowIndex(String)
    case missingTabGroupIdentifier
    case invalidTabGroupIdentifier(String)
    case missingTabGroupName
    case emptyTabGroupName
    case tabGroupNotFound(Int)
    case ambiguousTabGroupName(profileName: String, tabGroupName: String)
    case duplicateTabGroupName(profileName: String, tabGroupName: String)
    case privateWindowTabGroupMutationUnsupported(Int)
    case createdTabGroupNotFound(profileName: String)
    case windowForProfileNotFound(String)
    case sidebarUnavailable
    case sidebarTabGroupNotFound(String)
    case sidebarSelectedItemRenameUnavailable

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let path):
            "Could not open SafariTabs.db at \(path). Grant Full Disk Access to the terminal or app running computer-automation, make sure the file exists, and retry."
        case .queryPreparationFailed:
            "Could not prepare the Safari tab-group query. The Safari database schema may have changed."
        case .queryExecutionFailed:
            "Could not finish the Safari tab-group query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        default:
            nil
        }
    }
}
