import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

enum SafariTabGroupSidebarAccess {
    private static let profileWindowPollAttempts = SafariProfileWindowOpening.windowPollAttempts
    private static let profileWindowPollInterval = SafariProfileWindowOpening.windowPollInterval
    private static let sidebarMutationPollAttempts = 30
    private static let sidebarMutationPollInterval: TimeInterval = 0.25

    static func resolveUniqueTabGroup(
        identifier: Int,
        from groups: [SafariTabGroupRecord]
    ) throws -> SafariTabGroupRecord {
        guard let group = groups.first(where: { $0.identifier == identifier }) else {
            throw SafariTabGroupCommandError.tabGroupNotFound(identifier)
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

        if let matchingGroupWindow = windows.first(where: {
            guard
                !$0.isPrivate,
                $0.profileName.isEmpty || $0.profileName == group.profileName
            else {
                return false
            }

            return StableIdentifierMatching.matches(
                requestedIdentifier: group.identifier,
                observedIdentifier: $0.selectedTabGroupIdentifier,
                fallback: $0.tabGroupName == group.name || windowTitle($0.name, matchesTabGroupNamed: group.name)
            )
        }) {
            try focusWindow(matchingGroupWindow.identifier, executor)
            return matchingGroupWindow
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
        listWindows: @escaping () throws -> [SafariWindowRecord]
    ) throws -> SafariWindowRecord {
        try openNewWindowForProfile(
            profileName: profileName,
            executor: executor,
            listWindows: listWindows,
            focusWindow: SafariAppleScriptWindow.focus(windowIdentifier:executor:),
            openWindow: { profileName, _ in
                try SafariFileMenu.openWindow(profileName: profileName)
            },
            closeWindow: SafariAppleScriptWindow.close(windowIdentifier:executor:),
            profileNames: (try? SafariProfile.listAvailableProfiles().map(\.name)) ?? []
        )
    }

    static func listTabGroups(
        executor: SafariAppleScriptExecuting
    ) throws -> [SafariSidebarTabGroupRecord] {
        do {
            return try SafariSidebar.listTabGroups()
        } catch {
            do {
                return try SafariSidebar.listTabGroups(executor: executor)
            } catch {
                throw SafariTabGroupCommandError.sidebarUnavailable
            }
        }
    }

    static func listTabGroups(
        profileName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord]
    ) throws -> [SafariTabGroupSidebarRecord] {
        try withNewWindowForProfile(
            profileName: profileName,
            executor: executor,
            listWindows: listWindows,
            openWindow: openNewWindowForProfile,
            closeWindow: SafariAppleScriptWindow.close(windowIdentifier:executor:)
        ) {
            try listTabGroups(executor: executor).map {
                SafariTabGroupSidebarRecord(
                    identifier: $0.identifier,
                    profileName: profileName,
                    name: $0.name
                )
            }
        }
    }

    static func deleteTabGroup(
        profileName: String,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord]
    ) throws -> SafariTabGroupRecord {
        try deleteTabGroup(
            profileName: profileName,
            named: tabGroupName,
            executor: executor,
            listWindows: listWindows,
            openWindow: openNewWindowForProfile,
            closeWindow: SafariAppleScriptWindow.close(windowIdentifier:executor:),
            listSidebarTabGroups: listTabGroups(executor:),
            selectTabGroup: { identifier, name, executor in
                try selectTabGroup(
                    identifier: identifier,
                    named: name,
                    processIdentifier: nil,
                    executor: executor
                )
            },
            deleteSelectedTabGroup: { _ in
                try SafariSidebar.deleteSelectedTabGroup()
            },
            sleep: Thread.sleep
        )
    }

