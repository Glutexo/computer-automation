import AutomationFoundation
import SafariAppleScript

public struct SafariFileMenuListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "file-menu-items",
        abstract: "List Safari File menu items.",
        operation: .read
    )

    private let listItems: () throws -> [SafariMenuItemRecord]

    public init() {
        self.listItems = SafariFileMenu.listItems
    }

    init(executor: SafariAppleScriptExecuting) {
        self.listItems = { try SafariFileMenu.listItems(executor: executor) }
    }

    public func execute(arguments: [String]) throws -> String {
        let items = try listItems()
        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(SafariFileMenuItemsJSONOutput(items: listItems()))
    }
}

private struct SafariFileMenuItemsJSONOutput: Encodable {
    let items: [SafariMenuItemRecord]
}
