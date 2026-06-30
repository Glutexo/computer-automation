import AutomationFoundation
import SafariAppleScript

public struct SafariWindowSetTabGroupCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "set-window-tab-group",
        abstract: "Switch a Safari window to a saved tab group.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindows: () throws -> [SafariWindowRecord]
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (String, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindows = { try SafariWindow.list() }
        self.listTabGroups = { try SafariTabGroup.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        selectTabGroup: @escaping (String, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup
    ) {
        self.executor = executor
        self.listWindows = listWindows
        self.listTabGroups = listTabGroups
        self.focusWindow = focusWindow
        self.selectTabGroup = selectTabGroup
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

        try focusWindow(window.identifier, executor)
        try selectTabGroup(tabGroup.name, executor)

        return "Safari window \(windowIndex) switched to tab group \(tabGroup.name)."
    }
}
