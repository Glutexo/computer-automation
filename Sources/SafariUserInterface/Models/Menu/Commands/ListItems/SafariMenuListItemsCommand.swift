import AutomationFoundation
import SafariAppleScript

public struct SafariMenuListItemsCommand: CommandModel, JSONCommandModel {
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
        let menuBarItemIndex = try parseMenuBarItemIndex(arguments)
        let items = try SafariMenu.listItems(
            menuBarItemIndex: menuBarItemIndex,
            executor: executor
        )

        return items.map(SafariMenuItem.format).joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let menuBarItemIndex = try parseMenuBarItemIndex(arguments)
        return try CommandJSONEncoder.encode(
            SafariMenuItemsJSONOutput(
                menuBarItemIndex: menuBarItemIndex,
                items: SafariMenu.listItems(menuBarItemIndex: menuBarItemIndex, executor: executor)
            )
        )
    }

    private func parseMenuBarItemIndex(_ arguments: [String]) throws -> Int {
        guard let firstArgument = arguments.first else {
            throw SafariUserInterfaceError.missingMenuAddress
        }

        guard let menuBarItemIndex = Int(firstArgument) else {
            throw SafariUserInterfaceError.invalidMenuAddress(firstArgument)
        }

        return menuBarItemIndex
    }
}

private struct SafariMenuItemsJSONOutput: Encodable {
    let menuBarItemIndex: Int
    let items: [SafariMenuItemRecord]
}
