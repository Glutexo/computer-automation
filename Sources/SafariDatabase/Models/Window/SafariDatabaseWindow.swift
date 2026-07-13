import AutomationFoundation
import SQLite3

public struct SafariDatabaseWindowStateRecord: Equatable, Sendable {
    public let profileName: String
    public let selectedTabGroupIdentifier: Int?
    public let tabGroupName: String?
    public let isPrivate: Bool

    public init(
        profileName: String,
        selectedTabGroupIdentifier: Int?,
        tabGroupName: String?,
        isPrivate: Bool
    ) {
        self.profileName = profileName
        self.selectedTabGroupIdentifier = selectedTabGroupIdentifier
        self.tabGroupName = tabGroupName
        self.isPrivate = isPrivate
    }
}

public enum SafariDatabaseWindow: ModelModel {
    private static let modelName = "window"

    public static let descriptor = ModelDescriptor(
        name: modelName,
        abstract: "Safari window state rows stored in SafariTabs.db.",
        commands: []
    )

    public static func loadProfilesByWindowIdentifier(
        databasePath: String = SafariTabsDatabase.databasePath()
    ) throws -> [Int: String] {
        try loadStateByWindowIdentifier(databasePath: databasePath).mapValues(\.profileName)
    }

    public static func loadStateByWindowIdentifier(
        databasePath: String = SafariTabsDatabase.databasePath()
    ) throws -> [Int: SafariDatabaseWindowStateRecord] {
        let database = try SafariTabsDatabase.openReadOnly(databasePath: databasePath)
        defer { sqlite3_close(database) }

        let query = """
        SELECT
            w.id,
            COALESCE(b.title, gp.title, ''),
            g.id,
            g.title,
            CASE
                WHEN w.private_tab_group_id IS NOT NULL AND w.active_tab_group_id = w.private_tab_group_id THEN 1
                ELSE 0
            END
        FROM windows w
        LEFT JOIN bookmarks b ON b.id = w.active_profile_id
        LEFT JOIN bookmarks g ON g.id = w.active_tab_group_id
            AND g.type = 1
            AND g.subtype = 0
            AND EXISTS (
                SELECT 1
                FROM bookmarks child
                WHERE child.parent = g.id
                  AND child.type = 1
                  AND child.subtype = 1
            )
        LEFT JOIN bookmarks gp ON gp.id = g.parent
            AND gp.parent = 0
            AND gp.type = 1
            AND gp.subtype = 2
        WHERE w.date_closed IS NULL;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariDatabaseError.queryPreparationFailed(modelName: modelName)
        }
        defer { sqlite3_finalize(statement) }

        var stateByWindowIdentifier: [Int: SafariDatabaseWindowStateRecord] = [:]

        try SafariTabsDatabase.stepRows(statement, modelName: modelName) {
            let identifier = try SafariTabsDatabase.identifier(in: statement, column: 0, modelName: modelName)
            let profileName = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            let selectedTabGroupIdentifier: Int? = if sqlite3_column_type(statement, 2) == SQLITE_NULL {
                nil
            } else {
                try SafariTabsDatabase.identifier(in: statement, column: 2, modelName: modelName)
            }
            let tabGroupName = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            let isPrivate = sqlite3_column_int(statement, 4) == 1
            stateByWindowIdentifier[identifier] = SafariDatabaseWindowStateRecord(
                profileName: profileName,
                selectedTabGroupIdentifier: selectedTabGroupIdentifier,
                tabGroupName: tabGroupName,
                isPrivate: isPrivate
            )
        }

        return stateByWindowIdentifier
    }
}
