import AppKit
import AutomationFoundation
import SafariAppleScript

public struct SafariTabRecord: Equatable, Sendable {
    public let windowIndex: Int
    public let index: Int
    public let url: String

    public init(windowIndex: Int, index: Int, url: String) {
        self.windowIndex = windowIndex
        self.index = index
        self.url = url
    }
}

public enum SafariTab: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab",
        abstract: "Safari browser tabs.",
        commands: [
            SafariTabOpenCommand.descriptor,
            SafariTabListCommand.descriptor,
            SafariTabSetURLCommand.descriptor,
            SafariTabCloseCommand.descriptor
        ]
    )

    static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariTabRecord] {
        guard SafariApplication.isRunning() else {
            return []
        }

        return try SafariAppleScriptTab.list(executor: executor).map {
            SafariTabRecord(windowIndex: $0.windowIndex, index: $0.index, url: $0.url)
        }
    }

    static func parseTabList(_ descriptor: NSAppleEventDescriptor?) -> [SafariTabRecord] {
        SafariAppleScriptTab.parseTabList(descriptor).map {
            SafariTabRecord(windowIndex: $0.windowIndex, index: $0.index, url: $0.url)
        }
    }
}

enum SafariTabCommandError: Error, Equatable {
    case missingWindowIndex
    case invalidWindowIndex(String)
    case missingTabAddress
    case invalidTabAddress(String, String)
    case missingURL
}
