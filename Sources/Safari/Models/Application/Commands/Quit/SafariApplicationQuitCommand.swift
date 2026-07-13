import AppKit
import AutomationFoundation

public struct SafariApplicationQuitCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "quit",
        abstract: "Quit Safari if it is running.",
        operation: .delete,
        arguments: []
    )

    private let runningApplicationsProvider: () -> [SafariApplicationTerminating]

    public init() {
        self.runningApplicationsProvider = { SafariApplication.runningApplications().map { $0 as SafariApplicationTerminating } }
    }

    init(runningApplicationsProvider: @escaping () -> [SafariApplicationTerminating]) {
        self.runningApplicationsProvider = runningApplicationsProvider
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let applications = runningApplicationsProvider()
        guard !applications.isEmpty else {
            return "Safari is not running."
        }

        for application in applications {
            application.terminate()
        }

        return "Safari quit requested."
    }
}

public enum SafariApplicationCommandError: Error, Equatable, LocalizedError {
    case applicationNotFound

    public var errorDescription: String? {
        "Safari could not be found in the system Applications directory."
    }
}
