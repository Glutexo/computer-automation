import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupRenameCommand: CommandModel, JSONCommandModel {
    private static let selectionPollAttempts = 30
    private static let selectionPollInterval: TimeInterval = 0.1
    private static let databaseMutationPollAttempts = 30
    private static let databaseMutationPollInterval: TimeInterval = 0.25

    public static let descriptor = CommandDescriptor(
        name: "rename-tab-group",
        abstract: "Rename a saved Safari tab group without changing its identifier.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(
                name: "tab-group-identifier",
                kind: .positional,
                valueType: .integer
            ),
            CommandArgumentDescriptor(name: "name", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let openWindow: (
        String,
        SafariAppleScriptExecuting,
        @escaping () throws -> [SafariWindowRecord]
    ) throws -> SafariWindowRecord
    private let focusWindow: (SafariWindowRecord, SafariAppleScriptExecuting) throws -> Void
    private let renameSidebarTabGroup: (
        SafariTabGroupRecord,
        String,
        pid_t?,
        () throws -> Bool
    ) throws -> Void
    private let closeWindow: (Int) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.listTabGroups = { try SafariTabGroup.list() }
        self.listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.openWindow = SafariTabGroupSidebarAccess.openNewWindowForProfile
        self.focusWindow = { window, executor in
            if let processIdentifier = window.processId {
                try SafariAppleScriptWindow.focus(
                    windowIdentifier: window.identifier,
                    processIdentifier: processIdentifier
                )
            } else {
                try SafariAppleScriptWindow.focus(
                    windowIdentifier: window.identifier,
                    executor: executor
                )
            }
        }
        self.renameSidebarTabGroup = { group, newName, processIdentifier, selectionIsVerified in
            do {
                try SafariSidebar.renameTabGroup(
                    identifier: group.identifier,
                    named: group.name,
                    to: newName,
                    processIdentifier: processIdentifier,
                    selectionIsVerified: selectionIsVerified
                )
            } catch let error as SafariUserInterfaceError {
                switch error {
                case .sidebarSelectedItemRenameUnavailable:
                    throw SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable
                default:
                    throw SafariTabGroupCommandError.sidebarUnavailable
                }
            }
        }
        self.closeWindow = { identifier in
            _ = try SafariWindowCloseCommand().execute(
                arguments: ["--window-id", String(identifier)]
            )
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord],
        listWindows: @escaping () throws -> [SafariWindowRecord],
        openWindow: @escaping (
            String,
            SafariAppleScriptExecuting,
            @escaping () throws -> [SafariWindowRecord]
        ) throws -> SafariWindowRecord,
        focusWindow: @escaping (SafariWindowRecord, SafariAppleScriptExecuting) throws -> Void = { _, _ in },
        renameSidebarTabGroup: @escaping (
            SafariTabGroupRecord,
            String,
            pid_t?,
            () throws -> Bool
        ) throws -> Void,
        closeWindow: @escaping (Int) throws -> Void,
        sleep: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.executor = executor
        self.listTabGroups = listTabGroups
        self.listWindows = listWindows
        self.openWindow = openWindow
        self.focusWindow = focusWindow
        self.renameSidebarTabGroup = renameSidebarTabGroup
        self.closeWindow = closeWindow
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try SafariTabGroup.format(renameTabGroup(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(
            SafariTabGroupRenameJSONOutput(tabGroup: renameTabGroup(arguments: arguments))
        )
    }

    private func renameTabGroup(arguments: [String]) throws -> SafariTabGroupRecord {
        guard let rawIdentifier = arguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }
        guard let identifier = Int(rawIdentifier), identifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawIdentifier)
        }
        guard let rawName = arguments.dropFirst().first else {
            throw SafariTabGroupCommandError.missingTabGroupName
        }
        guard arguments.count == 2 else {
            throw SafariTabGroupCommandError.unexpectedArgument(arguments[2])
        }

        return try renameTabGroup(identifier: identifier, name: rawName)
    }

    func renameTabGroup(identifier: Int, name rawName: String) throws -> SafariTabGroupRecord {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SafariTabGroupCommandError.emptyTabGroupName
        }

        let group = try SafariTabGroupSidebarAccess.resolveUniqueTabGroup(
            identifier: identifier,
            from: listTabGroups()
        )
        guard group.name != name else {
            return group
        }

        let operationWindow = try openWindow(group.profileName, executor, listWindows)
        do {
            try focusWindow(operationWindow, executor)
            try renameSidebarTabGroup(
                group,
                name,
                operationWindow.processId,
                {
                    try waitForSelectedTabGroup(
                        identifier: group.identifier,
                        windowIdentifier: operationWindow.identifier
                    )
                }
            )
            let renamedGroup = try waitForRenamedTabGroup(
                identifier: group.identifier,
                expectedName: name
            )
            try closeWindow(operationWindow.identifier)
            return renamedGroup
        } catch {
            let operationError = error
            try? closeWindow(operationWindow.identifier)
            throw operationError
        }
    }

    private func waitForSelectedTabGroup(
        identifier: Int,
        windowIdentifier: Int
    ) throws -> Bool {
        for attempt in 0..<Self.selectionPollAttempts {
            if let window = try listWindows().first(where: { $0.identifier == windowIdentifier }) {
                if let observedIdentifier = window.selectedTabGroupIdentifier {
                    return observedIdentifier == identifier
                }
            }

            if attempt < Self.selectionPollAttempts - 1 {
                sleep(Self.selectionPollInterval)
            }
        }

        return false
    }

    private func waitForRenamedTabGroup(
        identifier: Int,
        expectedName: String
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            if let group = try listTabGroups().first(where: {
                $0.identifier == identifier && $0.name == expectedName
            }) {
                return group
            }

            if attempt < Self.databaseMutationPollAttempts - 1 {
                sleep(Self.databaseMutationPollInterval)
            }
        }

        throw SafariTabGroupCommandError.tabGroupRenameNotVerified(
            identifier: identifier,
            expectedName: expectedName
        )
    }
}

private struct SafariTabGroupRenameJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
