import AutomationFoundation
import SafariAppleScript

public enum SafariApplicationMenuBar: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "application-menu-bar",
        abstract: "The Safari application menu bar.",
        commands: [
            SafariApplicationMenuBarListCommand.descriptor
        ]
    )

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
        try SafariAppleScriptApplicationMenuBar.listItems(executor: executor).map(SafariMenuItemRecord.init)
    }
}
