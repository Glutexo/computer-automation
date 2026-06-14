import AutomationFoundation
import SafariAppleScript

public struct SafariFileMenuListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "file-menu-items",
        abstract: "List Safari File menu items.",
        operation: .read
    )

    private let executor: SafariAppleScriptExecuting

    public init() {
        self.executor = SafariAppleScriptExecutor()
    }

    init(executor: SafariAppleScriptExecuting) {
        self.executor = executor
    }

    public func execute(arguments: [String]) throws -> String {
        let items = try SafariFileMenu.listItems(executor: executor)
        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariFileMenuItemsJSONOutput(items: SafariFileMenu.listItems(executor: executor)))
    }
}

private struct SafariFileMenuItemsJSONOutput: Encodable {
    let items: [SafariMenuItemRecord]
}
