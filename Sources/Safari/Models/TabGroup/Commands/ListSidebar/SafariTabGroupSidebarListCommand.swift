import AutomationFoundation
import SafariAppleScript

public struct SafariTabGroupSidebarListCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "sidebar-tab-groups",
        abstract: "List saved Safari tab groups from a temporary profile window's sidebar.",
        operation: .read,
        isReadOnly: false,
        arguments: [
            CommandArgumentDescriptor(name: "profile", kind: .positional),
            CommandArgumentDescriptor(name: "name", kind: .positional, isRequired: false)
        ]
    )

    private let listTabGroups: (String) throws -> [SafariTabGroupSidebarRecord]

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.listTabGroups = { profileName in
            try SafariTabGroupSidebarAccess.listTabGroups(
                profileName: profileName,
                executor: executor,
                listWindows: { try SafariWindow.listForAutomation(executor: executor) }
            )
        }
    }

    init(listTabGroups: @escaping (String) throws -> [SafariTabGroupSidebarRecord]) {
        self.listTabGroups = listTabGroups
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try SafariTabGroupSidebarListRequest.parse(arguments)
        return try matchingTabGroups(request)
            .map(Self.format)
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let request = try SafariTabGroupSidebarListRequest.parse(arguments)
        return try CommandJSONEncoder.encode(
            SafariTabGroupSidebarListJSONOutput(
                profileName: request.profileName,
                name: request.name,
                tabGroups: matchingTabGroups(request)
            )
        )
    }

    private func matchingTabGroups(
        _ request: SafariTabGroupSidebarListRequest
    ) throws -> [SafariTabGroupSidebarRecord] {
        let groups = try listTabGroups(request.profileName)
        guard let name = request.name else {
            return groups
        }
        return groups.filter { $0.name == name }
    }

    private static func format(_ group: SafariTabGroupSidebarRecord) -> String {
        "\(group.identifier.map(String.init) ?? "")|\(group.profileName)|\(group.name)"
    }
}

private struct SafariTabGroupSidebarListRequest {
    let profileName: String
    let name: String?

    static func parse(_ arguments: [String]) throws -> SafariTabGroupSidebarListRequest {
        guard let profileName = arguments.first else {
            throw SafariTabGroupCommandError.missingProfileName
        }
        guard !profileName.isEmpty else {
            throw SafariTabGroupCommandError.emptyProfileName
        }
        guard arguments.count <= 2 else {
            throw SafariTabGroupCommandError.unexpectedArgument(arguments[2])
        }

        let name = arguments.dropFirst().first
        if let name, name.isEmpty {
            throw SafariTabGroupCommandError.emptyTabGroupName
        }

        return SafariTabGroupSidebarListRequest(profileName: profileName, name: name)
    }
}

private struct SafariTabGroupSidebarListJSONOutput: Encodable {
    let profileName: String
    let name: String?
    let tabGroups: [SafariTabGroupSidebarRecord]
}
