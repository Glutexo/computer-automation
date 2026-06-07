public struct CompletionSuggestion: Sendable, Equatable {
    public let value: String
    public let abstract: String

    public init(value: String, abstract: String) {
        self.value = value
        self.abstract = abstract
    }
}

public enum CompletionEngine {
    public static func suggestions(
        for arguments: [String],
        modules: [ModuleDescriptor]
    ) -> [CompletionSuggestion] {
        switch arguments.count {
        case 0:
            return modules.map { module in
                CompletionSuggestion(value: module.name, abstract: module.abstract)
            }
        case 1:
            if let module = modules.first(where: { $0.name == arguments[0] }) {
                return module.commands.map { command in
                    CompletionSuggestion(value: command.name, abstract: command.abstract)
                }
            }

            return modules
                .filter { $0.name.hasPrefix(arguments[0]) }
                .map { module in
                    CompletionSuggestion(value: module.name, abstract: module.abstract)
                }
        default:
            guard let module = modules.first(where: { $0.name == arguments[0] }) else {
                return []
            }

            let commandPrefix = arguments[1]
            return module.commands
                .filter { $0.name.hasPrefix(commandPrefix) }
                .map { command in
                    CompletionSuggestion(value: command.name, abstract: command.abstract)
                }
        }
    }
}
