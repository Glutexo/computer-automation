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
    private let isRunning: () -> Bool
    private let closeFrontWindow: (SafariAppleScriptExecuting) throws -> String

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.isRunning = SafariApplication.isRunning
        self.closeFrontWindow = SafariAppleScriptWindow.closeFrontWindow
    }

    init(
        executor: SafariAppleScriptExecuting,
        isRunning: @escaping () -> Bool = SafariApplication.isRunning,
        closeFrontWindow: @escaping (SafariAppleScriptExecuting) throws -> String = SafariAppleScriptWindow.closeFrontWindow
    ) {
        self.executor = executor
        self.isRunning = isRunning
        self.closeFrontWindow = closeFrontWindow
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard isRunning() else {
            return "Safari is not running."
        }
        return try closeFrontWindow(executor)
    }
}
