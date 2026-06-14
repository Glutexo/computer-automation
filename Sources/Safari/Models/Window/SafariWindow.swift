import AppKit
import AutomationFoundation
import SafariAppleScript
import SafariUserInterface
import SQLite3

public struct SafariWindowRecord: Equatable, Sendable {
    public let identifier: Int
    public let index: Int
    public let isPrivate: Bool
    public let profileName: String
    public let selectedTabGroupIdentifier: Int?
    public let tabGroupName: String?
    public let name: String

    public init(identifier: Int, index: Int, isPrivate: Bool = false, profileName: String, selectedTabGroupIdentifier: Int? = nil, tabGroupName: String? = nil, name: String) {
        self.identifier = identifier
        self.index = index
        self.isPrivate = isPrivate
        self.profileName = profileName
        self.selectedTabGroupIdentifier = selectedTabGroupIdentifier
        self.tabGroupName = tabGroupName
        self.name = name
    }
}

public enum SafariWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window",
        abstract: "Safari browser windows.",
        commands: [
            SafariWindowOpenCommand.descriptor,
            SafariWindowOpenPrivateCommand.descriptor,
            SafariWindowOpenTabGroupCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowSetTabGroupCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )

    static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariWindowRecord] {
        guard SafariApplication.isRunning() else {
            return []
        }
        let rawWindows = try SafariAppleScriptWindow.list(executor: executor)
        let statesByWindowIdentifier = try loadWindowStateByWindowIdentifier(databasePath: databasePath)
        let knownProfileNames = Set(try SafariProfile.listAvailableProfiles(databasePath: databasePath).map(\.name))

        return rawWindows.enumerated().map { offset, rawWindow in
            let state = statesByWindowIdentifier[rawWindow.identifier]
            let profileName = state?.profileName
                ?? inferProfileName(fromWindowTitle: rawWindow.name, knownProfileNames: knownProfileNames)
                ?? ""

            return SafariWindowRecord(
                identifier: rawWindow.identifier,
                index: offset + 1,
                isPrivate: state?.isPrivate ?? false,
                profileName: profileName,
                selectedTabGroupIdentifier: state?.selectedTabGroupIdentifier,
                tabGroupName: state?.tabGroupName,
                name: rawWindow.name
            )
        }
    }

    static func parseWindowList(
        _ descriptor: NSAppleEventDescriptor?,
        profilesByWindowIdentifier: [Int: String] = [:],
        privateWindowIdentifiers: Set<Int> = []
    ) -> [SafariWindowRecord] {
        let rawWindows = SafariAppleScriptWindow.parseWindowList(descriptor)
        return rawWindows.enumerated().map { offset, rawWindow in
            SafariWindowRecord(
                identifier: rawWindow.identifier,
                index: offset + 1,
                isPrivate: privateWindowIdentifiers.contains(rawWindow.identifier),
                profileName: profilesByWindowIdentifier[rawWindow.identifier] ?? "",
                selectedTabGroupIdentifier: nil,
                tabGroupName: nil,
                name: rawWindow.name
            )
        }
    }

    static func loadProfilesByWindowIdentifier(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [Int: String] {
        try loadWindowStateByWindowIdentifier(databasePath: databasePath).mapValues(\.profileName)
    }

    static func loadWindowStateByWindowIdentifier(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [Int: SafariWindowState] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw SafariWindowCommandError.databaseOpenFailed(path: databasePath)
        }
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
            throw SafariWindowCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        var stateByWindowIdentifier: [Int: SafariWindowState] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            let identifier = Int(sqlite3_column_int(statement, 0))
            let profileName = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            let selectedTabGroupIdentifier = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 2))
            let tabGroupName = sqlite3_column_text(statement, 3).map { String(cString: $0) }
            let isPrivate = sqlite3_column_int(statement, 4) == 1
            stateByWindowIdentifier[identifier] = SafariWindowState(
                profileName: profileName,
                selectedTabGroupIdentifier: selectedTabGroupIdentifier,
                tabGroupName: tabGroupName,
                isPrivate: isPrivate
            )
        }

        return stateByWindowIdentifier
    }

    private static func parseRawWindowList(_ descriptor: NSAppleEventDescriptor?) -> [RawSafariWindow] {
        SafariAppleScriptWindow.parseWindowList(descriptor).map {
            RawSafariWindow(identifier: $0.identifier, name: $0.name)
        }
    }

    private static func inferProfileName(
        fromWindowTitle title: String,
        knownProfileNames: Set<String>
    ) -> String? {
        knownProfileNames.first { profileName in
            title == profileName || title.hasPrefix("\(profileName) —") || title.hasPrefix("\(profileName) -")
        }
    }
}

private struct RawSafariWindow {
    let identifier: Int
    let name: String
}

struct SafariWindowState: Equatable, Sendable {
    let profileName: String
    let selectedTabGroupIdentifier: Int?
    let tabGroupName: String?
    let isPrivate: Bool
}

enum SafariWindowCommandError: Error, Equatable {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case profileNotFound(String)
    case profileMenuItemNotFound(String)
    case privateWindowMenuItemNotFound
    case missingWindowIndex
    case invalidWindowIndex(String)
    case missingTabGroupIdentifier
    case invalidTabGroupIdentifier(String)
    case tabGroupNotFound(Int)
    case ambiguousTabGroupName(profileName: String, tabGroupName: String)
    case privateWindowTabGroupSelectionUnsupported(Int)
    case windowTabGroupProfileMismatch(windowProfileName: String, tabGroupProfileName: String)
    case tabGroupPickerUnavailable
    case tabGroupPickerItemNotFound(String)
}
