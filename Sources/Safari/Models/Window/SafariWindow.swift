import AppKit
import AutomationFoundation
import SafariAppleScript
import SafariDatabase
import SafariUserInterface

public struct SafariWindowRecord: Equatable, Sendable, Encodable {
    public let processId: pid_t?
    public let identifier: Int
    public let index: Int
    public let isPrivate: Bool
    public let profileName: String
    public let selectedTabGroupIdentifier: Int?
    public let tabGroupName: String?
    public let name: String

    public init(processId: pid_t? = nil, identifier: Int, index: Int, isPrivate: Bool = false, profileName: String, selectedTabGroupIdentifier: Int? = nil, tabGroupName: String? = nil, name: String) {
        self.processId = processId
        self.identifier = identifier
        self.index = index
        self.isPrivate = isPrivate
        self.profileName = profileName
        self.selectedTabGroupIdentifier = selectedTabGroupIdentifier
        self.tabGroupName = tabGroupName
        self.name = name
    }
}

public enum SafariWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window",
        abstract: "Safari browser windows.",
        commands: [
            SafariWindowOpenCommand.descriptor,
            SafariWindowOpenPrivateCommand.descriptor,
            SafariWindowOpenTabGroupCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowSetTabGroupCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )

    static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        databasePath: String = SafariProfile.databasePath(),
        isRunning: () -> Bool = SafariApplication.isRunning
    ) throws -> [SafariWindowRecord] {
        guard isRunning() else {
            return []
        }
        let rawWindows = try SafariAppleScriptWindow.list(executor: executor)
        return try records(from: rawWindows, databasePath: databasePath)
    }

    static func listAcrossRunningProcesses(
        databasePath: String = SafariProfile.databasePath(),
        isRunning: () -> Bool = SafariApplication.isRunning,
        discoverWindows: () throws -> [SafariProcessWindowRecord] = { try SafariProcessWindowDiscovery.list() }
    ) throws -> [SafariWindowRecord] {
        guard isRunning() else {
            return []
        }

        let discoveredWindows = try discoverWindows()
        return try records(
            from: discoveredWindows.map(\.window),
            processIdentifiers: discoveredWindows.map { $0.processIdentifier },
            databasePath: databasePath
        )
    }

    static func listForAutomation(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariWindowRecord] {
        try listForAutomation(
            executor: executor,
            listAcrossRunningProcesses: { try listAcrossRunningProcesses() },
            listLegacy: { try list(executor: $0) }
        )
    }

    static func listForAutomation(
        executor: SafariAppleScriptExecuting,
        listAcrossRunningProcesses: () throws -> [SafariWindowRecord],
        listLegacy: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord]
    ) throws -> [SafariWindowRecord] {
        do {
            return try listAcrossRunningProcesses()
        } catch SafariUserInterfaceError.windowListUnavailable {
            return try listLegacy(executor)
        }
    }

    private static func records(
        from rawWindows: [SafariAppleScriptWindowRecord],
        processIdentifiers: [pid_t] = [],
        databasePath: String
    ) throws -> [SafariWindowRecord] {
        let databaseContext: ([Int: SafariWindowState], Set<String>)
        do {
            databaseContext = (
                try loadWindowStateByWindowIdentifier(databasePath: databasePath),
                Set(try SafariProfile.listAvailableProfiles(databasePath: databasePath).map(\.name))
            )
        } catch let error where isDatabaseUnavailable(error) {
            databaseContext = ([:], [])
        }
        let statesByWindowIdentifier = databaseContext.0
        let knownProfileNames = databaseContext.1

        return rawWindows.enumerated().map { offset, rawWindow in
            let state = statesByWindowIdentifier[rawWindow.identifier]
            let profileName = state?.profileName
                ?? inferProfileName(fromWindowTitle: rawWindow.name, knownProfileNames: knownProfileNames)
                ?? ""

            return SafariWindowRecord(
                processId: processIdentifiers.indices.contains(offset) ? processIdentifiers[offset] : nil,
                identifier: rawWindow.identifier,
                index: offset + 1,
                isPrivate: state?.isPrivate ?? false,
                profileName: profileName,
                selectedTabGroupIdentifier: state?.selectedTabGroupIdentifier,
                tabGroupName: state?.tabGroupName,
                name: rawWindow.name
            )
        }
    }

    static func parseWindowList(
        _ descriptor: NSAppleEventDescriptor?,
        profilesByWindowIdentifier: [Int: String] = [:],
        privateWindowIdentifiers: Set<Int> = []
    ) -> [SafariWindowRecord] {
        let rawWindows = SafariAppleScriptWindow.parseWindowList(descriptor)
        return rawWindows.enumerated().map { offset, rawWindow in
            SafariWindowRecord(
                identifier: rawWindow.identifier,
                index: offset + 1,
                isPrivate: privateWindowIdentifiers.contains(rawWindow.identifier),
                profileName: profilesByWindowIdentifier[rawWindow.identifier] ?? "",
                selectedTabGroupIdentifier: nil,
                tabGroupName: nil,
                name: rawWindow.name
            )
        }
    }

    static func loadProfilesByWindowIdentifier(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [Int: String] {
        do {
            return try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
        } catch let error as SafariDatabaseError {
            throw SafariWindowCommandError(error)
        }
    }

    static func loadWindowStateByWindowIdentifier(
        databasePath: String = SafariProfile.databasePath()
    ) throws -> [Int: SafariWindowState] {
        do {
            return try SafariDatabaseWindow.loadStateByWindowIdentifier(databasePath: databasePath)
                .mapValues(SafariWindowState.init)
        } catch let error as SafariDatabaseError {
            throw SafariWindowCommandError(error)
        }
    }

    private static func inferProfileName(
        fromWindowTitle title: String,
        knownProfileNames: Set<String>
    ) -> String? {
        knownProfileNames.first { profileName in
            title == profileName || title.hasPrefix("\(profileName) —") || title.hasPrefix("\(profileName) -")
        }
    }

    private static func isDatabaseUnavailable(_ error: Error) -> Bool {
        if let windowError = error as? SafariWindowCommandError {
            switch windowError {
            case .databaseOpenFailed, .queryExecutionFailed:
                return true
            default:
                return false
            }
        }

        if let profileError = error as? SafariProfileCommandError {
            switch profileError {
            case .databaseOpenFailed, .queryExecutionFailed:
                return true
            default:
                return false
            }
        }

        return false
    }
}

