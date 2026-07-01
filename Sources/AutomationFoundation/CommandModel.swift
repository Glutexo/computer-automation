import Foundation

public protocol CommandModel {
    static var descriptor: CommandDescriptor { get }

    func execute(arguments: [String]) throws -> String
}

public enum CommandOutputFormat: Sendable, Equatable {
    case text
    case json
}

public protocol JSONCommandModel: CommandModel {
    func executeJSON(arguments: [String]) throws -> String
}

public struct JSONMessageOutput: Encodable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum CommandJSONEncoder {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

public enum CommandOutputRenderer {
    public static func execute(
        _ command: some CommandModel,
        arguments: [String],
        outputFormat: CommandOutputFormat
    ) throws -> String {
        if CommandArgumentPreflight.requestsHelp(arguments) {
            return CommandUsageRenderer.render(command: type(of: command).descriptor)
        }

        try CommandArgumentPreflight.validate(type(of: command).descriptor, arguments: arguments)

        switch outputFormat {
        case .text:
            return try command.execute(arguments: arguments)
        case .json:
            if let jsonCommand = command as? any JSONCommandModel {
                return try jsonCommand.executeJSON(arguments: arguments)
            }
            return try CommandJSONEncoder.encode(JSONMessageOutput(message: command.execute(arguments: arguments)))
        }
    }
}

public extension JSONCommandModel {
    func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(JSONMessageOutput(message: execute(arguments: arguments)))
    }
}

public enum CRUDOperation: String, Sendable {
    case create = "C"
    case read = "R"
    case update = "U"
    case delete = "D"
}

public struct CommandDescriptor: Sendable, Equatable {
    public let name: String
    public let abstract: String
    public let operation: CRUDOperation
    public let arguments: [CommandArgumentDescriptor]
    public let usage: [CommandUsageComponent]?

    public init(
        name: String,
        abstract: String,
        operation: CRUDOperation,
        arguments: [CommandArgumentDescriptor] = [],
        usage: [CommandUsageComponent]? = nil
    ) {
        self.name = name
        self.abstract = abstract
        self.operation = operation
        self.arguments = arguments
        self.usage = usage
    }
}

public struct CommandArgumentDescriptor: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case positional
        case option
    }

    public let name: String
    public let kind: Kind
    public let isRequired: Bool
    public let valueName: String?
    public let isRepeating: Bool
    public let completionSuggestions: [CompletionSuggestion]

    public init(
        name: String,
        kind: Kind,
        isRequired: Bool = true,
        valueName: String? = nil,
        isRepeating: Bool = false,
        completionSuggestions: [CompletionSuggestion] = []
    ) {
        self.name = name
        self.kind = kind
        self.isRequired = isRequired
        self.valueName = valueName
        self.isRepeating = isRepeating
        self.completionSuggestions = completionSuggestions
    }
}

public struct CommandUsageArgument: Sendable, Equatable {
    public let name: String
    public let isRequired: Bool?

    public init(name: String, isRequired: Bool? = nil) {
        self.name = name
        self.isRequired = isRequired
    }
}

public struct CommandUsageAlternatives: Sendable, Equatable {
    public let alternatives: [[CommandUsageComponent]]
    public let isRequired: Bool

    public init(alternatives: [[CommandUsageComponent]], isRequired: Bool = true) {
        self.alternatives = alternatives
        self.isRequired = isRequired
    }
}

public enum CommandUsageComponent: Sendable, Equatable {
    case argument(CommandUsageArgument)
    case alternatives(CommandUsageAlternatives)

    public static func argumentRef(_ name: String, isRequired: Bool? = nil) -> CommandUsageComponent {
        .argument(CommandUsageArgument(name: name, isRequired: isRequired))
    }

    public static func requiredAlternatives(_ alternatives: [[CommandUsageComponent]]) -> CommandUsageComponent {
        .alternatives(CommandUsageAlternatives(alternatives: alternatives))
    }
}

public enum CommandArgumentError: Error, Equatable, LocalizedError {
    case unknownOption(commandName: String, option: String)
    case unexpectedArgument(commandName: String, argument: String)

    public var errorDescription: String? {
        switch self {
        case .unknownOption(let commandName, let option):
            "Unknown option \(option) for \(commandName)."
        case .unexpectedArgument(let commandName, let argument):
            "Unexpected argument \(argument) for \(commandName)."
        }
    }
}

public enum CommandArgumentPreflight {
    public static func requestsHelp(_ arguments: [String]) -> Bool {
        arguments.contains("--help")
    }

    public static func validate(_ descriptor: CommandDescriptor, arguments: [String]) throws {
        let knownOptions = Set(
            descriptor.arguments
                .filter { $0.kind == .option }
                .map { "--\($0.name)" }
        )

        for argument in arguments {
            if argument.hasPrefix("--") && !isKnownOption(argument, in: knownOptions) {
                throw CommandArgumentError.unknownOption(
                    commandName: descriptor.name,
                    option: argument
                )
            }
        }

        guard !descriptor.arguments.isEmpty || arguments.isEmpty else {
            throw CommandArgumentError.unexpectedArgument(
                commandName: descriptor.name,
                argument: arguments[0]
            )
        }
    }

    private static func isKnownOption(_ argument: String, in knownOptions: Set<String>) -> Bool {
        knownOptions.contains(argument) ||
            knownOptions.contains(where: { option in argument.hasPrefix("\(option)=") })
    }
}

public enum CommandUsageRenderer {
    public static func render(command: CommandDescriptor, invocation: [String]? = nil) -> String {
        let invocation = invocation ?? [command.name]
        let usage = (invocation + usageArguments(for: command)).joined(separator: " ")
        return """
        Usage: \(usage)

        \(command.abstract)
        """
    }

    private static func usageArguments(for command: CommandDescriptor) -> [String] {
        if let usage = command.usage {
            return usage.map { usageComponent($0, in: command) }
        }

        return command.arguments.map { argument in
            usageArgument(argument, isRequired: argument.isRequired)
        }
    }

    private static func usageComponent(_ component: CommandUsageComponent, in command: CommandDescriptor) -> String {
        switch component {
        case .argument(let usageArgument):
            guard let argument = command.arguments.first(where: { $0.name == usageArgument.name }) else {
                return "<\(usageArgument.name)>"
            }
            return self.usageArgument(argument, isRequired: usageArgument.isRequired ?? argument.isRequired)
        case .alternatives(let alternatives):
            let renderedAlternatives = alternatives.alternatives.map { alternative in
                alternative.map { usageComponent($0, in: command) }.joined(separator: " ")
            }
            let value = "(\(renderedAlternatives.joined(separator: " | ")))"
            return alternatives.isRequired ? value : "[\(value)]"
        }
    }

    private static func usageArgument(_ argument: CommandArgumentDescriptor, isRequired: Bool) -> String {
        let value: String
        switch argument.kind {
        case .positional:
            value = "<\(argument.name)>\(argument.isRepeating ? "..." : "")"
        case .option:
            value = optionUsage(argument)
        }
        return isRequired ? value : "[\(value)]"
    }

    private static func optionUsage(_ argument: CommandArgumentDescriptor) -> String {
        let option = "--\(argument.name)"
        guard let valueName = argument.valueName else {
            return option
        }

        return "\(option) <\(valueName)>"
    }
}
