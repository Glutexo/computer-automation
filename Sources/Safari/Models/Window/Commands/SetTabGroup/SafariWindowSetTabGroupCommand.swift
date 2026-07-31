import AutomationFoundation
import Foundation
import SafariAppleScript

public struct SafariWindowSetTabGroupCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "set-window-tab-group",
        abstract: "Switch a Safari window to a saved tab group.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional, valueType: .integer),
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional, valueType: .integer)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindows: () throws -> [SafariWindowRecord]
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let focusWindowInProcess: (Int, pid_t, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, pid_t?, SafariAppleScriptExecuting) throws -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.listTabGroups = { try SafariTabGroup.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.focusWindowInProcess = { windowIdentifier, processIdentifier, _ in
            try SafariAppleScriptWindow.focus(
                windowIdentifier: windowIdentifier,
                processIdentifier: processIdentifier
            )
        }
        self.selectTabGroup = { group, processIdentifier, executor in
            try SafariTabGroupSidebarAccess.selectTabGroup(
                group,
                processIdentifier: processIdentifier,
                executor: executor
            )
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        focusWindowInProcess: ((Int, pid_t, SafariAppleScriptExecuting) throws -> Void)? = nil,
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        selectTabGroupInProcess: ((SafariTabGroupRecord, pid_t?, SafariAppleScriptExecuting) throws -> Void)? = nil
    ) {
        self.executor = executor
        self.listWindows = listWindows
        self.listTabGroups = listTabGroups
        self.focusWindow = focusWindow
        self.focusWindowInProcess = focusWindowInProcess ?? { windowIdentifier, _, executor in
            try focusWindow(windowIdentifier, executor)
        }
        self.selectTabGroup = selectTabGroupInProcess ?? { group, _, executor in
            try selectTabGroup(group, executor)
        }
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawWindowIndex = arguments.first else {
            throw SafariWindowCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariWindowCommandError.invalidWindowIndex(rawWindowIndex)
        }

        guard let rawTabGroupIdentifier = arguments.dropFirst().first else {
            throw SafariWindowCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariWindowCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        let windows = try listWindows()
        guard let window = windows.first(where: { $0.index == windowIndex }) else {
            throw SafariWindowCommandError.invalidWindowIndex(rawWindowIndex)
        }

        guard !window.isPrivate else {
            throw SafariWindowCommandError.privateWindowTabGroupSelectionUnsupported(windowIndex)
        }

        let tabGroup = try SafariWindowTabGroupSelection.resolveTabGroup(
            identifier: tabGroupIdentifier,
            from: try listTabGroups()
        )

        guard window.profileName.isEmpty || window.profileName == tabGroup.profileName else {
            throw SafariWindowCommandError.windowTabGroupProfileMismatch(
                windowProfileName: window.profileName,
                tabGroupProfileName: tabGroup.profileName
            )
        }

        if let processIdentifier = window.processId {
            try focusWindowInProcess(window.identifier, processIdentifier, executor)
        } else {
            try focusWindow(window.identifier, executor)
        }
        try selectTabGroup(tabGroup, window.processId, executor)

        return "Safari window \(windowIndex) switched to tab group \(tabGroup.name)."
    }
}
