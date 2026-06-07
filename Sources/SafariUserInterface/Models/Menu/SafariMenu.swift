import AutomationFoundation
import SafariAppleScript

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
        do {
            return try SafariAppleScriptMenu.listItems(
                menuBarItemIndex: menuBarItemIndex,
                executor: executor
            ).map(SafariMenuItemRecord.init)
        } catch {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }
    }
}
