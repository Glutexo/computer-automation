import AppKit
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
        if let profileName, !profileName.isEmpty {
            do {
                try clickNewWindowMenuItem(
                    forProfileNamed: profileName,
                    executor: SafariAppleScriptExecutor()
                )
            } catch SafariUserInterfaceError.profileWindowMenuItemNotFound {
                guard visibleWindowCount() == 0 else {
                    throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
                }

                try SafariAppleScriptWindow.openNewDocument()
                _ = SafariAXPolling().firstResult {
                    visibleWindowCount() > 0 ? true : nil
                }
                try clickNewWindowMenuItem(
                    forProfileNamed: profileName,
                    executor: SafariAppleScriptExecutor()
                )
            }
            return
        }

        try SafariAppleScriptWindow.openNewDocument()
    }

    public static func openWindow(
        profileName: String?,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        if executor is SafariAppleScriptExecutor {
            try openWindow(profileName: profileName)
            return
        }

        if let profileName, !profileName.isEmpty {
            try clickNewWindowMenuItem(forProfileNamed: profileName, executor: executor)
            return
        }
        try SafariAppleScriptWindow.openNewDocument(executor: executor)
    }

    public static func openPrivateWindow(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        if executor is SafariAppleScriptExecutor {
            try openPrivateWindow()
            return
        }

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
        let didPress = try SafariMenu.pressFirstMenuItem(menuBarItemIndex: menuBarItemIndex) {
            SafariMenu.stringValue(for: kAXIdentifierAttribute, on: $0) == "NewPrivateWindow" ||
            (
                SafariMenu.stringValue(for: "AXMenuItemCmdChar", on: $0) == "N" &&
                SafariMenu.stringValue(for: "AXMenuItemCmdModifiers", on: $0) == "1"
            )
        }

        guard didPress else {
            throw SafariUserInterfaceError.privateWindowMenuItemNotFound
        }
    }

    public static func createEmptyTabGroup(
    ) throws {
        try clickFileMenuItem(matchingIdentifier: createEmptyTabGroupMenuItemIdentifier)
    }

    public static func createEmptyTabGroup(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        if executor is SafariAppleScriptExecutor {
            try createEmptyTabGroup()
            return
        }

        try clickFileMenuItem(
            matchingIdentifier: createEmptyTabGroupMenuItemIdentifier,
            executor: executor
        )
    }

    public static func deleteCurrentTabGroup() throws {
        try clickFileMenuItem(matchingIdentifier: deleteCurrentTabGroupMenuItemIdentifier)
        try SafariMenu.pressFrontWindowSheetButton(matchingIdentifier: "action-button-2")
    }

    public static func deleteCurrentTabGroup(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        if executor is SafariAppleScriptExecutor {
            try deleteCurrentTabGroup()
            return
        }

        try clickFileMenuItem(
            matchingIdentifier: deleteCurrentTabGroupMenuItemIdentifier,
            executor: executor
        )
    }

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
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

    private static func clickFileMenuItem(
        matchingIdentifier identifier: String
    ) throws {
        let didPress = try SafariMenu.pressFirstMenuItem(menuBarItemIndex: menuBarItemIndex) {
            stringValue(for: kAXIdentifierAttribute, on: $0) == identifier
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

    private static func stringValue(for attribute: String, on element: AXUIElement) -> String {
        SafariAX.stringValue(for: attribute, on: element)
    }

    private static func visibleWindowCount() -> Int {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            return 0
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        return SafariAX.elements(for: kAXWindowsAttribute, on: applicationElement).count
    }

}
