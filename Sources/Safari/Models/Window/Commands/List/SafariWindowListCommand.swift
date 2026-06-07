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

    public init() {
        self.executor = SafariAppleScriptExecutor()
    }

    init(executor: SafariAppleScriptExecuting) {
        self.executor = executor
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let windows = try SafariWindow.list(executor: executor)
        return windows
            .map { "\($0.index)|\($0.profileName)|\($0.name)" }
            .joined(separator: "\n")
    }
}
