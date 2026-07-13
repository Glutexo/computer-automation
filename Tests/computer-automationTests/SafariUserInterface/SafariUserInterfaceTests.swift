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

@Test func safariSidebarMatchesWholeTabGroupIdentifierTokens() async throws {
    #expect(SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup?TabGroup=100", matchesTabGroupIdentifier: 100))
    #expect(SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup-42-profile-7", matchesTabGroupIdentifier: 42))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup?TabGroup=1001", matchesTabGroupIdentifier: 100))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemTabGroup-42-profile-7", matchesTabGroupIdentifier: 7))
    #expect(!SafariSidebar.sidebarIdentifier("SidebarLibraryItemOther?TabGroup=100", matchesTabGroupIdentifier: 100))
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
