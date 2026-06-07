import AppKit
import AutomationFoundation

public struct SafariLaunchCommand: CommandModel {
    public static let bundleIdentifier = "com.apple.Safari"
    public static let descriptor = CommandDescriptor(
        name: "launch",
        abstract: "Launch Safari.",
        arguments: []
    )

    public init() {}

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else {
            throw SafariLaunchCommandError.applicationNotFound
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

public enum SafariLaunchCommandError: Error {
    case applicationNotFound
}
