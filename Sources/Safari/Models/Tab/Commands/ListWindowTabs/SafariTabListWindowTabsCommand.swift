import AutomationFoundation
import SafariAppleScript

public struct SafariTabListWindowTabsCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "window-tabs",
        abstract: "List Safari tabs in a specific window.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindowTabs: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindowTabs = { windowIndex, executor in
            try SafariTab.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindowTabs: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord] = { windowIndex, executor in
            try SafariTab.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
    ) {
        self.executor = executor
        self.listWindowTabs = listWindowTabs
    }

    public func execute(arguments: [String]) throws -> String {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let tabs = try listWindowTabs(windowIndex, executor)
        return tabs
            .map { "\($0.index)|\($0.isFromSelectedTabGroup)|\($0.selectedTabGroupTabIndex.map(String.init) ?? "")|\($0.url)" }
            .joined(separator: "\n")
    }
}
