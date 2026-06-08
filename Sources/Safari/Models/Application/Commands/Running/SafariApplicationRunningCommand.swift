import AutomationFoundation

public struct SafariApplicationRunningCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "running",
        abstract: "Report whether Safari is currently running.",
        operation: .read,
        arguments: []
    )

    private let isRunning: () -> Bool

    public init() {
        self.isRunning = SafariApplication.isRunning
    }

    init(isRunning: @escaping () -> Bool) {
        self.isRunning = isRunning
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        isRunning() ? "true" : "false"
    }
}
