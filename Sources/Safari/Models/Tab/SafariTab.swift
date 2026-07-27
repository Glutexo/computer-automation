import AppKit
import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabRecord: Equatable, Sendable, Encodable {
    public let processId: pid_t?
    public let windowIdentifier: Int
    public let windowIndex: Int
    public let index: Int
    public let url: String
    public let title: String

    public init(processId: pid_t? = nil, windowIdentifier: Int, windowIndex: Int, index: Int, url: String, title: String = "") {
        self.processId = processId
        self.windowIdentifier = windowIdentifier
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

enum SafariWindowAddress: Equatable, Sendable {
    case index(Int)
    case identifier(Int)

    var windowIndex: Int? {
        switch self {
        case .index(let value):
            value
        case .identifier:
            nil
        }
    }

    var windowIdentifier: Int? {
        switch self {
        case .index:
            nil
        case .identifier(let value):
            value
        }
    }

    var displayName: String {
        switch self {
        case .index(let value):
            "window \(value)"
        case .identifier(let value):
            "window id \(value)"
        }
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
            SafariTabRecord(
                windowIdentifier: $0.windowIdentifier,
                windowIndex: $0.windowIndex,
                index: $0.index,
                url: $0.url,
                title: $0.title
            )
        }
    }

    static func listAcrossRunningProcesses(
        isRunning: () -> Bool = SafariApplication.isRunning,
        discoverWindows: () throws -> [SafariProcessWindowRecord] = { try SafariProcessWindowDiscovery.list() },
        listTabs: (pid_t, Set<Int>) throws -> [SafariAppleScriptTabRecord] = { processIdentifier, windowIdentifiers in
            try SafariAppleScriptTab.list(
                processIdentifier: processIdentifier,
                windowIdentifiers: windowIdentifiers
            )
        }
    ) throws -> [SafariTabRecord] {
        guard isRunning() else {
            return []
        }

        let windows = try discoverWindows()
        let globalWindowIndexes = Dictionary(
            uniqueKeysWithValues: windows.enumerated().map {
                (SafariProcessWindowKey(processIdentifier: $0.element.processIdentifier, windowIdentifier: $0.element.window.identifier), $0.offset + 1)
            }
        )
        var visitedProcesses: Set<pid_t> = []
        let windowIdentifiersByProcess = Dictionary(grouping: windows, by: \.processIdentifier)
            .mapValues { Set($0.map(\.window.identifier)) }

        return try windows.flatMap { window -> [SafariTabRecord] in
            guard visitedProcesses.insert(window.processIdentifier).inserted else {
                return []
            }

            let windowIdentifiers = windowIdentifiersByProcess[window.processIdentifier] ?? []
            return try listTabs(window.processIdentifier, windowIdentifiers).compactMap { tab in
                let key = SafariProcessWindowKey(
                    processIdentifier: window.processIdentifier,
                    windowIdentifier: tab.windowIdentifier
                )
                guard let windowIndex = globalWindowIndexes[key] else {
                    return nil
                }

                return SafariTabRecord(
                    processId: window.processIdentifier,
                    windowIdentifier: tab.windowIdentifier,
                    windowIndex: windowIndex,
                    index: tab.index,
                    url: tab.url,
                    title: tab.title
                )
            }
        }
    }

    static func listForAutomation(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariTabRecord] {
        try listForAutomation(
            executor: executor,
            listAcrossRunningProcesses: { try listAcrossRunningProcesses() },
            listLegacy: { try list(executor: $0) }
        )
    }

    static func listForAutomation(
        executor: SafariAppleScriptExecuting,
        listAcrossRunningProcesses: () throws -> [SafariTabRecord],
        listLegacy: (SafariAppleScriptExecuting) throws -> [SafariTabRecord]
    ) throws -> [SafariTabRecord] {
        do {
            return try listAcrossRunningProcesses()
        } catch SafariUserInterfaceError.windowListUnavailable {
            return try listLegacy(executor)
        }
    }

    static func parseTabList(_ descriptor: NSAppleEventDescriptor?) -> [SafariTabRecord] {
        SafariAppleScriptTab.parseTabList(descriptor).map {
            SafariTabRecord(
                windowIdentifier: $0.windowIdentifier,
                windowIndex: $0.windowIndex,
                index: $0.index,
                url: $0.url,
                title: $0.title
            )
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
            try SafariTab.listForAutomation(executor: executor)
        },
        listWindows: (SafariAppleScriptExecuting) throws -> [SafariWindowRecord] = { executor in
            try SafariWindow.listForAutomation(executor: executor)
        }
    ) throws -> [SafariTabMatchRecord] {
        guard isRunning() else {
            return []
        }

        let windowsByIdentifier = Dictionary(uniqueKeysWithValues: try listWindows(executor).map { ($0.identifier, $0) })
        return try listTabs(executor).compactMap { tab in
            guard
                tab.matches(url: url, mode: matchMode),
                windowIdentifier.map({ $0 == tab.windowIdentifier }) ?? true,
                windowIndex.map({ $0 == tab.windowIndex }) ?? true,
                profileName.map({ $0 == windowsByIdentifier[tab.windowIdentifier]?.profileName }) ?? true
            else {
                return nil
            }

            return SafariTabMatchRecord(
                windowIdentifier: tab.windowIdentifier,
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
        listTabsByIdentifier: (Int, SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowTabRecord] = { windowIdentifier, executor in
            try SafariAppleScriptTab.list(windowIdentifier: windowIdentifier, executor: executor)
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
        return try listWindowTabs(
            windowIdentifier: windowIdentifier,
            executor: executor,
            databasePath: databasePath,
            isRunning: { true },
            listTabs: listTabsByIdentifier,
            loadWindowStates: loadWindowStates,
            loadTabGroupTabs: loadTabGroupTabs
        )
    }

    static func listWindowTabs(
        windowIdentifier: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        databasePath: String = SafariProfile.databasePath(),
        isRunning: () -> Bool = { SafariApplication.isRunning() },
        listTabs: (Int, SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowTabRecord] = { windowIdentifier, executor in
            try SafariAppleScriptTab.list(windowIdentifier: windowIdentifier, executor: executor)
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

        let liveTabs = try listTabs(windowIdentifier, executor)
            .map {
                SafariTabRecord(
                    windowIdentifier: windowIdentifier,
                    windowIndex: 0,
                    index: $0.index,
                    url: $0.url,
                    title: $0.title
                )
            }

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

private struct SafariProcessWindowKey: Hashable {
    let processIdentifier: pid_t
    let windowIdentifier: Int
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
        case .missingWindowIndex:
            "Missing Safari window index. Provide a positive window index or --window-id; run the command with --help for usage."
        case .missingWindowIdentifier:
            "Missing value for --window-id. Provide a positive Safari window identifier."
        case .invalidWindowIndex(let value):
            "Invalid Safari window index \(value). Use a positive integer."
        case .invalidWindowIdentifier(let value):
            "Invalid Safari window identifier \(value). Use a positive integer."
        case .missingTabAddress:
            "Missing Safari tab index. Provide a positive tab index; run the command with --help for usage."
        case .invalidTabAddress(let windowValue, let tabValue):
            "Invalid Safari tab address \(windowValue), \(tabValue). Window and tab indexes must be positive integers."
        case .missingURL:
            "Missing URL. Run the command with --help for usage."
        case .missingJavaScript:
            "Missing JavaScript source. Provide inline JavaScript, --stdin, or --file."
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
        case .unknownOption(let option):
            "Unknown option \(option). Run the command with --help for supported options."
        case .missingOptionValue(let option):
            "Missing value for option \(option)."
        case .unexpectedArgument(let argument):
            "Unexpected argument \(argument). Run the command with --help for usage."
        }
    }
}
