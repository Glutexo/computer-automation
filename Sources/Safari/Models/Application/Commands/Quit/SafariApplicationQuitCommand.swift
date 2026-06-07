import AppKit
import AutomationFoundation

public struct SafariApplicationQuitCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "quit",
        abstract: "Quit Safari if it is running.",
        operation: .delete,
        arguments: []
    )

    public init() {}

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let applications = SafariApplication.runningApplications()
        guard !applications.isEmpty else {
            return "Safari is not running."
        }

        for application in applications {
            application.terminate()
        }

        return "Safari quit requested."
    }
}

public enum SafariApplicationCommandError: Error {
    case applicationNotFound
}
