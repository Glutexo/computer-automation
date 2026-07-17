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
    private let listProfiles: () throws -> [SafariProfileRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let createEmptyTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let renameTabGroup: (SafariTabGroupRecord, String, SafariAppleScriptExecuting) throws -> Void
    private let deleteCurrentTabGroup: (SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.listTabGroups = { try SafariTabGroup.list() }
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.createEmptyTabGroup = { _ in
            try SafariFileMenu.createEmptyTabGroup()
        }
        self.renameTabGroup = { group, newName, _ in
            try SafariSidebar.renameTabGroup(identifier: group.identifier, named: group.name, to: newName)
        }
        self.deleteCurrentTabGroup = { _ in try SafariFileMenu.deleteCurrentTabGroup() }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        listProfiles: @escaping () throws -> [SafariProfileRecord] = { [] },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        createEmptyTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.createEmptyTabGroup,
        renameTabGroup: @escaping (SafariTabGroupRecord, String, SafariAppleScriptExecuting) throws -> Void = { group, newName, _ in
            try SafariSidebar.renameTabGroup(identifier: group.identifier, named: group.name, to: newName)
        },
        deleteCurrentTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.deleteCurrentTabGroup,
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listWindows = listWindows
        self.listTabGroups = listTabGroups
        self.listProfiles = listProfiles
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

        let profiles = try listProfiles()
        let existingGroups = try SafariTabGroup.normalizeDefaultProfileNames(listTabGroups(), profiles: profiles)
        let effectiveProfileName = resolveEffectiveProfileName(for: window, tabGroups: existingGroups)
        let matchingProfileNames = SafariTabGroup.storedProfileNames(for: effectiveProfileName, profiles: profiles)

        let hasDuplicateNameInTargetProfile: Bool
        if effectiveProfileName.isEmpty {
            hasDuplicateNameInTargetProfile = existingGroups.contains { $0.name == name }
        } else {
            hasDuplicateNameInTargetProfile = existingGroups.contains {
                matchingProfileNames.contains($0.profileName) && $0.name == name
            }
        }

        guard !hasDuplicateNameInTargetProfile else {
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
                matchingProfileNames: matchingProfileNames,
                knownIdentifiers: knownIdentifiers,
                profiles: profiles
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
                try renameTabGroup(createdGroup, name, executor)
            }

            let renamedGroup = try waitForRenamedTabGroup(
                identifier: createdGroup.identifier,
                expectedName: name,
                profiles: profiles
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
        matchingProfileNames: Set<String>,
        knownIdentifiers: Set<Int>,
        profiles: [SafariProfileRecord]
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            let newGroups = try SafariTabGroup
                .normalizeDefaultProfileNames(listTabGroups(), profiles: profiles)
                .filter { !knownIdentifiers.contains($0.identifier) }

            if let createdGroup = newGroups
                .filter({ profileName.isEmpty || matchingProfileNames.contains($0.profileName) })
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
        expectedName: String,
        profiles: [SafariProfileRecord]
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<Self.databaseMutationPollAttempts {
            if let renamedGroup = try SafariTabGroup
                .normalizeDefaultProfileNames(listTabGroups(), profiles: profiles)
                .first(where: { $0.identifier == identifier && $0.name == expectedName })
            {
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
        do {
            try focusWindow(windowIdentifier, executor)
        } catch let focusError {
            do {
                try waitForDeletedTabGroup(identifier: identifier)
                return
            } catch {
                throw focusError
            }
        }

        do {
            try deleteCurrentTabGroup(executor)
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
}

private struct SafariTabGroupMutationJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
