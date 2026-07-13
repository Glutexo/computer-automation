import Testing
import Foundation
import ApplicationServices
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

private final class FakeSafariAccessibility {
    private struct StoredAttribute {
        let element: AXUIElement
        let name: String
        let value: CFTypeRef
    }

    struct WrittenAttribute {
        let element: AXUIElement
        let name: String
        let value: CFTypeRef
    }

    let applicationElements: [AXUIElement]
    private var attributes: [StoredAttribute] = []
    var writtenAttributes: [WrittenAttribute] = []
    var performedActions: [(action: String, element: AXUIElement)] = []
    var sleptIntervals: [TimeInterval] = []
    var activationCount = 0
    var attributeReadCount = 0
    var actionHandler: ((String, AXUIElement) -> Bool)?
    var writeHandler: ((String, CFTypeRef, AXUIElement) -> Bool)?

    init(applicationElements: [AXUIElement]) {
        self.applicationElements = applicationElements
    }

    func set(_ name: String, on element: AXUIElement, to value: CFTypeRef) {
        attributes.removeAll { sameElement($0.element, element) && $0.name == name }
        attributes.append(StoredAttribute(element: element, name: name, value: value))
    }

    func setElements(_ name: String, on element: AXUIElement, to values: [AXUIElement]) {
        set(name, on: element, to: values as CFArray)
    }

    func value(_ name: String, on element: AXUIElement) -> CFTypeRef? {
        attributes.last(where: { sameElement($0.element, element) && $0.name == name })?.value
    }

    func backend(maxAttempts: Int = 3) -> SafariAccessibilityBackend {
        SafariAccessibilityBackend(
            applications: {
                self.applicationElements.map { element in
                    SafariAccessibilityApplication(
                        element: element,
                        activate: { self.activationCount += 1 }
                    )
                }
            },
            readAttribute: { name, element in
                self.attributeReadCount += 1
                return self.value(name, on: element)
            },
            writeAttribute: { name, value, element in
                self.writtenAttributes.append(WrittenAttribute(element: element, name: name, value: value))
                guard self.writeHandler?(name, value, element) ?? true else {
                    return false
                }
                self.set(name, on: element, to: value)
                return true
            },
            performAction: { action, element in
                self.performedActions.append((action, element))
                return self.actionHandler?(action, element) ?? true
            },
            polling: SafariAXPolling(
                maxAttempts: maxAttempts,
                interval: 0.05,
                sleep: { self.sleptIntervals.append($0) }
            )
        )
    }
}

private func testAXElement(_ identifier: Int32) -> AXUIElement {
    AXUIElementCreateApplication(pid_t(identifier))
}

private func sameElement(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
    CFEqual(lhs, rhs)
}

@discardableResult
private func configureMenu(
    fake: FakeSafariAccessibility,
    application: AXUIElement,
    menuBarItemIndex: Int = 3,
    items: [AXUIElement]
) -> AXUIElement {
    let menuBar = testAXElement(91_000)
    let menu = testAXElement(91_001)
    let menuBarItems = (0..<menuBarItemIndex).map { testAXElement(91_010 + Int32($0)) }
    let targetMenuBarItem = menuBarItems[menuBarItemIndex - 1]

    fake.setElements(kAXChildrenAttribute, on: application, to: [menuBar])
    fake.set(kAXRoleAttribute, on: menuBar, to: kAXMenuBarRole as CFString)
    fake.setElements(kAXChildrenAttribute, on: menuBar, to: menuBarItems)
    fake.setElements(kAXChildrenAttribute, on: targetMenuBarItem, to: [menu])
    fake.set(kAXRoleAttribute, on: menu, to: kAXMenuRole as CFString)
    fake.setElements(kAXChildrenAttribute, on: menu, to: items)
    for item in items {
        fake.set(kAXRoleAttribute, on: item, to: kAXMenuItemRole as CFString)
    }

    return targetMenuBarItem
}

