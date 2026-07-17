import AutomationFoundation

public struct SafariTabListTabGroupTabsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "tab-group-tabs",
        abstract: "List tabs stored in a saved Safari tab group.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "tab-group-identifier", kind: .positional, valueType: .integer)
        ]
    )

    private let listTabs: (Int) throws -> [SafariTabGroupTabRecord]

    public init() {
        self.listTabs = { identifier in
            try SafariTabList.listTabGroupTabs(tabGroupIdentifier: identifier)
        }
    }

    init(listTabs: @escaping (Int) throws -> [SafariTabGroupTabRecord]) {
        self.listTabs = listTabs
    }

    public func execute(arguments: [String] = []) throws -> String {
        let tabGroupIdentifier = try parseTabGroupIdentifier(arguments)
        let tabs = try listTabs(tabGroupIdentifier)
        return tabs
            .map { "\($0.index)|\($0.url)" }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        let tabGroupIdentifier = try parseTabGroupIdentifier(arguments)
        return try CommandJSONEncoder.encode(
            SafariTabGroupTabsJSONOutput(tabGroupIdentifier: tabGroupIdentifier, tabs: listTabs(tabGroupIdentifier))
        )
    }

    private func parseTabGroupIdentifier(_ arguments: [String]) throws -> Int {
        guard let rawTabGroupIdentifier = arguments.first else {
            throw SafariTabGroupCommandError.missingTabGroupIdentifier
        }

        guard let tabGroupIdentifier = Int(rawTabGroupIdentifier), tabGroupIdentifier > 0 else {
            throw SafariTabGroupCommandError.invalidTabGroupIdentifier(rawTabGroupIdentifier)
        }

        return tabGroupIdentifier
    }
}

private struct SafariTabGroupTabsJSONOutput: Encodable {
    let tabGroupIdentifier: Int
    let tabs: [SafariTabGroupTabRecord]
}
