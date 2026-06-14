import AutomationFoundation

public struct SafariTabGroupFindCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "find-tab-group",
        abstract: "Find saved Safari tab groups by profile and name.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "profile", kind: .positional),
            CommandArgumentDescriptor(name: "name", kind: .positional)
        ]
    )

    private let findTabGroups: (String, String) throws -> [SafariTabGroupRecord]

    public init() {
        self.findTabGroups = { profileName, name in
            try SafariTabGroup.find(profileName: profileName, name: name)
        }
    }

    init(findTabGroups: @escaping (String, String) throws -> [SafariTabGroupRecord]) {
        self.findTabGroups = findTabGroups
    }

    public func execute(arguments: [String]) throws -> String {
        let request = try SafariTabGroupLookupRequest.parse(arguments)
        return try findTabGroups(request.profileName, request.name)
            .map(SafariTabGroup.format)
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let request = try SafariTabGroupLookupRequest.parse(arguments)
        return try CommandJSONEncoder.encode(
            SafariTabGroupFindJSONOutput(
                profileName: request.profileName,
                name: request.name,
                matches: findTabGroups(request.profileName, request.name)
            )
        )
    }
}

struct SafariTabGroupLookupRequest: Equatable {
    let profileName: String
    let name: String

    static func parse(_ arguments: [String]) throws -> SafariTabGroupLookupRequest {
        guard let profileName = arguments.first else {
            throw SafariTabGroupCommandError.missingProfileName
        }
        guard !profileName.isEmpty else {
            throw SafariTabGroupCommandError.emptyProfileName
        }

        guard arguments.count >= 2 else {
            throw SafariTabGroupCommandError.missingTabGroupName
        }
        let name = arguments[1]
        guard !name.isEmpty else {
            throw SafariTabGroupCommandError.emptyTabGroupName
        }

        if arguments.count > 2 {
            throw SafariTabGroupCommandError.unexpectedArgument(arguments[2])
        }

        return SafariTabGroupLookupRequest(profileName: profileName, name: name)
    }
}

private struct SafariTabGroupFindJSONOutput: Encodable {
    let profileName: String
    let name: String
    let matches: [SafariTabGroupRecord]
}
