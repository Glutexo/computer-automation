import AutomationFoundation
import ApplicationServices
import SafariAppleScript

public enum SafariFileMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "file-menu",
        abstract: "The Safari File menu.",
        commands: [
            SafariFileMenuListCommand.descriptor
        ]
    )

    static let menuBarItemIndex = 3
    static let createEmptyTabGroupMenuItemIdentifier = "NewEmptyTabGroupMenuItem"
    static let deleteCurrentTabGroupMenuItemIdentifier = "DeleteTabGroupMenuItem"

    public static func openWindow(
        profileName: String?
    ) throws {
        try openWindow(
            profileName: profileName,
            accessibility: .live,
            openNewDocument: { try SafariAppleScriptWindow.openNewDocument() }
        )
    }

    static func openWindow(
        profileName: String?,
        accessibility: SafariAccessibilityBackend,
        openNewDocument: () throws -> Void
    ) throws {
        if let profileName, !profileName.isEmpty {
            do {
                try pressNewWindowMenuItem(
                    forProfileNamed: profileName,
                    accessibility: accessibility
                )
            } catch let error as SafariUserInterfaceError {
                switch error {
                case .profileWindowMenuItemNotFound, .menuUnavailable:
                    try pressNewWindowMenuItemAfterOpeningBootstrapWindow(
                        forProfileNamed: profileName,
                        accessibility: accessibility,
                        openNewDocument: openNewDocument
                    )
                default:
                    throw error
                }
            }
            return
        }

        try openNewDocument()
    }

    public static func openWindow(
        profileName: String?,
        executor: SafariAppleScriptExecuting
    ) throws {
        if let profileName, !profileName.isEmpty {
            try clickNewWindowMenuItem(forProfileNamed: profileName, executor: executor)
            return
        }
        try SafariAppleScriptWindow.openNewDocument(executor: executor)
    }

    public static func openPrivateWindow(
        executor: SafariAppleScriptExecuting
    ) throws {
        let menuItems = try listItems(executor: executor)

        guard let menuItem = menuItems.first(where: {
            $0.commandCharacter == "N" && $0.commandModifiers == "1"
        }) else {
            throw SafariUserInterfaceError.privateWindowMenuItemNotFound
        }

        try SafariAppleScriptMenu.clickItem(
            menuBarItemIndex: menuBarItemIndex,
            menuItemIndex: menuItem.index,
            executor: executor
        )
    }

    public static func openPrivateWindow() throws {
        try openPrivateWindow(accessibility: .live)
    }

    static func openPrivateWindow(accessibility: SafariAccessibilityBackend) throws {
        let didPress = try SafariMenu.pressFirstMenuItem(
            menuBarItemIndex: menuBarItemIndex,
            accessibility: accessibility
        ) {
            accessibility.stringValue(for: kAXIdentifierAttribute, on: $0) == "NewPrivateWindow" ||
            (
                accessibility.stringValue(for: "AXMenuItemCmdChar", on: $0) == "N" &&
                accessibility.stringValue(for: "AXMenuItemCmdModifiers", on: $0) == "1"
            )
        }

        guard didPress else {
            throw SafariUserInterfaceError.privateWindowMenuItemNotFound
        }
    }

    public static func createEmptyTabGroup(
    ) throws {
        try createEmptyTabGroup(accessibility: .live)
    }

    static func createEmptyTabGroup(accessibility: SafariAccessibilityBackend) throws {
        try clickFileMenuItem(
            matchingIdentifier: createEmptyTabGroupMenuItemIdentifier,
            accessibility: accessibility
        )
    }

    public static func createEmptyTabGroup(
        executor: SafariAppleScriptExecuting
    ) throws {
        try clickFileMenuItem(
            matchingIdentifier: createEmptyTabGroupMenuItemIdentifier,
            executor: executor
        )
    }

    public static func deleteCurrentTabGroup() throws {
        try deleteCurrentTabGroup(accessibility: .live)
    }

    static func deleteCurrentTabGroup(accessibility: SafariAccessibilityBackend) throws {
        try clickFileMenuItem(
            matchingIdentifier: deleteCurrentTabGroupMenuItemIdentifier,
            accessibility: accessibility
        )
        try SafariMenu.pressFrontWindowSheetButton(
            matchingIdentifier: "action-button-2",
            accessibility: accessibility
        )
    }

    public static func deleteCurrentTabGroup(
        executor: SafariAppleScriptExecuting
    ) throws {
        try clickFileMenuItem(
            matchingIdentifier: deleteCurrentTabGroupMenuItemIdentifier,
            executor: executor
        )
    }

    public static func listItems(
    ) throws -> [SafariMenuItemRecord] {
        try SafariMenu.listItems(menuBarItemIndex: menuBarItemIndex)
    }

    public static func listItems(
        executor: SafariAppleScriptExecuting
    ) throws -> [SafariMenuItemRecord] {
        try SafariMenu.listItems(
            menuBarItemIndex: menuBarItemIndex,
            executor: executor
        )
    }

    public static func openProfileWindowShortcut(
        profileName: String,
        profileNames: [String],
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        guard let profileIndex = profileNames.firstIndex(of: profileName), profileIndex <= 9 else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }

        let key = profileIndex == 0 ? "0" : String(profileIndex)
        try SafariAppleScriptMenu.pressKeyboardShortcut(
            key: key,
            modifiers: "command down, option down, shift down",
            executor: executor
        )
    }

    private static func clickNewWindowMenuItem(
        forProfileNamed profileName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let menuItems = try listItems(executor: executor)

        guard let menuItem = menuItems.first(where: { $0.title.hasSuffix(profileName) }) else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }
        try SafariAppleScriptMenu.clickItem(
            menuBarItemIndex: menuBarItemIndex,
            menuItemIndex: menuItem.index,
            executor: executor
        )
    }

    private static func pressNewWindowMenuItem(
        forProfileNamed profileName: String,
        accessibility: SafariAccessibilityBackend
    ) throws {
        let didPress = try SafariMenu.pressFirstMenuItem(
            menuBarItemIndex: menuBarItemIndex,
            accessibility: accessibility
        ) {
            accessibility.stringValue(for: kAXTitleAttribute, on: $0).hasSuffix(profileName)
        }

        guard didPress else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }
    }

    private static func pressNewWindowMenuItemAfterOpeningBootstrapWindow(
        forProfileNamed profileName: String,
        accessibility: SafariAccessibilityBackend,
        openNewDocument: () throws -> Void
    ) throws {
        guard visibleWindowCount(accessibility: accessibility) == 0 else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }

        try openNewDocument()
        _ = accessibility.polling.firstResult {
            visibleWindowCount(accessibility: accessibility) > 0 ? true : nil
        }
        try pressNewWindowMenuItem(
            forProfileNamed: profileName,
            accessibility: accessibility
        )
    }

    private static func clickFileMenuItem(
        matchingIdentifier identifier: String,
        accessibility: SafariAccessibilityBackend
    ) throws {
        let didPress = try SafariMenu.pressFirstMenuItem(
            menuBarItemIndex: menuBarItemIndex,
            accessibility: accessibility
        ) {
            accessibility.stringValue(for: kAXIdentifierAttribute, on: $0) == identifier
        }

        guard didPress else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }
    }

    private static func clickFileMenuItem(
        matchingIdentifier identifier: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu bar item \(menuBarItemIndex) of menu bar 1
                    repeat with currentItem in menu items
                        try
                            if value of attribute "AXIdentifier" of currentItem is "\(identifier)" then
                                click currentItem
                                return
                            end if
                        end try
                    end repeat
                    error "Safari File menu item \(identifier) not found."
                end tell
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    private static func visibleWindowCount(accessibility: SafariAccessibilityBackend) -> Int {
        accessibility.applications().reduce(into: 0) { count, application in
            count += accessibility.elements(for: kAXWindowsAttribute, on: application.element).count
        }
    }

}
