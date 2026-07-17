import AutomationFoundation
import SafariAppleScript

public struct SafariTabOpenCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-tab",
        abstract: "Open a new Safari tab in a specific window.",
        operation: .create,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .positional, valueType: .integer),
            CommandArgumentDescriptor(
                name: "window-id",
                kind: .option,
                valueType: .integer,
                isRequired: false,
                valueName: "window-id"
            ),
            CommandArgumentDescriptor(name: "url", kind: .positional, isRequired: false)
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("window-id", isRequired: true)],
                [.argumentRef("window-index", isRequired: true)]
            ]),
            .argumentRef("url")
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
        if addressArguments.remainingArguments.count > 1 {
            throw SafariTabCommandError.unexpectedArgument(addressArguments.remainingArguments[1])
        }
        return SafariTabOpenRequest(
            address: addressArguments.address,
            url: addressArguments.remainingArguments.first.flatMap(normalizedURL)
        )
    }

    private func normalizedURL(_ rawValue: String) -> String? {
        rawValue.isEmpty ? nil : rawValue
    }
}

private struct SafariTabOpenRequest {
    let address: SafariWindowAddress
    let url: String?
}
