import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupCreateCommand: CommandModel, JSONCommandModel {
    private static let databaseMutationPollAttempts = 30
    private static let databaseMutationPollInterval: TimeInterval = 0.25

    public static let descriptor = CommandDescriptor(
        name: "create-tab-group",
        abstract: "Create a new saved Safari tab group in a specific window.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "name", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindows: () throws -> [SafariWindowRecord]
    private let listTabGroups: () throws -> [SafariTabGroupRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let createEmptyTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let renameTabGroup: (String, String, SafariAppleScriptExecuting) throws -> Void
    private let deleteCurrentTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindows = { try SafariWindow.list() }
        self.listTabGroups = { try SafariTabGroup.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.createEmptyTabGroup = { executor in
            try SafariFileMenu.createEmptyTabGroup(executor: executor)
        }
        self.renameTabGroup = { currentName, newName, _ in
            try SafariSidebar.renameTabGroup(named: currentName, to: newName)
        }
        self.deleteCurrentTabGroup = SafariFileMenu.deleteCurrentTabGroup
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        createEmptyTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.createEmptyTabGroup,
        renameTabGroup: @escaping (String, String, SafariAppleScriptExecuting) throws -> Void = { currentName, newName, _ in
            try SafariSidebar.renameTabGroup(named: currentName, to: newName)
        },
        deleteCurrentTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.deleteCurrentTabGroup,
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listWindows = listWindows
        self.listTabGroups = listTabGroups
        self.focusWindow = focusWindow
        self.createEmptyTabGroup = createEmptyTabGroup
        self.renameTabGroup = renameTabGroup
        self.deleteCurrentTabGroup = deleteCurrentTabGroup
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try SafariTabGroup.format(createTabGroup(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariTabGroupMutationJSONOutput(tabGroup: createTabGroup(arguments: arguments)))
    }

    private func createTabGroup(arguments: [String]) throws -> SafariTabGroupRecord {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabGroupCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabGroupCommandError.invalidWindowIndex(rawWindowIndex)
        }

        guard let rawName = arguments.dropFirst().first else {
            throw SafariTabGroupCommandError.missingTabGroupName
        }

        return try createTabGroup(windowIndex: windowIndex, name: rawName)
    }

    func createTabGroup(windowIndex: Int, name rawName: String) throws -> SafariTabGroupRecord {
        let name = try validatedTabGroupName(rawName)
        let windows = try listWindows()
        guard let window = windows.first(where: { $0.index == windowIndex }) else {
            throw SafariTabGroupCommandError.invalidWindowIndex(String(windowIndex))
        }

        return try createTabGroup(in: window, name: name)
    }

    func createTabGroup(windowIdentifier: Int, name rawName: String) throws -> SafariTabGroupRecord {
        let name = try validatedTabGroupName(rawName)
        let windows = try listWindows()
        guard let window = windows.first(where: { $0.identifier == windowIdentifier }) else {
            throw SafariTabGroupCommandError.invalidWindowIndex(String(windowIdentifier))
        }

        return try createTabGroup(in: window, name: name)
    }

    private func validatedTabGroupName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SafariTabGroupCommandError.emptyTabGroupName
        }
        return name
    }

    private func createTabGroup(in window: SafariWindowRecord, name: String) throws -> SafariTabGroupRecord {
        guard !window.isPrivate else {
            throw SafariTabGroupCommandError.privateWindowTabGroupMutationUnsupported(window.index)
        }

        let existingGroups = try listTabGroups()
        let effectiveProfileName = resolveEffectiveProfileName(for: window, tabGroups: existingGroups)

        let hasDuplicateNameInTargetProfile = existingGroups.contains {
            $0.profileName == effectiveProfileName && $0.name == name
        }
        let hasDuplicateNameWithoutResolvedProfile = effectiveProfileName.isEmpty && existingGroups.contains { $0.name == name }

        guard !(hasDuplicateNameInTargetProfile || hasDuplicateNameWithoutResolvedProfile) else {
            throw SafariTabGroupCommandError.duplicateTabGroupName(
                profileName: effectiveProfileName,
                tabGroupName: name
            )
        }

        let knownIdentifiers = Set(existingGroups.map(\.identifier))

        try focusWindow(window.identifier, executor)
        try createEmptyTabGroup(executor)

        let createdGroup: SafariTabGroupRecord
        do {
            createdGroup = try waitForCreatedTabGroup(
                profileName: effectiveProfileName,
                knownIdentifiers: knownIdentifiers
            )
        } catch {
            try rollbackNewTabGroups(
                excluding: knownIdentifiers,
                windowIdentifier: window.identifier
            )
            throw error
        }

        do {
            if createdGroup.name != name {
                sleep(0.1)
                try renameTabGroup(createdGroup.name, name, executor)
            }

            let renamedGroup = try waitForRenamedTabGroup(
                identifier: createdGroup.identifier,
                expectedName: name
            )
            return renamedGroup
        } catch {
            try rollbackCreatedTabGroup(
                identifier: createdGroup.identifier,
                windowIdentifier: window.identifier
            )
            throw error
        }
    }

    private func resolveEffectiveProfileName(
        for window: SafariWindowRecord,
        tabGroups: [SafariTabGroupRecord]
    ) -> String {
        if !window.profileName.isEmpty {
            return window.profileName
        }

        if
            let selectedTabGroupIdentifier = window.selectedTabGroupIdentifier,
            let selectedTabGroup = tabGroups.first(where: { $0.identifier == selectedTabGroupIdentifier })
        {
            return selectedTabGroup.profileName
        }

        return ""
    }

    private func waitForCreatedTabGroup(
        profileName: String,
        knownIdentifiers: Set<Int>
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            let newGroups = try listTabGroups().filter { !knownIdentifiers.contains($0.identifier) }

            if let createdGroup = newGroups
                .filter({ profileName.isEmpty || $0.profileName == profileName })
                .max(by: { $0.identifier < $1.identifier })
            {
                return createdGroup
            }

            if attempt < Self.databaseMutationPollAttempts - 1 {
                sleep(Self.databaseMutationPollInterval)
            }
        }

        throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: profileName)
    }

    private func waitForRenamedTabGroup(
        identifier: Int,
        expectedName: String
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            if let renamedGroup = try listTabGroups().first(where: {
                $0.identifier == identifier && $0.name == expectedName
            }) {
                return renamedGroup
            }

            if attempt < Self.databaseMutationPollAttempts - 1 {
                sleep(Self.databaseMutationPollInterval)
            }
        }

        throw SafariTabGroupCommandError.tabGroupNotFound(identifier)
    }

    private func rollbackNewTabGroups(
        excluding knownIdentifiers: Set<Int>,
        windowIdentifier: Int
    ) throws {
        let newGroups = try listTabGroups().filter { !knownIdentifiers.contains($0.identifier) }
        for group in newGroups.sorted(by: { $0.identifier > $1.identifier }) {
            try rollbackCreatedTabGroup(identifier: group.identifier, windowIdentifier: windowIdentifier)
        }
    }

    private func rollbackCreatedTabGroup(identifier: Int, windowIdentifier: Int) throws {
        try focusWindow(windowIdentifier, executor)
        try deleteCurrentTabGroup(executor)
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
}

private struct SafariTabGroupMutationJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
