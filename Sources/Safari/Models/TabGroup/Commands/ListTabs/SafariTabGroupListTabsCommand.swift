import AutomationFoundation

public struct SafariTabGroupListTabsCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "tab-group-tabs",
        abstract: "List tabs stored in a saved Safari tab group.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional)
        ]
    )

    private let listTabs: (Int) throws -> [SafariTabGroupTabRecord]

    public init() {
        self.listTabs = { identifier in
            try SafariTabGroup.listTabs(tabGroupIdentifier: identifier)
        }
    }

    init(listTabs: @escaping (Int) throws -> [SafariTabGroupTabRecord]) {
        self.listTabs = listTabs
    }

    public func execute(arguments: [String] = []) throws -> String {
        guard let rawTabGroupIdentifier = arguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        let tabs = try listTabs(tabGroupIdentifier)
        return tabs
            .map { "\($0.index)|\($0.url)" }
            .joined(separator: "\n")
    }
}
