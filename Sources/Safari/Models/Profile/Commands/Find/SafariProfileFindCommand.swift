import AutomationFoundation

public struct SafariProfileFindCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "find-profile",
        abstract: "Find Safari profiles by name.",
        operation: .read,
        arguments: [
            CommandArgumentDescriptor(name: "name", kind: .positional)
        ]
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
        let request = try SafariProfileLookupRequest.parse(arguments)
        return try findProfiles(request.name)
            .map(SafariProfile.format)
            .joined(separator: "\n")
    }

    public func executeJSON(arguments: [String]) throws -> String {
        let request = try SafariProfileLookupRequest.parse(arguments)
        return try CommandJSONEncoder.encode(
            SafariProfileFindJSONOutput(
                name: request.name,
                matches: findProfiles(request.name)
            )
        )
    }
}

struct SafariProfileLookupRequest: Equatable {
    let name: String

    static func parse(_ arguments: [String]) throws -> SafariProfileLookupRequest {
        guard let name = arguments.first else {
            throw SafariProfileCommandError.missingProfileName
        }
        guard !name.isEmpty else {
            throw SafariProfileCommandError.emptyProfileName
        }

        if arguments.count > 1 {
            throw SafariProfileCommandError.unexpectedArgument(arguments[1])
        }

        return SafariProfileLookupRequest(name: name)
    }
}

private struct SafariProfileFindJSONOutput: Encodable {
    let name: String
    let matches: [SafariProfileRecord]
}
