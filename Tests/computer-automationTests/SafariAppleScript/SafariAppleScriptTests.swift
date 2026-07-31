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

@Test func safariAppleScriptWindowParsesWindowList() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "1|Start Page"), at: 1)
    listDescriptor.insert(NSAppleEventDescriptor(string: "2|OpenAI"), at: 2)

    #expect(
        SafariAppleScriptWindow.parseWindowList(listDescriptor) ==
        [
            SafariAppleScriptWindowRecord(identifier: 1, name: "Start Page"),
            SafariAppleScriptWindowRecord(identifier: 2, name: "OpenAI")
        ]
    )
}

@Test func safariAppleScriptWindowListsCurrentTabNameSeparatelyFromWindowTitle() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    let windowDescriptor = NSAppleEventDescriptor.list()
    windowDescriptor.insert(NSAppleEventDescriptor(string: "30874"), at: 1)
    windowDescriptor.insert(
        NSAppleEventDescriptor(string: "Twisto — Release Notes for Sprint Release S98"),
        at: 2
    )
    windowDescriptor.insert(NSAppleEventDescriptor(string: "TSD-9773"), at: 3)
    windowDescriptor.insert(NSAppleEventDescriptor(string: "4"), at: 4)
    listDescriptor.insert(windowDescriptor, at: 1)
    let executor = MockAppleScriptExecutor(results: [.descriptor(listDescriptor)])

    #expect(
        try SafariAppleScriptWindow.list(executor: executor) == [
            SafariAppleScriptWindowRecord(
                identifier: 30874,
                name: "Twisto — Release Notes for Sprint Release S98",
                currentTabName: "TSD-9773",
                tabCount: 4
            )
        ]
    )
    #expect(executor.executedScripts.first?.contains("name of current tab of currentWindow") == true)
    #expect(executor.executedScripts.first?.contains("count of tabs of currentWindow") == true)
}

@Test func safariAppleScriptWindowParseWindowListRejectsInvalidOrEmptyDescriptors() async throws {
    let descriptors: [NSAppleEventDescriptor?] = [
        nil,
        NSAppleEventDescriptor.list(),
        NSAppleEventDescriptor(string: ""),
        NSAppleEventDescriptor(string: "invalid"),
        NSAppleEventDescriptor(string: "abc|Start Page")
    ]

    for descriptor in descriptors {
        #expect(SafariAppleScriptWindow.parseWindowList(descriptor).isEmpty)
    }
}

@Test func safariAppleScriptWindowParseWindowListSkipsMalformedRows() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "1|Start Page"), at: 1)
    listDescriptor.insert(NSAppleEventDescriptor(string: "invalid"), at: 2)
    listDescriptor.insert(NSAppleEventDescriptor(string: "abc|Broken"), at: 3)
    listDescriptor.insert(NSAppleEventDescriptor(string: "2|OpenAI"), at: 4)

    #expect(
        SafariAppleScriptWindow.parseWindowList(listDescriptor) ==
        [
            SafariAppleScriptWindowRecord(identifier: 1, name: "Start Page"),
            SafariAppleScriptWindowRecord(identifier: 2, name: "OpenAI")
        ]
    )
}

@Test func safariAppleScriptProcessReadsTargetExactProcessIdentifier() async throws {
    var windowProcessIdentifier: pid_t?
    var tabProcessIdentifier: pid_t?
    var requestedWindowIdentifiers: Set<Int>?
    var focusedAddress: (pid_t, Int)?
    let backend = SafariAppleScriptProcessBackend(
        listWindows: { processIdentifier in
            windowProcessIdentifier = processIdentifier
            return [SafariAppleScriptWindowRecord(identifier: 42, name: "Glutexo")]
        },
        listTabs: { processIdentifier, windowIdentifiers in
            tabProcessIdentifier = processIdentifier
            requestedWindowIdentifiers = windowIdentifiers
            return [
                SafariAppleScriptTabRecord(
                    windowIdentifier: 42,
                    windowIndex: 1,
                    index: 1,
                    url: "https://example.com"
                )
            ]
        },
        focusWindow: { processIdentifier, windowIdentifier in
            focusedAddress = (processIdentifier, windowIdentifier)
        }
    )

    #expect(
        try SafariAppleScriptWindow.list(processIdentifier: 4317, backend: backend) ==
        [SafariAppleScriptWindowRecord(identifier: 42, name: "Glutexo")]
    )
    #expect(
        try SafariAppleScriptTab.list(
            processIdentifier: 4317,
            windowIdentifiers: [42],
            backend: backend
        ) ==
        [SafariAppleScriptTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com")]
    )
    #expect(windowProcessIdentifier == 4317)
    try SafariAppleScriptWindow.focus(
        windowIdentifier: 42,
        processIdentifier: 4317,
        backend: backend
    )
    #expect(focusedAddress?.0 == 4317)
    #expect(focusedAddress?.1 == 42)
    #expect(tabProcessIdentifier == 4317)
    #expect(requestedWindowIdentifiers == [42])
}

