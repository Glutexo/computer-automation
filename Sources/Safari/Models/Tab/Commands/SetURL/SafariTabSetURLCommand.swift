import AutomationFoundation
import SafariAppleScript

public struct SafariTabSetURLCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "set-tab-url",
        abstract: "Update the URL of a Safari tab.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional),
            CommandArgumentDescriptor(name: "url", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let setURLByIndex: (Int, Int, String, SafariAppleScriptExecuting) throws -> Void
    private let setURLByIdentifier: (Int, Int, String, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.setURLByIndex = { windowIndex, tabIndex, url, executor in
            try SafariAppleScriptTab.setURL(windowIndex: windowIndex, tabIndex: tabIndex, url: url, executor: executor)
        }
        self.setURLByIdentifier = { windowIdentifier, tabIndex, url, executor in
            try SafariAppleScriptTab.setURL(windowIdentifier: windowIdentifier, tabIndex: tabIndex, url: url, executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        setURL: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> Void = { windowIndex, tabIndex, url, executor in
            try SafariAppleScriptTab.setURL(windowIndex: windowIndex, tabIndex: tabIndex, url: url, executor: executor)
        },
        setURLByIdentifier: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> Void = { windowIdentifier, tabIndex, url, executor in
            try SafariAppleScriptTab.setURL(windowIdentifier: windowIdentifier, tabIndex: tabIndex, url: url, executor: executor)
        }
    ) {
        self.executor = executor
        self.setURLByIndex = setURL
        self.setURLByIdentifier = setURLByIdentifier
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try parse(arguments)
        switch request.address {
        case .index(let windowIndex):
            try setURLByIndex(windowIndex, request.tabIndex, request.url, executor)
        case .identifier(let windowIdentifier):
            try setURLByIdentifier(windowIdentifier, request.tabIndex, request.url, executor)
        }
        return "Safari tab URL updated for \(request.address.displayName) tab \(request.tabIndex)."
    }

    private func parse(_ arguments: [String]) throws -> SafariTabSetURLRequest {
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
            guard positionalArguments.count >= 2, !positionalArguments[1].isEmpty else {
                throw SafariTabCommandError.missingURL
            }
            guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
                throw SafariTabCommandError.invalidTabAddress(String(windowIdentifier), rawTabIndex)
            }
            if positionalArguments.count > 2 {
                throw SafariTabCommandError.unexpectedArgument(positionalArguments[2])
            }
            return SafariTabSetURLRequest(address: .identifier(windowIdentifier), tabIndex: tabIndex, url: positionalArguments[1])
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard positionalArguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        guard positionalArguments.count >= 3, !positionalArguments[2].isEmpty else {
            throw SafariTabCommandError.missingURL
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        let rawTabIndex = positionalArguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIndex, rawTabIndex)
        }

        if positionalArguments.count > 3 {
            throw SafariTabCommandError.unexpectedArgument(positionalArguments[3])
        }

        return SafariTabSetURLRequest(address: .index(windowIndex), tabIndex: tabIndex, url: positionalArguments[2])
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

private struct SafariTabSetURLRequest {
    let address: SafariWindowAddress
    let tabIndex: Int
    let url: String
}

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
