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

    public init(
        name: String,
        abstract: String,
        operation: CRUDOperation,
        arguments: [CommandArgumentDescriptor] = []
    ) {
        self.name = name
        self.abstract = abstract
        self.operation = operation
        self.arguments = arguments
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
    public let completionSuggestions: [CompletionSuggestion]

    public init(
        name: String,
        kind: Kind,
        isRequired: Bool = true,
        completionSuggestions: [CompletionSuggestion] = []
    ) {
        self.name = name
        self.kind = kind
        self.isRequired = isRequired
        self.completionSuggestions = completionSuggestions
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
        command.arguments.map { argument in
            switch argument.kind {
            case .positional:
                let value = "<\(argument.name)>"
                return argument.isRequired ? value : "[\(value)]"
            case .option:
                let value = "--\(argument.name)"
                return argument.isRequired ? value : "[\(value)]"
            }
        }
    }
}
