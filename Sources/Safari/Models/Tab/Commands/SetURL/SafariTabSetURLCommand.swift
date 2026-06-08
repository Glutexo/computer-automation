import AutomationFoundation
import SafariAppleScript

public struct SafariTabSetURLCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "set-tab-url",
        abstract: "Update the URL of a Safari tab.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional),
            CommandArgumentDescriptor(name: "url", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let setURL: (Int, Int, String, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.setURL = SafariAppleScriptTab.setURL
    }

    init(
        executor: SafariAppleScriptExecuting,
        setURL: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptTab.setURL
    ) {
        self.executor = executor
        self.setURL = setURL
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard arguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        guard arguments.count >= 3, !arguments[2].isEmpty else {
            throw SafariTabCommandError.missingURL
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let rawTabIndex = arguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIndex, rawTabIndex)
        }

        let url = arguments[2]
        try setURL(windowIndex, tabIndex, url, executor)
        return "Safari tab URL updated for window \(windowIndex) tab \(tabIndex)."
    }
}
