public protocol ModuleModel {
    static var descriptor: ModuleDescriptor { get }

    static func execute(commandName: String, arguments: [String]) throws -> String
}

public extension ModuleModel {
    static func execute(
        commandName: String,
        arguments: [String],
        outputFormat: CommandOutputFormat
    ) throws -> String {
        switch outputFormat {
        case .text:
            return try execute(commandName: commandName, arguments: arguments)
        case .json:
            return try CommandJSONEncoder.encode(
                JSONMessageOutput(message: execute(commandName: commandName, arguments: arguments))
            )
        }
    }
}

public struct ModuleDescriptor: Sendable, Equatable {
    public let name: String
    public let abstract: String
    public let models: [ModelDescriptor]

    public var commands: [CommandDescriptor] {
        models.flatMap(\.commands)
    }

    public init(name: String, abstract: String, models: [ModelDescriptor]) {
        self.name = name
        self.abstract = abstract
        self.models = models
    }
}
