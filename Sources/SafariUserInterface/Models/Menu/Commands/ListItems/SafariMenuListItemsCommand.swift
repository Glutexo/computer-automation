import AutomationFoundation
import SafariAppleScript

public struct SafariMenuListItemsCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "menu-items",
        abstract: "List items for a Safari application menu.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(
                name: "menu-bar-item-index",
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
        guard let firstArgument = arguments.first else {
            throw SafariUserInterfaceError.missingMenuAddress
        }

        guard let menuBarItemIndex = Int(firstArgument) else {
            throw SafariUserInterfaceError.invalidMenuAddress(firstArgument)
        }

        let items = try SafariMenu.listItems(
            menuBarItemIndex: menuBarItemIndex,
            executor: executor
        )

        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }
}
