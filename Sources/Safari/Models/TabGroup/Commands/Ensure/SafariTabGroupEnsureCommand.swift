import AutomationFoundation
import Foundation
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
    private let listProfiles: () throws -> [SafariProfileRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openNewDocument: (SafariAppleScriptExecuting) throws -> Void
    private let openProfileWindowShortcut: (String, [String], SafariAppleScriptExecuting) throws -> Void
    private let createTabGroup: (Int, String) throws -> SafariTabGroupRecord
    private let deleteTabGroup: (Int) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.findTabGroups = { profileName, name in
            try SafariTabGroup.find(profileName: profileName, name: name)
        }
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
        self.listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.openNewDocument = SafariAppleScriptWindow.openNewDocument
        self.openProfileWindowShortcut = SafariFileMenu.openProfileWindowShortcut
        self.createTabGroup = { windowIdentifier, name in
            try SafariTabGroupCreateCommand().createTabGroup(windowIdentifier: windowIdentifier, name: name)
        }
        self.deleteTabGroup = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        findTabGroups: @escaping (String, String) throws -> [SafariTabGroupRecord] = { profileName, name in
            try SafariTabGroup.find(profileName: profileName, name: name)
        },
        listProfiles: @escaping () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() },
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        openNewDocument: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.openNewDocument,
        openProfileWindowShortcut: @escaping (String, [String], SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openProfileWindowShortcut,
        createTabGroup: @escaping (Int, String) throws -> SafariTabGroupRecord = { windowIdentifier, name in
            try SafariTabGroupCreateCommand().createTabGroup(windowIdentifier: windowIdentifier, name: name)
        },
        deleteTabGroup: @escaping (Int) throws -> Void = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        },
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.findTabGroups = findTabGroups
        self.listProfiles = listProfiles
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.closeWindow = closeWindow
        self.openNewDocument = openNewDocument
        self.openProfileWindowShortcut = openProfileWindowShortcut
        self.createTabGroup = createTabGroup
        self.deleteTabGroup = deleteTabGroup
        self.sleep = sleep
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
        try ensureOperation(profileName: profileName, name: name).summary
    }

    func ensureOperation(profileName: String, name: String) throws -> SafariTabGroupEnsureOperationResult {
        let profiles = try listProfiles()
        let profileNames = profiles.map(\.name)
        let matchingProfileNames = SafariTabGroup.storedProfileNames(for: profileName, profiles: profiles)
        let matches = try findTabGroups(profileName, name)

        if let match = matches.first {
            guard matches.count == 1 else {
                throw SafariTabGroupCommandError.tabGroupLookupAmbiguous(
                    profileName: profileName,
                    tabGroupName: name,
                    count: matches.count
                )
            }

            return SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .reused,
                    tabGroup: normalizeDefaultProfileName(
                        match,
                        requestedProfileName: profileName,
                        matchingProfileNames: matchingProfileNames
                    )
                )
            )
        }

        let window = try SafariTabGroupSidebarAccess.openNewWindowForProfile(
            profileName: profileName,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow,
            closeWindow: closeWindow,
            openNewDocument: openNewDocument,
            openProfileWindowShortcut: openProfileWindowShortcut,
            profileNames: profileNames,
            sleep: sleep
        )
        let createdGroup: SafariTabGroupRecord
        do {
            createdGroup = try createTabGroup(window.identifier, name)
        } catch {
            try closeWindow(window.identifier, executor)
            throw error
        }
        if !matchingProfileNames.contains(createdGroup.profileName) {
            try rollbackMismatchedCreatedTabGroup(createdGroup, windowIdentifier: window.identifier)
            throw SafariTabGroupCommandError.createdTabGroupProfileMismatch(
                requestedProfileName: profileName,
                createdProfileName: createdGroup.profileName
            )
        }
        return SafariTabGroupEnsureOperationResult(
            summary: SafariTabGroupEnsureSummary(
                status: .created,
                tabGroup: normalizeDefaultProfileName(
                    createdGroup,
                    requestedProfileName: profileName,
                    matchingProfileNames: matchingProfileNames
                )
            ),
            createdWindow: window
        )
    }

    private func normalizeDefaultProfileName(
        _ group: SafariTabGroupRecord,
        requestedProfileName: String,
        matchingProfileNames: Set<String>
    ) -> SafariTabGroupRecord {
        guard group.profileName.isEmpty, matchingProfileNames.contains("") else {
            return group
        }

        return SafariTabGroupRecord(
            identifier: group.identifier,
            profileName: requestedProfileName,
            name: group.name
        )
    }

    private func rollbackMismatchedCreatedTabGroup(
        _ group: SafariTabGroupRecord,
        windowIdentifier: Int
    ) throws {
        var cleanupError: Error?

        do {
            try deleteTabGroup(group.identifier)
        } catch {
            cleanupError = error
        }

        do {
            try closeWindow(windowIdentifier, executor)
        } catch {
            if cleanupError == nil {
                cleanupError = error
            }
        }

        if let cleanupError {
            throw cleanupError
        }
    }
}

struct SafariTabGroupEnsureOperationResult {
    let summary: SafariTabGroupEnsureSummary
    let createdWindow: SafariWindowRecord?

    init(summary: SafariTabGroupEnsureSummary, createdWindow: SafariWindowRecord? = nil) {
        self.summary = summary
        self.createdWindow = createdWindow
    }
}
