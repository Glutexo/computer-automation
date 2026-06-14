import AutomationFoundation

public enum SafariAppleScriptToolbarItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "toolbar-item",
        abstract: "AppleScript access to a Safari toolbar item.",
        commands: []
    )

    public static func listChildItems(
        toolbarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptMenuItemRecord] {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                if (count of windows) is 0 then
                    return {}
                end if
                set toolbarItem to UI element \(toolbarItemIndex) of toolbar 1 of front window
                perform action "AXShowMenu" of toolbarItem
                delay 0.1
                tell UI element 1 of toolbarItem
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
                    key code 53
                    return outputItems
                end tell
            end tell
        end tell
        """

        let result = try executor.execute(script: script)
        return SafariAppleScriptMenuItem.parseRecordsWithKeyboardShortcut(from: result)
    }

    public static func clickChildItem(
        toolbarItemIndex: Int,
        childItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                if (count of windows) is 0 then
                    error "Safari has no open windows."
                end if
                set toolbarItem to UI element \(toolbarItemIndex) of toolbar 1 of front window
                perform action "AXShowMenu" of toolbarItem
                delay 0.1
                tell UI element 1 of toolbarItem
                    click menu item \(childItemIndex)
                end tell
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }
}
