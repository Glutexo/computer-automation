import AppKit
import AutomationFoundation
import SafariAppleScript

public enum SafariToolbarItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "toolbar-item",
        abstract: "A Safari front-window toolbar item.",
        commands: []
    )

    public static func listChildItems(
        toolbarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
        do {
            return try SafariAppleScriptToolbarItem.listChildItems(
                toolbarItemIndex: toolbarItemIndex,
                executor: executor
            ).map(SafariMenuItemRecord.init)
        } catch {
            throw SafariUserInterfaceError.toolbarItemChildrenUnavailable(toolbarItemIndex: toolbarItemIndex)
        }
    }

    public static func clickChildItem(
        toolbarItemIndex: Int,
        childItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        try SafariAppleScriptToolbarItem.clickChildItem(
            toolbarItemIndex: toolbarItemIndex,
            childItemIndex: childItemIndex,
            executor: executor
        )
    }
}
