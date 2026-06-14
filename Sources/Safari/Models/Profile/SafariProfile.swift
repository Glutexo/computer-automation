import AutomationFoundation
import Foundation
import SafariDatabase

public struct SafariProfileRecord: Equatable, Sendable, Encodable {
    public let name: String
    public let identifier: String

    public init(name: String, identifier: String) {
        self.name = name
        self.identifier = identifier
    }
}

public enum SafariProfile: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "profile",
        abstract: "Safari profiles available to the application.",
        commands: [
            SafariProfileListCommand.descriptor,
            SafariProfileFindCommand.descriptor,
            SafariProfileResolveCommand.descriptor
        ]
    )

    static func format(_ profile: SafariProfileRecord) -> String {
        "\(profile.identifier)|\(profile.name)"
    }

    static func databasePath(
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        SafariTabsDatabase.databasePath(homeDirectory: homeDirectory)
    }

    static func listAvailableProfiles(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariProfileRecord] {
        do {
            return try SafariDatabaseProfile.list(databasePath: databasePath).map(SafariProfileRecord.init)
        } catch let error as SafariDatabaseError {
            throw SafariProfileCommandError(error)
        }
    }

    static func find(
        name: String,
        listProfiles: () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() }
    ) throws -> [SafariProfileRecord] {
        try listProfiles().filter { $0.name == name }
    }
}

extension SafariProfileRecord {
    init(_ record: SafariDatabaseProfileRecord) {
        self.init(name: record.name, identifier: record.identifier)
    }
}

public enum SafariProfileCommandError: Error, Equatable, LocalizedError {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case queryExecutionFailed
    case missingProfileName
    case emptyProfileName
    case profileLookupNotFound(name: String)
    case profileLookupAmbiguous(name: String, count: Int)
    case unexpectedArgument(String)

    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let path):
            SafariDatabaseError.openFailed(path: path).localizedDescription
        case .queryPreparationFailed:
            "Could not prepare the Safari profile query. The Safari database schema may have changed."
        case .queryExecutionFailed:
            "Could not finish the Safari profile query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        case .missingProfileName:
            "Missing Safari profile name."
        case .emptyProfileName:
            "Safari profile name must not be empty."
        case .profileLookupNotFound(let name):
            "No Safari profile named \(name) exists."
        case .profileLookupAmbiguous(let name, let count):
            "Safari profile lookup for \(name) matched \(count) profiles."
        case .unexpectedArgument(let argument):
            "Unexpected argument: \(argument)"
        }
    }

    init(_ error: SafariDatabaseError) {
        switch error {
        case .openFailed(let path):
            self = .databaseOpenFailed(path: path)
        case .queryPreparationFailed:
            self = .queryPreparationFailed
        case .queryExecutionFailed:
            self = .queryExecutionFailed
        }
    }
}
