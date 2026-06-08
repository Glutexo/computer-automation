import AutomationFoundation
import SafariAppleScript

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
        try SafariAppleScriptWindow.openNewDocument(executor: executor)
    }

    public static func openPrivateWindow(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let menuItems = try listItems(executor: executor)

        guard let menuItem = menuItems.first(where: {
            $0.commandCharacter == "N" && $0.commandModifiers == "1"
        }) else {
            throw SafariUserInterfaceError.privateWindowMenuItemNotFound
        }

        try SafariAppleScriptMenu.clickItem(
            menuBarItemIndex: menuBarItemIndex,
            menuItemIndex: menuItem.index,
            executor: executor
        )
    }

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
        try SafariMenu.listItems(
            menuBarItemIndex: menuBarItemIndex,
            executor: executor
        )
    }

    private static func clickNewWindowMenuItem(
        forProfileNamed profileName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let menuItems = try listItems(executor: executor)

        guard let menuItem = menuItems.first(where: { $0.title.hasSuffix(profileName) }) else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }
        try SafariAppleScriptMenu.clickItem(
            menuBarItemIndex: menuBarItemIndex,
            menuItemIndex: menuItem.index,
            executor: executor
        )
    }
}
