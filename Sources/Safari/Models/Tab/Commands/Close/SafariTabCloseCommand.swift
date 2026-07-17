import AutomationFoundation
import SafariAppleScript

public struct SafariTabCloseCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "close-tab",
        abstract: "Close a Safari tab.",
        operation: .delete,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional, valueType: .integer),
            CommandArgumentDescriptor(
                name: "window-id",
                kind: .option,
                valueType: .integer,
                isRequired: false,
                valueName: "window-id"
            ),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional, valueType: .integer)
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("window-id", isRequired: true)],
                [.argumentRef("window-index", isRequired: true)]
            ]),
            .argumentRef("tab-index")
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
        let parsed = try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            arguments,
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
        let addressArguments = try SafariTabAddressArgumentParser.parseRequiredAddress(
            positionalArguments: parsed.positionalArguments,
            windowIdentifier: parsed.windowIdentifier,
            missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
            missingTabAddress: { SafariTabCommandError.missingTabAddress },
            invalidWindowIndex: SafariTabCommandError.invalidWindowIndex,
            invalidTabAddress: SafariTabCommandError.invalidTabAddress
        )
        if let extra = addressArguments.remainingArguments.first {
            throw SafariTabCommandError.unexpectedArgument(extra)
        }
        return SafariTabAddressRequest(address: addressArguments.address, tabIndex: addressArguments.tabIndex)
    }
}

private struct SafariTabAddressRequest {
    let address: SafariWindowAddress
    let tabIndex: Int
}