struct SafariWindowState: Equatable, Sendable {
    let profileName: String
    let selectedTabGroupIdentifier: Int?
    let tabGroupName: String?
    let isPrivate: Bool

    init(
        profileName: String,
        selectedTabGroupIdentifier: Int?,
        tabGroupName: String?,
        isPrivate: Bool
    ) {
        self.profileName = profileName
        self.selectedTabGroupIdentifier = selectedTabGroupIdentifier
        self.tabGroupName = tabGroupName
        self.isPrivate = isPrivate
    }

    init(_ record: SafariDatabaseWindowStateRecord) {
        self.init(
            profileName: record.profileName,
            selectedTabGroupIdentifier: record.selectedTabGroupIdentifier,
            tabGroupName: record.tabGroupName,
            isPrivate: record.isPrivate
        )
    }
}

enum SafariWindowCommandError: Error, Equatable, LocalizedError {
    case databaseOpenFailed(path: String)
    case queryPreparationFailed
    case queryExecutionFailed
    case profileNotFound(String)
    case profileMenuItemNotFound(String)
    case privateWindowMenuItemNotFound
    case missingWindowIndex
    case missingWindowIdentifier
    case invalidWindowIndex(String)
    case invalidWindowIdentifier(String)
    case missingTabGroupIdentifier
    case invalidTabGroupIdentifier(String)
    case tabGroupNotFound(Int)
    case ambiguousTabGroupName(profileName: String, tabGroupName: String)
    case privateWindowTabGroupSelectionUnsupported(Int)
    case windowTabGroupProfileMismatch(windowProfileName: String, tabGroupProfileName: String)
    case openedWindowIdentifierNotFound
    case openedWindowProfileMismatch(requestedProfileName: String, observedWindowName: String)
    case openedPrivateWindowStateMismatch(Int)
    case tabGroupSelectionNotVerified(windowIdentifier: Int, tabGroupIdentifier: Int)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let path):
            SafariDatabaseError.openFailed(path: path).localizedDescription
        case .queryPreparationFailed:
            "Could not prepare the Safari window query. The Safari database schema may have changed."
        case .queryExecutionFailed:
            "Could not finish the Safari window query before the short busy timeout. Close Safari or retry after Safari finishes writing its database."
        case .profileNotFound(let profileName):
            "No Safari profile named \(profileName) exists."
        case .profileMenuItemNotFound(let profileName):
            "Safari's File menu does not contain a new-window item for profile \(profileName). Verify the profile exists and retry."
        case .privateWindowMenuItemNotFound:
            "Safari's File menu does not expose the private-window command."
        case .missingWindowIndex:
            "Missing Safari window index. Provide a positive index; run the command with --help for usage."
        case .missingWindowIdentifier:
            "Missing value for --window-id. Provide a positive Safari window identifier."
        case .invalidWindowIndex(let value):
            "Invalid Safari window index \(value). Use a positive integer."
        case .invalidWindowIdentifier(let value):
            "Invalid Safari window identifier \(value). Use a positive integer."
        case .missingTabGroupIdentifier:
            "Missing saved tab-group identifier. Provide a positive identifier; run the command with --help for usage."
        case .invalidTabGroupIdentifier(let value):
            "Invalid saved tab-group identifier \(value). Use a positive integer."
        case .tabGroupNotFound(let identifier):
            "No saved Safari tab group has identifier \(identifier)."
        case .ambiguousTabGroupName(let profileName, let tabGroupName):
            "Profile \(profileName) contains multiple saved tab groups named \(tabGroupName); use a stable identifier."
        case .privateWindowTabGroupSelectionUnsupported(let windowIndex):
            "Safari window \(windowIndex) is private and cannot select a saved tab group."
        case .windowTabGroupProfileMismatch(let windowProfileName, let tabGroupProfileName):
            "The Safari window belongs to profile \(windowProfileName), but the saved tab group belongs to profile \(tabGroupProfileName)."
        case .openedWindowIdentifierNotFound:
            "Safari opened a window, but computer-automation could not resolve its window id."
        case .openedWindowProfileMismatch(let requestedProfileName, let observedWindowName):
            "Safari opened a window for \(observedWindowName), not requested profile \(requestedProfileName)."
        case .openedPrivateWindowStateMismatch(let windowIdentifier):
            "Safari window \(windowIdentifier) was created by the private-window action, but Safari reported it as a normal window. The new window was closed."
        case .tabGroupSelectionNotVerified(let windowIdentifier, let tabGroupIdentifier):
            "Safari window \(windowIdentifier) did not confirm saved tab group \(tabGroupIdentifier). The new window was closed."
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
