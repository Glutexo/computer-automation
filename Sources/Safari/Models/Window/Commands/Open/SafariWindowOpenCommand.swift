import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenCommand: CommandModel, JSONCommandModel {
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

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.listWindows = SafariAppleScriptWindow.list
    }

    init(
        executor: SafariAppleScriptExecuting,
        listProfiles: @escaping () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() },
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord] = SafariAppleScriptWindow.list
    ) {
        self.executor = executor
        self.listProfiles = listProfiles
        self.openWindow = openWindow
        self.listWindows = listWindows
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
        do {
            let profiles = try listProfiles()
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
        let windowIdentifier = try resolveNewWindowIdentifier(excluding: knownWindowIdentifiers)

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

    private func resolveNewWindowIdentifier(excluding knownWindowIdentifiers: Set<Int>) throws -> Int {
        for attempt in 0..<10 {
            let windows = try listWindows(executor)
            if let window = windows.first(where: { !knownWindowIdentifiers.contains($0.identifier) }) {
                return window.identifier
            }

            if attempt < 9 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        throw SafariWindowCommandError.openedWindowIdentifierNotFound
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
