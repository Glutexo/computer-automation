import AutomationFoundation
import Foundation
import SafariDatabase

public struct SafariTabGroupRecord: Equatable, Sendable, Encodable {
    public let identifier: Int
    public let profileName: String
    public let name: String

    public init(identifier: Int, profileName: String, name: String) {
        self.identifier = identifier
        self.profileName = profileName
        self.name = name
    }
}

public struct SafariTabGroupTabRecord: Equatable, Sendable, Encodable {
    public let tabGroupIdentifier: Int
    public let index: Int
    public let url: String

    public init(tabGroupIdentifier: Int, index: Int, url: String) {
        self.tabGroupIdentifier = tabGroupIdentifier
        self.index = index
        self.url = url
    }
}

public enum SafariTabGroup: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab-group",
        abstract: "Saved Safari tab groups.",
        commands: [
            SafariTabGroupCreateCommand.descriptor,
            SafariTabGroupListCommand.descriptor,
            SafariTabGroupFindCommand.descriptor,
            SafariTabGroupResolveCommand.descriptor,
            SafariTabGroupListTabsCommand.descriptor,
            SafariTabGroupDeleteCommand.descriptor
        ]
    )

    static func format(_ group: SafariTabGroupRecord) -> String {
        "\(group.identifier)|\(group.profileName)|\(group.name)"
    }

    static func list(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariTabGroupRecord] {
        do {
            return try SafariDatabaseTabGroup.list(databasePath: databasePath).map(SafariTabGroupRecord.init)
        } catch let error as SafariDatabaseError {
            throw SafariTabGroupCommandError(error)
        }
    }

    static func find(
        profileName: String,
        name: String,
        listTabGroups: () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() }
    ) throws -> [SafariTabGroupRecord] {
        try listTabGroups().filter {
            $0.profileName == profileName && $0.name == name
        }
    }

    static func listTabs(
        tabGroupIdentifier: Int,
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [SafariTabGroupTabRecord] {
        do {
            return try SafariDatabaseTabGroup.listTabs(
                tabGroupIdentifier: tabGroupIdentifier,
                databasePath: databasePath
            )
            .map(SafariTabGroupTabRecord.init)
        } catch let error as SafariDatabaseError {
            throw SafariTabGroupCommandError(error)
        }
    }

    static func delete(
        tabGroupIdentifier: Int,
        databasePath: String = SafariProfile.databasePath()
    ) throws -> SafariTabGroupRecord {
        do {
            return SafariTabGroupRecord(
                try SafariDatabaseTabGroup.delete(
                    tabGroupIdentifier: tabGroupIdentifier,
                    databasePath: databasePath
                )
            )
        } catch let error as SafariDatabaseError {
            throw SafariTabGroupCommandError(error)
        } catch SafariDatabaseTabGroupError.tabGroupNotFound(let identifier) {
            throw SafariTabGroupCommandError.tabGroupNotFound(identifier)
        }
    }
}

extension SafariTabGroupRecord {
    init(_ record: SafariDatabaseTabGroupRecord) {
        self.init(identifier: record.identifier, profileName: record.profileName, name: record.name)
    }
}

extension SafariTabGroupTabRecord {
    init(_ record: SafariDatabaseTabGroupTabRecord) {
        self.init(tabGroupIdentifier: record.tabGroupIdentifier, index: record.index, url: record.url)
    }
}

enum SafariTabGroupCommandError: Error, Equatable, LocalizedError {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case queryExecutionFailed
    case missingProfileName
    case emptyProfileName
    case missingWindowIndex
    case invalidWindowIndex(String)
    case missingTabGroupIdentifier
    case invalidTabGroupIdentifier(String)
    case missingTabGroupName
    case emptyTabGroupName
    case tabGroupNotFound(Int)
    case tabGroupLookupNotFound(profileName: String, tabGroupName: String)
    case tabGroupLookupAmbiguous(profileName: String, tabGroupName: String, count: Int)
    case ambiguousTabGroupName(profileName: String, tabGroupName: String)
    case duplicateTabGroupName(profileName: String, tabGroupName: String)
    case privateWindowTabGroupMutationUnsupported(Int)
    case createdTabGroupNotFound(profileName: String)
    case windowForProfileNotFound(String)
    case sidebarUnavailable
    case sidebarTabGroupNotFound(String)
    case sidebarSelectedItemRenameUnavailable
    case unexpectedArgument(String)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let path):
            SafariDatabaseError.openFailed(path: path).localizedDescription
        case .queryPreparationFailed:
            "Could not prepare the Safari tab-group query. The Safari database schema may have changed."
        case .queryExecutionFailed:
            "Could not finish the Safari tab-group query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        case .missingProfileName:
            "Missing Safari profile name."
        case .emptyProfileName:
            "Safari profile name must not be empty."
        case .tabGroupLookupNotFound(let profileName, let tabGroupName):
            "No Safari tab group named \(tabGroupName) exists in profile \(profileName)."
        case .tabGroupLookupAmbiguous(let profileName, let tabGroupName, let count):
            "Safari tab group lookup for \(tabGroupName) in profile \(profileName) matched \(count) groups."
        default:
            nil
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
