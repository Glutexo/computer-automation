import AutomationFoundation

public enum SafariFileMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "file-menu",
        abstract: "The Safari File menu.",
        commands: []
    )

    public static func openWindow(
        profileName: String?,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        if let profileName, !profileName.isEmpty {
            try clickNewWindowMenuItem(forProfileNamed: profileName, executor: executor)
            return
        }

        let script = """
        tell application "Safari"
            activate
            make new document
        end tell
        """

        _ = try executor.execute(script: script)
    }

    private static func clickNewWindowMenuItem(
        forProfileNamed profileName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
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

        _ = try executor.execute(script: script)
    }
}
