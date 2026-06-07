import AutomationFoundation

public enum SafariMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu",
        abstract: "A Safari application menu.",
        commands: [
            SafariMenuListItemsCommand.descriptor
        ]
    )

    public static func listItems(
        menuBarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
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

        do {
            let result = try executor.execute(script: script)
            return SafariMenuItem.parseRecordsWithKeyboardShortcut(from: result)
        } catch {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }
    }
}