@Test func safariMenuItemParsesIndexedMenuItemRecords() async throws {
    let itemOne = NSAppleEventDescriptor.list()
    itemOne.insert(NSAppleEventDescriptor(string: "1"), at: 1)
    itemOne.insert(NSAppleEventDescriptor(string: "File"), at: 2)
    itemOne.insert(NSAppleEventDescriptor(string: ""), at: 3)
    itemOne.insert(NSAppleEventDescriptor(string: ""), at: 4)

    let itemTwo = NSAppleEventDescriptor.list()
    itemTwo.insert(NSAppleEventDescriptor(string: "2"), at: 1)
    itemTwo.insert(NSAppleEventDescriptor(string: "Open…"), at: 2)
    itemTwo.insert(NSAppleEventDescriptor(string: "O"), at: 3)
    itemTwo.insert(NSAppleEventDescriptor(string: "0"), at: 4)

    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(itemOne, at: 1)
    listDescriptor.insert(itemTwo, at: 2)

    #expect(
        SafariMenuItem.parseRecordsWithKeyboardShortcut(from: listDescriptor) ==
        [
            SafariMenuItemRecord(index: 1, title: "File"),
            SafariMenuItemRecord(index: 2, title: "Open…", commandCharacter: "O", commandModifiers: "0")
        ]
    )
}

@Test(arguments: [
    SafariMenuItemRecord(index: 1, title: "Open…"),
    SafariMenuItemRecord(index: 2, title: "Close", commandCharacter: "W"),
    SafariMenuItemRecord(index: 3, title: "Share…", commandModifiers: "8"),
    SafariMenuItemRecord(index: 4, title: "Import", commandCharacter: "I", commandModifiers: "2")
])
func safariMenuItemFormatFillsMissingFieldsWithEmptyStrings(item: SafariMenuItemRecord) async throws {
    let components = SafariMenuItem.format(item).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    #expect(components.count == 4)
    #expect(components[0] == String(item.index))
    #expect(components[1] == item.title)
    #expect(components[2] == (item.commandCharacter ?? ""))
    #expect(components[3] == (item.commandModifiers ?? ""))
}

@Test(arguments: [
    SafariAppleScriptMenuItemRecord(index: 1, title: "Apple"),
    SafariAppleScriptMenuItemRecord(index: 2, title: "Open…", commandCharacter: "O", commandModifiers: "0")
])
func safariMenuItemBridgePreservesAppleScriptRecordFields(record: SafariAppleScriptMenuItemRecord) async throws {
    let bridged = SafariMenuItemRecord(record)
    #expect(bridged.index == record.index)
    #expect(bridged.title == record.title)
    #expect(bridged.commandCharacter == record.commandCharacter)
    #expect(bridged.commandModifiers == record.commandModifiers)
}

@Test func safariApplicationMenuBarMapsAppleScriptItemsIntoUiModel() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeIndexTitleList([(1, "Apple"), (2, "Safari")]))])
    let items = try SafariApplicationMenuBar.listItems(executor: executor)
    #expect(items == [
        SafariMenuItemRecord(index: 1, title: "Apple"),
        SafariMenuItemRecord(index: 2, title: "Safari")
    ])
}

@Test func safariMenuMapsAppleScriptItemsIntoUiModel() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList([(1, "Open…", "O", "0")]))])
    let items = try SafariMenu.listItems(menuBarItemIndex: 3, executor: executor)
    #expect(items == [SafariMenuItemRecord(index: 1, title: "Open…", commandCharacter: "O", commandModifiers: "0")])
}

@Test func safariMenuWrapsAppleScriptFailure() async throws {
    let executor = MockAppleScriptExecutor(error: SafariAppleScriptError.scriptCompilationFailed)
    #expect(throws: SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 3)) {
        try SafariMenu.listItems(menuBarItemIndex: 3, executor: executor)
    }
}

@Test func safariMenuAccessibilityBackendDrivesProductionMenuFlow() async throws {
    let application = testAXElement(92_000)
    let firstItem = testAXElement(92_001)
    let secondItem = testAXElement(92_002)
    let fake = FakeSafariAccessibility(applicationElements: [application])
    let menuBarItem = configureMenu(fake: fake, application: application, items: [firstItem, secondItem])
    fake.set(kAXTitleAttribute, on: firstItem, to: "Open…" as CFString)
    fake.set("AXMenuItemCmdChar", on: firstItem, to: "O" as CFString)
    fake.set("AXMenuItemCmdModifiers", on: firstItem, to: "0" as CFString)
    fake.set(kAXTitleAttribute, on: secondItem, to: "Close" as CFString)
    fake.set("AXMenuItemCmdChar", on: secondItem, to: "W" as CFString)

    let items = try SafariMenu.listItems(
        menuBarItemIndex: 3,
        backend: .accessibility(fake.backend())
    )

    #expect(
        items == [
            SafariMenuItemRecord(index: 1, title: "Open…", commandCharacter: "O", commandModifiers: "0"),
            SafariMenuItemRecord(index: 2, title: "Close", commandCharacter: "W")
        ]
    )
    #expect(fake.activationCount == 1)
    #expect(fake.performedActions.contains(where: { sameElement($0.element, menuBarItem) }))
}

