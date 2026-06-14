import AutomationFoundation
import SafariAppleScript

public struct SafariApplicationMenuBarListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "menu-bar-items",
        abstract: "List Safari application menu bar items.",
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
        let items = try SafariApplicationMenuBar.listItems(executor: executor)
        return items.map(SafariMenuItem.formatIndexAndTitle).joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariMenuItemsJSONOutput(items: SafariApplicationMenuBar.listItems(executor: executor)))
    }
}

private struct SafariMenuItemsJSONOutput: Encodable {
    let items: [SafariMenuItemRecord]
}
