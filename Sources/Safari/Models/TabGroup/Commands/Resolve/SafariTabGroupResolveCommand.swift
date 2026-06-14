import AutomationFoundation

public struct SafariTabGroupResolveCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "resolve-tab-group",
        abstract: "Resolve exactly one saved Safari tab group by profile and name.",
        operation: .read,
        arguments: SafariTabGroupFindCommand.descriptor.arguments
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
        try SafariTabGroup.format(resolve(arguments: arguments).match)
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let resolved = try resolve(arguments: arguments)
        return try CommandJSONEncoder.encode(
            SafariTabGroupResolveJSONOutput(
                profileName: resolved.request.profileName,
                name: resolved.request.name,
                match: resolved.match
            )
        )
    }

    private func resolve(arguments: [String]) throws -> SafariTabGroupResolvedMatch {
        let request = try SafariTabGroupLookupRequest.parse(arguments)
        let matches = try findTabGroups(request.profileName, request.name)

        guard let match = matches.first else {
            throw SafariTabGroupCommandError.tabGroupLookupNotFound(
                profileName: request.profileName,
                tabGroupName: request.name
            )
        }
        guard matches.count == 1 else {
            throw SafariTabGroupCommandError.tabGroupLookupAmbiguous(
                profileName: request.profileName,
                tabGroupName: request.name,
                count: matches.count
            )
        }

        return SafariTabGroupResolvedMatch(request: request, match: match)
    }
}

private struct SafariTabGroupResolvedMatch {
    let request: SafariTabGroupLookupRequest
    let match: SafariTabGroupRecord
}

private struct SafariTabGroupResolveJSONOutput: Encodable {
    let profileName: String
    let name: String
    let match: SafariTabGroupRecord
}
