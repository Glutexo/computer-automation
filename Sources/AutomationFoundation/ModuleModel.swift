public protocol ModuleModel {
    static var descriptor: ModuleDescriptor { get }

    static func execute(commandName: String, arguments: [String]) throws -> String
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
