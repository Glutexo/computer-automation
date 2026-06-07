import AutomationFoundation

public struct SafariProfileListCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "profiles",
        abstract: "List available Safari profiles.",
        operation: .read,
        arguments: []
    )

    public init() {}

    @discardableResult
    public func execute(arguments: [String] = []) throws -> String {
        let profiles = try SafariProfile.listAvailableProfiles()
        return profiles.map(\.name).joined(separator: "\n")
    }
}
