import Foundation
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
            try focusWindow(window.identifier, executor)
            return window
        }

        let unscopedWindows = windows.filter { !$0.isPrivate && $0.profileName.isEmpty }
        if unscopedWindows.count == 1, let window = unscopedWindows.first {
            try focusWindow(window.identifier, executor)
            return window
        }

        if let frontUnscopedWindow = windows.first(where: { !$0.isPrivate && $0.profileName.isEmpty }) {
            try focusWindow(frontUnscopedWindow.identifier, executor)
            return frontUnscopedWindow
        }

        try openWindow(profileName, executor)

        guard let openedWindow = try listWindows().first(where: { !$0.isPrivate && $0.profileName == profileName }) else {
            throw SafariTabGroupCommandError.windowForProfileNotFound(profileName)
        }

        try focusWindow(openedWindow.identifier, executor)
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
            try focusWindow(matchingSelectedGroupWindow.identifier, executor)
            return matchingSelectedGroupWindow
        }

        if let matchingNamedGroupWindow = windows.first(where: {
            !$0.isPrivate &&
            ($0.tabGroupName == group.name || windowTitle($0.name, matchesTabGroupNamed: group.name)) &&
            ($0.profileName.isEmpty || $0.profileName == group.profileName)
        }) {
            try focusWindow(matchingNamedGroupWindow.identifier, executor)
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

    static func openNewWindowForProfile(
        profileName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void,
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        sleep: (TimeInterval) -> Void = Thread.sleep
    ) throws -> SafariWindowRecord {
        let existingWindowIdentifiers = Set(try listWindows().map(\.identifier))
        try openWindow(profileName, executor)

        for attempt in 0..<20 {
            let newWindows = try listWindows().filter {
                !existingWindowIdentifiers.contains($0.identifier) && !$0.isPrivate
            }

            if let profileWindow = newWindows.first(where: {
                $0.profileName == profileName || windowTitle($0.name, matchesProfileNamed: profileName)
            }) {
                try focusWindow(profileWindow.identifier, executor)
                return profileWindow
            }

            if attempt < 19 {
                sleep(0.1)
            }
        }

        try rollbackNewWindows(
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            closeWindow: closeWindow
        )
        throw SafariTabGroupCommandError.windowForProfileNotFound(profileName)
    }

    static func selectTabGroup(
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        try selectTabGroup(identifier: nil, named: tabGroupName, executor: executor)
    }

    static func selectTabGroup(
        _ group: SafariTabGroupRecord,
        executor: SafariAppleScriptExecuting
    ) throws {
        try selectTabGroup(identifier: group.identifier, named: group.name, executor: executor)
    }

    private static func selectTabGroup(
        identifier tabGroupIdentifier: Int?,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        do {
            if let tabGroupIdentifier {
                try SafariSidebar.selectTabGroup(identifier: tabGroupIdentifier, named: tabGroupName)
            } else {
                try SafariSidebar.selectTabGroup(named: tabGroupName)
            }
        } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
            do {
                if let tabGroupIdentifier {
                    try SafariSidebar.selectTabGroup(identifier: tabGroupIdentifier, named: tabGroupName, executor: executor)
                } else {
                    try SafariSidebar.selectTabGroup(named: tabGroupName, executor: executor)
                }
            } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
                throw SafariTabGroupCommandError.sidebarTabGroupNotFound(tabGroupName)
            } catch {
                throw SafariTabGroupCommandError.sidebarUnavailable
            }
        } catch {
            do {
                if let tabGroupIdentifier {
                    try SafariSidebar.selectTabGroup(identifier: tabGroupIdentifier, named: tabGroupName, executor: executor)
                } else {
                    try SafariSidebar.selectTabGroup(named: tabGroupName, executor: executor)
                }
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

    private static func windowTitle(
        _ title: String,
        matchesProfileNamed profileName: String
    ) -> Bool {
        title == profileName || title.hasPrefix("\(profileName) —") || title.hasPrefix("\(profileName) -")
    }

    private static func rollbackNewWindows(
        excluding knownWindowIdentifiers: Set<Int>,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    ) throws {
        let newWindows = try listWindows().filter {
            !knownWindowIdentifiers.contains($0.identifier) && !$0.isPrivate
        }

        for window in newWindows {
            try closeWindow(window.identifier, executor)
        }
    }
}
