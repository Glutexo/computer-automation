import ApplicationServices
import AutomationFoundation
import SafariAppleScript

public struct SafariSidebarTabGroupRecord: Equatable, Sendable {
    public let identifier: Int?
    public let name: String

    public init(identifier: Int?, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public enum SafariSidebar: ModelModel {
    private static let tabGroupCellIdentifierPrefix = "SidebarLibraryItemTabGroup"
    private static let contextMenuIdentifier = "SafariContextMenu"
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
        try selectTabGroup(
            matchingIdentifier: nil,
            named: tabGroupName,
            processIdentifier: nil,
            accessibility: .live
        )
    }

    public static func listTabGroups() throws -> [SafariSidebarTabGroupRecord] {
        try listTabGroups(accessibility: .live)
    }

    static func listTabGroups(
        accessibility: SafariAccessibilityBackend
    ) throws -> [SafariSidebarTabGroupRecord] {
        let (_, focusedWindow) = try focusedWindow(
            accessibility: accessibility,
            error: SafariUserInterfaceError.sidebarUnavailable
        )
        let outline = try outlinedSidebar(in: focusedWindow, accessibility: accessibility)
        return tabGroupRows(in: outline, accessibility: accessibility).map {
            SafariSidebarTabGroupRecord(
                identifier: sidebarTabGroupIdentifier($0.identifier),
                name: $0.title
            )
        }
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String
    ) throws {
        try selectTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: tabGroupName,
            processIdentifier: nil,
            accessibility: .live
        )
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String,
        processIdentifier: pid_t?
    ) throws {
        try selectTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: tabGroupName,
            processIdentifier: processIdentifier,
            accessibility: .live
        )
    }

    static func selectTabGroup(
        identifier tabGroupIdentifier: Int?,
        named tabGroupName: String,
        processIdentifier: pid_t? = nil,
        accessibility: SafariAccessibilityBackend
    ) throws {
        try selectTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: tabGroupName,
            processIdentifier: processIdentifier,
            accessibility: accessibility
        )
    }

    private static func selectTabGroup(
        matchingIdentifier tabGroupIdentifier: Int?,
        named tabGroupName: String,
        processIdentifier: pid_t?,
        accessibility: SafariAccessibilityBackend
    ) throws {
        let (_, focusedWindow) = try focusedWindow(
            accessibility: accessibility,
            error: SafariUserInterfaceError.sidebarUnavailable,
            processIdentifier: processIdentifier
        )
        let outline = try outlinedSidebar(in: focusedWindow, accessibility: accessibility)
        let matches = tabGroupRows(in: outline, accessibility: accessibility)

        guard let match = StableIdentifierMatching.resolve(
            requestedIdentifier: tabGroupIdentifier,
            from: matches,
            identifier: { sidebarTabGroupIdentifier($0.identifier) },
            fallback: { $0.title == tabGroupName }
        ) else {
            throw SafariUserInterfaceError.sidebarTabGroupNotFound(tabGroupName)
        }

        try select(
            row: match.row,
            cell: match.cell,
            in: outline,
            accessibility: accessibility
        )
    }

    private static func tabGroupRows(
        in outline: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> [(row: AXUIElement, cell: AXUIElement, title: String, identifier: String)] {
        var matches: [(row: AXUIElement, cell: AXUIElement, title: String, identifier: String)] = []

        let rows = accessibility.elements(for: kAXRowsAttribute, on: outline)
        for row in rows {
            guard let cell = accessibility.elements(for: kAXChildrenAttribute, on: row).first else {
                continue
            }

            guard let titleElement = accessibility.elementValue(for: kAXTitleUIElementAttribute, on: cell) else {
                continue
            }

            let title = accessibility.stringValue(for: kAXValueAttribute, on: titleElement)
            let identifier = tabGroupIdentifier(for: cell, accessibility: accessibility)
            guard identifier.hasPrefix(tabGroupCellIdentifierPrefix) else { continue }

            matches.append((row: row, cell: cell, title: title, identifier: identifier))
        }

        return matches
    }

    private static func tabGroupIdentifier(
        for cell: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> String {
        let currentCellIdentifier = accessibility.stringValue(for: kAXIdentifierAttribute, on: cell)
        if !currentCellIdentifier.isEmpty {
            return currentCellIdentifier
        }

        let cellChildren = accessibility.elements(for: kAXChildrenAttribute, on: cell)
        return cellChildren.first.map {
            accessibility.stringValue(for: kAXIdentifierAttribute, on: $0)
        } ?? ""
    }

    private static func select(
        row: AXUIElement,
        cell: AXUIElement,
        in outline: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) throws {
        guard accessibility.polling.firstResult({ () -> Bool? in
            guard
                accessibility.setAttribute(kAXSelectedRowsAttribute, to: [row] as CFArray, on: outline),
                accessibility.setAttribute(kAXSelectedCellsAttribute, to: [cell] as CFArray, on: outline),
                accessibility.setAttribute(kAXFocusedAttribute, to: kCFBooleanTrue, on: outline)
            else {
                return nil
            }

            let selectedRowsContainTarget = accessibility
                .elements(for: kAXSelectedRowsAttribute, on: outline)
                .contains { CFEqual($0, row) }
            let selectedCellsContainTarget = accessibility
                .elements(for: kAXSelectedCellsAttribute, on: outline)
                .contains { CFEqual($0, cell) }

            guard selectedRowsContainTarget, selectedCellsContainTarget else {
                return nil
            }

            if let rowIsSelected = accessibility.optionalBooleanValue(
                for: kAXSelectedAttribute,
                on: row
            ) {
                return rowIsSelected ? true : nil
            }

            return true
        }) != nil else {
            throw SafariUserInterfaceError.sidebarUnavailable
        }
    }

    private static func outlinedSidebar(
        in focusedWindow: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) throws -> AXUIElement {
        try waitForSidebarOutline(
            polling: accessibility.polling,
            currentOutline: {
                sidebarOutline(
                    in: focusedWindow,
                    accessibility: accessibility
                )
            },
            revealSidebar: {
                guard let sidebarButton = firstDescendant(
                    in: focusedWindow,
                    matchingIdentifier: "SidebarButton",
                    accessibility: accessibility
                ) else {
                    throw SafariUserInterfaceError.sidebarUnavailable
                }

                guard accessibility.perform(kAXPressAction, on: sidebarButton) else {
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
        executor: SafariAppleScriptExecuting
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

    public static func listTabGroups(
        executor: SafariAppleScriptExecuting
    ) throws -> [SafariSidebarTabGroupRecord] {
        do {
            return try SafariAppleScriptSidebar.listTabGroups(executor: executor).map {
                SafariSidebarTabGroupRecord(identifier: $0.identifier, name: $0.name)
            }
        } catch {
            throw SafariUserInterfaceError.sidebarUnavailable
        }
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
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
        try renameTabGroup(
            matchingIdentifier: nil,
            named: currentName,
            to: newName,
            verifyAmbiguousSelection: false,
            selectionIsVerified: { false },
            accessibility: .live
        )
    }

    public static func renameTabGroup(
        identifier tabGroupIdentifier: Int,
        named currentName: String,
        to newName: String
    ) throws {
        try renameTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: currentName,
            to: newName,
            processIdentifier: nil,
            verifyAmbiguousSelection: false,
            selectionIsVerified: { false },
            accessibility: .live
        )
    }

    public static func renameTabGroup(
        identifier tabGroupIdentifier: Int,
        named currentName: String,
        to newName: String,
        processIdentifier: pid_t?,
        selectionIsVerified: () throws -> Bool
    ) throws {
        try renameTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: currentName,
            to: newName,
            processIdentifier: processIdentifier,
            verifyAmbiguousSelection: true,
            selectionIsVerified: selectionIsVerified,
            accessibility: .live
        )
    }

    static func renameTabGroup(
        identifier tabGroupIdentifier: Int?,
        named currentName: String,
        to newName: String,
        processIdentifier: pid_t? = nil,
        verifyAmbiguousSelection: Bool = false,
        selectionIsVerified: () throws -> Bool = { false },
        accessibility: SafariAccessibilityBackend
    ) throws {
        try renameTabGroup(
            matchingIdentifier: tabGroupIdentifier,
            named: currentName,
            to: newName,
            processIdentifier: processIdentifier,
            verifyAmbiguousSelection: verifyAmbiguousSelection,
            selectionIsVerified: selectionIsVerified,
            accessibility: accessibility
        )
    }

    private static func renameTabGroup(
        matchingIdentifier tabGroupIdentifier: Int?,
        named currentName: String,
        to newName: String,
        processIdentifier: pid_t? = nil,
        verifyAmbiguousSelection: Bool,
        selectionIsVerified: () throws -> Bool,
        accessibility: SafariAccessibilityBackend
    ) throws {
        let (applicationElement, focusedWindow) = try focusedWindow(
            accessibility: accessibility,
            error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
            processIdentifier: processIdentifier
        )

        if let focusedRenameField = focusedSidebarRenameField(
            in: applicationElement,
            matching: currentName,
            accessibility: accessibility
        ) {
            try confirmRenameFieldAndCleanUpOnFailure(
                focusedRenameField,
                to: newName,
                accessibility: accessibility
            )
            return
        }

        let outline = try outlinedSidebar(in: focusedWindow, accessibility: accessibility)
        let matches = tabGroupRows(in: outline, accessibility: accessibility)

        let identifiedMatches = matches.compactMap { match in
            sidebarTabGroupIdentifier(match.identifier).map { (match: match, identifier: $0) }
        }
        let candidates: [(row: AXUIElement, cell: AXUIElement, title: String, identifier: String)]
        if let tabGroupIdentifier {
            if let exactMatch = identifiedMatches.first(where: { $0.identifier == tabGroupIdentifier }) {
                candidates = [exactMatch.match]
            } else if !identifiedMatches.isEmpty {
                candidates = []
            } else {
                candidates = matches.filter { $0.title == currentName }
            }
        } else {
            candidates = matches.filter { $0.title == currentName }
        }

        guard !candidates.isEmpty else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let targetMatch: (row: AXUIElement, cell: AXUIElement, title: String, identifier: String)
        if candidates.count == 1, let onlyCandidate = candidates.first {
            try select(
                row: onlyCandidate.row,
                cell: onlyCandidate.cell,
                in: outline,
                accessibility: accessibility
            )
            targetMatch = onlyCandidate
        } else {
            guard verifyAmbiguousSelection else {
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }

            var verifiedMatch: (row: AXUIElement, cell: AXUIElement, title: String, identifier: String)?
            for candidate in candidates {
                try select(
                    row: candidate.row,
                    cell: candidate.cell,
                    in: outline,
                    accessibility: accessibility
                )
                if try selectionIsVerified() {
                    verifiedMatch = candidate
                    break
                }
            }

            guard let verifiedMatch else {
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }
            targetMatch = verifiedMatch
        }

        let targetCell = targetMatch.cell
        guard let titleElement = accessibility.elementValue(for: kAXTitleUIElementAttribute, on: targetCell) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let renameField: AXUIElement
        if accessibility.stringValue(for: kAXRoleAttribute, on: titleElement) != kAXTextFieldRole {
            guard accessibility.perform(kAXShowMenuAction, on: outline) else {
                dismissContextMenu(in: applicationElement, accessibility: accessibility)
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }

            let contextMenu: AXUIElement
            do {
                contextMenu = try waitForSidebarElement(
                    error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
                    polling: accessibility.polling
                ) {
                    firstDescendant(
                        in: applicationElement,
                        matchingRole: kAXMenuRole,
                        matchingIdentifier: contextMenuIdentifier,
                        accessibility: accessibility
                    )
                }
            } catch {
                dismissContextMenu(in: applicationElement, accessibility: accessibility)
                throw error
            }

            let renameMenuItem: AXUIElement
            do {
                renameMenuItem = try waitForSidebarElement(
                    error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
                    polling: accessibility.polling
                ) {
                    firstDescendant(
                        in: contextMenu,
                        matchingRole: kAXMenuItemRole,
                        matchingIdentifier: renameTabGroupMenuItemIdentifier,
                        accessibility: accessibility
                    )
                }
            } catch {
                dismiss(contextMenu: contextMenu, accessibility: accessibility)
                throw error
            }

            guard accessibility.perform(kAXPressAction, on: renameMenuItem) else {
                dismiss(contextMenu: contextMenu, accessibility: accessibility)
                throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
            }

            do {
                renameField = try waitForSidebarElement(
                    error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
                    polling: accessibility.polling
                ) {
                    guard let refreshedTitleElement = accessibility.elementValue(
                        for: kAXTitleUIElementAttribute,
                        on: targetCell
                    ) else {
                        return nil
                    }

                    return sidebarRenameField(
                        in: applicationElement,
                        titleElement: refreshedTitleElement,
                        accessibility: accessibility
                    )
                }
            } catch {
                dismiss(contextMenu: contextMenu, accessibility: accessibility)
                cancelFocusedRenameField(in: applicationElement, accessibility: accessibility)
                throw error
            }
        } else {
            renameField = sidebarRenameField(
                in: applicationElement,
                titleElement: titleElement,
                accessibility: accessibility
            ) ?? titleElement
        }

        try confirmRenameFieldAndCleanUpOnFailure(
            renameField,
            to: newName,
            accessibility: accessibility
        )
    }

    private static func dismissContextMenu(
        in applicationElement: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) {
        guard let contextMenu = firstDescendant(
            in: applicationElement,
            matchingRole: kAXMenuRole,
            matchingIdentifier: contextMenuIdentifier,
            accessibility: accessibility
        ) else {
            return
        }

        dismiss(contextMenu: contextMenu, accessibility: accessibility)
    }

    private static func dismiss(
        contextMenu: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) {
        _ = accessibility.perform(kAXCancelAction, on: contextMenu)
    }

    private static func cancelFocusedRenameField(
        in applicationElement: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) {
        guard
            let focusedElement = accessibility.elementValue(for: kAXFocusedUIElementAttribute, on: applicationElement),
            accessibility.stringValue(for: kAXRoleAttribute, on: focusedElement) == kAXTextFieldRole,
            accessibility.stringValue(for: kAXIdentifierAttribute, on: focusedElement) == sidebarTextFieldIdentifier
        else {
            return
        }

        _ = accessibility.perform(kAXCancelAction, on: focusedElement)
    }

    private static func confirmRenameFieldAndCleanUpOnFailure(
        _ renameField: AXUIElement,
        to newName: String,
        accessibility: SafariAccessibilityBackend
    ) throws {
        do {
            try confirmRenameField(renameField, to: newName, accessibility: accessibility)
        } catch {
            _ = accessibility.perform(kAXCancelAction, on: renameField)
            throw error
        }
    }

    private static func sidebarRenameField(
        in applicationElement: AXUIElement,
        titleElement: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> AXUIElement? {
        if
            let focusedElement = accessibility.elementValue(for: kAXFocusedUIElementAttribute, on: applicationElement),
            accessibility.stringValue(for: kAXRoleAttribute, on: focusedElement) == kAXTextFieldRole,
            accessibility.stringValue(for: kAXIdentifierAttribute, on: focusedElement) == sidebarTextFieldIdentifier
        {
            return focusedElement
        }

        guard accessibility.stringValue(for: kAXRoleAttribute, on: titleElement) == kAXTextFieldRole else {
            return nil
        }

        return titleElement
    }

    private static func focusedSidebarRenameField(
        in applicationElement: AXUIElement,
        matching currentName: String,
        accessibility: SafariAccessibilityBackend
    ) -> AXUIElement? {
        guard
            let focusedElement = accessibility.elementValue(for: kAXFocusedUIElementAttribute, on: applicationElement),
            accessibility.stringValue(for: kAXRoleAttribute, on: focusedElement) == kAXTextFieldRole,
            accessibility.stringValue(for: kAXIdentifierAttribute, on: focusedElement) == sidebarTextFieldIdentifier,
            accessibility.stringValue(for: kAXValueAttribute, on: focusedElement) == currentName
        else {
            return nil
        }

        return focusedElement
    }

    private static func confirmRenameField(
        _ renameField: AXUIElement,
        to newName: String,
        accessibility: SafariAccessibilityBackend
    ) throws {
        guard accessibility.stringValue(for: kAXRoleAttribute, on: renameField) == kAXTextFieldRole else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        guard accessibility.setAttribute(kAXValueAttribute, to: newName as CFString, on: renameField) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        guard accessibility.polling.firstResult({
            accessibility.perform(kAXConfirmAction, on: renameField) ? true : nil
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
        try deleteSelectedTabGroup(accessibility: .live)
    }

    static func deleteSelectedTabGroup(accessibility: SafariAccessibilityBackend) throws {
        let (applicationElement, focusedWindow) = try focusedWindow(
            accessibility: accessibility,
            error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        )
        guard let outline = sidebarOutline(
            in: focusedWindow,
            accessibility: accessibility
        ) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let rows = accessibility.elements(for: kAXRowsAttribute, on: outline)
        guard rows.contains(where: { accessibility.booleanValue(for: kAXSelectedAttribute, on: $0) }) else {
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }
        guard accessibility.perform(kAXShowMenuAction, on: outline) else {
            dismissContextMenu(in: applicationElement, accessibility: accessibility)
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        let contextMenu: AXUIElement
        do {
            contextMenu = try waitForSidebarElement(
                error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
                polling: accessibility.polling
            ) {
                firstDescendant(
                    in: applicationElement,
                    matchingRole: kAXMenuRole,
                    matchingIdentifier: contextMenuIdentifier,
                    accessibility: accessibility
                )
            }
        } catch {
            dismissContextMenu(in: applicationElement, accessibility: accessibility)
            throw error
        }

        let deleteMenuItem: AXUIElement
        do {
            deleteMenuItem = try waitForSidebarElement(
                error: SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable,
                polling: accessibility.polling
            ) {
                firstDescendant(
                    in: contextMenu,
                    matchingRole: kAXMenuItemRole,
                    matchingIdentifier: deleteTabGroupMenuItemIdentifier,
                    accessibility: accessibility
                )
            }
        } catch {
            dismiss(contextMenu: contextMenu, accessibility: accessibility)
            throw error
        }

        guard accessibility.perform(kAXPressAction, on: deleteMenuItem) else {
            dismiss(contextMenu: contextMenu, accessibility: accessibility)
            throw SafariUserInterfaceError.sidebarSelectedItemRenameUnavailable
        }

        try SafariMenu.pressFrontWindowSheetButton(
            matchingIdentifier: "action-button-2",
            accessibility: accessibility
        )
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

    private static func focusedWindow(
        accessibility: SafariAccessibilityBackend,
        error: SafariUserInterfaceError,
        processIdentifier: pid_t? = nil
    ) throws -> (application: AXUIElement, window: AXUIElement) {
        for application in accessibility.applications() {
            if
                let processIdentifier,
                application.processIdentifier != processIdentifier
            {
                continue
            }

            if let window = accessibility.elementValue(
                for: kAXFocusedWindowAttribute,
                on: application.element
            ) {
                application.activate()
                return (application.element, window)
            }
        }

        throw error
    }

    private static func descendantElements(
        on element: AXUIElement,
        accessibility: SafariAccessibilityBackend
    ) -> [AXUIElement] {
        var seen: Set<CFHashCode> = []
        var descendants: [AXUIElement] = []

        for child in accessibility.elements(for: kAXChildrenAttribute, on: element) +
            accessibility.elements(for: "AXVisibleChildren", on: element) {
            let key = CFHash(child)
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            descendants.append(child)
        }

        return descendants
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

    private static func sidebarOutline(
        in root: AXUIElement,
        accessibility: SafariAccessibilityBackend,
        depth: Int = 0
    ) -> AXUIElement? {
        if
            accessibility.stringValue(for: kAXRoleAttribute, on: root) == kAXOutlineRole,
            accessibility.stringValue(for: kAXIdentifierAttribute, on: root) == "Sidebar"
        {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root, accessibility: accessibility) {
            if let match = sidebarOutline(
                in: child,
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
        matchingIdentifier identifier: String,
        accessibility: SafariAccessibilityBackend,
        depth: Int = 0
    ) -> AXUIElement? {
        if accessibility.stringValue(for: kAXIdentifierAttribute, on: root) == identifier {
            return root
        }

        if depth > 18 {
            return nil
        }

        for child in descendantElements(on: root, accessibility: accessibility) {
            if let match = firstDescendant(
                in: child,
                matchingIdentifier: identifier,
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
}
