import AutomationFoundation

public enum SafariAppleScriptApplicationMenuBar: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "application-menu-bar",
        abstract: "AppleScript access to the Safari application menu bar.",
        commands: []
    )

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptMenuItemRecord] {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                set outputItems to {}
                repeat with itemIndex from 1 to count of menu bar items of menu bar 1
                    set currentItem to menu bar item itemIndex of menu bar 1
                    set currentName to name of currentItem
                    if currentName is missing value then set currentName to ""
                    copy {(itemIndex as text), currentName} to end of outputItems
                end repeat
                return outputItems
            end tell
        end tell
        """

        let result = try executor.execute(script: script)
        return SafariAppleScriptMenuItem.parseRecordsWithIndexAndTitle(from: result)
    }
}
