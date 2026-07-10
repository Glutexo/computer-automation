import AutomationFoundation

public enum SafariAppleScriptMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu",
        abstract: "AppleScript access to a Safari menu.",
        commands: []
    )

    public static func listItems(
        menuBarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptMenuItemRecord] {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu bar item \(menuBarItemIndex) of menu bar 1
                    set outputItems to {}
                    repeat with itemIndex from 1 to count of menu items
                        set currentItem to menu item itemIndex
                        set currentName to name of currentItem
                        if currentName is missing value then set currentName to ""
                        set currentChar to value of attribute "AXMenuItemCmdChar" of currentItem
                        if currentChar is missing value then set currentChar to ""
                        set currentModifiers to value of attribute "AXMenuItemCmdModifiers" of currentItem
                        if currentModifiers is missing value then set currentModifiers to ""
                        copy {(itemIndex as text), currentName, (currentChar as text), (currentModifiers as text)} to end of outputItems
                    end repeat
                    return outputItems
                end tell
            end tell
        end tell
        """

        let result = try executor.execute(script: script)
        return SafariAppleScriptMenuItem.parseRecordsWithKeyboardShortcut(from: result)
    }

    public static func clickItem(
        menuBarItemIndex: Int,
        menuItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu bar item \(menuBarItemIndex) of menu bar 1
                    click menu item \(menuItemIndex)
                end tell
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func pressKeyboardShortcut(
        key: String,
        modifiers: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            keystroke "\(key)" using {\(modifiers)}
        end tell
        """

        _ = try executor.execute(script: script)
    }
}
