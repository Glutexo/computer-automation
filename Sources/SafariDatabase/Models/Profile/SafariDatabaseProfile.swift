import AutomationFoundation
import SQLite3

public struct SafariDatabaseProfileRecord: Equatable, Sendable {
    public let name: String
    public let identifier: String

    public init(name: String, identifier: String) {
        self.name = name
        self.identifier = identifier
    }
}

public enum SafariDatabaseProfile: ModelModel {
    private static let modelName = "profile"

    public static let descriptor = ModelDescriptor(
        name: modelName,
        abstract: "Safari profile rows stored in SafariTabs.db.",
        commands: []
    )

    public static func list(
        databasePath: String = SafariTabsDatabase.databasePath()
    ) throws -> [SafariDatabaseProfileRecord] {
        let database = try SafariTabsDatabase.openReadOnly(databasePath: databasePath)
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
            throw SafariDatabaseError.queryPreparationFailed(modelName: modelName)
        }
        defer { sqlite3_finalize(statement) }

        var profiles: [SafariDatabaseProfileRecord] = []

        try SafariTabsDatabase.stepRows(statement, modelName: modelName) {
            guard
                let titlePointer = sqlite3_column_text(statement, 0),
                let identifierPointer = sqlite3_column_text(statement, 1)
            else {
                return
            }

            profiles.append(
                SafariDatabaseProfileRecord(
                    name: String(cString: titlePointer),
                    identifier: String(cString: identifierPointer)
                )
            )
        }

        return profiles
    }
}
