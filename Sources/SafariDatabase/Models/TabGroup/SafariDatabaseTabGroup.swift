import AutomationFoundation
import SQLite3

public struct SafariDatabaseTabGroupRecord: Equatable, Sendable {
    public let identifier: Int
    public let profileName: String
    public let name: String

    public init(identifier: Int, profileName: String, name: String) {
        self.identifier = identifier
        self.profileName = profileName
        self.name = name
    }
}

public struct SafariDatabaseTabGroupTabRecord: Equatable, Sendable {
    public let tabGroupIdentifier: Int
    public let index: Int
    public let url: String

    public init(tabGroupIdentifier: Int, index: Int, url: String) {
        self.tabGroupIdentifier = tabGroupIdentifier
        self.index = index
        self.url = url
    }
}

public enum SafariDatabaseTabGroup: ModelModel {
    private static let modelName = "tab-group"

    public static let descriptor = ModelDescriptor(
        name: modelName,
        abstract: "Saved Safari tab-group rows stored in SafariTabs.db.",
        commands: []
    )

    public static func list(
        databasePath: String = SafariTabsDatabase.databasePath()
    ) throws -> [SafariDatabaseTabGroupRecord] {
        let database = try SafariTabsDatabase.openReadOnly(databasePath: databasePath)
        defer { sqlite3_close(database) }

        let query = """
        SELECT g.id, COALESCE(p.title, ''), g.title
        FROM bookmarks g
        LEFT JOIN bookmarks p ON p.id = g.parent
          AND p.parent = 0
          AND p.type = 1
          AND p.subtype = 2
        WHERE g.type = 1
          AND g.subtype = 0
          AND (p.id IS NOT NULL OR g.parent = 0)
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
            throw SafariDatabaseError.queryPreparationFailed(modelName: modelName)
        }
        defer { sqlite3_finalize(statement) }

        var groups: [SafariDatabaseTabGroupRecord] = []

        try SafariTabsDatabase.stepRows(statement, modelName: modelName) {
            guard
                let rawProfileName = sqlite3_column_text(statement, 1),
                let rawName = sqlite3_column_text(statement, 2)
            else {
                return
            }

            groups.append(
                SafariDatabaseTabGroupRecord(
                    identifier: try SafariTabsDatabase.identifier(
                        in: statement,
                        column: 0,
                        modelName: modelName
                    ),
                    profileName: String(cString: rawProfileName),
                    name: String(cString: rawName)
                )
            )
        }

        return groups
    }

    public static func listTabs(
        tabGroupIdentifier: Int,
        databasePath: String = SafariTabsDatabase.databasePath()
    ) throws -> [SafariDatabaseTabGroupTabRecord] {
        let database = try SafariTabsDatabase.openReadOnly(databasePath: databasePath)
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
              UNION ALL
              SELECT 1
              WHERE g.parent = 0
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
            throw SafariDatabaseError.queryPreparationFailed(modelName: modelName)
        }
        defer { sqlite3_finalize(statement) }

        try SafariTabsDatabase.bindIdentifier(
            tabGroupIdentifier,
            to: statement,
            index: 1,
            modelName: modelName
        )

        var tabs: [SafariDatabaseTabGroupTabRecord] = []

        try SafariTabsDatabase.stepRows(statement, modelName: modelName) {
            let index = tabs.count + 1
            let url = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            tabs.append(SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: tabGroupIdentifier, index: index, url: url))
        }

        return tabs
    }

}
