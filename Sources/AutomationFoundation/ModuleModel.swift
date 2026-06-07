public protocol ModuleModel {
    static var descriptor: ModuleDescriptor { get }

    static func execute(commandName: String, arguments: [String]) throws -> String
}

public struct ModuleDescriptor: Sendable, Equatable {
    public let name: String
    public let abstract: String
    public let commands: [CommandDescriptor]

    public init(name: String, abstract: String, commands: [CommandDescriptor]) {
        self.name = name
        self.abstract = abstract
        self.commands = commands
    }
}
