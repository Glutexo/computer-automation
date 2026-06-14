import AutomationFoundation
import SafariAppleScript

public struct SafariTabExecuteJavaScriptCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "execute-tab-javascript",
        abstract: "Execute JavaScript in a concrete Safari tab.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "window-id", kind: .positional),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional),
            CommandArgumentDescriptor(name: "javascript", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let executeJavaScript: (Int, Int, String, SafariAppleScriptExecuting) throws -> String

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.executeJavaScript = SafariAppleScriptTab.executeJavaScript
    }

    init(
        executor: SafariAppleScriptExecuting,
        executeJavaScript: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> String = SafariAppleScriptTab.executeJavaScript
    ) {
        self.executor = executor
        self.executeJavaScript = executeJavaScript
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try parse(arguments)
        return try execute(request)
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let request = try parse(arguments)
        let result = try execute(request)
        return try CommandJSONEncoder.encode(
            SafariTabJavaScriptJSONOutput(
                windowId: request.windowIdentifier,
                tabIndex: request.tabIndex,
                result: result
            )
        )
    }

    private func parse(_ arguments: [String]) throws -> SafariTabJavaScriptRequest {
        guard let rawWindowIdentifier = arguments.first else {
            throw SafariTabCommandError.missingWindowIdentifier
        }

        guard let windowIdentifier = Int(rawWindowIdentifier), windowIdentifier > 0 else {
            throw SafariTabCommandError.invalidWindowIdentifier(rawWindowIdentifier)
        }

        guard arguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        let rawTabIndex = arguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIdentifier, rawTabIndex)
        }

        guard arguments.count >= 3, !arguments[2].isEmpty else {
            throw SafariTabCommandError.missingJavaScript
        }

        return SafariTabJavaScriptRequest(
            windowIdentifier: windowIdentifier,
            tabIndex: tabIndex,
            javaScript: arguments[2]
        )
    }

    private func execute(_ request: SafariTabJavaScriptRequest) throws -> String {
        do {
            return try executeJavaScript(
                request.windowIdentifier,
                request.tabIndex,
                request.javaScript,
                executor
            )
        } catch SafariAppleScriptTabJavaScriptError.windowNotFound(let windowIdentifier) {
            throw SafariTabCommandError.javaScriptTargetWindowNotFound(windowIdentifier)
        } catch SafariAppleScriptTabJavaScriptError.tabNotFound(let windowIdentifier, let tabIndex) {
            throw SafariTabCommandError.javaScriptTargetTabNotFound(
                windowIdentifier: windowIdentifier,
                tabIndex: tabIndex
            )
        } catch SafariAppleScriptTabJavaScriptError.executionFailed(let windowIdentifier, let tabIndex) {
            throw SafariTabCommandError.javaScriptExecutionFailed(
                windowIdentifier: windowIdentifier,
                tabIndex: tabIndex
            )
        }
    }
}

private struct SafariTabJavaScriptRequest {
    let windowIdentifier: Int
    let tabIndex: Int
    let javaScript: String
}

private struct SafariTabJavaScriptJSONOutput: Encodable {
    let windowId: Int
    let tabIndex: Int
    let result: String
}
