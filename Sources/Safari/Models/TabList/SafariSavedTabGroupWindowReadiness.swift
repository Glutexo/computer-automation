import Foundation

enum SafariSavedTabGroupWindowReadiness {
    static let pollAttempts = 80
    static let pollInterval: TimeInterval = 0.25

    static func waitForLoadedTabs(
        tabGroup: SafariTabGroupRecord,
        windowIdentifier: Int,
        listWindows: () throws -> [SafariWindowRecord],
        listWindowTabs: () throws -> [SafariWindowTabRecord],
        listTabGroupTabs: () throws -> [SafariTabGroupTabRecord],
        sleep: (TimeInterval) -> Void
    ) throws -> [SafariWindowTabRecord] {
        for attempt in 0..<pollAttempts {
            let windows = try listWindows()
            if
                let window = windows.first(where: { $0.identifier == windowIdentifier }),
                windowMatchesSelectedTabGroup(window, tabGroup: tabGroup)
            {
                let liveTabs = try listWindowTabs()
                let savedTabs = try listTabGroupTabs()

                if liveTabsRepresentSavedTabGroup(liveTabs, savedTabs: savedTabs) {
                    return liveTabs
                }
            }

            if attempt < pollAttempts - 1 {
                sleep(pollInterval)
            }
        }

        throw SafariTabListCommandError.savedTabGroupSelectionNotLoaded(tabGroup.identifier)
    }

    private static func windowMatchesSelectedTabGroup(
        _ window: SafariWindowRecord,
        tabGroup: SafariTabGroupRecord
    ) -> Bool {
        guard !window.isPrivate else {
            return false
        }

        guard window.profileName.isEmpty || window.profileName == tabGroup.profileName else {
            return false
        }

        return window.selectedTabGroupIdentifier == tabGroup.identifier ||
            window.tabGroupName == tabGroup.name ||
            windowTitle(window.name, matchesTabGroupNamed: tabGroup.name)
    }

    private static func liveTabsRepresentSavedTabGroup(
        _ liveTabs: [SafariWindowTabRecord],
        savedTabs: [SafariTabGroupTabRecord]
    ) -> Bool {
        let savedIndexes = Set(savedTabs.map(\.index))
        guard !savedIndexes.isEmpty else {
            return true
        }

        let matchedIndexes = Set(liveTabs.compactMap(\.selectedTabGroupTabIndex))
        if savedIndexes.isSubset(of: matchedIndexes) {
            return true
        }

        let savedURLs = savedTabs
            .sorted { $0.index < $1.index }
            .map { normalizedSavedTabGroupURL($0.url) }
        let liveURLs = liveTabs
            .sorted { $0.index < $1.index }
            .map { normalizedSavedTabGroupURL($0.url) }

        return Array(liveURLs.prefix(savedURLs.count)) == savedURLs
    }

    private static func windowTitle(
        _ title: String,
        matchesTabGroupNamed tabGroupName: String
    ) -> Bool {
        title == tabGroupName || title.hasPrefix("\(tabGroupName) -") || title.hasPrefix("\(tabGroupName) —")
    }

    private static func normalizedSavedTabGroupURL(_ url: String) -> String {
        url == "favorites://" ? "" : url
    }
}
