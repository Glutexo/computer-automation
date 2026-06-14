import SafariAppleScript
import SafariUserInterface

enum SafariTabGroupSidebarAccess {
    static func resolveUniqueTabGroup(
        identifier: Int,
        from groups: [SafariTabGroupRecord]
    ) throws -> SafariTabGroupRecord {
        guard let group = groups.first(where: { $0.identifier == identifier }) else {
            throw SafariTabGroupCommandError.tabGroupNotFound(identifier)
        }

        let duplicates = groups.filter {
            $0.profileName == group.profileName && $0.name == group.name
        }

        guard duplicates.count == 1 else {
            throw SafariTabGroupCommandError.ambiguousTabGroupName(
                profileName: group.profileName,
                tabGroupName: group.name
            )
        }

        return group
    }

    static func focusWindowForProfile(
        profileName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    ) throws -> SafariWindowRecord {
        let windows = try listWindows()

        if let window = windows.first(where: { !$0.isPrivate && $0.profileName == profileName }) {
            try focusWindow(window.index, executor)
            return window
        }

        let unscopedWindows = windows.filter { !$0.isPrivate && $0.profileName.isEmpty }
        if unscopedWindows.count == 1, let window = unscopedWindows.first {
            try focusWindow(window.index, executor)
            return window
        }

        if let frontUnscopedWindow = windows.first(where: { !$0.isPrivate && $0.profileName.isEmpty }) {
            try focusWindow(frontUnscopedWindow.index, executor)
            return frontUnscopedWindow
        }

        try openWindow(profileName, executor)

        guard let openedWindow = try listWindows().first(where: { !$0.isPrivate && $0.profileName == profileName }) else {
            throw SafariTabGroupCommandError.windowForProfileNotFound(profileName)
        }

        try focusWindow(openedWindow.index, executor)
        return openedWindow
    }

    static func focusWindowForTabGroup(
        _ group: SafariTabGroupRecord,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void
    ) throws -> SafariWindowRecord {
        let windows = try listWindows()

        if let matchingSelectedGroupWindow = windows.first(where: {
            !$0.isPrivate && $0.selectedTabGroupIdentifier == group.identifier
        }) {
            try focusWindow(matchingSelectedGroupWindow.index, executor)
            return matchingSelectedGroupWindow
        }

        if let matchingNamedGroupWindow = windows.first(where: {
            !$0.isPrivate &&
            ($0.tabGroupName == group.name || windowTitle($0.name, matchesTabGroupNamed: group.name)) &&
            ($0.profileName.isEmpty || $0.profileName == group.profileName)
        }) {
            try focusWindow(matchingNamedGroupWindow.index, executor)
            return matchingNamedGroupWindow
        }

        return try focusWindowForProfile(
            profileName: group.profileName,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openWindow: openWindow
        )
    }

    static func selectTabGroup(
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        do {
            try SafariSidebar.selectTabGroup(named: tabGroupName)
        } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
            do {
                try SafariSidebar.selectTabGroup(named: tabGroupName, executor: executor)
            } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
                throw SafariTabGroupCommandError.sidebarTabGroupNotFound(tabGroupName)
            } catch {
                throw SafariTabGroupCommandError.sidebarUnavailable
            }
        } catch {
            do {
                try SafariSidebar.selectTabGroup(named: tabGroupName, executor: executor)
            } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
                throw SafariTabGroupCommandError.sidebarTabGroupNotFound(tabGroupName)
            } catch {
                throw SafariTabGroupCommandError.sidebarUnavailable
            }
        }
    }

    private static func windowTitle(
        _ title: String,
        matchesTabGroupNamed tabGroupName: String
    ) -> Bool {
        title == tabGroupName || title.hasPrefix("\(tabGroupName) —") || title.hasPrefix("\(tabGroupName) -")
    }
}
