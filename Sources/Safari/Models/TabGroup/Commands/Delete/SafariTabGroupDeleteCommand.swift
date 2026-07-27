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
            CommandArgumentDescriptor(
                name: "tab-group-identifier",
                kind: .positional,
                valueType: .integer,
                isRequired: false
            ),
            CommandArgumentDescriptor(
                name: "profile",
                kind: .option,
                isRequired: false,
                valueName: "profile"
            ),
            CommandArgumentDescriptor(
                name: "name",
                kind: .option,
                isRequired: false,
                valueName: "name"
            )
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("tab-group-identifier", isRequired: true)],
                [
                    .argumentRef("profile", isRequired: true),
                    .argumentRef("name", isRequired: true)
                ]
            ])
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
    private let deleteSidebarTabGroup: (String, String) throws -> SafariTabGroupRecord
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.listTabGroups = { try SafariTabGroup.list() }
        self.listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.deleteSelectedTabGroup = { _ in
            try SafariSidebar.deleteSelectedTabGroup()
        }
        self.deleteCurrentTabGroup = { _ in try SafariFileMenu.deleteCurrentTabGroup() }
        self.deleteSidebarTabGroup = { profileName, tabGroupName in
            try SafariTabGroupSidebarAccess.deleteTabGroup(
                profileName: profileName,
                named: tabGroupName,
                executor: executor,
                listWindows: { try SafariWindow.listForAutomation(executor: executor) }
            )
        }
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
        deleteSidebarTabGroup: @escaping (String, String) throws -> SafariTabGroupRecord = { _, _ in
            throw SafariTabGroupCommandError.sidebarUnavailable
        },
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
        self.deleteSidebarTabGroup = deleteSidebarTabGroup
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try SafariTabGroup.format(deleteTabGroup(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariTabGroupDeleteJSONOutput(tabGroup: deleteTabGroup(arguments: arguments)))
    }

    private func deleteTabGroup(arguments: [String]) throws -> SafariTabGroupRecord {
        switch try SafariTabGroupDeleteRequest.parse(arguments) {
        case .identifier(let identifier):
            return try deleteTabGroup(identifier: identifier)
        case .sidebar(let profileName, let tabGroupName):
            return try deleteSidebarTabGroup(profileName, tabGroupName)
        }
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

private enum SafariTabGroupDeleteRequest: Equatable {
    case identifier(Int)
    case sidebar(profileName: String, tabGroupName: String)

    static func parse(_ arguments: [String]) throws -> SafariTabGroupDeleteRequest {
        var positionalArguments: [String] = []
        var profileName: String?
        var tabGroupName: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--profile":
                guard profileName == nil else {
                    throw SafariTabGroupCommandError.unexpectedArgument(argument)
                }
                index += 1
                guard index < arguments.count, !arguments[index].hasPrefix("--") else {
                    throw SafariTabGroupCommandError.missingProfileName
                }
                profileName = arguments[index]
            case "--name":
                guard tabGroupName == nil else {
                    throw SafariTabGroupCommandError.unexpectedArgument(argument)
                }
                index += 1
                guard index < arguments.count, !arguments[index].hasPrefix("--") else {
                    throw SafariTabGroupCommandError.missingTabGroupName
                }
                tabGroupName = arguments[index]
            default:
                if argument.hasPrefix("--profile=") {
                    guard profileName == nil else {
                        throw SafariTabGroupCommandError.unexpectedArgument(argument)
                    }
                    profileName = String(argument.dropFirst("--profile=".count))
                } else if argument.hasPrefix("--name=") {
                    guard tabGroupName == nil else {
                        throw SafariTabGroupCommandError.unexpectedArgument(argument)
                    }
                    tabGroupName = String(argument.dropFirst("--name=".count))
                } else if argument.hasPrefix("--") {
                    throw SafariTabGroupCommandError.unexpectedArgument(argument)
                } else {
                    positionalArguments.append(argument)
                }
            }
            index += 1
        }

        if profileName != nil || tabGroupName != nil {
            guard positionalArguments.isEmpty else {
                throw SafariTabGroupCommandError.unexpectedArgument(positionalArguments[0])
            }
            guard let profileName else {
                throw SafariTabGroupCommandError.missingProfileName
            }
            guard !profileName.isEmpty else {
                throw SafariTabGroupCommandError.emptyProfileName
            }
            guard let tabGroupName else {
                throw SafariTabGroupCommandError.missingTabGroupName
            }
            guard !tabGroupName.isEmpty else {
                throw SafariTabGroupCommandError.emptyTabGroupName
            }
            return .sidebar(profileName: profileName, tabGroupName: tabGroupName)
        }

        guard let rawIdentifier = positionalArguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }
        guard positionalArguments.count == 1 else {
            throw SafariTabGroupCommandError.unexpectedArgument(positionalArguments[1])
        }
        guard let identifier = Int(rawIdentifier), identifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawIdentifier)
        }
        return .identifier(identifier)
    }
}

private struct SafariTabGroupDeleteJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
