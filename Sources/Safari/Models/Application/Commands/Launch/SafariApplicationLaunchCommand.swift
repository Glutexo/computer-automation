import AppKit
import AutomationFoundation

public struct SafariApplicationLaunchCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "launch",
        abstract: "Launch Safari.",
        operation: .create,
        arguments: []
    )

    private let applicationURLProvider: () -> URL?
    private let openApplication: (URL) -> Void

    public init() {
        self.applicationURLProvider = SafariApplication.applicationURL
        self.openApplication = { safariURL in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: safariURL, configuration: configuration) { _, error in
                if let error {
                    assertionFailure("Safari launch failed: \(error.localizedDescription)")
                }
            }
        }
    }

    init(
        applicationURLProvider: @escaping () -> URL?,
        openApplication: @escaping (URL) -> Void
    ) {
        self.applicationURLProvider = applicationURLProvider
        self.openApplication = openApplication
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard let safariURL = applicationURLProvider() else {
            throw SafariApplicationCommandError.applicationNotFound
        }
        openApplication(safariURL)
        return "Safari launched."
    }
}
