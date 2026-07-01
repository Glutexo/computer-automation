import AutomationFoundation
import SafariAppleScript

public struct SafariTabListWindowTabsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "window-tabs",
        abstract: "List Safari tabs in a specific window.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false, valueName: "window-id")
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("window-id", isRequired: true)],
                [.argumentRef("window-index", isRequired: true)]
            ])
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let listWindowTabsByIndex: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listWindowTabsByIdentifier: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.listWindowTabsByIndex = { windowIndex, executor in
            try SafariTabList.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
        self.listWindowTabsByIdentifier = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        listWindowTabs: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord] = { windowIndex, executor in
            try SafariTabList.listWindowTabs(windowIndex: windowIndex, executor: executor)
        },
        listWindowTabsByIdentifier: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord] = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
        }
    ) {
        self.executor = executor
        self.listWindowTabsByIndex = listWindowTabs
        self.listWindowTabsByIdentifier = listWindowTabsByIdentifier
    }

    public func execute(arguments: [String]) throws -> String {
        let address = try parseWindowAddress(arguments)
        let tabs = try listTabs(for: address)
        return tabs
            .map { "\($0.index)|\($0.selectedTabGroupTabIndex.map(String.init) ?? "")|\($0.url)" }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let address = try parseWindowAddress(arguments)
        return try CommandJSONEncoder.encode(
            SafariWindowTabsJSONOutput(
                windowIndex: address.windowIndex,
                windowId: address.windowIdentifier,
                tabs: try listTabs(for: address).map(SafariWindowTabJSONRecord.init)
            )
        )
    }

    private func listTabs(for address: SafariWindowAddress) throws -> [SafariWindowTabRecord] {
        switch address {
        case .index(let windowIndex):
            try listWindowTabsByIndex(windowIndex, executor)
        case .identifier(let windowIdentifier):
            try listWindowTabsByIdentifier(windowIdentifier, executor)
        }
    }

    private func parseWindowAddress(_ arguments: [String]) throws -> SafariWindowAddress {
        let parsed = try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            arguments,
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
        let addressArguments = try SafariWindowAddressArgumentParser.parseRequiredAddress(
            positionalArguments: parsed.positionalArguments,
            windowIdentifier: parsed.windowIdentifier,
            missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
            invalidWindowIndex: SafariTabCommandError.invalidWindowIndex
        )
        if let extra = addressArguments.remainingArguments.first {
            throw SafariTabCommandError.unexpectedArgument(extra)
        }
        return addressArguments.address
    }
}

private struct SafariWindowTabsJSONOutput: Encodable {
    let windowIndex: Int?
    let windowId: Int?
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
