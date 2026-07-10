import Foundation
import SafariAppleScript
import SafariUserInterface

enum SafariTabGroupSidebarAccess {
    private static let profileWindowPollAttempts = SafariProfileWindowOpening.windowPollAttempts
    private static let profileWindowPollInterval = SafariProfileWindowOpening.windowPollInterval

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
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void,
        profileNames: () throws -> [String] = { try SafariProfile.listAvailableProfiles().map(\.name) },
        openProfileWindowShortcut: (String, [String], SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openProfileWindowShortcut,
        sleep: (TimeInterval) -> Void = Thread.sleep
    ) throws -> SafariWindowRecord {
        let windows = try listWindows()
        let existingWindowIdentifiers = Set(windows.map(\.identifier))

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

        let knownProfileNames = (try? profileNames()) ?? []
        if let shortcutWindow = try openProfileWindowWithShortcut(
            profileName: profileName,
            profileNames: knownProfileNames,
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openProfileWindowShortcut: openProfileWindowShortcut,
            sleep: sleep
        ) {
            return shortcutWindow
        }

        try openWindow(profileName, executor)
        var didObserveNewWindow = false

        for attempt in 0..<profileWindowPollAttempts {
            let currentWindows = try listWindows()
            let newWindows = currentWindows.filter {
                !existingWindowIdentifiers.contains($0.identifier) && !$0.isPrivate
            }
            didObserveNewWindow = didObserveNewWindow || !newWindows.isEmpty

            if let openedWindow = currentWindows.first(where: { !$0.isPrivate && $0.profileName == profileName }) {
                try focusWindow(openedWindow.identifier, executor)
                return openedWindow
            }

            if attempt < profileWindowPollAttempts - 1 {
                sleep(profileWindowPollInterval)
            }
        }

        guard !didObserveNewWindow else {
            throw SafariTabGroupCommandError.windowForProfileNotFound(profileName)
        }

        if knownProfileNames.isEmpty, let shortcutWindow = try openProfileWindowWithShortcut(
            profileName: profileName,
            profileNames: (try? profileNames()) ?? [],
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openProfileWindowShortcut: openProfileWindowShortcut,
            sleep: sleep
        ) {
            return shortcutWindow
        }

        throw SafariTabGroupCommandError.windowForProfileNotFound(profileName)
    }

    static func focusWindowForTabGroup(
        _ group: SafariTabGroupRecord,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void,
        sleep: (TimeInterval) -> Void = Thread.sleep
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
            openWindow: openWindow,
            sleep: sleep
        )
    }

    static func openNewWindowForProfile(
        profileName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openWindow: (String?, SafariAppleScriptExecuting) throws -> Void,
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openNewDocument: (SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.openNewDocument,
        openProfileWindowShortcut: (String, [String], SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openProfileWindowShortcut,
        profileNames: [String] = [],
        sleep: (TimeInterval) -> Void = Thread.sleep
    ) throws -> SafariWindowRecord {
        let existingWindowIdentifiers = Set(try listWindows().map(\.identifier))
        if let shortcutWindow = try openProfileWindowWithShortcut(
            profileName: profileName,
            profileNames: profileNames,
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openProfileWindowShortcut: openProfileWindowShortcut,
            sleep: sleep
        ) {
            return shortcutWindow
        }

        try openWindow(profileName, executor)
        var didObserveNewWindow = false

        for attempt in 0..<profileWindowPollAttempts {
            let newWindows = try listWindows().filter {
                !existingWindowIdentifiers.contains($0.identifier) && !$0.isPrivate
            }
            didObserveNewWindow = didObserveNewWindow || !newWindows.isEmpty

            if let profileWindow = newWindows.first(where: {
                $0.profileName == profileName || windowTitle($0.name, matchesProfileNamed: profileName)
            }) {
                try focusWindow(profileWindow.identifier, executor)
                return profileWindow
            }

            if attempt < profileWindowPollAttempts - 1 {
                sleep(profileWindowPollInterval)
            }
        }

        if !didObserveNewWindow, let fallbackWindow = try SafariProfileWindowOpening.openNewDocumentFromExistingProfileWindow(
            profileName: profileName,
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            focusWindow: focusWindow,
            openNewDocument: openNewDocument,
            sleep: sleep
        ) {
            try focusWindow(fallbackWindow.identifier, executor)
            return fallbackWindow
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

    private static func openProfileWindowWithShortcut(
        profileName: String,
        profileNames: [String],
        excluding existingWindowIdentifiers: Set<Int>,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openProfileWindowShortcut: (String, [String], SafariAppleScriptExecuting) throws -> Void,
        sleep: (TimeInterval) -> Void
    ) throws -> SafariWindowRecord? {
        guard !profileNames.isEmpty else {
            return nil
        }

        do {
            try openProfileWindowShortcut(profileName, profileNames, executor)
        } catch SafariUserInterfaceError.profileWindowMenuItemNotFound {
            return nil
        }

        guard let shortcutWindow = try SafariProfileWindowOpening.waitForNewProfileWindow(
            profileName: profileName,
            excluding: existingWindowIdentifiers,
            listWindows: listWindows,
            sleep: sleep
        ) else {
            return nil
        }

        try focusWindow(shortcutWindow.identifier, executor)
        return shortcutWindow
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
