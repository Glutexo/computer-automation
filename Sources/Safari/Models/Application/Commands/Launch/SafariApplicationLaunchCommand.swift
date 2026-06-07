import AppKit
import AutomationFoundation

public struct SafariApplicationLaunchCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "launch",
        abstract: "Launch Safari.",
        operation: .create,
        arguments: []
    )

    public init() {}

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard let safariURL = SafariApplication.applicationURL() else {
            throw SafariApplicationCommandError.applicationNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: safariURL, configuration: configuration) { _, error in
            if let error {
                assertionFailure("Safari launch failed: \(error.localizedDescription)")
            }
        }

        return "Safari launched."
    }
}