@Test(arguments: [
    (1, "Open…", "", ""),
    (2, "Share…", "missing value", "missing value"),
    (3, "Close", "W", "0")
])
func safariAppleScriptMenuItemParserNormalizesShortcutFields(row: (Int, String, String, String)) async throws {
    let descriptor = makeShortcutList([row])
    let items = SafariAppleScriptMenuItem.parseRecordsWithKeyboardShortcut(from: descriptor)

    #expect(items.count == 1)
    #expect(items[0].index == row.0)
    #expect(items[0].title == row.1)
    #expect(items[0].commandCharacter == normalizedShortcut(row.2))
    #expect(items[0].commandModifiers == normalizedShortcut(row.3))
}

@Test func safariAppleScriptMenuItemParserSkipsMalformedRows() async throws {
    let valid = NSAppleEventDescriptor.list()
    valid.insert(NSAppleEventDescriptor(string: "1"), at: 1)
    valid.insert(NSAppleEventDescriptor(string: "Open…"), at: 2)
    valid.insert(NSAppleEventDescriptor(string: "O"), at: 3)
    valid.insert(NSAppleEventDescriptor(string: "0"), at: 4)

    let missingIndex = NSAppleEventDescriptor.list()
    missingIndex.insert(NSAppleEventDescriptor(string: "Broken"), at: 1)

    let nonNumericIndex = NSAppleEventDescriptor.list()
    nonNumericIndex.insert(NSAppleEventDescriptor(string: "x"), at: 1)
    nonNumericIndex.insert(NSAppleEventDescriptor(string: "Broken"), at: 2)
    nonNumericIndex.insert(NSAppleEventDescriptor(string: ""), at: 3)
    nonNumericIndex.insert(NSAppleEventDescriptor(string: ""), at: 4)

    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(valid, at: 1)
    listDescriptor.insert(missingIndex, at: 2)
    listDescriptor.insert(nonNumericIndex, at: 3)

    #expect(
        SafariAppleScriptMenuItem.parseRecordsWithKeyboardShortcut(from: listDescriptor) ==
        [
            SafariAppleScriptMenuItemRecord(index: 1, title: "Open…", commandCharacter: "O", commandModifiers: "0")
        ]
    )
}

@Test func safariAppleScriptTabOpenExecutesExpectedScripts() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.open(windowIndex: 2, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("tell window 2"))
    #expect(executor.executedScripts[0].contains("make new tab at end of tabs"))

    let secondExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.open(windowIndex: 1, url: "https://example.com", executor: secondExecutor)
    #expect(secondExecutor.executedScripts[0].contains("set URL of newTab"))
    #expect(secondExecutor.executedScripts[0].contains("https://example.com"))
}

