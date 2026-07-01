import AutomationFoundation
import SafariAppleScript

public struct SafariTabSetURLCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "set-tab-url",
        abstract: "Update the URL of a Safari tab.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false, valueName: "window-id"),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional),
            CommandArgumentDescriptor(name: "url", kind: .positional)
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("window-id", isRequired: true)],
                [.argumentRef("window-index", isRequired: true)]
            ]),
            .argumentRef("tab-index"),
            .argumentRef("url")
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
        let parsed = try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            arguments,
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
        try validateRequiredURLShape(
            positionalArguments: parsed.positionalArguments,
            windowIdentifier: parsed.windowIdentifier
        )
        let addressArguments = try SafariTabAddressArgumentParser.parseRequiredAddress(
            positionalArguments: parsed.positionalArguments,
            windowIdentifier: parsed.windowIdentifier,
            missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
            missingTabAddress: { SafariTabCommandError.missingTabAddress },
            invalidWindowIndex: SafariTabCommandError.invalidWindowIndex,
            invalidTabAddress: SafariTabCommandError.invalidTabAddress
        )
        if addressArguments.remainingArguments.count > 1 {
            throw SafariTabCommandError.unexpectedArgument(addressArguments.remainingArguments[1])
        }
        return SafariTabSetURLRequest(
            address: addressArguments.address,
            tabIndex: addressArguments.tabIndex,
            url: addressArguments.remainingArguments[0]
        )
    }

    private func validateRequiredURLShape(
        positionalArguments: [String],
        windowIdentifier: Int?
    ) throws {
        if windowIdentifier != nil {
            guard positionalArguments.first != nil else {
                throw SafariTabCommandError.missingTabAddress
            }
            guard positionalArguments.count >= 2, !positionalArguments[1].isEmpty else {
                throw SafariTabCommandError.missingURL
            }
            return
        }

        guard positionalArguments.first != nil else {
            throw SafariTabCommandError.missingWindowIndex
        }
        guard positionalArguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }
        guard positionalArguments.count >= 3, !positionalArguments[2].isEmpty else {
            throw SafariTabCommandError.missingURL
        }
    }
}

private struct SafariTabSetURLRequest {
    let address: SafariWindowAddress
    let tabIndex: Int
    let url: String
}
