import AutomationFoundation
import Foundation

import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupDeleteCommand: CommandModel, JSONCommandModel {
    private static let databaseMutationPollAttempts = 30
    private static let databaseMutationPollInterval: TimeInterval = 0.25

    public static let descriptor = CommandDescriptor(
        name: "delete-tab-group",
        abstract: "Delete a saved Safari tab group.",
        operation: .delete,
        arguments: [
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void
    private let deleteSelectedTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let deleteCurrentTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabGroups = { try SafariTabGroup.list() }
        self.listWindows = { try SafariWindow.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.deleteSelectedTabGroup = { _ in
            try SafariSidebar.deleteSelectedTabGroup()
        }
        self.deleteCurrentTabGroup = SafariFileMenu.deleteCurrentTabGroup
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        deleteSelectedTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = { _ in
            try SafariSidebar.deleteSelectedTabGroup()
        },
        deleteCurrentTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.deleteCurrentTabGroup,
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listTabGroups = listTabGroups
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.selectTabGroup = selectTabGroup
        self.deleteSelectedTabGroup = deleteSelectedTabGroup
        self.deleteCurrentTabGroup = deleteCurrentTabGroup
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try SafariTabGroup.format(deleteTabGroup(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariTabGroupDeleteJSONOutput(tabGroup: deleteTabGroup(arguments: arguments)))
    }

    private func deleteTabGroup(arguments: [String]) throws -> SafariTabGroupRecord {
        guard let rawTabGroupIdentifier = arguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        return try deleteTabGroup(identifier: tabGroupIdentifier)
    }

    func deleteTabGroup(identifier tabGroupIdentifier: Int) throws -> SafariTabGroupRecord {
        let groups = try listTabGroups()
        let group = try SafariTabGroupSidebarAccess.resolveUniqueTabGroup(identifier: tabGroupIdentifier, from: groups)

        let focusedWindow = try SafariTabGroupSidebarAccess.focusWindowForTabGroup(
            group,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow,
            sleep: sleep
        )
        do {
            try selectTabGroup(group, executor)
            do {
                try deleteAndVerifyTabGroup(identifier: group.identifier, using: deleteSelectedTabGroup)
            } catch where window(focusedWindow, matches: group) {
                try deleteAndVerifyTabGroup(identifier: group.identifier, using: deleteCurrentTabGroup)
            }
        } catch SafariTabGroupCommandError.sidebarTabGroupNotFound where window(focusedWindow, matches: group) {
            try deleteAndVerifyTabGroup(identifier: group.identifier, using: deleteCurrentTabGroup)
        } catch SafariTabGroupCommandError.sidebarUnavailable where window(focusedWindow, matches: group) {
            try deleteAndVerifyTabGroup(identifier: group.identifier, using: deleteCurrentTabGroup)
        }
        return group
    }

    private func deleteAndVerifyTabGroup(
        identifier: Int,
        using deleteTabGroup: (SafariAppleScriptExecuting) throws -> Void
    ) throws {
        do {
            try deleteTabGroup(executor)
        } catch let deletionError {
            do {
                try waitForDeletedTabGroup(identifier: identifier)
                return
            } catch {
                throw deletionError
            }
        }

        try waitForDeletedTabGroup(identifier: identifier)
    }

    private func waitForDeletedTabGroup(identifier: Int) throws {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            if try !listTabGroups().contains(where: { $0.identifier == identifier }) {
                return
            }

            if attempt < Self.databaseMutationPollAttempts - 1 {
                sleep(Self.databaseMutationPollInterval)
            }
        }

        throw SafariTabGroupCommandError.tabGroupDeletionNotVerified(identifier)
    }

    private func window(_ window: SafariWindowRecord, matches group: SafariTabGroupRecord) -> Bool {
        StableIdentifierMatching.matches(
            requestedIdentifier: group.identifier,
            observedIdentifier: window.selectedTabGroupIdentifier,
            fallback: window.tabGroupName == group.name ||
                window.name == group.name ||
                window.name.hasPrefix("\(group.name) —") ||
                window.name.hasPrefix("\(group.name) -")
        )
    }
}

private struct SafariTabGroupDeleteJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
