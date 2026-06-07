import AutomationFoundation

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

        let script = """
        tell application "Safari"
            activate
            make new document
        end tell
        """

        _ = try executor.execute(script: script)
        return "Safari window opened."
    }

    private func openWindow(forProfileNamed profileName: String) throws -> String {
        let profiles = try SafariProfile.listAvailableProfiles()
        guard profiles.contains(where: { $0.name == profileName }) else {
            throw SafariWindowCommandError.profileNotFound(profileName)
        }

        let escapedProfileName = profileName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu bar item 3 of menu bar 1
                    set targetItemName to missing value
                    repeat with currentItem in every menu item
                        set currentName to name of currentItem
                        if currentName ends with "\(escapedProfileName)" then
                            set targetItemName to currentName
                            exit repeat
                        end if
                    end repeat
                    if targetItemName is missing value then error "Profile menu item not found"
                    click menu item targetItemName
                end tell
            end tell
        end tell
        """

        do {
            _ = try executor.execute(script: script)
        } catch {
            throw SafariWindowCommandError.profileMenuItemNotFound(profileName)
        }

        return "Safari window opened for profile \(profileName)."
    }
}
