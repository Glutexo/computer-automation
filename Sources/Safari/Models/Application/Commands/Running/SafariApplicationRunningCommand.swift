import AutomationFoundation

public struct SafariApplicationRunningCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "running",
        abstract: "Report whether Safari is currently running.",
        operation: .read,
        arguments: []
    )

    public init() {}

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        SafariApplication.isRunning() ? "true" : "false"
    }
}
