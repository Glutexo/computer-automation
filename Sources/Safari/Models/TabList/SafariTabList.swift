import AutomationFoundation
import Foundation
import SafariAppleScript

public enum SafariTabList: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab-list",
        abstract: "Ordered Safari tab lists for windows and saved tab groups.",
        commands: [
            SafariTabListEnsureURLsCommand.descriptor,
            SafariTabListTabGroupTabsCommand.descriptor,
            SafariTabListWindowTabsCommand.descriptor
        ]
    )

    static func listWindowTabs(
        windowIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariWindowTabRecord] {
        try SafariTab.listWindowTabs(windowIndex: windowIndex, executor: executor)
    }

    static func listTabGroupTabs(
        tabGroupIdentifier: Int
    ) throws -> [SafariTabGroupTabRecord] {
        try SafariTabGroup.listTabs(tabGroupIdentifier: tabGroupIdentifier)
    }
}

public struct SafariTabListEnsureURLsContext: Equatable, Sendable, Encodable {
    public enum Kind: String, Sendable, Encodable {
        case window
        case tabGroup
    }

    public let kind: Kind
    public let windowIndex: Int?
    public let tabGroupIdentifier: Int?
    public let profileName: String?
    public let name: String?

    public init(
        kind: Kind,
        windowIndex: Int? = nil,
        tabGroupIdentifier: Int? = nil,
        profileName: String? = nil,
        name: String? = nil
    ) {
        self.kind = kind
        self.windowIndex = windowIndex
        self.tabGroupIdentifier = tabGroupIdentifier
        self.profileName = profileName
        self.name = name
    }
}

public struct SafariTabListEnsureURLsSummary: Equatable, Sendable, Encodable {
    public let context: SafariTabListEnsureURLsContext
    public let tabGroup: SafariTabGroupEnsureSummary?
    public let addedURLs: [String]
    public let skippedURLs: [String]

    public init(
        context: SafariTabListEnsureURLsContext,
        tabGroup: SafariTabGroupEnsureSummary? = nil,
        addedURLs: [String],
        skippedURLs: [String]
    ) {
        self.context = context
        self.tabGroup = tabGroup
        self.addedURLs = addedURLs
        self.skippedURLs = skippedURLs
    }
}

enum SafariTabListCommandError: Error, Equatable, LocalizedError {
    case missingContext
    case multipleContexts
    case missingTabGroupProfile
    case emptyTabGroupProfile
    case missingTabGroupName
    case emptyTabGroupName
    case missingURL
    case emptyURL
    case unknownOption(String)
    case missingOptionValue(String)

    var errorDescription: String? {
        switch self {
        case .missingContext:
            "Provide either --window-index or both --tab-group-profile and --tab-group-name."
        case .multipleContexts:
            "Provide only one tab-list context: either a window or a saved tab group."
        case .missingTabGroupProfile:
            "Missing Safari tab-group profile name."
        case .emptyTabGroupProfile:
            "Safari tab-group profile name must not be empty."
        case .missingTabGroupName:
            "Missing Safari tab-group name."
        case .emptyTabGroupName:
            "Safari tab-group name must not be empty."
        case .missingURL:
            "Missing URL."
        case .emptyURL:
            "URL must not be empty."
        case .unknownOption(let option):
            "Unknown option \(option)."
        case .missingOptionValue(let option):
            "Missing value for option \(option)."
        }
    }
}
