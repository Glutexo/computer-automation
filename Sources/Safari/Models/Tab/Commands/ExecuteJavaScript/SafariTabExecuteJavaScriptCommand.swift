import AutomationFoundation
import Foundation
import SafariAppleScript

public struct SafariTabExecuteJavaScriptCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "execute-tab-javascript",
        abstract: "Execute JavaScript in a concrete Safari tab.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "window-id", kind: .positional),
            CommandArgumentDescriptor(name: "tab-index", kind: .positional),
            CommandArgumentDescriptor(name: "javascript", kind: .positional, isRequired: false),
            CommandArgumentDescriptor(name: "stdin", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "file", kind: .option, isRequired: false)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let executeJavaScript: (Int, Int, String, SafariAppleScriptExecuting) throws -> String
    private let readStandardInput: () throws -> String
    private let readFile: (String) throws -> String

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.executeJavaScript = SafariAppleScriptTab.executeJavaScript
        self.readStandardInput = {
            String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        }
        self.readFile = { path in
            try String(contentsOfFile: path, encoding: .utf8)
        }
    }

    init(
        executor: SafariAppleScriptExecuting,
        executeJavaScript: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> String = SafariAppleScriptTab.executeJavaScript,
        readStandardInput: @escaping () throws -> String = { "" },
        readFile: @escaping (String) throws -> String = { _ in "" }
    ) {
        self.executor = executor
        self.executeJavaScript = executeJavaScript
        self.readStandardInput = readStandardInput
        self.readFile = readFile
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
        var positionalArguments: [String] = []
        var source: SafariTabJavaScriptSource?

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--stdin":
                try assign(source: .standardInput, to: &source)
            case "--file":
                let path = try optionValue(after: argument, in: arguments, at: &index)
                try assign(source: .file(path), to: &source)
            default:
                if let path = argument.optionValue(prefix: "--file=") {
                    guard !path.isEmpty else {
                        throw SafariTabCommandError.missingOptionValue("--file")
                    }
                    try assign(source: .file(path), to: &source)
                } else if argument.hasPrefix("--") {
                    throw SafariTabCommandError.unknownOption(argument)
                } else {
                    positionalArguments.append(argument)
                }
            }

            index += 1
        }

        guard let rawWindowIdentifier = positionalArguments.first else {
            throw SafariTabCommandError.missingWindowIdentifier
        }

        guard let windowIdentifier = Int(rawWindowIdentifier), windowIdentifier > 0 else {
            throw SafariTabCommandError.invalidWindowIdentifier(rawWindowIdentifier)
        }

        guard positionalArguments.count >= 2 else {
            throw SafariTabCommandError.missingTabAddress
        }

        let rawTabIndex = positionalArguments[1]
        guard let tabIndex = Int(rawTabIndex), tabIndex > 0 else {
            throw SafariTabCommandError.invalidTabAddress(rawWindowIdentifier, rawTabIndex)
        }

        if positionalArguments.count > 3 {
            throw SafariTabCommandError.unexpectedArgument(positionalArguments[3])
        }

        if positionalArguments.count == 3 {
            try assign(source: .inline(positionalArguments[2]), to: &source)
        }

        guard let source else {
            throw SafariTabCommandError.missingJavaScript
        }

        let javaScript = try javaScript(from: source)
        guard !javaScript.isEmpty else {
            throw SafariTabCommandError.missingJavaScript
        }

        return SafariTabJavaScriptRequest(
            windowIdentifier: windowIdentifier,
            tabIndex: tabIndex,
            javaScript: javaScript
        )
    }

    private func assign(source newSource: SafariTabJavaScriptSource, to source: inout SafariTabJavaScriptSource?) throws {
        guard source == nil else {
            throw SafariTabCommandError.multipleJavaScriptSources
        }
        source = newSource
    }

    private func javaScript(from source: SafariTabJavaScriptSource) throws -> String {
        switch source {
        case .inline(let javaScript):
            return javaScript
        case .standardInput:
            return try readStandardInput()
        case .file(let path):
            do {
                return try readFile(path)
            } catch {
                throw SafariTabCommandError.javaScriptFileReadFailed(path)
            }
        }
    }

    private func optionValue(after option: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--"), !arguments[valueIndex].isEmpty else {
            throw SafariTabCommandError.missingOptionValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
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
        } catch SafariAppleScriptTabJavaScriptError.unsupportedResult(let windowIdentifier, let tabIndex) {
            throw SafariTabCommandError.javaScriptResultUnsupported(
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

private enum SafariTabJavaScriptSource: Equatable {
    case inline(String)
    case standardInput
    case file(String)
}

private struct SafariTabJavaScriptJSONOutput: Encodable {
    let windowId: Int
    let tabIndex: Int
    let result: String
}

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
