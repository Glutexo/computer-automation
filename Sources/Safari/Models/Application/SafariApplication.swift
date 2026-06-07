import AppKit
import AutomationFoundation

public enum SafariApplication: ModelModel {
    public static let bundleIdentifier = "com.apple.Safari"

    public static let descriptor = ModelDescriptor(
        name: "application",
        abstract: "The Safari application process and lifecycle.",
        commands: [
            SafariApplicationLaunchCommand.descriptor,
            SafariApplicationRunningCommand.descriptor,
            SafariApplicationQuitCommand.descriptor
        ]
    )

    static func applicationURL() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func runningApplications() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    }

    static func isRunning() -> Bool {
        !runningApplications().isEmpty
    }
}
