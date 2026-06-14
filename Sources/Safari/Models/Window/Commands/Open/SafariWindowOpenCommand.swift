import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenCommand: CommandModel {
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
        if let requestedProfile = arguments.first, !requestedProfile.isEmpty {
            return try openWindow(forProfileNamed: requestedProfile)
        }
        let windowIdentifier = try openWindowAndResolveIdentifier(profileName: nil)
        return formatSuccessMessage("Safari window opened.", windowIdentifier: windowIdentifier)
    }

    private func openWindow(forProfileNamed profileName: String) throws -> String {
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

        return formatSuccessMessage("Safari window opened for profile \(profileName).", windowIdentifier: windowIdentifier)
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
