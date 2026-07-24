import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "windows",
        abstract: "List open Safari browser windows.",
        operation: .read,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindows = { executor in
            do {
                return try SafariWindow.listAcrossRunningProcesses()
            } catch SafariUserInterfaceError.windowListUnavailable {
                return try SafariWindow.list(executor: executor)
            }
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { executor in
            try SafariWindow.list(executor: executor)
        }
    ) {
        self.executor = executor
        self.listWindows = listWindows
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let windows = try listWindows(executor)
        return windows
            .map {
                "\($0.identifier)|\($0.index)|\($0.isPrivate)|\($0.profileName)|\($0.selectedTabGroupIdentifier.map(String.init) ?? "")|\($0.tabGroupName ?? "")|\($0.currentTabName ?? $0.name)|\($0.processId.map(String.init) ?? "")"
            }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        try CommandJSONEncoder.encode(
            SafariWindowListJSONOutput(
                windows: listWindows(executor).map(SafariWindowJSONRecord.init)
            )
        )
    }
}

private struct SafariWindowListJSONOutput: Encodable {
    let windows: [SafariWindowJSONRecord]
}

private struct SafariWindowJSONRecord: Encodable {
    let processId: pid_t?
    let identifier: Int
    let index: Int
    let windowId: Int
    let windowIndex: Int
    let isPrivate: Bool
    let profileName: String
    let selectedTabGroupIdentifier: Int?
    let tabGroupName: String?
    let name: String

    init(_ record: SafariWindowRecord) {
        self.processId = record.processId
        self.identifier = record.identifier
        self.index = record.index
        self.windowId = record.identifier
        self.windowIndex = record.index
        self.isPrivate = record.isPrivate
        self.profileName = record.profileName
        self.selectedTabGroupIdentifier = record.selectedTabGroupIdentifier
        self.tabGroupName = record.tabGroupName
        self.name = record.currentTabName ?? record.name
    }
}
