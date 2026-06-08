import AutomationFoundation
import SafariAppleScript

public struct SafariTabOpenCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-tab",
        abstract: "Open a new Safari tab in a specific window.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "url", kind: .positional, isRequired: false)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let openTab: (Int, String?, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.openTab = SafariAppleScriptTab.open
    }

    init(
        executor: SafariAppleScriptExecuting,
        openTab: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptTab.open
    ) {
        self.executor = executor
        self.openTab = openTab
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let url = arguments.count >= 2 ? normalizedURL(arguments[1]) : nil
        try openTab(windowIndex, url, executor)

        if let url {
            return "Safari tab opened in window \(windowIndex) with URL \(url)."
        }

        return "Safari tab opened in window \(windowIndex)."
    }

    private func normalizedURL(_ rawValue: String) -> String? {
        rawValue.isEmpty ? nil : rawValue
    }
}
