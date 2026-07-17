import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowCloseCommand: CommandModel {
    private static let removalPollAttempts = 40
    private static let removalPollInterval: TimeInterval = 0.1

    public static let descriptor = CommandDescriptor(
        name: "close-window",
        abstract: "Close a Safari browser window.",
        operation: .delete,
        arguments: [
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false, valueName: "window-id")
        ],
        usage: [
            .argumentRef("window-id", isRequired: false)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let isRunning: () -> Bool
    private let closeFrontWindow: (SafariAppleScriptExecuting) throws -> String
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let closeWindowByIdentifier: (Int, SafariAppleScriptExecuting) throws -> Void
    private let closeFocusedWindow: (pid_t?, () throws -> Void) throws -> Void
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord]
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.isRunning = SafariApplication.isRunning
        self.closeFrontWindow = SafariAppleScriptWindow.closeFrontWindow
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.closeWindowByIdentifier = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.closeFocusedWindow = { processIdentifier, performClose in
            try SafariAccessibilityWindow.closeFocusedWindow(
                processIdentifier: processIdentifier,
                performClose: performClose
            )
        }
        self.listWindows = { executor in
            try SafariWindow.listForAutomation(executor: executor)
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        isRunning: @escaping () -> Bool = SafariApplication.isRunning,
        closeFrontWindow: @escaping (SafariAppleScriptExecuting) throws -> String = SafariAppleScriptWindow.closeFrontWindow,
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = { _, _ in },
        closeWindowByIdentifier: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        closeFocusedWindow: @escaping (pid_t?, () throws -> Void) throws -> Void = { _, performClose in try performClose() },
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { _ in [] },
        sleep: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.executor = executor
        self.isRunning = isRunning
        self.closeFrontWindow = closeFrontWindow
        self.focusWindow = focusWindow
        self.closeWindowByIdentifier = closeWindowByIdentifier
        self.closeFocusedWindow = closeFocusedWindow
        self.listWindows = listWindows
        self.sleep = sleep
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard isRunning() else {
            return "Safari is not running."
        }

        if let windowIdentifier = try parseWindowIdentifier(arguments) {
            guard let targetWindow = try listWindows(executor).first(where: {
                $0.identifier == windowIdentifier
            }) else {
                return "Safari window \(windowIdentifier) closed."
            }

            try focusWindow(windowIdentifier, executor)
            try closeFocusedWindow(targetWindow.processId) {
                try closeWindowByIdentifier(windowIdentifier, executor)
            }
            guard waitUntilWindowIsRemoved(windowIdentifier) else {
                throw SafariUserInterfaceError.windowCloseNotVerified
            }
            return "Safari window \(windowIdentifier) closed."
        }

        return try closeFrontWindow(executor)
    }

    private func waitUntilWindowIsRemoved(_ windowIdentifier: Int) -> Bool {
        for attempt in 0..<Self.removalPollAttempts {
            if
                let windows = try? listWindows(executor),
                !windows.contains(where: { $0.identifier == windowIdentifier })
            {
                return true
            }

            if attempt < Self.removalPollAttempts - 1 {
                sleep(Self.removalPollInterval)
            }
        }

        return false
    }

    private func parseWindowIdentifier(_ arguments: [String]) throws -> Int? {
        var windowIdentifier: Int?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--window-id":
                let valueIndex = index + 1
                guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--"), !arguments[valueIndex].isEmpty else {
                    throw SafariWindowCommandError.missingWindowIdentifier
                }
                windowIdentifier = try parsedWindowIdentifier(arguments[valueIndex])
                index = valueIndex
            default:
                if let rawValue = argument.optionValue(prefix: "--window-id=") {
                    guard !rawValue.isEmpty else {
                        throw SafariWindowCommandError.missingWindowIdentifier
                    }
                    windowIdentifier = try parsedWindowIdentifier(rawValue)
                } else if argument.hasPrefix("--") {
                    throw CommandArgumentError.unknownOption(commandName: Self.descriptor.name, option: argument)
                } else {
                    throw CommandArgumentError.unexpectedArgument(commandName: Self.descriptor.name, argument: argument)
                }
            }

            index += 1
        }

        return windowIdentifier
    }

    private func parsedWindowIdentifier(_ rawValue: String) throws -> Int {
        guard let windowIdentifier = Int(rawValue), windowIdentifier > 0 else {
            throw SafariWindowCommandError.invalidWindowIdentifier(rawValue)
        }
        return windowIdentifier
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
