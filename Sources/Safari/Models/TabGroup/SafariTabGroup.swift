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
            SafariTabGroupEnsureCommand.descriptor,
            SafariTabGroupListCommand.descriptor,
            SafariTabGroupFindCommand.descriptor,
            SafariTabGroupResolveCommand.descriptor,
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
            let groups = try SafariDatabaseTabGroup.list(databasePath: databasePath).map(SafariTabGroupRecord.init)
            return try normalizeDefaultProfileNames(groups, databasePath: databasePath)
        } catch let error as SafariDatabaseError {
            throw SafariTabGroupCommandError(error)
        }
    }

    static func find(
        profileName: String,
        name: String,
        listTabGroups: () throws -> [SafariTabGroupRecord] = { try SafariTabGroup.list() },
        listProfiles: () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() }
    ) throws -> [SafariTabGroupRecord] {
        let profiles = try listProfiles()
        let profileNames = storedProfileNames(for: profileName, profiles: profiles)
        return try normalizeDefaultProfileNames(listTabGroups(), profiles: profiles).filter {
            profileNames.contains($0.profileName) && $0.name == name
        }
    }

    static func matchingStoredProfileNames(
        for profileName: String,
        listProfiles: () throws -> [SafariProfileRecord] = { try SafariProfile.listAvailableProfiles() }
    ) throws -> Set<String> {
        storedProfileNames(for: profileName, profiles: try listProfiles())
    }

    static func storedProfileNames(
        for profileName: String,
        profiles: [SafariProfileRecord]
    ) -> Set<String> {
        var names = Set([profileName])
        if profiles.first?.name == profileName {
            names.insert("")
        }
        return names
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

    static func normalizeDefaultProfileNames(
        _ groups: [SafariTabGroupRecord],
        profiles: [SafariProfileRecord]
    ) -> [SafariTabGroupRecord] {
        guard let defaultProfileName = profiles.first?.name else {
            return groups
        }

        return groups.map { group in
            guard group.profileName.isEmpty else {
                return group
            }

            return SafariTabGroupRecord(
                identifier: group.identifier,
                profileName: defaultProfileName,
                name: group.name
            )
        }
    }

    private static func normalizeDefaultProfileNames(
        _ groups: [SafariTabGroupRecord],
        databasePath: String
    ) throws -> [SafariTabGroupRecord] {
        let profiles = try SafariDatabaseProfile.list(databasePath: databasePath).map(SafariProfileRecord.init)
        return normalizeDefaultProfileNames(groups, profiles: profiles)
    }
}

public struct SafariTabGroupEnsureSummary: Equatable, Sendable, Encodable {
    public enum Status: String, Sendable, Encodable {
        case created
        case reused
    }

    public let status: Status
    public let tabGroup: SafariTabGroupRecord

    public init(status: Status, tabGroup: SafariTabGroupRecord) {
        self.status = status
        self.tabGroup = tabGroup
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
    case createdTabGroupProfileMismatch(requestedProfileName: String, createdProfileName: String)
    case tabGroupDeletionNotVerified(Int)
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
        case .missingWindowIndex:
            "Missing Safari window index. Provide a positive index; run the command with --help for usage."
        case .invalidWindowIndex(let value):
            "Invalid Safari window index \(value). Use a positive integer."
        case .missingTabGroupIdentifier:
            "Missing saved tab-group identifier. Provide a positive identifier; run the command with --help for usage."
        case .invalidTabGroupIdentifier(let value):
            "Invalid saved tab-group identifier \(value). Use a positive integer."
        case .missingTabGroupName:
            "Missing saved tab-group name. Run the command with --help for usage."
        case .emptyTabGroupName:
            "Saved tab-group name must not be empty."
        case .tabGroupNotFound(let identifier):
            "No saved Safari tab group has identifier \(identifier)."
        case .tabGroupLookupNotFound(let profileName, let tabGroupName):
            "No Safari tab group named \(tabGroupName) exists in profile \(profileName)."
        case .tabGroupLookupAmbiguous(let profileName, let tabGroupName, let count):
            "Safari tab group lookup for \(tabGroupName) in profile \(profileName) matched \(count) groups."
        case .ambiguousTabGroupName(let profileName, let tabGroupName):
            "Profile \(profileName) contains multiple saved tab groups named \(tabGroupName); use a stable identifier."
        case .duplicateTabGroupName(let profileName, let tabGroupName):
            "Profile \(profileName) already contains a saved tab group named \(tabGroupName)."
        case .privateWindowTabGroupMutationUnsupported(let windowIndex):
            "Safari window \(windowIndex) is private and cannot own saved tab groups. Use a normal profile window."
        case .createdTabGroupNotFound(let profileName):
            "Safari did not persist the newly created tab group in profile \(profileName)."
        case .createdTabGroupProfileMismatch(let requestedProfileName, let createdProfileName):
            "Safari created the tab group in profile \(createdProfileName), not requested profile \(requestedProfileName)."
        case .tabGroupDeletionNotVerified(let identifier):
            "Safari did not confirm deletion of saved tab group \(identifier)."
        case .windowForProfileNotFound(let profileName):
            "Safari did not create a new window for profile \(profileName). No existing window was repurposed."
        case .sidebarUnavailable:
            "Safari's visible sidebar could not be opened or inspected. Grant Accessibility permission and retry."
        case .sidebarTabGroupNotFound(let tabGroupName):
            "Safari's sidebar does not contain saved tab group \(tabGroupName) in the expected profile window."
        case .sidebarSelectedItemRenameUnavailable:
            "Safari did not expose the inline name field for the newly created tab group."
        case .unexpectedArgument(let argument):
            "Unexpected argument \(argument). Run the command with --help for usage."
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
