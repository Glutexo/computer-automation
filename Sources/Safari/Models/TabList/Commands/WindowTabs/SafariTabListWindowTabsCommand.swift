import AutomationFoundation
import SafariAppleScript

public struct SafariTabListWindowTabsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "window-tabs",
        abstract: "List Safari tabs in a specific window.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false)
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
        var windowIdentifier: Int?
        var positionalArguments: [String] = []
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--window-id":
                let rawValue = try optionValue(after: argument, in: arguments, at: &index)
                windowIdentifier = try parseWindowIdentifier(rawValue)
            default:
                if let rawValue = argument.optionValue(prefix: "--window-id=") {
                    guard !rawValue.isEmpty else {
                        throw SafariTabCommandError.missingOptionValue("--window-id")
                    }
                    windowIdentifier = try parseWindowIdentifier(rawValue)
                } else if argument.hasPrefix("--") {
                    throw SafariTabCommandError.unknownOption(argument)
                } else {
                    positionalArguments.append(argument)
                }
            }

            index += 1
        }

        if let windowIdentifier {
            if let extra = positionalArguments.first {
                throw SafariTabCommandError.unexpectedArgument(extra)
            }
            return .identifier(windowIdentifier)
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        if positionalArguments.count > 1 {
            throw SafariTabCommandError.unexpectedArgument(positionalArguments[1])
        }

        return .index(windowIndex)
    }

    private func parseWindowIdentifier(_ rawValue: String) throws -> Int {
        guard let windowIdentifier = Int(rawValue), windowIdentifier > 0 else {
            throw SafariTabCommandError.invalidWindowIdentifier(rawValue)
        }
        return windowIdentifier
    }

    private func optionValue(after option: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--"), !arguments[valueIndex].isEmpty else {
            throw SafariTabCommandError.missingOptionValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
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

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
