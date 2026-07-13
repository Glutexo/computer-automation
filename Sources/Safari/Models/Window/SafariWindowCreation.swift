import Foundation
import SafariAppleScript

struct SafariWindowCreationResult: Encodable {
    let message: String
    let windowId: Int
    let profileName: String?
    let isPrivate: Bool

    var text: String {
        "\(message)\nwindow-id|\(windowId)"
    }
}

enum SafariWindowCreation {
    static let pollAttempts = 10
    static let pollInterval: TimeInterval = 0.1

    static func currentWindowIdentifiers(
        executor: SafariAppleScriptExecuting,
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord]
    ) throws -> Set<Int> {
        Set(try listWindows(executor).map(\.identifier))
    }

    static func waitForNewWindow(
        excluding existingWindowIdentifiers: Set<Int>,
        executor: SafariAppleScriptExecuting,
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord],
        sleep: (TimeInterval) -> Void = Thread.sleep,
        maxAttempts: Int = pollAttempts,
        interval: TimeInterval = pollInterval
    ) throws -> SafariAppleScriptWindowRecord? {
        for attempt in 0..<max(1, maxAttempts) {
            if let window = try listWindows(executor).first(where: {
                !existingWindowIdentifiers.contains($0.identifier)
            }) {
                return window
            }

            if attempt < max(1, maxAttempts) - 1 {
                sleep(interval)
            }
        }

        return nil
    }

    static func rollbackNewWindows(
        excluding existingWindowIdentifiers: Set<Int>,
        executor: SafariAppleScriptExecuting,
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord],
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    ) throws {
        for window in try listWindows(executor) where !existingWindowIdentifiers.contains(window.identifier) {
            try closeWindow(window.identifier, executor)
        }
    }
}
