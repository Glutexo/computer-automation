import AutomationFoundation
import SafariAppleScript

public struct SafariTabResolveCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "resolve-tab",
        abstract: "Resolve exactly one Safari tab by URL.",
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
        let resolved = try resolve(arguments)
        return "\(resolved.match.windowIdentifier)|\(resolved.match.windowIndex)|\(resolved.match.tabIndex)|\(resolved.match.url)|\(resolved.match.title)"
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let resolved = try resolve(arguments)
        return try CommandJSONEncoder.encode(
            SafariTabResolveJSONOutput(
                query: resolved.request.url,
                matchMode: resolved.request.matchMode.rawValue,
                windowId: resolved.request.windowIdentifier,
                windowIndex: resolved.request.windowIndex,
                profileName: resolved.request.profileName,
                match: SafariTabResolveJSONRecord(resolved.match)
            )
        )
    }

    private func resolve(_ arguments: [String]) throws -> SafariTabResolvedMatch {
        let request = try SafariTabLookupRequest.parse(arguments)
        let matches = try findTabs(
            request.url,
            request.matchMode,
            request.windowIdentifier,
            request.windowIndex,
            request.profileName,
            executor
        )

        guard let match = matches.first else {
            throw SafariTabCommandError.resolveNoMatch(request.url)
        }
        guard matches.count == 1 else {
            throw SafariTabCommandError.resolveAmbiguous(request.url, matches.count)
        }

        return SafariTabResolvedMatch(request: request, match: match)
    }
}

private struct SafariTabResolvedMatch {
    let request: SafariTabLookupRequest
    let match: SafariTabMatchRecord
}

private struct SafariTabResolveJSONOutput: Encodable {
    let query: String
    let matchMode: String
    let windowId: Int?
    let windowIndex: Int?
    let profileName: String?
    let match: SafariTabResolveJSONRecord
}

private struct SafariTabResolveJSONRecord: Encodable {
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