    static func deleteTabGroup(
        profileName: String,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord],
        openWindow: (String, SafariAppleScriptExecuting, @escaping () throws -> [SafariWindowRecord]) throws -> SafariWindowRecord,
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        listSidebarTabGroups: (SafariAppleScriptExecuting) throws -> [SafariSidebarTabGroupRecord],
        selectTabGroup: (Int, String, SafariAppleScriptExecuting) throws -> Void,
        deleteSelectedTabGroup: (SafariAppleScriptExecuting) throws -> Void,
        sleep: (TimeInterval) -> Void,
        maxAttempts: Int = sidebarMutationPollAttempts
    ) throws -> SafariTabGroupRecord {
        try withNewWindowForProfile(
            profileName: profileName,
            executor: executor,
            listWindows: listWindows,
            openWindow: openWindow,
            closeWindow: closeWindow
        ) {
            let matches = try listSidebarTabGroups(executor).filter { $0.name == tabGroupName }
            guard let match = matches.first else {
                throw SafariTabGroupCommandError.tabGroupLookupNotFound(
                    profileName: profileName,
                    tabGroupName: tabGroupName
                )
            }
            guard matches.count == 1 else {
                throw SafariTabGroupCommandError.tabGroupLookupAmbiguous(
                    profileName: profileName,
                    tabGroupName: tabGroupName,
                    count: matches.count
                )
            }
            guard let identifier = match.identifier else {
                throw SafariTabGroupCommandError.sidebarTabGroupIdentifierUnavailable(
                    profileName: profileName,
                    tabGroupName: tabGroupName
                )
            }

            let group = SafariTabGroupRecord(
                identifier: identifier,
                profileName: profileName,
                name: tabGroupName
            )
            try selectTabGroup(identifier, tabGroupName, executor)

            do {
                try deleteSelectedTabGroup(executor)
            } catch let deletionError {
                do {
                    try waitForDeletedSidebarTabGroup(
                        identifier: identifier,
                        executor: executor,
                        listSidebarTabGroups: listSidebarTabGroups,
                        sleep: sleep,
                        maxAttempts: maxAttempts
                    )
                    return group
                } catch {
                    throw deletionError
                }
            }

            try waitForDeletedSidebarTabGroup(
                identifier: identifier,
                executor: executor,
                listSidebarTabGroups: listSidebarTabGroups,
                sleep: sleep,
                maxAttempts: maxAttempts
            )
            return group
        }
    }

    static func withNewWindowForProfile<Result>(
        profileName: String,
        executor: SafariAppleScriptExecuting,
        listWindows: @escaping () throws -> [SafariWindowRecord],
        openWindow: (String, SafariAppleScriptExecuting, @escaping () throws -> [SafariWindowRecord]) throws -> SafariWindowRecord,
        closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        operation: () throws -> Result
    ) throws -> Result {
        let window = try openWindow(profileName, executor, listWindows)

        do {
            let result = try operation()
            try closeWindow(window.identifier, executor)
            return result
        } catch {
            let operationError = error
            try? closeWindow(window.identifier, executor)
            throw operationError
        }
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
        try selectTabGroup(
            identifier: nil,
            named: tabGroupName,
            processIdentifier: nil,
            executor: executor
        )
    }

    static func selectTabGroup(
        _ group: SafariTabGroupRecord,
        executor: SafariAppleScriptExecuting
    ) throws {
        try selectTabGroup(
            group,
            processIdentifier: nil,
            executor: executor
        )
    }

    static func selectTabGroup(
        _ group: SafariTabGroupRecord,
        processIdentifier: pid_t?,
        executor: SafariAppleScriptExecuting
    ) throws {
        try selectTabGroup(
            identifier: group.identifier,
            named: group.name,
            processIdentifier: processIdentifier,
            executor: executor
        )
    }

    private static func selectTabGroup(
        identifier tabGroupIdentifier: Int?,
        named tabGroupName: String,
        processIdentifier: pid_t?,
        executor: SafariAppleScriptExecuting
    ) throws {
        do {
            if let tabGroupIdentifier {
                try SafariSidebar.selectTabGroup(
                    identifier: tabGroupIdentifier,
                    named: tabGroupName,
                    processIdentifier: processIdentifier
                )
            } else {
                try SafariSidebar.selectTabGroup(named: tabGroupName)
            }
        } catch SafariUserInterfaceError.sidebarTabGroupNotFound {
            do {
                if let tabGroupIdentifier {
                    try SafariAppleScriptSidebar.selectTabGroup(
                        identifier: tabGroupIdentifier,
                        named: tabGroupName,
                        processIdentifier: processIdentifier,
                        executor: executor
                    )
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
                    try SafariAppleScriptSidebar.selectTabGroup(
                        identifier: tabGroupIdentifier,
                        named: tabGroupName,
                        processIdentifier: processIdentifier,
                        executor: executor
                    )
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

    private static func waitForDeletedSidebarTabGroup(
        identifier: Int,
        executor: SafariAppleScriptExecuting,
        listSidebarTabGroups: (SafariAppleScriptExecuting) throws -> [SafariSidebarTabGroupRecord],
        sleep: (TimeInterval) -> Void,
        maxAttempts: Int
    ) throws {
        for attempt in 0..<max(1, maxAttempts) {
            if try !listSidebarTabGroups(executor).contains(where: { $0.identifier == identifier }) {
                return
            }

            if attempt < max(1, maxAttempts) - 1 {
                sleep(sidebarMutationPollInterval)
            }
        }

        throw SafariTabGroupCommandError.tabGroupDeletionNotVerified(identifier)
    }
}