@Test func safariMenuAccessibilityBackendReportsNativeDiscoveryTimeout() async throws {
    let application = testAXElement(93_000)
    let fake = FakeSafariAccessibility(applicationElements: [application])

    #expect(throws: SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 3)) {
        try SafariMenu.listItems(
            menuBarItemIndex: 3,
            backend: .accessibility(fake.backend(maxAttempts: 3))
        )
    }

    #expect(fake.attributeReadCount > 0)
    #expect(fake.sleptIntervals == [0.05, 0.05])
}

@Test func safariFileMenuAccessibilityBackendPressesStableIdentifier() async throws {
    let application = testAXElement(94_000)
    let unrelatedItem = testAXElement(94_001)
    let targetItem = testAXElement(94_002)
    let fake = FakeSafariAccessibility(applicationElements: [application])
    configureMenu(fake: fake, application: application, items: [unrelatedItem, targetItem])
    fake.set(kAXIdentifierAttribute, on: unrelatedItem, to: "Unrelated" as CFString)
    fake.set(
        kAXIdentifierAttribute,
        on: targetItem,
        to: SafariFileMenu.createEmptyTabGroupMenuItemIdentifier as CFString
    )

    try SafariFileMenu.createEmptyTabGroup(accessibility: fake.backend())

    #expect(
        fake.performedActions.contains {
            $0.action == kAXPressAction && sameElement($0.element, targetItem)
        }
    )
}

@Test func safariMenuItemMapsAppleScriptChildItemsIntoUiModel() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList([(1, "Firefox…", "", "0")]))])
    let items = try SafariMenuItem.listChildItems(menuBarItemIndex: 3, menuItemIndex: 27, executor: executor)
    #expect(items == [SafariMenuItemRecord(index: 1, title: "Firefox…", commandModifiers: "0")])
}

@Test func safariMenuItemWrapsAppleScriptFailure() async throws {
    let executor = MockAppleScriptExecutor(error: SafariAppleScriptError.scriptCompilationFailed)
    #expect(throws: SafariUserInterfaceError.menuItemChildrenUnavailable(menuBarItemIndex: 3, menuItemIndex: 27)) {
        try SafariMenuItem.listChildItems(menuBarItemIndex: 3, menuItemIndex: 27, executor: executor)
    }
}

@Test func safariSidebarWrapsLookupFailures() async throws {
    let missingExecutor = MockAppleScriptExecutor(error: SafariAppleScriptError.executionFailed("not found"))
    #expect(throws: SafariUserInterfaceError.sidebarTabGroupNotFound("Focus")) {
        try SafariSidebar.selectTabGroup(named: "Focus", executor: missingExecutor)
    }
}

@Test func safariSidebarAccessibilityBackendRevealsAndSelectsIdentifierOrName() async throws {
    let application = testAXElement(95_000)
    let window = testAXElement(95_001)
    let decoy = testAXElement(95_002)
    let sidebarButton = testAXElement(95_003)
    let outline = testAXElement(95_004)
    let firstRow = testAXElement(95_005)
    let firstCell = testAXElement(95_006)
    let firstTitle = testAXElement(95_007)
    let secondRow = testAXElement(95_008)
    let secondCell = testAXElement(95_009)
    let secondTitle = testAXElement(95_010)
    let fake = FakeSafariAccessibility(applicationElements: [application])

    fake.set(kAXFocusedWindowAttribute, on: application, to: window)
    fake.setElements(kAXChildrenAttribute, on: window, to: [decoy, sidebarButton])
    fake.set(kAXRoleAttribute, on: decoy, to: kAXGroupRole as CFString)
    fake.set(kAXIdentifierAttribute, on: sidebarButton, to: "SidebarButton" as CFString)
    fake.set(kAXRoleAttribute, on: outline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: outline, to: "Sidebar" as CFString)
    fake.set("AXVisible", on: outline, to: kCFBooleanFalse)
    fake.setElements(kAXRowsAttribute, on: outline, to: [firstRow, secondRow])
    fake.setElements(kAXChildrenAttribute, on: firstRow, to: [firstCell])
    fake.setElements(kAXChildrenAttribute, on: secondRow, to: [secondCell])
    fake.set(kAXTitleUIElementAttribute, on: firstCell, to: firstTitle)
    fake.set(kAXTitleUIElementAttribute, on: secondCell, to: secondTitle)
    fake.set(kAXValueAttribute, on: firstTitle, to: "Alpha" as CFString)
    fake.set(kAXValueAttribute, on: secondTitle, to: "Focus" as CFString)
    fake.set(kAXIdentifierAttribute, on: firstCell, to: "SidebarLibraryItemTabGroup-10" as CFString)
    fake.set(kAXIdentifierAttribute, on: secondCell, to: "SidebarLibraryItemTabGroup-11" as CFString)
    fake.actionHandler = { action, element in
        if action == kAXPressAction && sameElement(element, sidebarButton) {
            fake.setElements(kAXChildrenAttribute, on: window, to: [decoy, sidebarButton, outline])
        }
        return true
    }

    let accessibility = fake.backend()
    try SafariSidebar.selectTabGroup(identifier: 11, named: "Focus", accessibility: accessibility)

    let identifierSelection = fake.writtenAttributes.first(where: { $0.name == kAXSelectedRowsAttribute })
    #expect((identifierSelection?.value as? [AXUIElement])?.first.map { sameElement($0, secondRow) } == true)
    #expect(fake.performedActions.contains(where: { $0.action == kAXPressAction && sameElement($0.element, sidebarButton) }))
    #expect(fake.activationCount == 1)

    fake.writtenAttributes.removeAll()
    fake.set(kAXIdentifierAttribute, on: firstCell, to: "SidebarLibraryItemTabGroup" as CFString)
    fake.set(kAXIdentifierAttribute, on: secondCell, to: "SidebarLibraryItemTabGroup" as CFString)
    try SafariSidebar.selectTabGroup(identifier: 99, named: "Alpha", accessibility: accessibility)

    let nameSelection = fake.writtenAttributes.first(where: { $0.name == kAXSelectedRowsAttribute })
    #expect((nameSelection?.value as? [AXUIElement])?.first.map { sameElement($0, firstRow) } == true)
    #expect(fake.activationCount == 2)
}

