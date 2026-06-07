public protocol CommandModel {
    static var descriptor: CommandDescriptor { get }

    func execute(arguments: [String]) throws -> String
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
