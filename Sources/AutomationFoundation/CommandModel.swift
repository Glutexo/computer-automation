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
