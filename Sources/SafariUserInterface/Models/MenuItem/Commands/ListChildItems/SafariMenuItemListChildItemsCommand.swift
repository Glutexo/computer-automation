import AutomationFoundation
import SafariAppleScript

public struct SafariMenuItemListChildItemsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "menu-item-children",
        abstract: "List child menu items for a Safari menu item.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(
                name: "menu-bar-item-index",
                kind: .positional
            ),
            CommandArgumentDescriptor(
                name: "menu-item-index",
                kind: .positional
            )
        ]
    )

    private let executor: SafariAppleScriptExecuting

    public init() {
        self.executor = SafariAppleScriptExecutor()
    }

    init(executor: SafariAppleScriptExecuting) {
        self.executor = executor
    }

    public func execute(arguments: [String]) throws -> String {
        let address = try parseMenuItemAddress(arguments)
        let items = try SafariMenuItem.listChildItems(
            menuBarItemIndex: address.menuBarItemIndex,
            menuItemIndex: address.menuItemIndex,
            executor: executor
        )

        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let address = try parseMenuItemAddress(arguments)
        return try CommandJSONEncoder.encode(
            SafariMenuItemChildrenJSONOutput(
                menuBarItemIndex: address.menuBarItemIndex,
                menuItemIndex: address.menuItemIndex,
                items: SafariMenuItem.listChildItems(
                    menuBarItemIndex: address.menuBarItemIndex,
                    menuItemIndex: address.menuItemIndex,
                    executor: executor
                )
            )
        )
    }

    private func parseMenuItemAddress(_ arguments: [String]) throws -> SafariMenuItemAddress {
        guard arguments.count >= 2 else {
            throw SafariUserInterfaceError.missingMenuItemAddress
        }

        guard let menuBarItemIndex = Int(arguments[0]), let menuItemIndex = Int(arguments[1]) else {
            throw SafariUserInterfaceError.invalidMenuItemAddress(arguments[0], arguments[1])
        }

        return SafariMenuItemAddress(menuBarItemIndex: menuBarItemIndex, menuItemIndex: menuItemIndex)
    }
}

private struct SafariMenuItemAddress {
    let menuBarItemIndex: Int
    let menuItemIndex: Int
}

private struct SafariMenuItemChildrenJSONOutput: Encodable {
    let menuBarItemIndex: Int
    let menuItemIndex: Int
    let items: [SafariMenuItemRecord]
}
