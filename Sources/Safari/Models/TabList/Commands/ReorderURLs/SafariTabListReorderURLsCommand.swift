import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabListReorderURLsCommand: CommandModel, JSONCommandModel {
    private static let persistencePollAttempts = 30
    private static let persistencePollInterval: TimeInterval = 0.25

    public static let descriptor = CommandDescriptor(
        name: "reorder-tab-list-urls",
        abstract: "Reorder Safari tab lists to match requested URL order.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(
                name: "window-index",
                kind: .option,
                valueType: .integer,
                isRequired: false,
                valueName: "window-index"
            ),
            CommandArgumentDescriptor(
                name: "window-id",
                kind: .option,
                valueType: .integer,
                isRequired: false,
                valueName: "window-id"
            ),
            CommandArgumentDescriptor(name: "tab-group-profile", kind: .option, isRequired: false, valueName: "profile"),
            CommandArgumentDescriptor(name: "tab-group-name", kind: .option, isRequired: false, valueName: "name"),
            CommandArgumentDescriptor(name: "url", kind: .positional, isRepeating: true)
        ],
        usage: [
            .requiredAlternatives([
                [.argumentRef("window-index", isRequired: true)],
                [.argumentRef("window-id", isRequired: true)],
                [
                    .argumentRef("tab-group-profile", isRequired: true),
                    .argumentRef("tab-group-name", isRequired: true)
                ]
            ]),
            .argumentRef("url")
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let ensureTabGroup: (String, String) throws -> SafariTabGroupEnsureOperationResult
    private let listWindowTabsByIndex: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listWindowTabsByIdentifier: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listTabGroupTabs: (Int) throws -> [SafariTabGroupTabRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let openNewWindowForProfile: (String) throws -> SafariWindowRecord
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void
    private let moveTabByIndex: (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void
    private let moveTabByIdentifier: (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void
    private let deleteTabGroup: (Int) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        let listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.executor = executor
        self.ensureTabGroup = { profileName, name in
            try SafariTabGroupEnsureCommand(
                executor: executor,
                listWindows: listWindows
            )
            .ensureOperation(profileName: profileName, name: name)
        }
        self.listWindowTabsByIndex = { windowIndex, executor in
            try SafariTabList.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
        self.listWindowTabsByIdentifier = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
        }
        self.listTabGroupTabs = { identifier in
            try SafariTabList.listTabGroupTabs(tabGroupIdentifier: identifier)
        }
        self.listWindows = listWindows
        self.openNewWindowForProfile = { profileName in
            try SafariTabGroupSidebarAccess.openNewWindowForProfile(
                profileName: profileName,
                executor: executor,
                listWindows: listWindows
            )
        }
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.selectTabGroup = SafariTabGroupSidebarAccess.selectTabGroup
        self.moveTabByIndex = { windowIndex, sourceIndex, destinationIndex, executor in
            try SafariAppleScriptTab.move(
                windowIndex: windowIndex,
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex,
                executor: executor
            )
        }
        self.moveTabByIdentifier = { windowIdentifier, sourceIndex, destinationIndex, executor in
            try SafariAppleScriptTab.move(
                windowIdentifier: windowIdentifier,
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex,
                executor: executor
            )
        }
        self.deleteTabGroup = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        ensureTabGroup: @escaping (String, String) throws -> SafariTabGroupEnsureOperationResult,
        listWindowTabs: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord],
        listWindowTabsByIdentifier: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord] = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
        },
        listTabGroupTabs: @escaping (Int) throws -> [SafariTabGroupTabRecord],
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        openNewWindowForProfile: @escaping (String) throws -> SafariWindowRecord = {
            throw SafariTabGroupCommandError.windowForProfileNotFound($0)
        },
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = { _, _ in },
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        moveTab: @escaping (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void = { windowIndex, sourceIndex, destinationIndex, executor in
            try SafariAppleScriptTab.move(
                windowIndex: windowIndex,
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex,
                executor: executor
            )
        },
        moveTabByIdentifier: @escaping (Int, Int, Int, SafariAppleScriptExecuting) throws -> Void = { windowIdentifier, sourceIndex, destinationIndex, executor in
            try SafariAppleScriptTab.move(
                windowIdentifier: windowIdentifier,
                sourceIndex: sourceIndex,
                destinationIndex: destinationIndex,
                executor: executor
            )
        },
        deleteTabGroup: @escaping (Int) throws -> Void = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        },
        sleep: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.executor = executor
        self.ensureTabGroup = ensureTabGroup
        self.listWindowTabsByIndex = listWindowTabs
        self.listWindowTabsByIdentifier = listWindowTabsByIdentifier
        self.listTabGroupTabs = listTabGroupTabs
        self.listWindows = listWindows
        self.openNewWindowForProfile = openNewWindowForProfile
        self.closeWindow = closeWindow
        self.selectTabGroup = selectTabGroup
        self.moveTabByIndex = moveTab
        self.moveTabByIdentifier = moveTabByIdentifier
        self.deleteTabGroup = deleteTabGroup
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
        case .window(let address):
            let tabs = try listWindowTabs(for: address).map(SafariTabListReorderItem.init)
            let result = try reorder(windowAddress: address, tabs: tabs, requestedURLs: request.urls)
            return SafariTabListReorderURLsSummary(
                context: SafariTabListContext(
                    kind: .window,
                    windowIndex: address.windowIndex,
                    windowIdentifier: address.windowIdentifier
                ),
                moved: result.moved,
                unchanged: result.unchanged,
                missingURLs: result.missingURLs,
                extra: result.extra
            )
        case .tabGroup(let profileName, let name):
            let ensureResult = try ensureTabGroup(profileName, name)
            let context = try SafariSavedTabGroupMutationContext.prepare(
                ensureResult: ensureResult,
                openNewWindowForProfile: openNewWindowForProfile
            )
            do {
                return try reorderTabGroupURLs(context: context, requestedURLs: request.urls)
            } catch {
                try context.rollback(
                    deleteTabGroup: deleteTabGroup,
                    closeWindow: { try closeWindow($0, executor) }
                )
                throw error
            }
        }
    }

    private func reorderTabGroupURLs(
        context: SafariSavedTabGroupMutationContext,
        requestedURLs: [String]
    ) throws -> SafariTabListReorderURLsSummary {
        let tabGroupSummary = context.summary
        let tabGroup = tabGroupSummary.tabGroup
        let window = context.window
        try selectTabGroup(tabGroup, executor)

        let windowAddress = SafariWindowAddress.identifier(window.identifier)
        let tabs = try SafariSavedTabGroupWindowReadiness.waitForLoadedTabs(
            tabGroup: tabGroup,
            windowIdentifier: window.identifier,
            listWindows: listWindows,
            listWindowTabs: {
                try listWindowTabs(for: windowAddress)
            },
            listTabGroupTabs: {
                try listTabGroupTabs(tabGroup.identifier)
            },
            sleep: sleep
        )
        .map(SafariTabListReorderItem.init)
        let result = try reorder(windowAddress: windowAddress, tabs: tabs, requestedURLs: requestedURLs)
        try verifySavedTabGroupOrder(
            tabGroupIdentifier: tabGroup.identifier,
            expectedURLs: result.finalURLs,
            movedCount: result.moved.count
        )

        return SafariTabListReorderURLsSummary(
            context: SafariTabListContext(
                kind: .tabGroup,
                windowIndex: window.index,
                windowIdentifier: window.identifier,
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

    private func listWindowTabs(for address: SafariWindowAddress) throws -> [SafariWindowTabRecord] {
        switch address {
        case .index(let windowIndex):
            try listWindowTabsByIndex(windowIndex, executor)
        case .identifier(let windowIdentifier):
            try listWindowTabsByIdentifier(windowIdentifier, executor)
        }
    }

    private func moveTab(in address: SafariWindowAddress, sourceIndex: Int, destinationIndex: Int) throws {
        switch address {
        case .index(let windowIndex):
            try moveTabByIndex(windowIndex, sourceIndex, destinationIndex, executor)
        case .identifier(let windowIdentifier):
            try moveTabByIdentifier(windowIdentifier, sourceIndex, destinationIndex, executor)
        }
    }

    private func reorder(
        windowAddress: SafariWindowAddress,
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

            try moveTab(in: windowAddress, sourceIndex: sourceIndex, destinationIndex: destinationIndex)
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

        let normalizedExpectedURLs = expectedURLs.map(normalizedSavedTabGroupURL)
        for attempt in 0..<Self.persistencePollAttempts {
            let storedURLs = try listTabGroupTabs(tabGroupIdentifier).map(\.url)
            if storedURLs == normalizedExpectedURLs {
                return
            }

            if attempt < Self.persistencePollAttempts - 1 {
                sleep(Self.persistencePollInterval)
            }
        }

        throw SafariTabListCommandError.savedTabGroupOrderPersistenceNotVerified(tabGroupIdentifier)
    }

    private func normalizedSavedTabGroupURL(_ url: String) -> String {
        url == "favorites://" ? "" : url
    }

    private func format(_ summary: SafariTabListReorderURLsSummary) -> String {
        var lines = ["Safari tab list URLs reordered."]

        switch summary.context.kind {
        case .window:
            if let windowIdentifier = summary.context.windowIdentifier, summary.context.windowIndex == nil {
                lines.append("context|window-id|\(windowIdentifier)")
            } else {
                lines.append("context|window|\(summary.context.windowIndex.map(String.init) ?? "")")
            }
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
    let context: SafariTabListAddressedURLsArguments.Context
    let urls: [String]

    static func parse(_ arguments: [String]) throws -> SafariTabListReorderURLsRequest {
        let parsed = try SafariTabListAddressedURLsArguments.parse(arguments)
        return SafariTabListReorderURLsRequest(context: parsed.context, urls: parsed.urls)
    }
}
