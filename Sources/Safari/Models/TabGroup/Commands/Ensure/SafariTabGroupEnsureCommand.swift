import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupEnsureCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "ensure-tab-group",
        abstract: "Create or reuse a saved Safari tab group by profile and name.",
        operation: .create,
        arguments: SafariTabGroupFindCommand.descriptor.arguments
    )

    private let executor: SafariAppleScriptExecuting
    private let findTabGroups: (String, String) throws -> [SafariTabGroupRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let createTabGroup: (Int, String) throws -> SafariTabGroupRecord

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.findTabGroups = { profileName, name in
            try SafariTabGroup.find(profileName: profileName, name: name)
        }
        self.listWindows = { try SafariWindow.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.createTabGroup = { windowIdentifier, name in
            try SafariTabGroupCreateCommand().createTabGroup(windowIdentifier: windowIdentifier, name: name)
        }
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        findTabGroups: @escaping (String, String) throws -> [SafariTabGroupRecord] = { profileName, name in
            try SafariTabGroup.find(profileName: profileName, name: name)
        },
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        createTabGroup: @escaping (Int, String) throws -> SafariTabGroupRecord = { windowIdentifier, name in
            try SafariTabGroupCreateCommand().createTabGroup(windowIdentifier: windowIdentifier, name: name)
        }
    ) {
        self.executor = executor
        self.findTabGroups = findTabGroups
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.closeWindow = closeWindow
        self.createTabGroup = createTabGroup
    }

    public func execute(arguments: [String]) throws -> String {
        let summary = try ensure(arguments: arguments)
        return """
        Safari tab group \(summary.status.rawValue).
        \(SafariTabGroup.format(summary.tabGroup))
        """
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(ensure(arguments: arguments))
    }

    private func ensure(arguments: [String]) throws -> SafariTabGroupEnsureSummary {
        let request = try SafariTabGroupLookupRequest.parse(arguments)
        return try ensure(profileName: request.profileName, name: request.name)
    }

    func ensure(profileName: String, name: String) throws -> SafariTabGroupEnsureSummary {
        let matches = try findTabGroups(profileName, name)

        if let match = matches.first {
            guard matches.count == 1 else {
                throw SafariTabGroupCommandError.tabGroupLookupAmbiguous(
                    profileName: profileName,
                    tabGroupName: name,
                    count: matches.count
                )
            }

            return SafariTabGroupEnsureSummary(status: .reused, tabGroup: match)
        }

        let window = try SafariTabGroupSidebarAccess.openNewWindowForProfile(
            profileName: profileName,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow
        )
        let createdGroup: SafariTabGroupRecord
        do {
            createdGroup = try createTabGroup(window.identifier, name)
        } catch {
            try closeWindow(window.identifier, executor)
            throw error
        }
        return SafariTabGroupEnsureSummary(status: .created, tabGroup: createdGroup)
    }
}
