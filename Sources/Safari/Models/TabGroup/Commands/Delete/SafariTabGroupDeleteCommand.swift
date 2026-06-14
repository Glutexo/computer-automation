import AutomationFoundation

import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupDeleteCommand: CommandModel {
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
    private let selectTabGroup: (String, SafariAppleScriptExecuting) throws -> Void
    private let deleteSelectedTabGroup: (SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabGroups = { try SafariTabGroup.list() }
        self.listWindows = { try SafariWindow.list() }
        self.focusWindow = SafariAppleScriptWindow.focus
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.deleteSelectedTabGroup = { _ in
            try SafariSidebar.deleteSelectedTabGroup()
        }
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus,
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        selectTabGroup: @escaping (String, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        deleteSelectedTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.deleteCurrentTabGroup
    ) {
        self.executor = executor
        self.listTabGroups = listTabGroups
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.selectTabGroup = selectTabGroup
        self.deleteSelectedTabGroup = deleteSelectedTabGroup
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawTabGroupIdentifier = arguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        let groups = try listTabGroups()
        let group = try SafariTabGroupSidebarAccess.resolveUniqueTabGroup(identifier: tabGroupIdentifier, from: groups)

        _ = try SafariTabGroupSidebarAccess.focusWindowForTabGroup(
            group,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow
        )
        try selectTabGroup(group.name, executor)
        try deleteSelectedTabGroup(executor)
        return SafariTabGroup.format(group)
    }
}
