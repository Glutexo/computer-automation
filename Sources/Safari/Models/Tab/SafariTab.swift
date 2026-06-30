import AppKit
import AutomationFoundation
import SafariAppleScript

public struct SafariTabRecord: Equatable, Sendable, Encodable {
    public let windowIndex: Int
    public let index: Int
    public let url: String
    public let title: String

    public init(windowIndex: Int, index: Int, url: String, title: String = "") {
        self.windowIndex = windowIndex
        self.index = index
        self.url = url
        self.title = title
    }
}

public struct SafariWindowTabRecord: Equatable, Sendable, Encodable {
    public let index: Int
    public let selectedTabGroupTabIndex: Int?
    public let url: String

    public init(index: Int, selectedTabGroupTabIndex: Int?, url: String) {
        self.index = index
        self.selectedTabGroupTabIndex = selectedTabGroupTabIndex
        self.url = url
    }
}

public struct SafariTabMatchRecord: Equatable, Sendable, Encodable {
    public let windowIdentifier: Int
    public let windowIndex: Int
    public let tabIndex: Int
    public let url: String
    public let title: String

    public init(windowIdentifier: Int, windowIndex: Int, tabIndex: Int, url: String, title: String = "") {
        self.windowIdentifier = windowIdentifier
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.url = url
        self.title = title
    }
}

enum SafariTabURLMatchMode: String, Equatable {
    case exact
    case prefix
}

public enum SafariTab: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab",
        abstract: "Safari browser tabs.",
        commands: [
            SafariTabOpenCommand.descriptor,
            SafariTabListCommand.descriptor,
            SafariTabFindCommand.descriptor,
            SafariTabResolveCommand.descriptor,
            SafariTabExecuteJavaScriptCommand.descriptor,
            SafariTabSetURLCommand.descriptor,
            SafariTabCloseCommand.descriptor
        ]
    )

    static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariTabRecord] {
        guard SafariApplication.isRunning() else {
            return []
        }

        return try SafariAppleScriptTab.list(executor: executor).map {
            SafariTabRecord(windowIndex: $0.windowIndex, index: $0.index, url: $0.url, title: $0.title)
        }
    }

    static func parseTabList(_ descriptor: NSAppleEventDescriptor?) -> [SafariTabRecord] {
        SafariAppleScriptTab.parseTabList(descriptor).map {
            SafariTabRecord(windowIndex: $0.windowIndex, index: $0.index, url: $0.url, title: $0.title)
        }
    }

    static func find(
        url: String,
        matchMode: SafariTabURLMatchMode = .exact,
        windowIdentifier: Int? = nil,
        windowIndex: Int? = nil,
        profileName: String? = nil,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        isRunning: () -> Bool = { SafariApplication.isRunning() },
        listTabs: (SafariAppleScriptExecuting) throws -> [SafariTabRecord] = { executor in
            try SafariTab.list(executor: executor)
        },
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { executor in
            try SafariWindow.list(executor: executor)
        }
    ) throws -> [SafariTabMatchRecord] {
        guard isRunning() else {
            return []
        }

        let windowsByIndex = Dictionary(uniqueKeysWithValues: try listWindows(executor).map { ($0.index, $0) })
        return try listTabs(executor).compactMap { tab in
            guard
                tab.matches(url: url, mode: matchMode),
                let window = windowsByIndex[tab.windowIndex],
                windowIdentifier.map({ $0 == window.identifier }) ?? true,
                windowIndex.map({ $0 == window.index }) ?? true,
                profileName.map({ $0 == window.profileName }) ?? true
            else {
                return nil
            }

            return SafariTabMatchRecord(
                windowIdentifier: window.identifier,
                windowIndex: tab.windowIndex,
                tabIndex: tab.index,
                url: tab.url,
                title: tab.title
            )
        }
    }

    static func listWindowTabs(
        windowIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        databasePath: String = SafariProfile.databasePath(),
        isRunning: () -> Bool = { SafariApplication.isRunning() },
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord] = { executor in
            try SafariAppleScriptWindow.list(executor: executor)
        },
        listTabs: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptTabRecord] = { executor in
            try SafariAppleScriptTab.list(executor: executor)
        },
        loadWindowStates: (String) throws -> [Int: SafariWindowState] = { path in
            try SafariWindow.loadWindowStateByWindowIdentifier(databasePath: path)
        },
        loadTabGroupTabs: (Int, String) throws -> [SafariTabGroupTabRecord] = { tabGroupIdentifier, path in
            try SafariTabGroup.listTabs(tabGroupIdentifier: tabGroupIdentifier, databasePath: path)
        }
    ) throws -> [SafariWindowTabRecord] {
        guard isRunning() else {
            return []
        }

        let windows = try listWindows(executor)
        guard windowIndex > 0, windowIndex <= windows.count else {
            return []
        }

        let windowIdentifier = windows[windowIndex - 1].identifier
        let liveTabs = try listTabs(executor)
            .filter { $0.windowIndex == windowIndex }
            .map { SafariTabRecord(windowIndex: $0.windowIndex, index: $0.index, url: $0.url) }

        let windowState = try loadWindowStates(databasePath)[windowIdentifier]
        let selectedTabGroupIdentifier = windowState?.isPrivate == true ? nil : windowState?.selectedTabGroupIdentifier
        let selectedTabGroupTabs: [SafariTabGroupTabRecord]
        if let selectedTabGroupIdentifier {
            selectedTabGroupTabs = try loadTabGroupTabs(selectedTabGroupIdentifier, databasePath)
        } else {
            selectedTabGroupTabs = []
        }

        return matchTabs(liveTabs, againstSelectedTabGroupTabs: selectedTabGroupTabs)
    }

    static func matchTabs(
        _ liveTabs: [SafariTabRecord],
        againstSelectedTabGroupTabs selectedTabGroupTabs: [SafariTabGroupTabRecord]
    ) -> [SafariWindowTabRecord] {
        let selectedTabGroupTabsByIndex = Dictionary(uniqueKeysWithValues: selectedTabGroupTabs.map { ($0.index, $0) })

        return liveTabs.map { liveTab in
            let matchedTab = selectedTabGroupTabsByIndex[liveTab.index]

            return SafariWindowTabRecord(
                index: liveTab.index,
                selectedTabGroupTabIndex: matchedTab?.url == liveTab.url ? matchedTab?.index : nil,
                url: liveTab.url
            )
        }
    }
}

