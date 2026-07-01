import AutomationFoundation
import SafariAppleScript

public struct SafariTabCloseCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "close-tab",
        abstract: "Close a Safari tab.",
        operation: .delete,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let closeTabByIndex: (Int, Int, SafariAppleScriptExecuting) throws -> String
    private let closeTabByIdentifier: (Int, Int, SafariAppleScriptExecuting) throws -> String

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.closeTabByIndex = { windowIndex, tabIndex, executor in
            try SafariAppleScriptTab.close(windowIndex: windowIndex, tabIndex: tabIndex, executor: executor)
        }
        self.closeTabByIdentifier = { windowIdentifier, tabIndex, executor in
            try SafariAppleScriptTab.close(windowIdentifier: windowIdentifier, tabIndex: tabIndex, executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        closeTab: @escaping (Int, Int, SafariAppleScriptExecuting) throws -> String = { windowIndex, tabIndex, executor in
            try SafariAppleScriptTab.close(windowIndex: windowIndex, tabIndex: tabIndex, executor: executor)
        },
        closeTabByIdentifier: @escaping (Int, Int, SafariAppleScriptExecuting) throws -> String = { windowIdentifier, tabIndex, executor in
            try SafariAppleScriptTab.close(windowIdentifier: windowIdentifier, tabIndex: tabIndex, executor: executor)
        }
    ) {
        self.executor = executor
        self.closeTabByIndex = closeTab
        self.closeTabByIdentifier = closeTabByIdentifier
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try parse(arguments)
        switch request.address {
        case .index(let windowIndex):
            return try closeTabByIndex(windowIndex, request.tabIndex, executor)
        case .identifier(let windowIdentifier):
            return try closeTabByIdentifier(windowIdentifier, request.tabIndex, executor)
        }
    }

    private func parse(_ arguments: [String]) throws -> SafariTabAddressRequest {
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
            guard let rawTabIndex = positionalArguments.first else {
                throw SafariTabCommandError.missingTabAddress
            }
            guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
                throw SafariTabCommandError.invalidTabAddress(String(windowIdentifier), rawTabIndex)
            }
            if positionalArguments.count > 1 {
                throw SafariTabCommandError.unexpectedArgument(positionalArguments[1])
            }
            return SafariTabAddressRequest(address: .identifier(windowIdentifier), tabIndex: tabIndex)
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard positionalArguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let rawTabIndex = positionalArguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIndex, rawTabIndex)
        }

        if positionalArguments.count > 2 {
            throw SafariTabCommandError.unexpectedArgument(positionalArguments[2])
        }

        return SafariTabAddressRequest(address: .index(windowIndex), tabIndex: tabIndex)
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

private struct SafariTabAddressRequest {
    let address: SafariWindowAddress
    let tabIndex: Int
}

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
