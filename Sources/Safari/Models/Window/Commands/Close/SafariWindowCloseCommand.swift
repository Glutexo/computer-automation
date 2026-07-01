import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowCloseCommand: CommandModel {
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
    private let closeWindowByIdentifier: (Int, SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.isRunning = SafariApplication.isRunning
        self.closeFrontWindow = SafariAppleScriptWindow.closeFrontWindow
        self.closeWindowByIdentifier = SafariAppleScriptWindow.close(windowIdentifier:executor:)
    }

    init(
        executor: SafariAppleScriptExecuting,
        isRunning: @escaping () -> Bool = SafariApplication.isRunning,
        closeFrontWindow: @escaping (SafariAppleScriptExecuting) throws -> String = SafariAppleScriptWindow.closeFrontWindow,
        closeWindowByIdentifier: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:)
    ) {
        self.executor = executor
        self.isRunning = isRunning
        self.closeFrontWindow = closeFrontWindow
        self.closeWindowByIdentifier = closeWindowByIdentifier
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        guard isRunning() else {
            return "Safari is not running."
        }

        if let windowIdentifier = try parseWindowIdentifier(arguments) {
            try closeWindowByIdentifier(windowIdentifier, executor)
            return "Safari window \(windowIdentifier) closed."
        }

        return try closeFrontWindow(executor)
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