@Test func safariAppleScriptTabWindowIdentifierOperationsTargetMatchingWindow() async throws {
    let listExecutor = MockAppleScriptExecutor()
    _ = try SafariAppleScriptTab.list(windowIdentifier: 42, executor: listExecutor)
    #expect(listExecutor.executedScripts[0].contains("repeat with currentWindow in every window"))
    #expect(listExecutor.executedScripts[0].contains("if id of currentWindow is 42"))
    #expect(!listExecutor.executedScripts[0].contains("whose id"))
    #expect(listExecutor.executedScripts[0].contains("every tab of targetWindow"))

    let openExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.open(windowIdentifier: 42, url: "https://example.com", executor: openExecutor)
    #expect(openExecutor.executedScripts.count == 2)
    #expect(openExecutor.executedScripts[0].contains("every tab of targetWindow"))
    #expect(openExecutor.executedScripts[1].contains("if id of currentWindow is 42"))
    #expect(!openExecutor.executedScripts[1].contains("whose id"))
    #expect(openExecutor.executedScripts[1].contains("set URL of newTab"))

    let setURLExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.setURL(windowIdentifier: 42, tabIndex: 3, url: "https://openai.com", executor: setURLExecutor)
    #expect(setURLExecutor.executedScripts[0].contains("if id of currentWindow is 42"))
    #expect(!setURLExecutor.executedScripts[0].contains("whose id"))
    #expect(setURLExecutor.executedScripts[0].contains("set URL of tab 3"))

    let moveExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.move(windowIdentifier: 42, sourceIndex: 3, destinationIndex: 1, executor: moveExecutor)
    #expect(moveExecutor.executedScripts[0].contains("if id of currentWindow is 42"))
    #expect(!moveExecutor.executedScripts[0].contains("whose id"))
    #expect(moveExecutor.executedScripts[0].contains("move tab 3 to before tab 1"))

    let closeExecutor = MockAppleScriptExecutor(results: [.string("Safari tab closed.")])
    #expect(
        try SafariAppleScriptTab.close(windowIdentifier: 42, tabIndex: 2, executor: closeExecutor) ==
        "Safari tab closed."
    )
    #expect(closeExecutor.executedScripts[0].contains("if id of currentWindow is 42"))
    #expect(!closeExecutor.executedScripts[0].contains("whose id"))
    #expect(closeExecutor.executedScripts[0].contains("close tab 2"))
}

@Test func safariAppleScriptTabWaitsForNewWindowAddressability() async throws {
    var attempts = 0
    var sleptIntervals: [TimeInterval] = []

    try SafariAppleScriptTab.waitUntilWindowIsAddressable(
        windowIdentifier: 42,
        listWindowTabs: {
            attempts += 1
            if attempts < 3 {
                throw SafariAppleScriptError.executionFailed("window pending")
            }
            return []
        },
        sleep: { sleptIntervals.append($0) },
        maxAttempts: 4,
        interval: 0.25
    )

    #expect(attempts == 3)
    #expect(sleptIntervals == [0.25, 0.25])
}

@Test func safariAppleScriptTabAddressabilityWaitPropagatesFinalFailure() async throws {
    var attempts = 0
    let expected = SafariAppleScriptError.executionFailed("still unavailable")

    #expect(throws: expected) {
        try SafariAppleScriptTab.waitUntilWindowIsAddressable(
            windowIdentifier: 42,
            listWindowTabs: {
                attempts += 1
                throw expected
            },
            sleep: { _ in },
            maxAttempts: 3
        )
    }
    #expect(attempts == 3)
}

@Test func safariAppleScriptTabSetURLExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.setURL(windowIndex: 2, tabIndex: 3, url: "https://openai.com", executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("tell window 2"))
    #expect(executor.executedScripts[0].contains("set URL of tab 3"))
    #expect(executor.executedScripts[0].contains("https://openai.com"))
}

@Test func safariAppleScriptTabMoveExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.move(windowIndex: 2, sourceIndex: 4, destinationIndex: 1, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("tell window 2"))
    #expect(executor.executedScripts[0].contains("move tab 4 to before tab 1"))
    #expect(executor.executedScripts[0].contains("set current tab to tab 1"))

    let secondExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.move(windowIndex: 2, sourceIndex: 1, destinationIndex: 3, executor: secondExecutor)
    #expect(secondExecutor.executedScripts[0].contains("move tab 1 to after tab 3"))
    #expect(secondExecutor.executedScripts[0].contains("set current tab to tab 3"))
}

@Test func safariAppleScriptTabCloseReturnsScriptResult() async throws {
    let executor = MockAppleScriptExecutor(results: [.string("Safari tab closed.")])
    #expect(try SafariAppleScriptTab.close(windowIndex: 1, tabIndex: 2, executor: executor) == "Safari tab closed.")
}

