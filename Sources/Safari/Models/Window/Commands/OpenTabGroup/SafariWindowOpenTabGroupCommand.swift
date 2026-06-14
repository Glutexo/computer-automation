import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenTabGroupCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-tab-group-window",
        abstract: "Open a new Safari window for a saved tab group.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (String, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabGroups = { try SafariTabGroup.list() }
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.selectTabGroup = SafariWindowTabGroupSelection.selectTabGroup
    }

    init(
        executor: SafariAppleScriptExecuting,
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        selectTabGroup: @escaping (String, SafariAppleScriptExecuting) throws -> Void = SafariWindowTabGroupSelection.selectTabGroup
    ) {
        self.executor = executor
        self.listTabGroups = listTabGroups
        self.openWindow = openWindow
        self.selectTabGroup = selectTabGroup
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawTabGroupIdentifier = arguments.first else {
            throw SafariWindowCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariWindowCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        let tabGroup = try SafariWindowTabGroupSelection.resolveTabGroup(
            identifier: tabGroupIdentifier,
            from: try listTabGroups()
        )

        do {
            try openWindow(tabGroup.profileName, executor)
        } catch SafariUserInterfaceError.profileWindowMenuItemNotFound {
            throw SafariWindowCommandError.profileMenuItemNotFound(tabGroup.profileName)
        }

        try selectTabGroup(tabGroup.name, executor)

        return "Safari window opened for tab group \(tabGroup.name)."
    }
}
