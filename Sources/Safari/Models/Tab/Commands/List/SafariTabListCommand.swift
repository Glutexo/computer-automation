import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "tabs",
        abstract: "List Safari browser tabs across all open windows.",
        operation: .read,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let listTabs: (SafariAppleScriptExecuting) throws -> [SafariTabRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listTabs = { executor in
            try SafariTab.listForAutomation(executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listTabs: @escaping (SafariAppleScriptExecuting) throws -> [SafariTabRecord] = { executor in
            try SafariTab.list(executor: executor)
        }
    ) {
        self.executor = executor
        self.listTabs = listTabs
    }

    public func execute(arguments: [String] = []) throws -> String {
        let tabs = try listTabs(executor)
        return tabs
            .map {
                "\($0.windowIdentifier)|\($0.windowIndex)|\($0.index)|\($0.url)|\($0.processId.map(String.init) ?? "")"
            }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        try CommandJSONEncoder.encode(SafariTabListJSONOutput(tabs: listTabs(executor).map(SafariTabJSONRecord.init)))
    }
}

private struct SafariTabListJSONOutput: Encodable {
    let tabs: [SafariTabJSONRecord]
}

private struct SafariTabJSONRecord: Encodable {
    let processId: pid_t?
    let windowId: Int
    let windowIndex: Int
    let tabIndex: Int
    let url: String
    let title: String

    init(_ record: SafariTabRecord) {
        self.processId = record.processId
        self.windowId = record.windowIdentifier
        self.windowIndex = record.windowIndex
        self.tabIndex = record.index
        self.url = record.url
        self.title = record.title
    }
}
