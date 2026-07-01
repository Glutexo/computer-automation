import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariTabListEnsureURLsCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "ensure-tab-list-urls",
        abstract: "Ensure requested URLs exist in a Safari tab list.",
        operation: .update,
        arguments: [
            CommandArgumentDescriptor(name: "window-index", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "window-id", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-group-profile", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "tab-group-name", kind: .option, isRequired: false),
            CommandArgumentDescriptor(name: "url", kind: .positional)
        ]
    )

    private let executor: SafariAppleScriptExecuting
    private let ensureTabGroup: (String, String) throws -> SafariTabGroupEnsureSummary
    private let listWindowTabsByIndex: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listWindowTabsByIdentifier: (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord]
    private let listTabGroupTabs: (Int) throws -> [SafariTabGroupTabRecord]
    private let listWindows: () throws -> [SafariWindowRecord]
    private let focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    private let selectTabGroup: (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void
    private let openTabByIndex: (Int, String?, SafariAppleScriptExecuting) throws -> Void
    private let openTabByIdentifier: (Int, String?, SafariAppleScriptExecuting) throws -> Void
    private let deleteTabGroup: (Int) throws -> Void

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
        self.listWindowTabsByIndex = { windowIndex, executor in
            try SafariTabList.listWindowTabs(windowIndex: windowIndex, executor: executor)
        }
        self.listWindowTabsByIdentifier = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
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
        self.openTabByIndex = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        }
        self.openTabByIdentifier = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        }
        self.deleteTabGroup = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        }
    }

    init(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor(),
        ensureTabGroup: @escaping (String, String) throws -> SafariTabGroupEnsureSummary,
        listWindowTabs: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord],
        listWindowTabsByIdentifier: @escaping (Int, SafariAppleScriptExecuting) throws -> [SafariWindowTabRecord] = { windowIdentifier, executor in
            try SafariTabList.listWindowTabs(windowIdentifier: windowIdentifier, executor: executor)
        },
        listTabGroupTabs: @escaping (Int) throws -> [SafariTabGroupTabRecord],
        listWindows: @escaping () throws -> [SafariWindowRecord] = { try SafariWindow.list() },
        focusWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.focus(windowIdentifier:executor:),
        openWindow: @escaping (String?, SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openWindow,
        selectTabGroup: @escaping (SafariTabGroupRecord, SafariAppleScriptExecuting) throws -> Void = SafariTabGroupSidebarAccess.selectTabGroup,
        openTab: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIndex, url, executor in
            try SafariAppleScriptTab.open(windowIndex: windowIndex, url: url, executor: executor)
        },
        openTabByIdentifier: @escaping (Int, String?, SafariAppleScriptExecuting) throws -> Void = { windowIdentifier, url, executor in
            try SafariAppleScriptTab.open(windowIdentifier: windowIdentifier, url: url, executor: executor)
        },
        deleteTabGroup: @escaping (Int) throws -> Void = { identifier in
            _ = try SafariTabGroupDeleteCommand().deleteTabGroup(identifier: identifier)
        }
    ) {
        self.executor = executor
        self.ensureTabGroup = ensureTabGroup
        self.listWindowTabsByIndex = listWindowTabs
        self.listWindowTabsByIdentifier = listWindowTabsByIdentifier
        self.listTabGroupTabs = listTabGroupTabs
        self.listWindows = listWindows
        self.focusWindow = focusWindow
        self.openWindow = openWindow
        self.selectTabGroup = selectTabGroup
        self.openTabByIndex = openTab
        self.openTabByIdentifier = openTabByIdentifier
        self.deleteTabGroup = deleteTabGroup
    }

    public func execute(arguments: [String]) throws -> String {
        try format(ensureURLs(arguments: arguments))
    }

    public func executeJSON(arguments: [String]) throws -> String {
        try CommandJSONEncoder.encode(ensureURLs(arguments: arguments))
    }

    private func ensureURLs(arguments: [String]) throws -> SafariTabListEnsureURLsSummary {
        let request = try SafariTabListEnsureURLsRequest.parse(arguments)

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
            let tabGroupSummary = try ensureTabGroup(profileName, name)
            do {
                return try ensureTabGroupURLs(tabGroupSummary: tabGroupSummary, requestedURLs: request.urls)
            } catch {
                try rollbackCreatedTabGroup(tabGroupSummary)
                throw error
            }
        }
    }

    private func ensureTabGroupURLs(
        tabGroupSummary: SafariTabGroupEnsureSummary,
        requestedURLs: [String]
    ) throws -> SafariTabListEnsureURLsSummary {
        let tabGroup = tabGroupSummary.tabGroup
        let window = try SafariTabGroupSidebarAccess.focusWindowForTabGroup(
            tabGroup,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow
        )
        try selectTabGroup(tabGroup, executor)

        let existingURLs = try listTabGroupTabs(tabGroup.identifier).map(\.url)
        let result = try reconcile(requestedURLs: requestedURLs, existingURLs: existingURLs) { url in
            try openTabByIdentifier(window.identifier, url, executor)
        }

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

    private func rollbackCreatedTabGroup(_ summary: SafariTabGroupEnsureSummary) throws {
        guard summary.status == .created else {
            return
        }

        try deleteTabGroup(summary.tabGroup.identifier)
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
    enum Context: Equatable {
        case window(SafariWindowAddress)
        case tabGroup(profileName: String, name: String)
    }

    let context: Context
    let urls: [String]

    static func parse(_ arguments: [String]) throws -> SafariTabListEnsureURLsRequest {
        var windowIndex: Int?
        var windowIdentifier: Int?
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
            case "--window-id":
                let rawValue = try optionValue(after: argument, in: arguments, at: &index)
                guard let value = Int(rawValue), value > 0 else {
                    throw SafariTabCommandError.invalidWindowIdentifier(rawValue)
                }
                windowIdentifier = value
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
                } else if let rawValue = argument.optionValue(prefix: "--window-id=") {
                    guard !rawValue.isEmpty else {
                        throw SafariTabListCommandError.missingOptionValue("--window-id")
                    }
                    guard let value = Int(rawValue), value > 0 else {
                        throw SafariTabCommandError.invalidWindowIdentifier(rawValue)
                    }
                    windowIdentifier = value
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

        if windowIndex != nil && windowIdentifier != nil {
            throw SafariTabListCommandError.multipleContexts
        }

        if (windowIndex != nil || windowIdentifier != nil) && (tabGroupProfile != nil || tabGroupName != nil) {
            throw SafariTabListCommandError.multipleContexts
        }

        if let windowIndex {
            return SafariTabListEnsureURLsRequest(context: .window(.index(windowIndex)), urls: urls)
        }

        if let windowIdentifier {
            return SafariTabListEnsureURLsRequest(context: .window(.identifier(windowIdentifier)), urls: urls)
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

        return SafariTabListEnsureURLsRequest(
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
