import AutomationFoundation
import SafariAppleScript

public enum SafariTabList: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab-list",
        abstract: "Ordered Safari tab lists for windows and saved tab groups.",
        commands: [
            SafariTabListTabGroupTabsCommand.descriptor,
            SafariTabListWindowTabsCommand.descriptor
        ]
    )

    static func listWindowTabs(
        windowIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariWindowTabRecord] {
        try SafariTab.listWindowTabs(windowIndex: windowIndex, executor: executor)
    }

    static func listTabGroupTabs(
        tabGroupIdentifier: Int
    ) throws -> [SafariTabGroupTabRecord] {
        try SafariTabGroup.listTabs(tabGroupIdentifier: tabGroupIdentifier)
    }
}
