import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabGroupCreateCommand: CommandModel, JSONCommandModel {
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
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindows = { try SafariWindow.list() }
        self.listTabGroups = { try SafariTabGroup.list() }
        self.focusWindow = SafariAppleScriptWindow.focus
        self.createEmptyTabGroup = { _ in
            try SafariFileMenu.createEmptyTabGroup()
        }
        self.renameTabGroup = { currentName, newName, _ in
            try SafariSidebar.renameTabGroup(named: currentName, to: newName)
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        listTabGroups: @escaping () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus,
        createEmptyTabGroup: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.createEmptyTabGroup,
        renameTabGroup: @escaping (String, String, SafariAppleScriptExecuting) throws -> Void = { currentName, newName, _ in
            try SafariSidebar.renameTabGroup(named: currentName, to: newName)
        },
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listWindows = listWindows
        self.listTabGroups = listTabGroups
        self.focusWindow = focusWindow
        self.createEmptyTabGroup = createEmptyTabGroup
        self.renameTabGroup = renameTabGroup
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

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SafariTabGroupCommandError.emptyTabGroupName
        }

        let windows = try listWindows()
        guard let window = windows.first(where: { $0.index == windowIndex }) else {
            throw SafariTabGroupCommandError.invalidWindowIndex(rawWindowIndex)
        }

        guard !window.isPrivate else {
            throw SafariTabGroupCommandError.privateWindowTabGroupMutationUnsupported(windowIndex)
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

        try focusWindow(windowIndex, executor)
        try createEmptyTabGroup(executor)

        let createdGroup = try waitForCreatedTabGroup(
            profileName: effectiveProfileName,
            knownIdentifiers: knownIdentifiers
        )

        if createdGroup.name != name {
            sleep(0.1)
            try renameTabGroup(createdGroup.name, name, executor)
        }

        let renamedGroup = try waitForRenamedTabGroup(
            identifier: createdGroup.identifier,
            expectedName: name
        )
        return renamedGroup
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
        for attempt in 0..<10 {
            let newGroups = try listTabGroups().filter { !knownIdentifiers.contains($0.identifier) }

            if let createdGroup = newGroups
                .filter({ profileName.isEmpty || $0.profileName == profileName })
                .max(by: { $0.identifier < $1.identifier })
            {
                return createdGroup
            }

            if let createdGroup = newGroups.max(by: { $0.identifier < $1.identifier }), profileName.isEmpty {
                return createdGroup
            }

            if attempt < 9 {
                sleep(0.1)
            }
        }

        throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: profileName)
    }

    private func waitForRenamedTabGroup(
        identifier: Int,
        expectedName: String
    ) throws -> SafariTabGroupRecord {
        for attempt in 0..<10 {
            if let renamedGroup = try listTabGroups().first(where: {
                $0.identifier == identifier && $0.name == expectedName
            }) {
                return renamedGroup
            }

            if attempt < 9 {
                sleep(0.1)
            }
        }

        throw SafariTabGroupCommandError.tabGroupNotFound(identifier)
    }
}

private struct SafariTabGroupMutationJSONOutput: Encodable {
    let tabGroup: SafariTabGroupRecord
}
