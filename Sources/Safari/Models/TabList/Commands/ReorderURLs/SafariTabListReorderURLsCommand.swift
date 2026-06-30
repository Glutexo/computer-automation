import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabListReorderURLsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "reorder-tab-list-urls",
        abstract: "Reorder Safari tab lists to match requested URL order.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-group-profile", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-group-name", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "url", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let ensureTabGroup: (String, String) throws -> SafariTabGroupEnsureSummary
    private let listWindowTabs: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listTabGroupTabs: (Int) throws -> [SafariTabGroupTabRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (String, SafariAppleScriptExecuting) throws -> Void
    private let moveTab: (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        self.executor = executor
        self.ensureTabGroup = { profileName, name in
            try SafariTabGroupEnsureCommand(
                executor: executor,
                listWindows: { try SafariWindow.list(executor: executor) }
            )
            .ensure(profileName: profileName, name: name)
        }
        self.listWindowTabs = { windowIndex, executor in
            try SafariTabList.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
        self.listTabGroupTabs = { identifier in
            try SafariTabList.listTabGroupTabs(tabGroupIdentifier: identifier)
        }
        self.listWindows = { try SafariWindow.list(executor: executor) }
        self.focusWindow = SafariAppleScriptWindow.focus(windowIdentifier:executor:)
        self.openWindow = { profileName, _ in
            try SafariFileMenu.openWindow(profileName: profileName)
        }
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.moveTab = SafariAppleScriptTab.move
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        ensureTabGroup: @escaping (String, String) throws -> SafariTabGroupEnsureSummary,
        listWindowTabs: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord],
        listTabGroupTabs: @escaping (Int) throws -> [SafariTabGroupTabRecord],
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        selectTabGroup: @escaping (String, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        moveTab: @escaping (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptTab.move,
        sleep: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.executor = executor
        self.ensureTabGroup = ensureTabGroup
        self.listWindowTabs = listWindowTabs
        self.listTabGroupTabs = listTabGroupTabs
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.selectTabGroup = selectTabGroup
        self.moveTab = moveTab
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try format(reorderURLs(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(reorderURLs(arguments: arguments))
    }

    private func reorderURLs(arguments: [String]) throws -> SafariTabListReorderURLsSummary {
        let request = try SafariTabListReorderURLsRequest.parse(arguments)

        switch request.context {
        case .window(let windowIndex):
            let tabs = try listWindowTabs(windowIndex, executor).map(SafariTabListReorderItem.init)
            let result = try reorder(windowIndex: windowIndex, tabs: tabs, requestedURLs: request.urls)
            return SafariTabListReorderURLsSummary(
                context: SafariTabListContext(kind: .window, windowIndex: windowIndex),
                moved: result.moved,
                unchanged: result.unchanged,
                missingURLs: result.missingURLs,
                extra: result.extra
            )
        case .tabGroup(let profileName, let name):
            let tabGroupSummary = try ensureTabGroup(profileName, name)
            let tabGroup = tabGroupSummary.tabGroup
            let window = try SafariTabGroupSidebarAccess.focusWindowForTabGroup(
                tabGroup,
                executor: executor,
                listWindows: listWindows,
                focusWindow: focusWindow,
                openWindow: openWindow
            )
            try selectTabGroup(tabGroup.name, executor)

            let tabs = try listWindowTabs(window.index, executor).map(SafariTabListReorderItem.init)
            let result = try reorder(windowIndex: window.index, tabs: tabs, requestedURLs: request.urls)
            try verifySavedTabGroupOrder(
                tabGroupIdentifier: tabGroup.identifier,
                expectedURLs: result.finalURLs,
                movedCount: result.moved.count
            )

            return SafariTabListReorderURLsSummary(
                context: SafariTabListContext(
                    kind: .tabGroup,
                    windowIndex: window.index,
                    tabGroupIdentifier: tabGroup.identifier,
                    profileName: tabGroup.profileName,
                    name: tabGroup.name
                ),
                tabGroup: tabGroupSummary,
                moved: result.moved,
                unchanged: result.unchanged,
                missingURLs: result.missingURLs,
                extra: result.extra
            )
        }
    }

    private func reorder(
        windowIndex: Int,
        tabs: [SafariTabListReorderItem],
        requestedURLs: [String]
    ) throws -> SafariTabListReorderResult {
        var matchedItems: [SafariTabListReorderItem] = []
        var usedIdentifiers = Set<Int>()
        var missingURLs: [String] = []

        for url in requestedURLs {
            guard !url.isEmpty else {
                throw SafariTabListCommandError.emptyURL
            }

            if let item = tabs.first(where: { $0.url == url && !usedIdentifiers.contains($0.identifier) }) {
                matchedItems.append(item)
                usedIdentifiers.insert(item.identifier)
            } else {
                missingURLs.append(url)
            }
        }

        var currentItems = tabs
        var moved: [SafariTabListReorderURLMove] = []
        var unchanged: [SafariTabListReorderURLRecord] = []

        for (offset, item) in matchedItems.enumerated() {
            let destinationIndex = offset + 1
            guard let currentOffset = currentItems.firstIndex(where: { $0.identifier == item.identifier }) else {
                continue
            }

            let sourceIndex = currentOffset + 1
            if sourceIndex == destinationIndex {
                unchanged.append(SafariTabListReorderURLRecord(url: item.url, index: destinationIndex))
                continue
            }

            try moveTab(windowIndex, sourceIndex, destinationIndex, executor)
            moved.append(
                SafariTabListReorderURLMove(
                    url: item.url,
                    fromIndex: sourceIndex,
                    toIndex: destinationIndex
                )
            )

            currentItems.remove(at: currentOffset)
            currentItems.insert(item, at: destinationIndex - 1)
        }

        let extra = currentItems.enumerated().compactMap { offset, item in
            usedIdentifiers.contains(item.identifier)
                ? nil
                : SafariTabListReorderURLRecord(url: item.url, index: offset + 1)
        }

        return SafariTabListReorderResult(
            moved: moved,
            unchanged: unchanged,
            missingURLs: missingURLs,
            extra: extra,
            finalURLs: currentItems.map(\.url)
        )
    }

    private func verifySavedTabGroupOrder(
        tabGroupIdentifier: Int,
        expectedURLs: [String],
        movedCount: Int
    ) throws {
        guard movedCount > 0 else {
            return
        }

        for attempt in 0..<10 {
            let storedURLs = try listTabGroupTabs(tabGroupIdentifier).map(\.url)
            if storedURLs == expectedURLs {
                return
            }

            if attempt < 9 {
                sleep(0.1)
            }
        }

        throw SafariTabListCommandError.savedTabGroupOrderPersistenceNotVerified(tabGroupIdentifier)
    }

    private func format(_ summary: SafariTabListReorderURLsSummary) -> String {
        var lines = ["Safari tab list URLs reordered."]

        switch summary.context.kind {
        case .window:
            lines.append("context|window|\(summary.context.windowIndex.map(String.init) ?? "")")
        case .tabGroup:
            lines.append(
                [
                    "context",
                    "tab-group",
                    summary.context.tabGroupIdentifier.map(String.init) ?? "",
                    summary.context.profileName ?? "",
                    summary.context.name ?? "",
                    summary.context.windowIndex.map(String.init) ?? ""
                ].joined(separator: "|")
            )
        }

        if let tabGroup = summary.tabGroup {
            lines.append(
                [
                    "tab-group",
                    tabGroup.status.rawValue,
                    String(tabGroup.tabGroup.identifier),
                    tabGroup.tabGroup.profileName,
                    tabGroup.tabGroup.name
                ].joined(separator: "|")
            )
        }

        lines += summary.moved.map { "moved|\($0.url)|\($0.fromIndex)|\($0.toIndex)" }
        lines += summary.unchanged.map { "unchanged|\($0.url)|\($0.index)" }
        lines += summary.missingURLs.map { "missing|\($0)" }
        lines += summary.extra.map { "extra|\($0.url)|\($0.index)" }
        return lines.joined(separator: "\n")
    }
}

private struct SafariTabListReorderResult {
    let moved: [SafariTabListReorderURLMove]
    let unchanged: [SafariTabListReorderURLRecord]
    let missingURLs: [String]
    let extra: [SafariTabListReorderURLRecord]
    let finalURLs: [String]
}

private struct SafariTabListReorderItem: Equatable {
    let identifier: Int
    let url: String

    init(_ record: SafariWindowTabRecord) {
        self.identifier = record.index
        self.url = record.url
    }
}

private struct SafariTabListReorderURLsRequest: Equatable {
    enum Context: Equatable {
        case window(Int)
        case tabGroup(profileName: String, name: String)
    }

    let context: Context
    let urls: [String]

    static func parse(_ arguments: [String]) throws -> SafariTabListReorderURLsRequest {
        var windowIndex: Int?
        var tabGroupProfile: String?
        var tabGroupName: String?
        var urls: [String] = []

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--window-index":
                let rawValue = try optionValue(after: argument, in: arguments, at: &index)
                guard let value = Int(rawValue), value > 0 else {
                    throw SafariTabCommandError.invalidWindowIndex(rawValue)
                }
                windowIndex = value
            case "--tab-group-profile":
                tabGroupProfile = try optionValue(after: argument, in: arguments, at: &index)
            case "--tab-group-name":
                tabGroupName = try optionValue(after: argument, in: arguments, at: &index)
            default:
                if let rawValue = argument.optionValue(prefix: "--window-index=") {
                    guard !rawValue.isEmpty else {
                        throw SafariTabListCommandError.missingOptionValue("--window-index")
                    }
                    guard let value = Int(rawValue), value > 0 else {
                        throw SafariTabCommandError.invalidWindowIndex(rawValue)
                    }
                    windowIndex = value
                } else if let value = argument.optionValue(prefix: "--tab-group-profile=") {
                    tabGroupProfile = value
                } else if let value = argument.optionValue(prefix: "--tab-group-name=") {
                    tabGroupName = value
                } else if argument.hasPrefix("--") {
                    throw SafariTabListCommandError.unknownOption(argument)
                } else {
                    urls.append(argument)
                }
            }

            index += 1
        }

        guard !urls.isEmpty else {
            throw SafariTabListCommandError.missingURL
        }

        if windowIndex != nil && (tabGroupProfile != nil || tabGroupName != nil) {
            throw SafariTabListCommandError.multipleContexts
        }

        if let windowIndex {
            return SafariTabListReorderURLsRequest(context: .window(windowIndex), urls: urls)
        }

        guard let tabGroupProfile else {
            throw tabGroupName == nil ? SafariTabListCommandError.missingContext : SafariTabListCommandError.missingTabGroupProfile
        }
        guard !tabGroupProfile.isEmpty else {
            throw SafariTabListCommandError.emptyTabGroupProfile
        }

        guard let tabGroupName else {
            throw SafariTabListCommandError.missingTabGroupName
        }
        guard !tabGroupName.isEmpty else {
            throw SafariTabListCommandError.emptyTabGroupName
        }

        return SafariTabListReorderURLsRequest(
            context: .tabGroup(profileName: tabGroupProfile, name: tabGroupName),
            urls: urls
        )
    }

    private static func optionValue(after option: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
            throw SafariTabListCommandError.missingOptionValue(option)
        }

        index = valueIndex
        return arguments[valueIndex]
    }
}

private extension String {
    func optionValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }

        return String(dropFirst(prefix.count))
    }
}