@Test func safariSidebarAccessibilityBackendSkipsDecoyAndAcceptsFalseAXVisible() async throws {
    let application = testAXElement(95_100)
    let window = testAXElement(95_101)
    let decoyOutline = testAXElement(95_102)
    let splitGroup = testAXElement(95_104)
    let scrollArea = testAXElement(95_105)
    let sidebarOutline = testAXElement(95_106)
    let sidebarButton = testAXElement(95_107)
    let row = testAXElement(95_108)
    let cell = testAXElement(95_109)
    let title = testAXElement(95_110)
    let fake = FakeSafariAccessibility(applicationElements: [application])

    fake.set(kAXFocusedWindowAttribute, on: application, to: window)
    fake.setElements(
        kAXChildrenAttribute,
        on: window,
        to: [decoyOutline, splitGroup, sidebarButton]
    )
    fake.set(kAXRoleAttribute, on: decoyOutline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: decoyOutline, to: "OtherOutline" as CFString)
    fake.set("AXVisible", on: decoyOutline, to: kCFBooleanTrue)
    fake.setElements(kAXChildrenAttribute, on: splitGroup, to: [scrollArea])
    fake.setElements(kAXChildrenAttribute, on: scrollArea, to: [sidebarOutline])
    fake.set(kAXRoleAttribute, on: sidebarOutline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: sidebarOutline, to: "Sidebar" as CFString)
    fake.set("AXVisible", on: sidebarOutline, to: kCFBooleanFalse)
    fake.setElements(kAXRowsAttribute, on: sidebarOutline, to: [row])
    fake.setElements(kAXChildrenAttribute, on: row, to: [cell])
    fake.set(kAXIdentifierAttribute, on: cell, to: "SidebarLibraryItemTabGroup-42" as CFString)
    fake.set(kAXTitleUIElementAttribute, on: cell, to: title)
    fake.set(kAXValueAttribute, on: title, to: "Focus" as CFString)
    fake.set(kAXIdentifierAttribute, on: sidebarButton, to: "SidebarButton" as CFString)

    try SafariSidebar.selectTabGroup(
        identifier: 42,
        named: "Focus",
        accessibility: fake.backend()
    )

    let selection = fake.writtenAttributes.first(where: { $0.name == kAXSelectedRowsAttribute })
    #expect(sameElement(selection?.element ?? decoyOutline, sidebarOutline))
    #expect((selection?.value as? [AXUIElement])?.first.map { sameElement($0, row) } == true)
    #expect(!fake.performedActions.contains(where: {
        $0.action == kAXPressAction && sameElement($0.element, sidebarButton)
    }))
}

