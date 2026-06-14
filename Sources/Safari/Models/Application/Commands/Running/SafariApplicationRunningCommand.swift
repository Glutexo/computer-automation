import AutomationFoundation

public struct SafariApplicationRunningCommand: CommandModel, JSONCommandModel {
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

    public func executeJSON(arguments: [String] = []) throws -> String {
        try CommandJSONEncoder.encode(SafariApplicationRunningJSONOutput(running: isRunning()))
    }
}

private struct SafariApplicationRunningJSONOutput: Encodable {
    let running: Bool
}
