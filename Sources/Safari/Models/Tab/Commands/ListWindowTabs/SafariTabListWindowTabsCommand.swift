import AutomationFoundation
import SafariAppleScript

public struct SafariTabListWindowTabsCommand: CommandModel, JSONCommandModel {
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
        let windowIndex = try parseWindowIndex(arguments)
        let tabs = try listWindowTabs(windowIndex, executor)
        return tabs
            .map { "\($0.index)|\($0.selectedTabGroupTabIndex.map(String.init) ?? "")|\($0.url)" }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let windowIndex = try parseWindowIndex(arguments)
        return try CommandJSONEncoder.encode(
            SafariWindowTabsJSONOutput(
                windowIndex: windowIndex,
                tabs: try listWindowTabs(windowIndex, executor).map(SafariWindowTabJSONRecord.init)
            )
        )
    }

    private func parseWindowIndex(_ arguments: [String]) throws -> Int {
        guard let rawWindowIndex = arguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        return windowIndex
    }
}

private struct SafariWindowTabsJSONOutput: Encodable {
    let windowIndex: Int
    let tabs: [SafariWindowTabJSONRecord]
}

private struct SafariWindowTabJSONRecord: Encodable {
    let tabIndex: Int
    let selectedTabGroupTabIndex: Int?
    let url: String

    init(_ record: SafariWindowTabRecord) {
        self.tabIndex = record.index
        self.selectedTabGroupTabIndex = record.selectedTabGroupTabIndex
        self.url = record.url
    }
}
