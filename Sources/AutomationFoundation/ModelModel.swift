public protocol ModelModel {
    static var descriptor: ModelDescriptor { get }
}

public struct ModelDescriptor: Sendable, Equatable {
    public let name: String
    public let abstract: String
    public let commands: [CommandDescriptor]

    public init(name: String, abstract: String, commands: [CommandDescriptor]) {
        self.name = name
        self.abstract = abstract
        self.commands = commands
    }
}
