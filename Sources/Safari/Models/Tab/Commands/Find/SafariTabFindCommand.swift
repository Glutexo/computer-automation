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
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "window-index", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "profile", kind: .option, isRequired: false)
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
        let request = try parse(arguments)
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
        let request = try parse(arguments)
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

    private func parse(_ arguments: [String]) throws -> SafariTabFindRequest {
        var url: String?
        var matchMode = SafariTabURLMatchMode.exact
        var windowIdentifier: Int?
        var windowIndex: Int?
        var profileName: String?

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--prefix":
                matchMode = .prefix
            case "--window-id":
                let rawValue = try optionValue(after: argument, in: arguments, at: &index)
                guard let value = Int(rawValue), value > 0 else {
                    throw SafariTabCommandError.invalidWindowIdentifier(rawValue)
                }
                windowIdentifier = value
            case "--window-index":
                let rawValue = try optionValue(after: argument, in: arguments, at: &index)
                guard let value = Int(rawValue), value > 0 else {
                    throw SafariTabCommandError.invalidWindowIndex(rawValue)
                }
                windowIndex = value
            case "--profile":
                profileName = try optionValue(after: argument, in: arguments, at: &index)
            default:
                if let rawValue = argument.optionValue(prefix: "--window-id=") {
                    guard let value = Int(rawValue), value > 0 else {
                        throw SafariTabCommandError.invalidWindowIdentifier(rawValue)
                    }
                    windowIdentifier = value
                } else if let rawValue = argument.optionValue(prefix: "--window-index=") {
                    guard let value = Int(rawValue), value > 0 else {
                        throw SafariTabCommandError.invalidWindowIndex(rawValue)
                    }
                    windowIndex = value
                } else if let rawValue = argument.optionValue(prefix: "--profile=") {
                    profileName = rawValue
                } else if argument.hasPrefix("--") {
                    throw SafariTabCommandError.unknownOption(argument)
                } else if url == nil {
                    url = argument
                } else {
                    throw SafariTabCommandError.unexpectedArgument(argument)
                }
            }

            index += 1
        }

        guard let url else {
            throw SafariTabCommandError.missingURL
        }

        return SafariTabFindRequest(
            url: url,
            matchMode: matchMode,
            windowIdentifier: windowIdentifier,
            windowIndex: windowIndex,
            profileName: profileName
        )
    }

    private func optionValue(after option: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw SafariTabCommandError.missingOptionValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
    }
}

private struct SafariTabFindRequest: Equatable {
    let url: String
    let matchMode: SafariTabURLMatchMode
    let windowIdentifier: Int?
    let windowIndex: Int?
    let profileName: String?
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

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