private extension SafariTabRecord {
    func matches(url searchedURL: String, mode: SafariTabURLMatchMode) -> Bool {
        switch mode {
        case .exact:
            return url == searchedURL
        case .prefix:
            return url.hasPrefix(searchedURL)
        }
    }
}

enum SafariTabCommandError: Error, Equatable {
    case missingWindowIndex
    case missingWindowIdentifier
    case invalidWindowIndex(String)
    case invalidWindowIdentifier(String)
    case missingTabAddress
    case invalidTabAddress(String, String)
    case missingURL
    case missingJavaScript
    case multipleJavaScriptSources
    case javaScriptFileReadFailed(String)
    case resolveNoMatch(String)
    case resolveAmbiguous(String, Int)
    case javaScriptTargetWindowNotFound(Int)
    case javaScriptTargetTabNotFound(windowIdentifier: Int, tabIndex: Int)
    case javaScriptResultUnsupported(windowIdentifier: Int, tabIndex: Int)
    case javaScriptExecutionFailed(windowIdentifier: Int, tabIndex: Int)
    case unknownOption(String)
    case missingOptionValue(String)
    case unexpectedArgument(String)
}

extension SafariTabCommandError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .multipleJavaScriptSources:
            "Provide JavaScript from exactly one source: inline argument, --stdin, or --file."
        case .javaScriptFileReadFailed(let path):
            "Could not read JavaScript file \(path)."
        case .resolveNoMatch(let url):
            "No Safari tab matched URL \(url)."
        case .resolveAmbiguous(let url, let count):
            "Safari tab query for URL \(url) matched \(count) tabs."
        case .javaScriptTargetWindowNotFound(let windowIdentifier):
            "Safari window \(windowIdentifier) does not exist."
        case .javaScriptTargetTabNotFound(let windowIdentifier, let tabIndex):
            "Safari window \(windowIdentifier) does not contain tab \(tabIndex)."
        case .javaScriptResultUnsupported(let windowIdentifier, let tabIndex):
            "JavaScript result in Safari window \(windowIdentifier) tab \(tabIndex) could not be converted to text. Return a primitive value, or use JSON.stringify(...) before returning objects."
        case .javaScriptExecutionFailed(let windowIdentifier, let tabIndex):
            "Could not execute JavaScript in Safari window \(windowIdentifier) tab \(tabIndex)."
        default:
            nil
        }
    }
}
