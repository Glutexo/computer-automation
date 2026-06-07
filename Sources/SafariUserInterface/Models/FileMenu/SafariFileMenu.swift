import AutomationFoundation

public enum SafariFileMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "file-menu",
        abstract: "The Safari File menu.",
        commands: [
            SafariFileMenuListCommand.descriptor
        ]
    )

    static let menuBarItemIndex = 3

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

    public static func listItems(
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

        let result = try executor.execute(script: script)
        return SafariMenuItem.parseRecordsWithKeyboardShortcut(from: result)
    }

    private static func clickNewWindowMenuItem(
        forProfileNamed profileName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let menuItems = try listItems(executor: executor)

        guard let menuItem = menuItems.first(where: { $0.title.hasSuffix(profileName) }) else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }

        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu bar item \(menuBarItemIndex) of menu bar 1
                    click menu item \(menuItem.index)
                end tell
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }
}
