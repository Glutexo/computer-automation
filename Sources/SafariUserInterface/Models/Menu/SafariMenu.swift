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
        menuBarItemIndex: Int
    ) throws -> [SafariMenuItemRecord] {
        try listItems(
            menuBarItemIndex: menuBarItemIndex,
            backend: .accessibility(.live)
        )
    }

    public static func listItems(
        menuBarItemIndex: Int,
        executor: SafariAppleScriptExecuting
    ) throws -> [SafariMenuItemRecord] {
        try listItems(
            menuBarItemIndex: menuBarItemIndex,
            backend: .appleScript(executor)
        )
    }

    static func listItems(
        menuBarItemIndex: Int,
        backend: SafariUserInterfaceBackend
    ) throws -> [SafariMenuItemRecord] {
        switch backend {
        case .accessibility(let accessibility):
            return try listItems(
                menuBarItemIndex: menuBarItemIndex,
                accessibility: accessibility
            )
        case .appleScript(let executor):
            do {
                return try SafariAppleScriptMenu.listItems(
                    menuBarItemIndex: menuBarItemIndex,
                    executor: executor
                ).map(SafariMenuItemRecord.init)
            } catch {
                throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
            }
        }
    }

    static func listItems(
        menuBarItemIndex: Int,
        accessibility: SafariAccessibilityBackend
    ) throws -> [SafariMenuItemRecord] {
        let menuItems = try menuItemElements(
            menuBarItemIndex: menuBarItemIndex,
            accessibility: accessibility
        )

        return menuItems.enumerated().compactMap { offset, element in
            let title = accessibility.stringValue(for: kAXTitleAttribute, on: element)
            let commandCharacter = accessibility.stringValue(for: "AXMenuItemCmdChar", on: element)

            guard !title.isEmpty || !commandCharacter.isEmpty else {
                return nil
            }

            return SafariMenuItemRecord(
                index: offset + 1,
                title: title,
                commandCharacter: normalized(commandCharacter),
                commandModifiers: normalized(accessibility.stringValue(for: "AXMenuItemCmdModifiers", on: element))
            )
        }
    }

    static func pressFirstMenuItem(
        menuBarItemIndex: Int,
        accessibility: SafariAccessibilityBackend = .live,
        matching predicate: (AXUIElement) -> Bool
    ) throws -> Bool {
        guard let menuItem = try menuItemElements(
            menuBarItemIndex: menuBarItemIndex,
            accessibility: accessibility
        ).first(where: predicate) else {
            return false
        }

        return accessibility.perform(kAXPressAction, on: menuItem)
    }

    static func pressFrontWindowSheetButton(
        matchingIdentifier identifier: String,
        accessibility: SafariAccessibilityBackend = .live
    ) throws {
        let applications = accessibility.applications()
        guard !applications.isEmpty else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)
        }

        try waitForSheetButtonPress(polling: accessibility.polling) {
            for application in applications {
                if let button = sheetButton(
                    matchingIdentifier: identifier,
                    in: application.element,
                    accessibility: accessibility
                ) {
                    return accessibility.perform(kAXPressAction, on: button)
                }
            }

            return false
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

    private static func sheetButton(
        matchingIdentifier identifier: String,
        in applicationElement: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> AXUIElement? {
        let focusedWindow = accessibility.elementValue(for: kAXFocusedWindowAttribute, on: applicationElement)
        let windows = unique(
            [focusedWindow].compactMap { $0 } +
            accessibility.elements(for: kAXWindowsAttribute, on: applicationElement)
        )

        for window in windows {
            for sheet in sheetElements(attachedTo: window, accessibility: accessibility) {
                if let button = firstDescendant(
                    in: sheet,
                    matchingRole: kAXButtonRole,
                    matchingIdentifier: identifier,
                    accessibility: accessibility
                ) {
                    return button
                }
            }
        }

        for sheet in directSheetElements(on: applicationElement, accessibility: accessibility) {
            if let button = firstDescendant(
                in: sheet,
                matchingRole: kAXButtonRole,
                matchingIdentifier: identifier,
                accessibility: accessibility
            ) {
                return button
            }
        }

        return nil
    }

    private static func menuItemElements(
        menuBarItemIndex: Int,
        accessibility: SafariAccessibilityBackend
    ) throws -> [AXUIElement] {
        let applications = accessibility.applications()
        guard !applications.isEmpty else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let (application, menuBar) = try waitForMenuElement(
            menuBarItemIndex: menuBarItemIndex,
            polling: accessibility.polling
        ) {
            for application in applications {
                if let menuBar = firstDescendant(
                    in: application.element,
                    matchingRole: kAXMenuBarRole,
                    accessibility: accessibility
                ) {
                    return (application, menuBar)
                }
            }

            return nil
        }
        application.activate()

        let menuBarItems = accessibility.elements(for: kAXChildrenAttribute, on: menuBar)
        guard menuBarItems.indices.contains(menuBarItemIndex - 1) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menuBarItem = menuBarItems[menuBarItemIndex - 1]
        guard accessibility.perform(kAXPressAction, on: menuBarItem) else {
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: menuBarItemIndex)
        }

        let menu = try waitForMenuElement(
            menuBarItemIndex: menuBarItemIndex,
            polling: accessibility.polling
        ) {
            accessibility.elements(for: kAXChildrenAttribute, on: menuBarItem).first(where: {
                accessibility.stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuRole
            })
        }

        return unique(
            accessibility.elements(for: kAXChildrenAttribute, on: menu) +
                accessibility.elements(for: "AXVisibleChildren", on: menu)
        ).filter {
            accessibility.stringValue(for: kAXRoleAttribute, on: $0) == kAXMenuItemRole
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

    private static func sheetElements(
        attachedTo window: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> [AXUIElement] {
        unique(
            accessibility.elements(for: "AXSheets", on: window) +
                directSheetElements(on: window, accessibility: accessibility)
        )
    }

    private static func directSheetElements(
        on element: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> [AXUIElement] {
        descendantElements(on: element, accessibility: accessibility).filter {
            accessibility.stringValue(for: kAXRoleAttribute, on: $0) == kAXSheetRole
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

    private static func descendantElements(
        on element: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> [AXUIElement] {
        unique(
            accessibility.elements(for: kAXChildrenAttribute, on: element) +
                accessibility.elements(for: "AXVisibleChildren", on: element)
        )
    }

    private static func firstDescendant(
        in root: AXUIElement,
        matchingRole role: String,
        accessibility: SafariAccessibilityBackend,
        depth: Int = 0
    ) -> AXUIElement? {
        if accessibility.stringValue(for: kAXRoleAttribute, on: root) == role {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root, accessibility: accessibility) {
            if let match = firstDescendant(
                in: child,
                matchingRole: role,
                accessibility: accessibility,
                depth: depth + 1
            ) {
                return match
            }
        }

        return nil
    }

    private static func firstDescendant(
        in root: AXUIElement,
        matchingRole role: String,
        matchingIdentifier identifier: String,
        accessibility: SafariAccessibilityBackend,
        depth: Int = 0
    ) -> AXUIElement? {
        if
            accessibility.stringValue(for: kAXRoleAttribute, on: root) == role,
            accessibility.stringValue(for: kAXIdentifierAttribute, on: root) == identifier
        {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root, accessibility: accessibility) {
            if let match = firstDescendant(
                in: child,
                matchingRole: role,
                matchingIdentifier: identifier,
                accessibility: accessibility,
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
