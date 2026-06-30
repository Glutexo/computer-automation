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

    static func stringValue(for attribute: String, on element: AXUIElement) -> String {
        guard let value = copyAttributeValue(attribute, from: element) else {
            return ""
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return ""
    }

    private static func menuItemElements(menuBarItemIndex: Int) throws -> [AXUIElement] {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        safariApplication.activate(options: [.activateIgnoringOtherApps])
        Thread.sleep(forTimeInterval: 0.1)

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        guard
            let menuBar = firstDescendant(in: applicationElement, matchingRole: kAXMenuBarRole)
        else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menuBarItems = elements(for: kAXChildrenAttribute, on: menuBar)
        guard menuBarItems.indices.contains(menuBarItemIndex - 1) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menuBarItem = menuBarItems[menuBarItemIndex - 1]
        guard AXUIElementPerformAction(menuBarItem, kAXPressAction as CFString) == .success else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        Thread.sleep(forTimeInterval: 0.1)

        guard let menu = elements(for: kAXChildrenAttribute, on: menuBarItem).first(where: {
            stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuRole
        }) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        return unique(
            elements(for: kAXChildrenAttribute, on: menu) + elements(for: "AXVisibleChildren", on: menu)
        ).filter {
            stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuItemRole
        }
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

    private static func normalized(_ value: String) -> String? {
        value.isEmpty || value == "missing value" ? nil : value
    }
}
