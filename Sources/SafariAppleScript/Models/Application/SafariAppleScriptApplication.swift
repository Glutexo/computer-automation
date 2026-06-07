import AutomationFoundation

public enum SafariAppleScriptApplication: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "application",
        abstract: "AppleScript access to the Safari application.",
        commands: []
    )

    public static func activate(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        """

        _ = try executor.execute(script: script)
    }
}
