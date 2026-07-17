import AutomationFoundation
import Foundation
import SafariAppleScript

public struct SafariWindowOpenTabGroupCommand: CommandModel, JSONCommandModel {
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
    private let openNewWindowForProfile: (String, SafariAppleScriptExecuting) throws -> SafariWindowRecord
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord]
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabGroups = { try SafariTabGroup.list() }
        self.openNewWindowForProfile = { profileName, executor in
            try SafariTabGroupSidebarAccess.openNewWindowForProfile(
                profileName: profileName,
                executor: executor,
                listWindows: { try SafariWindow.listForAutomation(executor: executor) }
            )
        }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.listWindows = { executor in try SafariWindow.listForAutomation(executor: executor) }
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        openNewWindowForProfile: @escaping (String, SafariAppleScriptExecuting) throws -> SafariWindowRecord,
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { executor in
            try SafariWindow.list(executor: executor)
        },
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listTabGroups = listTabGroups
        self.openNewWindowForProfile = openNewWindowForProfile
        self.focusWindow = focusWindow
        self.selectTabGroup = selectTabGroup
        self.listWindows = listWindows
        self.closeWindow = closeWindow
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try openTabGroupWindowResult(arguments: arguments).text
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(openTabGroupWindowResult(arguments: arguments))
    }

    private func openTabGroupWindowResult(arguments: [String]) throws -> SafariWindowCreationResult {
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

        let createdWindow = try openNewWindowForProfile(tabGroup.profileName, executor)

        do {
            try focusWindow(createdWindow.identifier, executor)
            try selectTabGroup(tabGroup, executor)

            for attempt in 0..<SafariWindowCreation.pollAttempts {
                let windows = try listWindows(executor)
                if
                    let operationWindow = windows.first(where: { $0.identifier == createdWindow.identifier }),
                    !operationWindow.profileName.isEmpty,
                    operationWindow.profileName != tabGroup.profileName
                {
                    throw SafariWindowCommandError.openedWindowProfileMismatch(
                        requestedProfileName: tabGroup.profileName,
                        observedWindowName: operationWindow.profileName
                    )
                }

                if windows.contains(where: {
                    window($0, matches: tabGroup, windowIdentifier: createdWindow.identifier)
                }) {
                    return SafariWindowCreationResult(
                        message: "Safari window opened for tab group \(tabGroup.name).",
                        windowId: createdWindow.identifier,
                        profileName: tabGroup.profileName,
                        isPrivate: false
                    )
                }

                if attempt < SafariWindowCreation.pollAttempts - 1 {
                    sleep(SafariWindowCreation.pollInterval)
                }
            }
        } catch {
            try closeWindow(createdWindow.identifier, executor)
            throw error
        }

        try closeWindow(createdWindow.identifier, executor)
        throw SafariWindowCommandError.tabGroupSelectionNotVerified(
            windowIdentifier: createdWindow.identifier,
            tabGroupIdentifier: tabGroup.identifier
        )
    }

    private func window(
        _ window: SafariWindowRecord,
        matches tabGroup: SafariTabGroupRecord,
        windowIdentifier: Int
    ) -> Bool {
        guard
            window.identifier == windowIdentifier,
            !window.isPrivate,
            window.profileName == tabGroup.profileName
        else {
            return false
        }

        if let selectedTabGroupIdentifier = window.selectedTabGroupIdentifier {
            return selectedTabGroupIdentifier == tabGroup.identifier
        }

        return window.tabGroupName == tabGroup.name ||
            window.name == tabGroup.name ||
            window.name.hasPrefix("\(tabGroup.name) —") ||
            window.name.hasPrefix("\(tabGroup.name) -")
    }
}
