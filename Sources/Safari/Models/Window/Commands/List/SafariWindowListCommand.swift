import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowListCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "windows",
        abstract: "List open Safari browser windows.",
        operation: .read,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindows = { executor in try SafariWindow.list(executor: executor) }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { executor in
            try SafariWindow.list(executor: executor)
        }
    ) {
        self.executor = executor
        self.listWindows = listWindows
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let windows = try listWindows(executor)
        return windows
            .map { "\($0.index)|\($0.isPrivate)|\($0.profileName)|\($0.selectedTabGroupIdentifier.map(String.init) ?? "")|\($0.tabGroupName ?? "")|\($0.name)" }
            .joined(separator: "\n")
    }
}
