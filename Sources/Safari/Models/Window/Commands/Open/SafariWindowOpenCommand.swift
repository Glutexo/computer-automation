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

    public init() {
        self.executor = SafariAppleScriptExecutor()
    }

    init(executor: SafariAppleScriptExecuting) {
        self.executor = executor
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        if let requestedProfile = arguments.first, !requestedProfile.isEmpty {
            return try openWindow(forProfileNamed: requestedProfile)
        }
        try SafariFileMenu.openWindow(profileName: nil, executor: executor)
        return "Safari window opened."
    }

    private func openWindow(forProfileNamed profileName: String) throws -> String {
        let profiles = try SafariProfile.listAvailableProfiles()
        guard profiles.contains(where: { $0.name == profileName }) else {
            throw SafariWindowCommandError.profileNotFound(profileName)
        }

        do {
            try SafariFileMenu.openWindow(profileName: profileName, executor: executor)
        } catch {
            throw SafariWindowCommandError.profileMenuItemNotFound(profileName)
        }

        return "Safari window opened for profile \(profileName)."
    }
}
