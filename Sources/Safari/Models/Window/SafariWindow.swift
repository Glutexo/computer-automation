import AppKit
import AutomationFoundation
import SQLite3

public struct SafariWindowRecord: Equatable {
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

        let script = """
        tell application "Safari"
            set output to {}
            repeat with currentWindow in every window
                set end of output to ((id of currentWindow as string) & "|" & (name of currentWindow as string))
            end repeat
            return output
        end tell
        """

        let descriptor = try executor.execute(script: script)
        let rawWindows = parseRawWindowList(descriptor)
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
        let rawWindows = parseRawWindowList(descriptor)
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
        guard let descriptor else {
            return []
        }

        if descriptor.descriptorType != typeAEList {
            let rawValue = descriptor.stringValue ?? ""
            return rawValue.isEmpty ? [] : parseWindowLines([rawValue])
        }

        guard descriptor.numberOfItems > 0 else {
            return []
        }

        var lines: [String] = []
        for index in 1...descriptor.numberOfItems {
            if let item = descriptor.atIndex(index)?.stringValue {
                lines.append(item)
            }
        }
        return parseWindowLines(lines)
    }

    private static func parseWindowLines(_ lines: [String]) -> [RawSafariWindow] {
        lines.compactMap { line in
            let components = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard components.count == 2, let identifier = Int(components[0]) else {
                return nil
            }
            return RawSafariWindow(identifier: identifier, name: components[1])
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