@Test func safariSidebarAccessibilityBackendDiscoversAndConfirmsRename() async throws {
    let application = testAXElement(96_000)
    let window = testAXElement(96_001)
    let outline = testAXElement(96_002)
    let row = testAXElement(96_003)
    let cell = testAXElement(96_004)
    let title = testAXElement(96_005)
    let renameMenuItem = testAXElement(96_006)
    let renameField = testAXElement(96_007)
    let fake = FakeSafariAccessibility(applicationElements: [application])

    fake.set(kAXFocusedWindowAttribute, on: application, to: window)
    fake.setElements(kAXChildrenAttribute, on: application, to: [window, renameMenuItem])
    fake.setElements(kAXChildrenAttribute, on: window, to: [outline])
    fake.set(kAXRoleAttribute, on: outline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: outline, to: "Sidebar" as CFString)
    fake.set("AXVisible", on: outline, to: kCFBooleanFalse)
    fake.setElements(kAXRowsAttribute, on: outline, to: [row])
    fake.setElements(kAXChildrenAttribute, on: row, to: [cell])
    fake.set(kAXIdentifierAttribute, on: cell, to: "SidebarLibraryItemTabGroup-42" as CFString)
    fake.set(kAXTitleUIElementAttribute, on: cell, to: title)
    fake.set(kAXRoleAttribute, on: title, to: kAXStaticTextRole as CFString)
    fake.set(kAXValueAttribute, on: title, to: "Old" as CFString)
    fake.set(kAXRoleAttribute, on: renameMenuItem, to: kAXMenuItemRole as CFString)
    fake.set(kAXIdentifierAttribute, on: renameMenuItem, to: "RenameTabGroupMenuItem" as CFString)
    fake.set(kAXRoleAttribute, on: renameField, to: kAXTextFieldRole as CFString)
    fake.set(kAXIdentifierAttribute, on: renameField, to: "LibraryItemCellTextField" as CFString)
    fake.actionHandler = { action, element in
        if action == kAXPressAction && sameElement(element, renameMenuItem) {
            fake.set(kAXTitleUIElementAttribute, on: cell, to: renameField)
        }
        return true
    }

    try SafariSidebar.renameTabGroup(
        identifier: 42,
        named: "Old",
        to: "New",
        accessibility: fake.backend()
    )

    #expect((fake.value(kAXValueAttribute, on: renameField) as? String) == "New")
    #expect(fake.performedActions.contains(where: { $0.action == kAXShowMenuAction && sameElement($0.element, title) }))
    #expect(fake.performedActions.contains(where: { $0.action == kAXPressAction && sameElement($0.element, renameMenuItem) }))
    #expect(fake.performedActions.contains(where: { $0.action == kAXConfirmAction && sameElement($0.element, renameField) }))
}

@Test func safariSidebarAccessibilityBackendDeletesSelectedGroupAndConfirmsSheet() async throws {
    let application = testAXElement(97_000)
    let window = testAXElement(97_001)
    let outline = testAXElement(97_002)
    let row = testAXElement(97_003)
    let cell = testAXElement(97_004)
    let title = testAXElement(97_005)
    let deleteMenuItem = testAXElement(97_006)
    let sheet = testAXElement(97_007)
    let confirmationButton = testAXElement(97_008)
    let decoyOutline = testAXElement(97_009)
    let fake = FakeSafariAccessibility(applicationElements: [application])

    fake.set(kAXFocusedWindowAttribute, on: application, to: window)
    fake.setElements(kAXChildrenAttribute, on: application, to: [window, deleteMenuItem])
    fake.setElements(kAXChildrenAttribute, on: window, to: [decoyOutline, outline])
    fake.set(kAXRoleAttribute, on: decoyOutline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: decoyOutline, to: "OtherOutline" as CFString)
    fake.set("AXVisible", on: decoyOutline, to: kCFBooleanTrue)
    fake.set(kAXRoleAttribute, on: outline, to: kAXOutlineRole as CFString)
    fake.set(kAXIdentifierAttribute, on: outline, to: "Sidebar" as CFString)
    fake.set("AXVisible", on: outline, to: kCFBooleanTrue)
    fake.setElements(kAXRowsAttribute, on: outline, to: [row])
    fake.set(kAXSelectedAttribute, on: row, to: kCFBooleanTrue)
    fake.setElements(kAXChildrenAttribute, on: row, to: [cell])
    fake.set(kAXTitleUIElementAttribute, on: cell, to: title)
    fake.set(kAXRoleAttribute, on: deleteMenuItem, to: kAXMenuItemRole as CFString)
    fake.set(kAXIdentifierAttribute, on: deleteMenuItem, to: "DeleteTabGroupMenuItem" as CFString)
    fake.setElements("AXSheets", on: window, to: [sheet])
    fake.set(kAXRoleAttribute, on: sheet, to: kAXSheetRole as CFString)
    fake.setElements(kAXChildrenAttribute, on: sheet, to: [confirmationButton])
    fake.set(kAXRoleAttribute, on: confirmationButton, to: kAXButtonRole as CFString)
    fake.set(kAXIdentifierAttribute, on: confirmationButton, to: "action-button-2" as CFString)

    try SafariSidebar.deleteSelectedTabGroup(accessibility: fake.backend())

    #expect(fake.performedActions.contains(where: { $0.action == kAXShowMenuAction && sameElement($0.element, title) }))
    #expect(fake.performedActions.contains(where: { $0.action == kAXPressAction && sameElement($0.element, deleteMenuItem) }))
    #expect(fake.performedActions.contains(where: { $0.action == kAXPressAction && sameElement($0.element, confirmationButton) }))
}

