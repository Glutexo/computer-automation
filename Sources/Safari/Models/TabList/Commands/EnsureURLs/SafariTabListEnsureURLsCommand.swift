import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabListEnsureURLsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "ensure-tab-list-urls",
        abstract: "Ensure requested URLs exist in a Safari tab list.",
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
    private let ensureTabGroup: (
        String,
        String,
        (SafariWindowRecord) throws -> Void
    ) throws -> SafariTabGroupEnsureOperationResult
    private let listWindowTabsByIndex: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listWindowTabsByIdentifier: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listTabGroupTabs: (Int) throws -> [SafariTabGroupTabRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let openNewWindowForProfile: (String) throws -> SafariWindowRecord
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let focusWindowInProcess: (Int, pid_t, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, pid_t?, SafariAppleScriptExecuting) throws -> Void
    private let openTabByIndex: (Int, String?, SafariAppleScriptExecuting) throws -> Void
    private let openTabByIdentifier: (Int, String?, SafariAppleScriptExecuting) throws -> Void
    private let setTabURLByIdentifier: (Int, Int, String, SafariAppleScriptExecuting) throws -> Void
    private let deleteTabGroup: (Int) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        let executor = SafariAppleScriptExecutor()
        let listWindows = { try SafariWindow.listForAutomation(executor: executor) }
        self.executor = executor
        self.ensureTabGroup = { profileName, name, prepareNewWindow in
            try SafariTabGroupEnsureCommand(
                executor: executor,
                listWindows: listWindows
            )
            .ensureOperation(
                profileName: profileName,
                name: name,
                prepareNewWindow: prepareNewWindow
            )
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
        self.focusWindowInProcess = { windowIdentifier, processIdentifier, _ in
            try SafariAppleScriptWindow.focus(
                windowIdentifier: windowIdentifier,
                processIdentifier: processIdentifier
            )
        }
        self.selectTabGroup = { group, processIdentifier, executor in
            try SafariTabGroupSidebarAccess.selectTabGroup(
                group,
                processIdentifier: processIdentifier,
                executor: executor
            )
        }
        self.openTabByIndex = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        }
        self.openTabByIdentifier = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        }
        self.setTabURLByIdentifier = SafariAppleScriptTab.setURL(windowIdentifier:tabIndex:url:executor:)
        self.deleteTabGroup = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        }
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        ensureTabGroup: @escaping (String, String) throws -> SafariTabGroupEnsureOperationResult,
        ensureTabGroupWithPreparation: ((String, String, (SafariWindowRecord) throws -> Void) throws -> SafariTabGroupEnsureOperationResult)? = nil,
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
        focusWindowInProcess: @escaping (Int, pid_t, SafariAppleScriptExecuting) throws -> Void = { _, _, _ in },
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        selectTabGroupInProcess: ((SafariTabGroupRecord, pid_t?, SafariAppleScriptExecuting) throws -> Void)? = nil,
        openTab: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        },
        openTabByIdentifier: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        },
        setTabURLByIdentifier: @escaping (Int, Int, String, SafariAppleScriptExecuting) throws -> Void = { _, _, _, _ in },
        deleteTabGroup: @escaping (Int) throws -> Void = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        },
        sleep: @escaping (TimeInterval) -> Void = { _ in }
    ) {
        self.executor = executor
        self.ensureTabGroup = ensureTabGroupWithPreparation ?? { profileName, name, _ in
            try ensureTabGroup(profileName, name)
        }
        self.listWindowTabsByIndex = listWindowTabs
        self.listWindowTabsByIdentifier = listWindowTabsByIdentifier
        self.listTabGroupTabs = listTabGroupTabs
        self.listWindows = listWindows
        self.openNewWindowForProfile = openNewWindowForProfile
        self.closeWindow = closeWindow
        self.focusWindowInProcess = focusWindowInProcess
        self.selectTabGroup = selectTabGroupInProcess ?? { group, _, executor in
            try selectTabGroup(group, executor)
        }
        self.openTabByIndex = openTab
        self.openTabByIdentifier = openTabByIdentifier
        self.setTabURLByIdentifier = setTabURLByIdentifier
        self.deleteTabGroup = deleteTabGroup
        self.sleep = sleep
    }

    public func execute(arguments: [String]) throws -> String {
        try format(ensureURLs(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(ensureURLs(arguments: arguments))
    }

    private func ensureURLs(arguments: [String]) throws -> SafariTabListEnsureURLsSummary {
        let request = try SafariTabListEnsureURLsRequest.parse(arguments)
        try validate(requestedURLs: request.urls)

        switch request.context {
        case .window(let address):
            let existingURLs = try listWindowTabs(for: address).map(\.url)
            let result = try reconcile(requestedURLs: request.urls, existingURLs: existingURLs) { url in
                try openTab(in: address, url: url)
            }

            return SafariTabListEnsureURLsSummary(
                context: SafariTabListContext(
                    kind: .window,
                    windowIndex: address.windowIndex,
                    windowIdentifier: address.windowIdentifier
                ),
                addedURLs: result.addedURLs,
                skippedURLs: result.skippedURLs
            )
        case .tabGroup(let profileName, let name):
            var seededChanges: SafariTabListEnsureURLChanges?
            let ensureResult = try ensureTabGroup(profileName, name) { window in
                seededChanges = try seedNewTabGroupWindow(
                    window,
                    requestedURLs: request.urls
                )
            }
            let context = try SafariSavedTabGroupMutationContext.prepare(
                ensureResult: ensureResult,
                openNewWindowForProfile: openNewWindowForProfile
            )
            do {
                return try ensureTabGroupURLs(
                    context: context,
                    requestedURLs: request.urls,
                    seededChanges: seededChanges
                )
            } catch {
                try context.rollback(
                    deleteTabGroup: deleteTabGroup,
                    closeWindow: { try closeWindow($0, executor) }
                )
                throw error
            }
        }
    }

    private func ensureTabGroupURLs(
        context: SafariSavedTabGroupMutationContext,
        requestedURLs: [String],
        seededChanges: SafariTabListEnsureURLChanges?
    ) throws -> SafariTabListEnsureURLsSummary {
        let tabGroupSummary = context.summary
        let tabGroup = tabGroupSummary.tabGroup
        let window = context.window
        if tabGroupSummary.status == .reused || seededChanges == nil {
            try selectTabGroup(tabGroup, window.processId, executor)
        }

        let loadedTabs = try SafariSavedTabGroupWindowReadiness.waitForLoadedTabs(
            tabGroup: tabGroup,
            windowIdentifier: window.identifier,
            listWindows: listWindows,
            listWindowTabs: {
                try listWindowTabs(for: .identifier(window.identifier))
            },
            listTabGroupTabs: {
                try listTabGroupTabs(tabGroup.identifier)
            },
            sleep: sleep
        )
        let existingURLs = loadedTabs.map(\.url)
        let reconciliation = try reconcile(requestedURLs: requestedURLs, existingURLs: existingURLs) { url in
            try openTabByIdentifier(window.identifier, url, executor)
        }
        let result = mergedChanges(
            seededChanges: seededChanges,
            reconciliation: reconciliation
        )

        return SafariTabListEnsureURLsSummary(
            context: SafariTabListContext(
                kind: .tabGroup,
                windowIndex: window.index,
                windowIdentifier: window.identifier,
                tabGroupIdentifier: tabGroup.identifier,
                profileName: tabGroup.profileName,
                name: tabGroup.name
            ),
            tabGroup: tabGroupSummary,
            addedURLs: result.addedURLs,
            skippedURLs: result.skippedURLs
        )
    }

    private func seedNewTabGroupWindow(
        _ window: SafariWindowRecord,
        requestedURLs: [String]
    ) throws -> SafariTabListEnsureURLChanges {
        if let processIdentifier = window.processId {
            try focusWindowInProcess(
                window.identifier,
                processIdentifier,
                executor
            )
        }
        let existingTabs = try listWindowTabs(for: .identifier(window.identifier))
        var replaceableTabIndex = existingTabs.count == 1 && isStartPageURL(existingTabs[0].url)
            ? existingTabs[0].index
            : nil

        return try reconcile(
            requestedURLs: requestedURLs,
            existingURLs: existingTabs.map(\.url)
        ) { url in
            if let tabIndex = replaceableTabIndex {
                try setTabURLByIdentifier(
                    window.identifier,
                    tabIndex,
                    url,
                    executor
                )
                replaceableTabIndex = nil
            } else {
                try openTabByIdentifier(window.identifier, url, executor)
            }
        }
    }

    private func isStartPageURL(_ url: String) -> Bool {
        url.isEmpty || url == "favorites://"
    }

    private func mergedChanges(
        seededChanges: SafariTabListEnsureURLChanges?,
        reconciliation: SafariTabListEnsureURLChanges
    ) -> SafariTabListEnsureURLChanges {
        guard let seededChanges else {
            return reconciliation
        }

        var addedURLs = seededChanges.addedURLs
        for url in reconciliation.addedURLs where !addedURLs.contains(url) {
            addedURLs.append(url)
        }

        return SafariTabListEnsureURLChanges(
            addedURLs: addedURLs,
            skippedURLs: seededChanges.skippedURLs
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

    private func openTab(in address: SafariWindowAddress, url: String) throws {
        switch address {
        case .index(let windowIndex):
            try openTabByIndex(windowIndex, url, executor)
        case .identifier(let windowIdentifier):
            try openTabByIdentifier(windowIdentifier, url, executor)
        }
    }

    private func reconcile(
        requestedURLs: [String],
        existingURLs: [String],
        addURL: (String) throws -> Void
    ) throws -> SafariTabListEnsureURLChanges {
        var knownURLs = Set(existingURLs)
        var addedURLs: [String] = []
        var skippedURLs: [String] = []

        for url in requestedURLs {
            guard !url.isEmpty else {
                throw SafariTabListCommandError.emptyURL
            }

            if knownURLs.contains(url) {
                skippedURLs.append(url)
                continue
            }

            try addURL(url)
            knownURLs.insert(url)
            addedURLs.append(url)
        }

        return SafariTabListEnsureURLChanges(addedURLs: addedURLs, skippedURLs: skippedURLs)
    }

    private func validate(requestedURLs: [String]) throws {
        if requestedURLs.contains(where: \.isEmpty) {
            throw SafariTabListCommandError.emptyURL
        }
    }

    private func format(_ summary: SafariTabListEnsureURLsSummary) -> String {
        var lines = ["Safari tab list URLs ensured."]

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

        lines += summary.addedURLs.map { "added|\($0)" }
        lines += summary.skippedURLs.map { "skipped|\($0)" }
        return lines.joined(separator: "\n")
    }
}

private struct SafariTabListEnsureURLChanges {
    let addedURLs: [String]
    let skippedURLs: [String]
}

private struct SafariTabListEnsureURLsRequest: Equatable {
    let context: SafariTabListAddressedURLsArguments.Context
    let urls: [String]

    static func parse(_ arguments: [String]) throws -> SafariTabListEnsureURLsRequest {
        let parsed = try SafariTabListAddressedURLsArguments.parse(arguments)
        return SafariTabListEnsureURLsRequest(context: parsed.context, urls: parsed.urls)
    }
}