@Test func safariAppleScriptTabExecuteJavaScriptTargetsWindowIdentifierAndTab() async throws {
    let executor = MockAppleScriptExecutor(results: [.string("ready")])

    #expect(
        try SafariAppleScriptTab.executeJavaScript(
            windowIdentifier: 42,
            tabIndex: 2,
            javaScript: "document.querySelector(\"main\").textContent",
            executor: executor
        ) == "ready"
    )
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("repeat with currentWindow in every window"))
    #expect(executor.executedScripts[0].contains("if id of currentWindow is 42"))
    #expect(!executor.executedScripts[0].contains("whose id"))
    #expect(executor.executedScripts[0].contains("do JavaScript"))
    #expect(executor.executedScripts[0].contains("in tab 2 of targetWindow"))
    #expect(executor.executedScripts[0].contains("COMPUTER_AUTOMATION_JAVASCRIPT_RESULT_NOT_TEXT"))
    #expect(!executor.executedScripts[0].contains("eval("))
    #expect(executor.executedScripts[0].contains("const computerAutomationResult = (document.querySelector"))
    #expect(executor.executedScripts[0].contains("JSON.stringify(computerAutomationResult)"))
    #expect(executor.executedScripts[0].contains("document.querySelector"))
}

@Test func safariAppleScriptTabExecuteJavaScriptMapsTargetAndExecutionFailures() async throws {
    let missingWindow = MockAppleScriptExecutor(
        error: SafariAppleScriptError.executionFailed("COMPUTER_AUTOMATION_WINDOW_NOT_FOUND")
    )
    #expect(throws: SafariAppleScriptTabJavaScriptError.windowNotFound(42)) {
        try SafariAppleScriptTab.executeJavaScript(
            windowIdentifier: 42,
            tabIndex: 2,
            javaScript: "document.title",
            executor: missingWindow
        )
    }

    let missingTab = MockAppleScriptExecutor(
        error: SafariAppleScriptError.executionFailed("COMPUTER_AUTOMATION_TAB_NOT_FOUND")
    )
    #expect(throws: SafariAppleScriptTabJavaScriptError.tabNotFound(windowIdentifier: 42, tabIndex: 2)) {
        try SafariAppleScriptTab.executeJavaScript(
            windowIdentifier: 42,
            tabIndex: 2,
            javaScript: "document.title",
            executor: missingTab
        )
    }

    for message in [
        "Safari got an error: Can’t get tab 2 of window id 42. (-1728)",
        "NSAppleScriptErrorMessage = \"Invalid index.\"; NSAppleScriptErrorNumber = \"-1719\";"
    ] {
        let staleTab = MockAppleScriptExecutor(
            error: SafariAppleScriptError.executionFailed(message)
        )
        #expect(throws: SafariAppleScriptTabJavaScriptError.tabNotFound(windowIdentifier: 42, tabIndex: 2)) {
            try SafariAppleScriptTab.executeJavaScript(
                windowIdentifier: 42,
                tabIndex: 2,
                javaScript: "document.title",
                executor: staleTab
            )
        }
    }

    let failedJavaScript = MockAppleScriptExecutor(
        error: SafariAppleScriptError.executionFailed("ReferenceError: sensitive page detail")
    )
    #expect(throws: SafariAppleScriptTabJavaScriptError.executionFailed(windowIdentifier: 42, tabIndex: 2)) {
        try SafariAppleScriptTab.executeJavaScript(
            windowIdentifier: 42,
            tabIndex: 2,
            javaScript: "window.secret.token",
            executor: failedJavaScript
        )
    }

    let unsupportedResult = MockAppleScriptExecutor(
        error: SafariAppleScriptError.executionFailed("COMPUTER_AUTOMATION_JAVASCRIPT_RESULT_NOT_TEXT")
    )
    #expect(throws: SafariAppleScriptTabJavaScriptError.unsupportedResult(windowIdentifier: 42, tabIndex: 2)) {
        try SafariAppleScriptTab.executeJavaScript(
            windowIdentifier: 42,
            tabIndex: 2,
            javaScript: "({ a: 1 })",
            executor: unsupportedResult
        )
    }
}

@Test(arguments: [
    [(42, 1, 1, "https://example.com")],
    [(42, 1, 1, "https://example.com"), (42, 1, 2, "https://openai.com"), (84, 2, 1, "https://swift.org")],
    []
])
func safariAppleScriptTabListsItems(rows: [(Int, Int, Int, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeTabList(rows))])
    let items = try SafariAppleScriptTab.list(executor: executor)
    let expected = rows.map {
        SafariAppleScriptTabRecord(windowIdentifier: $0.0, windowIndex: $0.1, index: $0.2, url: $0.3)
    }
    #expect(items == expected)
    #expect(executor.executedScripts[0].contains("set windowIdentifier to id of currentWindow"))
}