@Test func safariAccessibilityWindowAcceptsNormalCloseReadback() async throws {
    var isVisible = true
    var didPressCloseButton = false

    try SafariAccessibilityWindow.closeCapturedWindow(
        performClose: { isVisible = false },
        isVisible: { isVisible },
        pressCloseButton: {
            didPressCloseButton = true
            return true
        },
        sleep: { _ in },
        maxAttempts: 1
    )

    #expect(!didPressCloseButton)
}

@Test func safariAccessibilityWindowFallsBackToExactCloseButton() async throws {
    var isVisible = true
    var didPressCloseButton = false

    try SafariAccessibilityWindow.closeCapturedWindow(
        performClose: {},
        isVisible: { isVisible },
        pressCloseButton: {
            didPressCloseButton = true
            isVisible = false
            return true
        },
        sleep: { _ in },
        maxAttempts: 1
    )

    #expect(didPressCloseButton)
}

@Test func safariAccessibilityWindowReportsUnverifiedVisibleWindows() async throws {
    #expect(throws: SafariUserInterfaceError.windowCloseButtonUnavailable) {
        try SafariAccessibilityWindow.closeCapturedWindow(
            performClose: {},
            isVisible: { true },
            pressCloseButton: { false },
            sleep: { _ in },
            maxAttempts: 1
        )
    }

    #expect(throws: SafariUserInterfaceError.windowCloseNotVerified) {
        try SafariAccessibilityWindow.closeCapturedWindow(
            performClose: {},
            isVisible: { true },
            pressCloseButton: { true },
            sleep: { _ in },
            maxAttempts: 1
        )
    }
}

@Test func safariAccessibilityWindowUsesInjectedFocusedWindowAndCloseButton() async throws {
    let application = testAXElement(98_000)
    let window = testAXElement(98_001)
    let closeButton = testAXElement(98_002)
    let fake = FakeSafariAccessibility(applicationElements: [application])
    fake.set(kAXFocusedWindowAttribute, on: application, to: window)
    fake.set("AXVisible", on: window, to: kCFBooleanTrue)
    fake.set(kAXCloseButtonAttribute, on: window, to: closeButton)
    fake.actionHandler = { action, element in
        if action == kAXPressAction && sameElement(element, closeButton) {
            fake.set("AXVisible", on: window, to: kCFBooleanFalse)
        }
        return true
    }

    try SafariAccessibilityWindow.closeFocusedWindow(
        performClose: {},
        accessibility: fake.backend(maxAttempts: 1)
    )

    #expect(fake.performedActions.contains(where: { sameElement($0.element, closeButton) }))
}

@Test func safariSidebarMatchesWholeTabGroupIdentifierTokens() async throws {
    #expect(SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup?TabGroup=100", matchesTabGroupIdentifier: 100))
    #expect(SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup-42-profile-7", matchesTabGroupIdentifier: 42))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup?TabGroup=1001", matchesTabGroupIdentifier: 100))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup-42-profile-7", matchesTabGroupIdentifier: 7))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemOther?TabGroup=100", matchesTabGroupIdentifier: 100))
    #expect(SafariSidebar.sidebarTabGroupIdentifier("SidebarLibraryItemTabGroup?TabGroup=100") == 100)
    #expect(SafariSidebar.sidebarTabGroupIdentifier("SidebarLibraryItemTabGroup-42-profile-7") == 42)
    #expect(SafariSidebar.sidebarTabGroupIdentifier("SidebarLibraryItemTabGroup") == nil)
    #expect(SafariSidebar.sidebarTabGroupIdentifier("SidebarLibraryItemOther?TabGroup=100") == nil)
}

