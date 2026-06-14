import AutomationFoundation
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

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listProfiles: @escaping () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() },
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow
    ) {
        self.executor = executor
        self.listProfiles = listProfiles
        self.openWindow = openWindow
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        if let requestedProfile = arguments.first, !requestedProfile.isEmpty {
            return try openWindow(forProfileNamed: requestedProfile)
        }
        try openWindow(nil, executor)
        return "Safari window opened."
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

        do {
            try openWindow(profileName, executor)
        } catch {
            throw SafariWindowCommandError.profileMenuItemNotFound(profileName)
        }

        return "Safari window opened for profile \(profileName)."
    }
}
