import AutomationFoundation

public struct SafariProfileResolveCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "resolve-profile",
        abstract: "Resolve exactly one Safari profile by name.",
        operation: .read,
        arguments: SafariProfileFindCommand.descriptor.arguments
    )

    private let findProfiles: (String) throws -> [SafariProfileRecord]

    public init() {
        self.findProfiles = { name in
            try SafariProfile.find(name: name)
        }
    }

    init(findProfiles: @escaping (String) throws -> [SafariProfileRecord]) {
        self.findProfiles = findProfiles
    }

    public func execute(arguments: [String]) throws -> String {
        try SafariProfile.format(resolve(arguments: arguments).match)
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let resolved = try resolve(arguments: arguments)
        return try CommandJSONEncoder.encode(
            SafariProfileResolveJSONOutput(
                name: resolved.request.name,
                match: resolved.match
            )
        )
    }

    private func resolve(arguments: [String]) throws -> SafariProfileResolvedMatch {
        let request = try SafariProfileLookupRequest.parse(arguments)
        let matches = try findProfiles(request.name)

        guard let match = matches.first else {
            throw SafariProfileCommandError.profileLookupNotFound(name: request.name)
        }
        guard matches.count == 1 else {
            throw SafariProfileCommandError.profileLookupAmbiguous(name: request.name, count: matches.count)
        }

        return SafariProfileResolvedMatch(request: request, match: match)
    }
}

private struct SafariProfileResolvedMatch {
    let request: SafariProfileLookupRequest
    let match: SafariProfileRecord
}

private struct SafariProfileResolveJSONOutput: Encodable {
    let name: String
    let match: SafariProfileRecord
}
