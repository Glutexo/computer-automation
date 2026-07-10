import AppKit
import ApplicationServices
import AutomationFoundation
import SafariAppleScript

public enum SafariMenu: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu",
        abstract: "A Safari application menu.",
        commands: [
            SafariMenuListItemsCommand.descriptor
        ]
    )

    public static func listItems(
        menuBarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
        if executor is SafariAppleScriptExecutor {
            return try listItems(menuBarItemIndex: menuBarItemIndex)
        }

        do {
            return try SafariAppleScriptMenu.listItems(
                menuBarItemIndex: menuBarItemIndex,
                executor: executor
            ).map(SafariMenuItemRecord.init)
        } catch {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }
    }

    static func listItems(
        menuBarItemIndex: Int
    ) throws -> [SafariMenuItemRecord] {
        let menuItems = try menuItemElements(menuBarItemIndex: menuBarItemIndex)

        return menuItems.enumerated().compactMap { offset, element in
            let title = stringValue(for: kAXTitleAttribute, on: element)
            let commandCharacter = stringValue(for: "AXMenuItemCmdChar", on: element)

            guard !title.isEmpty || !commandCharacter.isEmpty else {
                return nil
            }

            return SafariMenuItemRecord(
                index: offset + 1,
                title: title,
                commandCharacter: normalized(commandCharacter),
                commandModifiers: normalized(stringValue(for: "AXMenuItemCmdModifiers", on: element))
            )
        }
    }

    static func pressFirstMenuItem(
        menuBarItemIndex: Int,
        matching predicate: (AXUIElement) -> Bool
    ) throws -> Bool {
        guard let menuItem = try menuItemElements(menuBarItemIndex: menuBarItemIndex).first(where: predicate) else {
            return false
        }

        return AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success
    }

    static func pressFrontWindowSheetButton(
        matchingIdentifier identifier: String,
        polling: SafariAXPolling = SafariAXPolling()
    ) throws {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        try waitForSheetButtonPress(polling: polling) {
            guard let button = sheetButton(matchingIdentifier: identifier, in: applicationElement) else {
                return false
            }

            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
    }

    static func waitForSheetButtonPress(
        polling: SafariAXPolling = SafariAXPolling(),
        pressMatchingButton: () throws -> Bool
    ) throws {
        guard try polling.firstResult({ try pressMatchingButton() ? true : nil }) != nil else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)
        }
    }

    static func stringValue(for attribute: String, on element: AXUIElement) -> String {
        SafariAX.stringValue(for: attribute, on: element)
    }

    private static func sheetButton(
        matchingIdentifier identifier: String,
        in applicationElement: AXUIElement
    ) -> AXUIElement? {
        let focusedWindow = elementValue(for: kAXFocusedWindowAttribute, on: applicationElement)
        let windows = unique(
            [focusedWindow].compactMap { $0 } +
            elements(for: kAXWindowsAttribute, on: applicationElement)
        )

        for window in windows {
            for sheet in sheetElements(attachedTo: window) {
                if let button = firstDescendant(in: sheet, matchingRole: kAXButtonRole, matchingIdentifier: identifier) {
                    return button
                }
            }
        }

        for sheet in directSheetElements(on: applicationElement) {
            if let button = firstDescendant(in: sheet, matchingRole: kAXButtonRole, matchingIdentifier: identifier) {
                return button
            }
        }

        return nil
    }

    private static func menuItemElements(menuBarItemIndex: Int) throws -> [AXUIElement] {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        safariApplication.activate(options: [.activateIgnoringOtherApps])

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        let menuBar = try waitForMenuElement(menuBarItemIndex: menuBarItemIndex) {
            firstDescendant(in: applicationElement, matchingRole: kAXMenuBarRole)
        }

        let menuBarItems = elements(for: kAXChildrenAttribute, on: menuBar)
        guard menuBarItems.indices.contains(menuBarItemIndex - 1) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menuBarItem = menuBarItems[menuBarItemIndex - 1]
        guard AXUIElementPerformAction(menuBarItem, kAXPressAction as CFString) == .success else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menu = try waitForMenuElement(menuBarItemIndex: menuBarItemIndex) {
            elements(for: kAXChildrenAttribute, on: menuBarItem).first(where: {
                stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuRole
            })
        }

        return unique(
            elements(for: kAXChildrenAttribute, on: menu) + elements(for: "AXVisibleChildren", on: menu)
        ).filter {
            stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuItemRole
        }
    }

    static func waitForMenuElement<Element>(
        menuBarItemIndex: Int,
        polling: SafariAXPolling = SafariAXPolling(),
        currentElement: () throws -> Element?
    ) throws -> Element {
        guard let element = try polling.firstResult(currentElement) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        return element
    }

    private static func elements(for attribute: String, on element: AXUIElement) -> [AXUIElement] {
        SafariAX.elements(for: attribute, on: element)
    }

    private static func elementValue(for attribute: String, on element: AXUIElement) -> AXUIElement? {
        SafariAX.elementValue(for: attribute, on: element)
    }

    private static func sheetElements(attachedTo window: AXUIElement) -> [AXUIElement] {
        unique(
            elements(for: "AXSheets", on: window) +
            directSheetElements(on: window)
        )
    }

    private static func directSheetElements(on element: AXUIElement) -> [AXUIElement] {
        descendantElements(on: element).filter {
            stringValue(for: kAXRoleAttribute, on: $0) == kAXSheetRole
        }
    }

    private static func unique(_ elements: [AXUIElement]) -> [AXUIElement] {
        var seen: Set<CFHashCode> = []
        var uniqueElements: [AXUIElement] = []

        for element in elements {
            let key = CFHash(element)
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            uniqueElements.append(element)
        }

        return uniqueElements
    }

    private static func descendantElements(on element: AXUIElement) -> [AXUIElement] {
        unique(elements(for: kAXChildrenAttribute, on: element) + elements(for: "AXVisibleChildren", on: element))
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
        if
            stringValue(for: kAXRoleAttribute, on: root) == role,
            stringValue(for: kAXIdentifierAttribute, on: root) == identifier
        {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root) {
            if let match = firstDescendant(
                in: child,
                matchingRole: role,
                matchingIdentifier: identifier,
                depth: depth + 1
            ) {
                return match
            }
        }

        return nil
    }

    private static func normalized(_ value: String) -> String? {
        value.isEmpty || value == "missing value" ? nil : value
    }
}
