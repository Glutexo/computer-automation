import AutomationFoundation

public struct SafariProfileListCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "profiles",
        abstract: "List available Safari profiles.",
        operation: .read,
        arguments: []
    )

    private let listProfiles: () throws -> [SafariProfileRecord]

    public init() {
        self.listProfiles = { try SafariProfile.listAvailableProfiles() }
    }

    init(listProfiles: @escaping () throws -> [SafariProfileRecord]) {
        self.listProfiles = listProfiles
    }

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let profiles = try listProfiles()
        return profiles.map(\.name).joined(separator: "\n")
    }
}
