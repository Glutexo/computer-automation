import AutomationFoundation
import SafariAppleScript

public struct SafariTabListCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "tabs",
        abstract: "List Safari browser tabs across all open windows.",
        operation: .read,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let listTabs: (SafariAppleScriptExecuting) throws -> [SafariTabRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabs = { executor in try SafariTab.list(executor: executor) }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listTabs: @escaping (SafariAppleScriptExecuting) throws -> [SafariTabRecord] = { executor in
            try SafariTab.list(executor: executor)
        }
    ) {
        self.executor = executor
        self.listTabs = listTabs
    }

    public func execute(arguments: [String] = []) throws -> String {
        let tabs = try listTabs(executor)
        return tabs
            .map { "\($0.windowIndex)|\($0.index)|\($0.url)" }
            .joined(separator: "\n")
    }
}
