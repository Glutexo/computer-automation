import AppKit
import ApplicationServices
import AutomationFoundation
import SafariAppleScript

public enum SafariSidebar: ModelModel {
    private static let tabGroupCellIdentifierPrefix = "SidebarLibraryItemTabGroup"
    private static let renameTabGroupMenuItemIdentifier = "RenameTabGroupMenuItem"
    private static let deleteTabGroupMenuItemIdentifier = "DeleteTabGroupMenuItem"
    private static let sidebarTextFieldIdentifier = "LibraryItemCellTextField"

    public static let descriptor = ModelDescriptor(
        name: "sidebar",
        abstract: "The Safari front-window sidebar.",
        commands: []
    )

    public static func selectTabGroup(
        named tabGroupName: String
    ) throws {
        try selectTabGroup(matchingIdentifier: nil, named: tabGroupName)
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String
    ) throws {
        try selectTabGroup(matchingIdentifier: tabGroupIdentifier, named: tabGroupName)
    }

    private static func selectTabGroup(
        matchingIdentifier tabGroupIdentifier: Int?,
        named tabGroupName: String
    ) throws {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.sidebarUnavailable
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        let focusedWindow = try SafariAX.requiredElementValue(
            for: kAXFocusedWindowAttribute,
            on: applicationElement,
            error: SafariUserInterfaceError.sidebarUnavailable
        )
        let outline = try outlinedSidebar(in: focusedWindow)
        let matches = tabGroupRows(in: outline)

        guard let match = StableIdentifierMatching.resolve(
            requestedIdentifier: tabGroupIdentifier,
            from: matches,
            identifier: { sidebarTabGroupIdentifier($0.identifier) },
            fallback: { $0.title == tabGroupName }
        ) else {
            throw SafariUserInterfaceError.sidebarTabGroupNotFound(tabGroupName)
        }

        try select(row: match.row, cell: match.cell, in: outline)
    }

    private static func tabGroupRows(in outline: AXUIElement) -> [(row: AXUIElement, cell: AXUIElement, title: String, identifier: String)] {
        var matches: [(row: AXUIElement, cell: AXUIElement, title: String, identifier: String)] = []

        let rows = elements(for: kAXRowsAttribute, on: outline)
        for row in rows {
            guard let cell = elements(for: kAXChildrenAttribute, on: row).first else {
                continue
            }

            guard let titleElement = elementValue(for: kAXTitleUIElementAttribute, on: cell) else {
                continue
            }

            let title = stringValue(for: kAXValueAttribute, on: titleElement)
            let identifier = tabGroupIdentifier(for: cell)
            guard identifier.hasPrefix(tabGroupCellIdentifierPrefix) else { continue }

            matches.append((row: row, cell: cell, title: title, identifier: identifier))
        }

        return matches
    }

    private static func tabGroupIdentifier(for cell: AXUIElement) -> String {
        let currentCellIdentifier = stringValue(for: kAXIdentifierAttribute, on: cell)
        if !currentCellIdentifier.isEmpty {
            return currentCellIdentifier
        }

        let cellChildren = elements(for: kAXChildrenAttribute, on: cell)
        return cellChildren.first.map { stringValue(for: kAXIdentifierAttribute, on: $0) } ?? ""
    }