@Test func safariAppleScriptTabListsStructuredItemsWithTitles() async throws {
    let executor = MockAppleScriptExecutor(
        results: [
            .descriptor(
                makeStructuredTabList([
                    (84, 1, 1, "https://example.com/a|b", "Example | Home"),
                    (42, 2, 3, "", "")
                ])
            )
        ]
    )

    #expect(
        try SafariAppleScriptTab.list(executor: executor) ==
        [
            SafariAppleScriptTabRecord(windowIdentifier: 84, windowIndex: 1, index: 1, url: "https://example.com/a|b", title: "Example | Home"),
            SafariAppleScriptTabRecord(windowIdentifier: 42, windowIndex: 2, index: 3, url: "", title: "")
        ]
    )
}

@Test func safariAppleScriptTabParseListSkipsMalformedRowsAndPreservesURLs() async throws {
    let descriptor = NSAppleEventDescriptor.list()
    descriptor.insert(NSAppleEventDescriptor(string: "84|1|1|https://example.com"), at: 1)
    descriptor.insert(NSAppleEventDescriptor(string: "bad row"), at: 2)
    descriptor.insert(NSAppleEventDescriptor(string: "42|2|3|https://example.com/a|b"), at: 3)

    #expect(
        SafariAppleScriptTab.parseTabList(descriptor) ==
        [
            SafariAppleScriptTabRecord(windowIdentifier: 84, windowIndex: 1, index: 1, url: "https://example.com"),
            SafariAppleScriptTabRecord(windowIdentifier: 42, windowIndex: 2, index: 3, url: "https://example.com/a|b")
        ]
    )
}

@Test func safariAppleScriptApplicationActivateExecutesActivateScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptApplication.activate(executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("tell application \"Safari\" to activate"))
}

@Test func safariAppleScriptExecutorRejectsInvalidScript() async throws {
    let executor = SafariAppleScriptExecutor()

    do {
        _ = try executor.execute(script: "not valid applescript")
        Issue.record("Expected invalid AppleScript to throw.")
    } catch let error as SafariAppleScriptError {
        switch error {
        case .scriptCompilationFailed:
            break
        case .executionFailed(let message):
            #expect(!message.isEmpty)
        }
    }
}

@Test func safariAppleScriptWindowOpenNewDocumentExecutesDocumentScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptWindow.openNewDocument(executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("make new document"))
}

@Test func safariAppleScriptWindowFocusExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptWindow.focus(windowIndex: 2, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("set index of window 2 to 1"))
}

@Test func safariAppleScriptWindowFocusByIdentifierExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptWindow.focus(windowIdentifier: 42, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("repeat with currentWindow in every window"))
    #expect(executor.executedScripts[0].contains("if id of currentWindow is 42 then"))
    #expect(executor.executedScripts[0].contains("set index of currentWindow to 1"))
}

@Test func safariAppleScriptWindowCloseFrontWindowReturnsScriptResult() async throws {
    let executor = MockAppleScriptExecutor(results: [.string("Safari front window closed.")])
    #expect(try SafariAppleScriptWindow.closeFrontWindow(executor: executor) == "Safari front window closed.")
}

@Test func safariAppleScriptWindowCloseByIdentifierExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptWindow.close(windowIdentifier: 42, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("repeat with currentWindow in every window"))
    #expect(executor.executedScripts[0].contains("if id of currentWindow is 42 then"))
    #expect(executor.executedScripts[0].contains("close currentWindow"))
}

@Test(arguments: [
    [(1, "Apple"), (2, "Safari")],
    []
])
func safariAppleScriptApplicationMenuBarListsItems(rows: [(Int, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeIndexTitleList(rows))])
    let items = try SafariAppleScriptApplicationMenuBar.listItems(executor: executor)
    let expected = rows.map { SafariAppleScriptMenuItemRecord(index: $0.0, title: $0.1) }
    #expect(items == expected)
}

