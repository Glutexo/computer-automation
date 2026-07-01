import AutomationFoundation
import SafariAppleScript

public struct SafariTabOpenCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-tab",
        abstract: "Open a new Safari tab in a specific window.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "url", kind: .positional, isRequired: false)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let openTabByIndex: (Int, String?, SafariAppleScriptExecuting) throws -> Void
    private let openTabByIdentifier: (Int, String?, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.openTabByIndex = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        }
        self.openTabByIdentifier = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        openTab: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        },
        openTabByIdentifier: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        }
    ) {
        self.executor = executor
        self.openTabByIndex = openTab
        self.openTabByIdentifier = openTabByIdentifier
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try parse(arguments)
        switch request.address {
        case .index(let windowIndex):
            try openTabByIndex(windowIndex, request.url, executor)
        case .identifier(let windowIdentifier):
            try openTabByIdentifier(windowIdentifier, request.url, executor)
        }

        if let url = request.url {
            return "Safari tab opened in \(request.address.displayName) with URL \(url)."
        }

        return "Safari tab opened in \(request.address.displayName)."
    }

    private func parse(_ arguments: [String]) throws -> SafariTabOpenRequest {
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
            if positionalArguments.count > 1 {
                throw SafariTabCommandError.unexpectedArgument(positionalArguments[1])
            }
            return SafariTabOpenRequest(
                address: .identifier(windowIdentifier),
                url: positionalArguments.first.flatMap(normalizedURL)
            )
        }

        guard let rawWindowIndex = positionalArguments.first else {
            throw SafariTabCommandError.missingWindowIndex
        }

        guard let windowIndex = Int(rawWindowIndex), windowIndex > 0 else {
            throw SafariTabCommandError.invalidWindowIndex(rawWindowIndex)
        }

        if positionalArguments.count > 2 {
            throw SafariTabCommandError.unexpectedArgument(positionalArguments[2])
        }

        return SafariTabOpenRequest(
            address: .index(windowIndex),
            url: positionalArguments.count >= 2 ? normalizedURL(positionalArguments[1]) : nil
        )
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

    private func normalizedURL(_ rawValue: String) -> String? {
        rawValue.isEmpty ? nil : rawValue
    }
}

private struct SafariTabOpenRequest {
    let address: SafariWindowAddress
    let url: String?
}

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