    private static func select(row: AXUIElement, cell: AXUIElement, in outline: AXUIElement) throws {
        guard
            AXUIElementSetAttributeValue(outline, kAXSelectedRowsAttribute as CFString, [row] as CFArray) == .success,
            AXUIElementSetAttributeValue(outline, kAXSelectedCellsAttribute as CFString, [cell] as CFArray) == .success,
            AXUIElementSetAttributeValue(outline, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
        else {
            throw SafariUserInterfaceError.sidebarUnavailable
        }
    }

    private static func outlinedSidebar(in focusedWindow: AXUIElement) throws -> AXUIElement {
        try waitForSidebarOutline(
            currentOutline: {
                firstDescendant(in: focusedWindow, matchingRole: kAXOutlineRole)
            },
            revealSidebar: {
                guard let sidebarButton = firstDescendant(in: focusedWindow, matchingIdentifier: "SidebarButton") else {
                    throw SafariUserInterfaceError.sidebarUnavailable
                }

                guard AXUIElementPerformAction(sidebarButton, kAXPressAction as CFString) == .success else {
                    throw SafariUserInterfaceError.sidebarUnavailable
                }
            }
        )
    }

    static func waitForSidebarOutline<Element>(
        polling: SafariAXPolling = SafariAXPolling(),
        currentOutline: () throws -> Element?,
        revealSidebar: () throws -> Void
    ) throws -> Element {
        if let outline = try currentOutline() {
            return outline
        }

        try revealSidebar()

        guard let outline = try polling.firstResult(currentOutline) else {
            throw SafariUserInterfaceError.sidebarUnavailable
        }

        return outline
    }

    public static func selectTabGroup(
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        do {
            try SafariAppleScriptSidebar.selectTabGroup(named: tabGroupName, executor: executor)
        } catch SafariAppleScriptError.executionFailed(let message) {
            if message.localizedCaseInsensitiveContains("not found") {
                throw SafariUserInterfaceError.sidebarTabGroupNotFound(tabGroupName)
            }
            throw SafariUserInterfaceError.sidebarUnavailable
        } catch {
            throw SafariUserInterfaceError.sidebarUnavailable
        }
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        do {
            try SafariAppleScriptSidebar.selectTabGroup(identifier: tabGroupIdentifier, named: tabGroupName, executor: executor)
        } catch SafariAppleScriptError.executionFailed(let message) {
            if message.localizedCaseInsensitiveContains("not found") {
                throw SafariUserInterfaceError.sidebarTabGroupNotFound(tabGroupName)
            }
            throw SafariUserInterfaceError.sidebarUnavailable
        } catch {
            throw SafariUserInterfaceError.sidebarUnavailable
        }
    }

    public static func renameTabGroup(
        named currentName: String,
        to newName: String
    ) throws {
        try renameTabGroup(matchingIdentifier: nil, named: currentName, to: newName)
    }

    public static func renameTabGroup(
        identifier tabGroupIdentifier: Int,
        named currentName: String,
        to newName: String
    ) throws {
        try renameTabGroup(matchingIdentifier: tabGroupIdentifier, named: currentName, to: newName)
    }

    private static func renameTabGroup(
        matchingIdentifier tabGroupIdentifier: Int?,
        named currentName: String,
        to newName: String
    ) throws {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        let focusedWindow = try SafariAX.requiredElementValue(
            for: kAXFocusedWindowAttribute,
            on: applicationElement,
            error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        )

        if let focusedRenameField = focusedSidebarRenameField(in: applicationElement, matching: currentName) {
            try confirmRenameField(focusedRenameField, to: newName)
            return
        }

        let outline = try outlinedSidebar(in: focusedWindow)
        let matches = tabGroupRows(in: outline)

        let targetMatch = StableIdentifierMatching.resolve(
            requestedIdentifier: tabGroupIdentifier,
            from: matches,
            identifier: { sidebarTabGroupIdentifier($0.identifier) },
            fallback: { $0.title == currentName }
        )

        guard let targetMatch else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let targetRow = targetMatch.row
        let targetCell = targetMatch.cell

        guard
            AXUIElementSetAttributeValue(outline, kAXSelectedRowsAttribute as CFString, [targetRow] as CFArray) == .success,
            AXUIElementSetAttributeValue(outline, kAXSelectedCellsAttribute as CFString, [targetCell] as CFArray) == .success,
            AXUIElementSetAttributeValue(outline, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
        else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        guard let titleElement = elementValue(for: kAXTitleUIElementAttribute, on: targetCell) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let renameField: AXUIElement
        if stringValue(for: kAXRoleAttribute, on: titleElement) != kAXTextFieldRole {
            guard AXUIElementPerformAction(titleElement, kAXShowMenuAction as CFString) == .success else {
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }

            let renameMenuItem = try waitForSidebarElement(
                error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            ) {
                firstDescendant(
                    in: applicationElement,
                    matchingRole: kAXMenuItemRole,
                    matchingIdentifier: renameTabGroupMenuItemIdentifier
                )
            }

            guard AXUIElementPerformAction(renameMenuItem, kAXPressAction as CFString) == .success else {
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }

            renameField = try waitForSidebarElement(
                error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            ) {
                guard let refreshedTitleElement = elementValue(for: kAXTitleUIElementAttribute, on: targetCell) else {
                    return nil
                }

                return sidebarRenameField(in: applicationElement, titleElement: refreshedTitleElement)
            }
        } else {
            renameField = sidebarRenameField(in: applicationElement, titleElement: titleElement) ?? titleElement
        }

        try confirmRenameField(renameField, to: newName)
    }

    private static func sidebarRenameField(
        in applicationElement: AXUIElement,
        titleElement: AXUIElement
    ) -> AXUIElement? {
        if
            let focusedElement = elementValue(for: kAXFocusedUIElementAttribute, on: applicationElement),
            stringValue(for: kAXRoleAttribute, on: focusedElement) == kAXTextFieldRole,
            stringValue(for: kAXIdentifierAttribute, on: focusedElement) == sidebarTextFieldIdentifier
        {
            return focusedElement
        }

        guard stringValue(for: kAXRoleAttribute, on: titleElement) == kAXTextFieldRole else {
            return nil
        }

        return titleElement
    }

    private static func focusedSidebarRenameField(in applicationElement: AXUIElement, matching currentName: String) -> AXUIElement? {
        guard
            let focusedElement = elementValue(for: kAXFocusedUIElementAttribute, on: applicationElement),
            stringValue(for: kAXRoleAttribute, on: focusedElement) == kAXTextFieldRole,
            stringValue(for: kAXIdentifierAttribute, on: focusedElement) == sidebarTextFieldIdentifier,
            stringValue(for: kAXValueAttribute, on: focusedElement) == currentName
        else {
            return nil
        }

        return focusedElement
    }

    private static func confirmRenameField(_ renameField: AXUIElement, to newName: String) throws {
        guard stringValue(for: kAXRoleAttribute, on: renameField) == kAXTextFieldRole else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        guard AXUIElementSetAttributeValue(renameField, kAXValueAttribute as CFString, newName as CFString) == .success else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        guard SafariAXPolling().firstResult({
            AXUIElementPerformAction(renameField, kAXConfirmAction as CFString) == .success ? true : nil
        }) != nil else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }
    }

    static func sidebarIdentifier(_ rawIdentifier: String, matchesTabGroupIdentifier tabGroupIdentifier: Int) -> Bool {
        sidebarTabGroupIdentifier(rawIdentifier) == tabGroupIdentifier
    }

    static func sidebarTabGroupIdentifier(_ rawIdentifier: String) -> Int? {
        guard rawIdentifier.hasPrefix(tabGroupCellIdentifierPrefix) else {
            return nil
        }

        var currentDigits = ""

        for character in rawIdentifier.dropFirst(tabGroupCellIdentifierPrefix.count) {
            if character.isNumber {
                currentDigits.append(character)
                continue
            }

            if !currentDigits.isEmpty {
                return Int(currentDigits)
            }
        }

        return Int(currentDigits)
    }

    public static func deleteSelectedTabGroup() throws {
        guard let safariApplication = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let applicationElement = AXUIElementCreateApplication(safariApplication.processIdentifier)
        let focusedWindow = try SafariAX.requiredElementValue(
            for: kAXFocusedWindowAttribute,
            on: applicationElement,
            error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        )
        guard let outline = firstDescendant(in: focusedWindow, matchingRole: kAXOutlineRole) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let rows = elements(for: kAXRowsAttribute, on: outline)
        guard
            let selectedRow = rows.first(where: { booleanValue(for: kAXSelectedAttribute, on: $0) }),
            let cell = elements(for: kAXChildrenAttribute, on: selectedRow).first,
            let titleElement = elementValue(for: kAXTitleUIElementAttribute, on: cell),
            AXUIElementPerformAction(titleElement, kAXShowMenuAction as CFString) == .success
        else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let deleteMenuItem = try waitForSidebarElement(
            error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        ) {
            firstDescendant(
                in: applicationElement,
                matchingRole: kAXMenuItemRole,
                matchingIdentifier: deleteTabGroupMenuItemIdentifier
            )
        }

        guard AXUIElementPerformAction(deleteMenuItem, kAXPressAction as CFString) == .success else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        try SafariMenu.pressFrontWindowSheetButton(matchingIdentifier: "action-button-2")
    }

    static func waitForSidebarElement<Element>(
        error: SafariUserInterfaceError,
        polling: SafariAXPolling = SafariAXPolling(),
        currentElement: () throws -> Element?
    ) throws -> Element {
        guard let element = try polling.firstResult(currentElement) else {
            throw error
        }

        return element
    }

    private static func elements(for attribute: String, on element: AXUIElement) -> [AXUIElement] {
        SafariAX.elements(for: attribute, on: element)
    }

    private static func elementValue(for attribute: String, on element: AXUIElement) -> AXUIElement? {
        SafariAX.elementValue(for: attribute, on: element)
    }

    private static func stringValue(for attribute: String, on element: AXUIElement) -> String {
        SafariAX.stringValue(for: attribute, on: element)
    }

    private static func booleanValue(for attribute: String, on element: AXUIElement) -> Bool {
        SafariAX.booleanValue(for: attribute, on: element)
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

    private static func firstDescendant(in root: AXUIElement, matchingRole role: String, depth: Int = 0) -> AXUIElement? {
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
        matchingIdentifier identifier: String,
        depth: Int = 0
    ) -> AXUIElement? {
        if stringValue(for: kAXIdentifierAttribute, on: root) == identifier {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root) {
            if let match = firstDescendant(in: child, matchingIdentifier: identifier, depth: depth + 1) {
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
}