@Test(arguments: [
    [(1, "Open…", "O", "0"), (2, "Close", "W", "0")],
    []
])
func safariAppleScriptMenuListsItems(rows: [(Int, String, String, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList(rows))])
    let items = try SafariAppleScriptMenu.listItems(menuBarItemIndex: 3, executor: executor)
    let expected = rows.map {
        SafariAppleScriptMenuItemRecord(index: $0.0, title: $0.1, commandCharacter: emptyToNil($0.2), commandModifiers: emptyToNil($0.3))
    }
    #expect(items == expected)
}

@Test func safariAppleScriptMenuClickItemExecutesIndexedClickScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptMenu.clickItem(menuBarItemIndex: 3, menuItemIndex: 7, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("click menu item 7"))
}

@Test(arguments: [
    [(1, "Google Chrome…", "", "0"), (2, "Firefox…", "", "0")],
    []
])
func safariAppleScriptMenuItemListsChildItems(rows: [(Int, String, String, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList(rows))])
    let items = try SafariAppleScriptMenuItem.listChildItems(menuBarItemIndex: 3, menuItemIndex: 27, executor: executor)
    let expected = rows.map {
        SafariAppleScriptMenuItemRecord(index: $0.0, title: $0.1, commandCharacter: emptyToNil($0.2), commandModifiers: emptyToNil($0.3))
    }
    #expect(items == expected)
}

@Test func safariAppleScriptSidebarSelectTabGroupByIdentifierExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptSidebar.selectTabGroup(identifier: 57189, named: "名称未設定", executor: executor)
    #expect(executor.executedScripts.count == 1)
    let script = executor.executedScripts[0]
    #expect(script.contains("sidebarTabGroupIdentifier(currentIdentifier)"))
    #expect(script.contains("set sawStableTabGroupIdentifier to true"))
    #expect(script.contains("if sawStableTabGroupIdentifier then"))
    #expect(script.contains("Safari sidebar tab group identifier 57189 not found."))
    #expect(script.contains("SidebarLibraryItemTabGroup"))
    #expect(script.contains("名称未設定"))
    #expect(script.contains("on firstSidebarOutline(rootElement, currentDepth)"))
    #expect(script.contains("set targetWindow to value of attribute \"AXFocusedWindow\""))
    #expect(script.contains("set outlineItem to my firstSidebarOutline(targetWindow, 0)"))
    #expect(script.contains("perform action \"AXPress\" of sidebarButton"))
    #expect(!script.contains("UI element 1 of UI element 1 of UI element 1"))

    var compileError: NSDictionary?
    #expect(NSAppleScript(source: script)?.compileAndReturnError(&compileError) == true)
    #expect(compileError == nil)
}

@Test func safariAppleScriptSidebarListsTabGroupsWithoutCyclingOrSelecting() async throws {
    let list = NSAppleEventDescriptor.list()
    let identified = NSAppleEventDescriptor.list()
    identified.insert(NSAppleEventDescriptor(string: "57189"), at: 1)
    identified.insert(NSAppleEventDescriptor(string: "Focus"), at: 2)
    let unidentified = NSAppleEventDescriptor.list()
    unidentified.insert(NSAppleEventDescriptor(string: ""), at: 1)
    unidentified.insert(NSAppleEventDescriptor(string: "Inbox"), at: 2)
    list.insert(identified, at: 1)
    list.insert(unidentified, at: 2)
    let executor = MockAppleScriptExecutor(results: [.descriptor(list)])

    #expect(
        try SafariAppleScriptSidebar.listTabGroups(executor: executor) == [
            SafariAppleScriptSidebarTabGroupRecord(identifier: 57189, name: "Focus"),
            SafariAppleScriptSidebarTabGroupRecord(identifier: nil, name: "Inbox")
        ]
    )

    let script = try #require(executor.executedScripts.first)
    #expect(script.contains("repeat with currentRow in rows of outlineItem"))
    #expect(script.contains("sidebarTabGroupIdentifier(currentIdentifier)"))
    #expect(!script.contains("GoToNextTabGroup"))
    #expect(!script.contains("AXSelectedRows"))
    #expect(!script.contains("AXSelectedCells"))

    var compileError: NSDictionary?
    #expect(NSAppleScript(source: script)?.compileAndReturnError(&compileError) == true)
    #expect(compileError == nil)
}
