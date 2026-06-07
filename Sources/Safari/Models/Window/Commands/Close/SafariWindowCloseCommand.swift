import AutomationFoundation
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

        let script = """
        tell application "Safari"
            if (count of windows) is 0 then
                return "Safari has no open windows."
            end if
            close front window
            return "Safari front window closed."
        end tell
        """

        return try executor.execute(script: script)?.stringValue ?? "Safari front window closed."
    }
}
