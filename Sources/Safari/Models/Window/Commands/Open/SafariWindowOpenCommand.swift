import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenCommand: CommandModel, JSONCommandModel {
    private static let unprofiledWindowIdentifierPollAttempts = 10
    private static let unprofiledWindowIdentifierPollInterval: TimeInterval = 0.1
    private static let profiledWindowIdentifierPollAttempts = SafariProfileWindowOpening.windowPollAttempts
    private static let profiledWindowIdentifierPollInterval = SafariProfileWindowOpening.windowPollInterval

    public static let descriptor = CommandDescriptor(
        name: "open-window",
        abstract: "Open a new Safari browser window.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(
                name: "profile",
                kind: .positional,
                isRequired: false
            )
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listProfiles: () throws -> [SafariProfileRecord]
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord]
    private let listResolvedWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openNewDocument: (SafariAppleScriptExecuting) throws -> Void
    private let openProfileWindowShortcut: (String, [String], SafariAppleScriptExecuting) throws -> Void
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.listWindows = SafariAppleScriptWindow.list
        self.listResolvedWindows = { try SafariWindow.list() }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openNewDocument = SafariAppleScriptWindow.openNewDocument
        self.openProfileWindowShortcut = SafariFileMenu.openProfileWindowShortcut
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        listProfiles: @escaping () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() },
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord] = SafariAppleScriptWindow.list,
        listResolvedWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openNewDocument: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.openNewDocument,
        openProfileWindowShortcut: @escaping (String, [String], SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openProfileWindowShortcut,
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.listProfiles = listProfiles
        self.openWindow = openWindow
        self.listWindows = listWindows
        self.listResolvedWindows = listResolvedWindows
        self.focusWindow = focusWindow
        self.openNewDocument = openNewDocument
        self.openProfileWindowShortcut = openProfileWindowShortcut
        self.closeWindow = closeWindow
        self.sleep = sleep
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let result = try openWindowResult(arguments: arguments)
        return formatSuccessMessage(result.message, windowIdentifier: result.windowIdentifier)
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        let result = try openWindowResult(arguments: arguments)
        return try CommandJSONEncoder.encode(
            SafariWindowOpenJSONOutput(
                message: result.message,
                windowId: result.windowIdentifier,
                profileName: result.profileName
            )
        )
    }

    private func openWindowResult(arguments: [String]) throws -> SafariWindowOpenResult {
        if let requestedProfile = arguments.first, !requestedProfile.isEmpty {
            return try openWindow(forProfileNamed: requestedProfile)
        }
        let windowIdentifier = try openWindowAndResolveIdentifier(profileName: nil)
        return SafariWindowOpenResult(message: "Safari window opened.", windowIdentifier: windowIdentifier, profileName: nil)
    }

    private func openWindow(forProfileNamed profileName: String) throws -> SafariWindowOpenResult {
        var profileNames: [String] = []
        do {
            let profiles = try listProfiles()
            profileNames = profiles.map(\.name)
            guard profiles.contains(where: { $0.name == profileName }) else {
                throw SafariWindowCommandError.profileNotFound(profileName)
            }
        } catch SafariProfileCommandError.databaseOpenFailed {
            // Opening by profile ultimately targets Safari's File menu; do not make
            // that UI path unusable only because Safari's private DB is protected.
        }

        let knownWindowIdentifiers = try currentWindowIdentifiers()
        do {
            try openWindow(profileName, executor)
        } catch {
            throw SafariWindowCommandError.profileMenuItemNotFound(profileName)
        }
        let windowIdentifier: Int
        do {
            windowIdentifier = try resolveNewWindowIdentifier(
                excluding: knownWindowIdentifiers,
                requestedProfileName: profileName
            )
        } catch SafariWindowCommandError.openedWindowIdentifierNotFound {
            do {
                windowIdentifier = try openNewDocumentFromExistingProfileWindow(
                    excluding: knownWindowIdentifiers,
                    requestedProfileName: profileName
                )
            } catch {
                do {
                    windowIdentifier = try openNewWindowWithProfileShortcut(
                        excluding: knownWindowIdentifiers,
                        requestedProfileName: profileName,
                        profileNames: profileNames
                    )
                } catch {
                    try rollbackNewWindows(excluding: knownWindowIdentifiers)
                    throw error
                }
            }
        } catch {
            try rollbackNewWindows(excluding: knownWindowIdentifiers)
            throw error
        }

        return SafariWindowOpenResult(
            message: "Safari window opened for profile \(profileName).",
            windowIdentifier: windowIdentifier,
            profileName: profileName
        )
    }

    private func openWindowAndResolveIdentifier(profileName: String?) throws -> Int {
        let knownWindowIdentifiers = try currentWindowIdentifiers()
        try openWindow(profileName, executor)
        return try resolveNewWindowIdentifier(excluding: knownWindowIdentifiers)
    }

    private func currentWindowIdentifiers() throws -> Set<Int> {
        Set(try listWindows(executor).map(\.identifier))
    }

    private func resolveNewWindowIdentifier(
        excluding knownWindowIdentifiers: Set<Int>,
        requestedProfileName: String? = nil
    ) throws -> Int {
        var lastObservedMismatchedWindowName: String?
        let pollAttempts = requestedProfileName == nil
            ? Self.unprofiledWindowIdentifierPollAttempts
            : Self.profiledWindowIdentifierPollAttempts
        let pollInterval = requestedProfileName == nil
            ? Self.unprofiledWindowIdentifierPollInterval
            : Self.profiledWindowIdentifierPollInterval

        for attempt in 0..<pollAttempts {
            let windows = try listWindows(executor)
            let newWindows = windows.filter { !knownWindowIdentifiers.contains($0.identifier) }

            if requestedProfileName == nil, let window = newWindows.first {
                return window.identifier
            }

            if
                let requestedProfileName,
                let window = try matchingProfileWindow(
                    in: newWindows,
                    requestedProfileName: requestedProfileName
                )
            {
                return window.identifier
            }

            if let window = newWindows.first {
                lastObservedMismatchedWindowName = window.name
            }

            if attempt < pollAttempts - 1 {
                sleep(pollInterval)
            }
        }

        if let requestedProfileName, let lastObservedMismatchedWindowName {
            throw SafariWindowCommandError.openedWindowProfileMismatch(
                requestedProfileName: requestedProfileName,
                observedWindowName: lastObservedMismatchedWindowName
            )
        }

        throw SafariWindowCommandError.openedWindowIdentifierNotFound
    }

    private func openNewDocumentFromExistingProfileWindow(
        excluding knownWindowIdentifiers: Set<Int>,
        requestedProfileName: String
    ) throws -> Int {
        guard let window = try SafariProfileWindowOpening.openNewDocumentFromExistingProfileWindow(
            profileName: requestedProfileName,
            excluding: knownWindowIdentifiers,
            executor: executor,
            listWindows: listResolvedWindows,
            focusWindow: focusWindow,
            openNewDocument: openNewDocument,
            sleep: sleep
        ) else {
            throw SafariWindowCommandError.openedWindowIdentifierNotFound
        }

        return window.identifier
    }

    private func openNewWindowWithProfileShortcut(
        excluding knownWindowIdentifiers: Set<Int>,
        requestedProfileName: String,
        profileNames: [String]
    ) throws -> Int {
        try openProfileWindowShortcut(requestedProfileName, profileNames, executor)
        return try resolveNewWindowIdentifier(
            excluding: knownWindowIdentifiers,
            requestedProfileName: requestedProfileName
        )
    }

    private func matchingProfileWindow(
        in newWindows: [SafariAppleScriptWindowRecord],
        requestedProfileName: String
    ) throws -> SafariAppleScriptWindowRecord? {
        guard !newWindows.isEmpty else {
            return nil
        }

        if let titleMatchedWindow = newWindows.first(where: {
            windowTitle($0.name, matchesProfileNamed: requestedProfileName)
        }) {
            return titleMatchedWindow
        }

        let newWindowIdentifiers = Set(newWindows.map(\.identifier))
        if let resolvedWindow = try listResolvedWindows().first(where: {
            newWindowIdentifiers.contains($0.identifier) && $0.profileName == requestedProfileName
        }) {
            return newWindows.first { $0.identifier == resolvedWindow.identifier }
        }

        return nil
    }

    private func rollbackNewWindows(excluding knownWindowIdentifiers: Set<Int>) throws {
        let newWindows = try listWindows(executor).filter {
            !knownWindowIdentifiers.contains($0.identifier)
        }

        for window in newWindows {
            try closeWindow(window.identifier, executor)
        }
    }

    private func windowTitle(_ title: String, matchesProfileNamed profileName: String) -> Bool {
        title == profileName || title.hasPrefix("\(profileName) —") || title.hasPrefix("\(profileName) -")
    }

    private func formatSuccessMessage(_ message: String, windowIdentifier: Int) -> String {
        "\(message)\nwindow-id|\(windowIdentifier)"
    }
}

private struct SafariWindowOpenResult {
    let message: String
    let windowIdentifier: Int
    let profileName: String?
}

private struct SafariWindowOpenJSONOutput: Encodable {
    let message: String
    let windowId: Int
    let profileName: String?
}
