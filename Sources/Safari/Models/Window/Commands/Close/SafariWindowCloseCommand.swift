import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowCloseCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "close-window",
        abstract: "Close the front Safari browser window.",
        operation: .delete,
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
        guard SafariApplication.isRunning() else {
            return "Safari is not running."
        }
        return try SafariAppleScriptWindow.closeFrontWindow(executor: executor)
    }
}
