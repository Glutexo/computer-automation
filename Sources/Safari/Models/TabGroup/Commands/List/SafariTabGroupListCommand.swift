import AutomationFoundation

public struct SafariTabGroupListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "tab-groups",
        abstract: "List saved Safari tab groups.",
        operation: .read,
        arguments: []
    )

    private let listTabGroups: () throws -> [SafariTabGroupRecord]

    public init() {
        self.listTabGroups = { try SafariTabGroup.list() }
    }

    init(listTabGroups: @escaping () throws -> [SafariTabGroupRecord]) {
        self.listTabGroups = listTabGroups
    }

    public func execute(arguments: [String] = []) throws -> String {
        let groups = try listTabGroups()
        return groups
            .map { "\($0.identifier)|\($0.profileName)|\($0.name)" }
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        try CommandJSONEncoder.encode(SafariTabGroupListJSONOutput(tabGroups: listTabGroups()))
    }
}

private struct SafariTabGroupListJSONOutput: Encodable {
    let tabGroups: [SafariTabGroupRecord]
}
