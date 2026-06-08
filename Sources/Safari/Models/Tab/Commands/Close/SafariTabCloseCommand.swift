import AutomationFoundation
import SafariAppleScript

public struct SafariTabCloseCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "close-tab",
        abstract: "Close a Safari tab.",
        operation: .delete,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let closeTab: (Int, Int, SafariAppleScriptExecuting) throws -> String

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.closeTab = SafariAppleScriptTab.close
    }

    init(
        executor: SafariAppleScriptExecuting,
        closeTab: @escaping (Int, Int, SafariAppleScriptExecuting) throws -> String = SafariAppleScriptTab.close
    ) {
        self.executor = executor
        self.closeTab = closeTab
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard arguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let rawTabIndex = arguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIndex, rawTabIndex)
        }

        return try closeTab(windowIndex, tabIndex, executor)
    }
}
