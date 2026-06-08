import AppKit
import AutomationFoundation
import SafariAppleScript
import SafariUserInterface
import SQLite3

public struct SafariWindowRecord: Equatable, Sendable {
    public let identifier: Int
    public let index: Int
    public let profileName: String
    public let name: String

    public init(identifier: Int, index: Int, profileName: String, name: String) {
        self.identifier = identifier
        self.index = index
        self.profileName = profileName
        self.name = name
    }
}

public enum SafariWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window",
        abstract: "Safari browser windows.",
        commands: [
            SafariWindowOpenCommand.descriptor,
            SafariWindowListCommand.descriptor,
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
        let profilesByWindowIdentifier = try loadProfilesByWindowIdentifier(databasePath: databasePath)
        let knownProfileNames = Set(try SafariProfile.listAvailableProfiles(databasePath: databasePath).map(\.name))

        return rawWindows.enumerated().map { offset, rawWindow in
            let profileName = profilesByWindowIdentifier[rawWindow.identifier]
                ?? inferProfileName(fromWindowTitle: rawWindow.name, knownProfileNames: knownProfileNames)
                ?? ""

            return SafariWindowRecord(
                identifier: rawWindow.identifier,
                index: offset + 1,
                profileName: profileName,
                name: rawWindow.name
            )
        }
    }

    static func parseWindowList(
        _ descriptor: NSAppleEventDescriptor?,
        profilesByWindowIdentifier: [Int: String] = [:]
    ) -> [SafariWindowRecord] {
        let rawWindows = SafariAppleScriptWindow.parseWindowList(descriptor)
        return rawWindows.enumerated().map { offset, rawWindow in
            SafariWindowRecord(
                identifier: rawWindow.identifier,
                index: offset + 1,
                profileName: profilesByWindowIdentifier[rawWindow.identifier] ?? "",
                name: rawWindow.name
            )
        }
    }

    static func loadProfilesByWindowIdentifier(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [Int: String] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw SafariWindowCommandError.databaseOpenFailed(path: databasePath)
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT w.id, COALESCE(b.title, '')
        FROM windows w
        LEFT JOIN bookmarks b ON b.id = w.active_profile_id
        WHERE w.date_closed IS NULL;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            defer { sqlite3_finalize(statement) }
            throw SafariWindowCommandError.queryPreparationFailed
        }
        defer { sqlite3_finalize(statement) }

        var profilesByWindowIdentifier: [Int: String] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            let identifier = Int(sqlite3_column_int(statement, 0))
            let profileName = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            profilesByWindowIdentifier[identifier] = profileName
        }

        return profilesByWindowIdentifier
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

enum SafariWindowCommandError: Error, Equatable {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case profileNotFound(String)
    case profileMenuItemNotFound(String)
}