@Test func safariAXElementReaderThrowsDomainErrorForWrongAttributeType() async throws {
    let root = AXUIElementCreateSystemWide()
    let wrongValue: CFTypeRef = "not an AX element" as CFString

    #expect(throws: SafariUserInterfaceError.sidebarUnavailable) {
        try SafariAX.requiredElementValue(
            for: kAXFocusedWindowAttribute,
            on: root,
            error: SafariUserInterfaceError.sidebarUnavailable,
            readAttribute: { _, _ in wrongValue }
        )
    }
}

@Test func safariAXElementReaderThrowsDomainErrorForMissingFocusedWindow() async throws {
    let root = AXUIElementCreateSystemWide()

    #expect(throws: SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)) {
        try SafariAX.requiredElementValue(
            for: kAXFocusedWindowAttribute,
            on: root,
            error: SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0),
            readAttribute: { _, _ in nil }
        )
    }
}

@Test func safariAXElementArrayFiltersUnexpectedElementTypes() async throws {
    let root = AXUIElementCreateSystemWide()
    let child = AXUIElementCreateSystemWide()
    let mixedValues: CFTypeRef = [child, "unexpected child"] as CFArray

    let elements = SafariAX.elements(
        for: kAXChildrenAttribute,
        on: root,
        readAttribute: { _, _ in mixedValues }
    )

    #expect(elements.count == 1)
    #expect(CFEqual(elements[0], child))
}

@Test func safariSidebarWaitsForDelayedOutlineAvailability() async throws {
    var didRevealSidebar = false
    var lookupCount = 0
    var sleptIntervals: [TimeInterval] = []

    let outline = try SafariSidebar.waitForSidebarOutline(
        polling: SafariAXPolling(maxAttempts: 4, interval: 0.25, sleep: { sleptIntervals.append($0) }),
        currentOutline: {
            lookupCount += 1
            return lookupCount == 3 ? "outline" : nil
        },
        revealSidebar: {
            didRevealSidebar = true
        }
    )

    #expect(outline == "outline")
    #expect(didRevealSidebar)
    #expect(lookupCount == 3)
    #expect(sleptIntervals == [0.25])
}

@Test func safariMenuWaitsForDelayedMenuAvailability() async throws {
    var lookupCount = 0
    var sleptIntervals: [TimeInterval] = []

    let menu = try SafariMenu.waitForMenuElement(
        menuBarItemIndex: 3,
        polling: SafariAXPolling(maxAttempts: 4, interval: 0.05, sleep: { sleptIntervals.append($0) }),
        currentElement: {
            lookupCount += 1
            return lookupCount == 3 ? "menu" : nil
        }
    )

    #expect(menu == "menu")
    #expect(lookupCount == 3)
    #expect(sleptIntervals == [0.05, 0.05])
}

@Test func safariMenuPollsForDelayedSheetButtonAvailability() async throws {
    var pressAttempts = 0
    var sleptIntervals: [TimeInterval] = []

    try SafariMenu.waitForSheetButtonPress(
        polling: SafariAXPolling(maxAttempts: 4, interval: 0.1, sleep: { sleptIntervals.append($0) }),
        pressMatchingButton: {
            pressAttempts += 1
            return pressAttempts == 3
        }
    )

    #expect(pressAttempts == 3)
    #expect(sleptIntervals == [0.1, 0.1])
}

@Test func safariMenuPollingThrowsDomainErrorAfterTimeout() async throws {
    var lookupCount = 0
    var sleptIntervals: [TimeInterval] = []

    #expect(throws: SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 3)) {
        try SafariMenu.waitForMenuElement(
            menuBarItemIndex: 3,
            polling: SafariAXPolling(maxAttempts: 3, interval: 0.2, sleep: { sleptIntervals.append($0) }),
            currentElement: {
                lookupCount += 1
                return Optional<String>.none
            }
        )
    }

    #expect(lookupCount == 3)
    #expect(sleptIntervals == [0.2, 0.2])
}

@Test func safariFileMenuListItemsUsesFileMenuIndex() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList([(1, "Open…", "O", "0")]))])
    let items = try SafariFileMenu.listItems(executor: executor)
    #expect(items == [SafariMenuItemRecord(index: 1, title: "Open…", commandCharacter: "O", commandModifiers: "0")])
    #expect(executor.executedScripts[0].contains("menu bar item 3"))
}

@Test func safariFileMenuOpenWindowWithoutProfileUsesNewDocumentPath() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariFileMenu.openWindow(profileName: nil, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("make new document"))
}

