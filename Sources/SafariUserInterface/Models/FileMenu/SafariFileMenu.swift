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
                try clickNewWindowMenuItem(forProfileNamed: profileName)
            } catch SafariUserInterfaceError.profileWindowMenuItemNotFound {
                guard visibleWindowCount() == 0 else {
                    throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
                }

                try SafariAppleScriptWindow.openNewDocument()
                Thread.sleep(forTimeInterval: 0.2)
                try clickNewWindowMenuItem(forProfileNamed: profileName)
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

    private static func clickNewWindowMenuItem(
        forProfileNamed profileName: String
    ) throws {
        guard
            let menuItem = findFileMenuItem(titleSuffix: profileName),
            AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
        else {
            throw SafariUserInterfaceError.profileWindowMenuItemNotFound(profileName)
        }
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
        guard
            let menuItem = findFileMenuItem(matchingIdentifier: identifier),
            AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
        else {
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

    private static func copyAttributeValue(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func elements(for attribute: String, on element: AXUIElement) -> [AXUIElement] {
        (copyAttributeValue(attribute, from: element) as? [AXUIElement]) ?? []
    }

    private static func descendantElements(on element: AXUIElement) -> [AXUIElement] {
        var seen: Set<CFHashCode> = []
        var descendants: [AXUIElement] = []

        for child in elements(for: kAXChildrenAttribute, on: element) + elements(for: "AXVisibleChildren", on: element) {
            let key = CFHash(child)
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            descendants.append(child)
        }

        return descendants
    }

    private static func stringValue(for attribute: String, on element: AXUIElement) -> String {
        (copyAttributeValue(attribute, from: element) as? String) ?? ""
    }

    private static func visibleWindowCount() -> Int {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            return 0
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        return elements(for: kAXWindowsAttribute, on: applicationElement).count
    }

    private static func findFileMenuItem(
        matchingIdentifier identifier: String
    ) -> AXUIElement? {
        guard let applicationElement = fileMenuApplicationElement() else {
            return nil
        }

        return firstDescendant(
            in: applicationElement,
            matchingRole: kAXMenuItemRole,
            matchingIdentifier: identifier
        )
    }

    private static func findFileMenuItem(
        titleSuffix: String
    ) -> AXUIElement? {
        guard let applicationElement = fileMenuApplicationElement() else {
            return nil
        }

        return firstDescendant(
            in: applicationElement,
            matchingRole: kAXMenuItemRole,
            titleSuffix: titleSuffix
        )
    }

    private static func fileMenuApplicationElement() -> AXUIElement? {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            return nil
        }

        safariApplication.activate(options: [.activateIgnoringOtherApps])
        Thread.sleep(forTimeInterval: 0.1)

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        guard
            let menuBar = firstDescendant(in: applicationElement, matchingRole: kAXMenuBarRole)
        else {
            return nil
        }

        let menuBarItems = elements(for: kAXChildrenAttribute, on: menuBar)
        guard menuBarItems.indices.contains(menuBarItemIndex - 1) else {
            return nil
        }

        let fileMenuBarItem = menuBarItems[menuBarItemIndex - 1]
        guard AXUIElementPerformAction(fileMenuBarItem, kAXPressAction as CFString) == .success else {
            return nil
        }

        Thread.sleep(forTimeInterval: 0.1)
        return applicationElement
    }

    private static func firstDescendant(
        in root: AXUIElement,
        matchingRole role: String,
        depth: Int = 0
    ) -> AXUIElement? {
        if stringValue(for: kAXRoleAttribute, on: root) == role {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root) {
            if let match = firstDescendant(in: child, matchingRole: role, depth: depth + 1) {
                return match
            }
        }

        return nil
    }

    private static func firstDescendant(
        in root: AXUIElement,
        matchingRole role: String,
        matchingIdentifier identifier: String,
        depth: Int = 0
    ) -> AXUIElement? {
        if stringValue(for: kAXRoleAttribute, on: root) == role && stringValue(for: kAXIdentifierAttribute, on: root) == identifier {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root) {
            if let match = firstDescendant(in: child, matchingRole: role, matchingIdentifier: identifier, depth: depth + 1) {
                return match
            }
        }

        return nil
    }

    private static func firstDescendant(
        in root: AXUIElement,
        matchingRole role: String,
        titleSuffix: String,
        depth: Int = 0
    ) -> AXUIElement? {
        if stringValue(for: kAXRoleAttribute, on: root) == role && stringValue(for: kAXTitleAttribute, on: root).hasSuffix(titleSuffix) {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root) {
            if let match = firstDescendant(in: child, matchingRole: role, titleSuffix: titleSuffix, depth: depth + 1) {
                return match
            }
        }

        return nil
    }
}
