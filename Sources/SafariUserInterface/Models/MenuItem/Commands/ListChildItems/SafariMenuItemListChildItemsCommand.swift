import AutomationFoundation

public struct SafariMenuItemListChildItemsCommand: CommandModel {
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
        guard arguments.count >= 2 else {
            throw SafariUserInterfaceError.missingMenuItemAddress
        }

        guard let menuBarItemIndex = Int(arguments[0]), let menuItemIndex = Int(arguments[1]) else {
            throw SafariUserInterfaceError.invalidMenuItemAddress(arguments[0], arguments[1])
        }

        let items = try SafariMenuItem.listChildItems(
            menuBarItemIndex: menuBarItemIndex,
            menuItemIndex: menuItemIndex,
            executor: executor
        )

        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }
}