@Test func safariFileMenuOpenWindowForProfileClicksMatchedSuffixItem() async throws {
    let executor = MockAppleScriptExecutor(results: [
        .descriptor(makeShortcutList([
            (1, "Nuova finestra di Glutexo", "N", "0"),
            (2, "Nuova finestra di Twisto", "N", "0")
        ])),
        .none
    ])

    try SafariFileMenu.openWindow(profileName: "Twisto", executor: executor)

    #expect(executor.executedScripts.count == 2)
    #expect(executor.executedScripts[1].contains("click menu item 2"))
}

@Test func safariFileMenuOpenWindowRejectsMissingProfileMenuItem() async throws {
    let executor = MockAppleScriptExecutor(results: [
        .descriptor(makeShortcutList([(1, "Nuova finestra privata", "N", "1")]))
    ])

    #expect(throws: SafariUserInterfaceError.profileWindowMenuItemNotFound("Twisto")) {
        try SafariFileMenu.openWindow(profileName: "Twisto", executor: executor)
    }
}

@Test func safariFileMenuOpenProfileWindowShortcutUsesProfileOrder() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariFileMenu.openProfileWindowShortcut(
        profileName: "Twisto",
        profileNames: ["Glutexo", "Twisto"],
        executor: executor
    )

    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("keystroke \"1\" using {command down, option down, shift down}"))
}

@Test func safariFileMenuOpenProfileWindowShortcutRejectsMissingProfile() async throws {
    #expect(throws: SafariUserInterfaceError.profileWindowMenuItemNotFound("Twisto")) {
        try SafariFileMenu.openProfileWindowShortcut(
            profileName: "Twisto",
            profileNames: ["Glutexo"],
            executor: MockAppleScriptExecutor()
        )
    }
}

@Test func safariFileMenuOpenPrivateWindowClicksShortcutMatchedItem() async throws {
    let executor = MockAppleScriptExecutor(results: [
        .descriptor(makeShortcutList([
            (1, "Nuova finestra", "N", "0"),
            (2, "Nuova finestra privata", "N", "1")
        ])),
        .none
    ])

    try SafariFileMenu.openPrivateWindow(executor: executor)

    #expect(executor.executedScripts.count == 2)
    #expect(executor.executedScripts[1].contains("click menu item 2"))
}

@Test func safariFileMenuOpenPrivateWindowRejectsMissingMenuItem() async throws {
    let executor = MockAppleScriptExecutor(results: [
        .descriptor(makeShortcutList([
            (1, "Nuova finestra", "N", "0")
        ]))
    ])

    #expect(throws: SafariUserInterfaceError.privateWindowMenuItemNotFound) {
        try SafariFileMenu.openPrivateWindow(executor: executor)
    }
}

@Test func safariFileMenuCreateAndDeleteTabGroupUseExpectedMenuIndexes() async throws {
    let executor = MockAppleScriptExecutor(results: [.none, .none])

    try SafariFileMenu.createEmptyTabGroup(executor: executor)
    try SafariFileMenu.deleteCurrentTabGroup(executor: executor)

    #expect(executor.executedScripts.count == 2)
    #expect(executor.executedScripts[0].contains("AXIdentifier"))
    #expect(executor.executedScripts[0].contains("NewEmptyTabGroupMenuItem"))
    #expect(executor.executedScripts[1].contains("DeleteTabGroupMenuItem"))
}

@Test func safariMenuItemListChildItemsCommandRejectsMissingAddress() async throws {
    let command = SafariMenuItemListChildItemsCommand()

    #expect(throws: SafariUserInterfaceError.missingMenuItemAddress) {
        try command.execute(arguments: [])
    }
}

@Test func safariMenuItemListChildItemsCommandRejectsInvalidAddress() async throws {
    let command = SafariMenuItemListChildItemsCommand()

    #expect(throws: SafariUserInterfaceError.invalidMenuItemAddress("x", "2")) {
        try command.execute(arguments: ["x", "2"])
    }
}

@Test func safariMenuListItemsCommandRejectsMissingAddress() async throws {
    let command = SafariMenuListItemsCommand()

    #expect(throws: SafariUserInterfaceError.missingMenuAddress) {
        try command.execute(arguments: [])
    }
}

@Test func safariMenuListItemsCommandRejectsInvalidAddress() async throws {
    let command = SafariMenuListItemsCommand()

    #expect(throws: SafariUserInterfaceError.invalidMenuAddress("x")) {
        try command.execute(arguments: ["x"])
    }
}
