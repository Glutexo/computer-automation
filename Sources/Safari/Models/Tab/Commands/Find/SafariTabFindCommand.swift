import AutomationFoundation
import SafariAppleScript

public struct SafariTabFindCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "find-tab",
        abstract: "Find Safari tabs by URL.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "url", kind: .positional),
            CommandArgumentDescriptor(name: "prefix", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false, valueName: "window-id"),
            CommandArgumentDescriptor(name: "window-index", kind: .option, isRequired: false, valueName: "window-index"),
            CommandArgumentDescriptor(name: "profile", kind: .option, isRequired: false, valueName: "profile")
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let findTabs: (
        String,
        SafariTabURLMatchMode,
        Int?,
        Int?,
        String?,
        SafariAppleScriptExecuting
    ) throws -> [SafariTabMatchRecord]

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.findTabs = { url, matchMode, windowIdentifier, windowIndex, profileName, executor in
            try SafariTab.find(
                url: url,
                matchMode: matchMode,
                windowIdentifier: windowIdentifier,
                windowIndex: windowIndex,
                profileName: profileName,
                executor: executor
            )
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        findTabs: @escaping (
            String,
            SafariTabURLMatchMode,
            Int?,
            Int?,
            String?,
            SafariAppleScriptExecuting
        ) throws -> [SafariTabMatchRecord]
    ) {
        self.executor = executor
        self.findTabs = findTabs
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try SafariTabLookupRequest.parse(arguments)
        let matches = try findTabs(
            request.url,
            request.matchMode,
            request.windowIdentifier,
            request.windowIndex,
            request.profileName,
            executor
        )

        return matches
            .map { "\($0.windowIdentifier)|\($0.windowIndex)|\($0.tabIndex)|\($0.url)|\($0.title)" }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let request = try SafariTabLookupRequest.parse(arguments)
        let matches = try findTabs(
            request.url,
            request.matchMode,
            request.windowIdentifier,
            request.windowIndex,
            request.profileName,
            executor
        )

        return try CommandJSONEncoder.encode(
            SafariTabFindJSONOutput(
                query: request.url,
                matchMode: request.matchMode.rawValue,
                windowId: request.windowIdentifier,
                windowIndex: request.windowIndex,
                profileName: request.profileName,
                matches: matches.map(SafariTabMatchJSONRecord.init)
            )
        )
    }

}

struct SafariTabLookupRequest: Equatable {
    let url: String
    let matchMode: SafariTabURLMatchMode
    let windowIdentifier: Int?
    let windowIndex: Int?
    let profileName: String?

    static func parse(_ arguments: [String]) throws -> SafariTabLookupRequest {
        var url: String?
        var matchMode = SafariTabURLMatchMode.exact
        var windowIdentifier: Int?
        var windowIndex: Int?
        var profileName: String?

        var scanner = SafariCommandArgumentScanner(
            arguments: arguments,
            options: [
                .flag("--prefix"),
                .value(SafariWindowAddressArgumentParser.windowIdentifierOption),
                .value(SafariWindowAddressArgumentParser.windowIndexOption),
                .value("--profile")
            ],
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption
        )
        while let token = try scanner.next() {
            switch token {
            case .flag("--prefix"):
                matchMode = .prefix
            case .option(SafariWindowAddressArgumentParser.windowIdentifierOption, let rawValue):
                windowIdentifier = try SafariArgumentValueParser.positiveInteger(
                    rawValue,
                    invalid: SafariTabCommandError.invalidWindowIdentifier
                )
            case .option(SafariWindowAddressArgumentParser.windowIndexOption, let rawValue):
                windowIndex = try SafariArgumentValueParser.positiveInteger(
                    rawValue,
                    invalid: SafariTabCommandError.invalidWindowIndex
                )
            case .option("--profile", let rawValue):
                profileName = rawValue
            case .positional(let argument):
                if url == nil {
                    url = argument
                } else {
                    throw SafariTabCommandError.unexpectedArgument(argument)
                }
            case .flag:
                break
            case .option:
                break
            }
        }

        guard let url else {
            throw SafariTabCommandError.missingURL
        }

        return SafariTabLookupRequest(
            url: url,
            matchMode: matchMode,
            windowIdentifier: windowIdentifier,
            windowIndex: windowIndex,
            profileName: profileName
        )
    }
}

private struct SafariTabFindJSONOutput: Encodable {
    let query: String
    let matchMode: String
    let windowId: Int?
    let windowIndex: Int?
    let profileName: String?
    let matches: [SafariTabMatchJSONRecord]
}

private struct SafariTabMatchJSONRecord: Encodable {
    let windowId: Int
    let windowIndex: Int
    let tabIndex: Int
    let url: String
    let title: String

    init(_ record: SafariTabMatchRecord) {
        self.windowId = record.windowIdentifier
        self.windowIndex = record.windowIndex
        self.tabIndex = record.tabIndex
        self.url = record.url
        self.title = record.title
    }
}
