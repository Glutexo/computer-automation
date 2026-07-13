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
    #expect(listExecutor.executedScripts[0].contains("every window whose id is 42"))
    #expect(listExecutor.executedScripts[0].contains("every tab of targetWindow"))

    let openExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.open(windowIdentifier: 42, url: "https://example.com", executor: openExecutor)
    #expect(openExecutor.executedScripts[0].contains("every window whose id is 42"))
    #expect(openExecutor.executedScripts[0].contains("set URL of newTab"))

    let setURLExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.setURL(windowIdentifier: 42, tabIndex: 3, url: "https://openai.com", executor: setURLExecutor)
    #expect(setURLExecutor.executedScripts[0].contains("every window whose id is 42"))
    #expect(setURLExecutor.executedScripts[0].contains("set URL of tab 3"))

    let moveExecutor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.move(windowIdentifier: 42, sourceIndex: 3, destinationIndex: 1, executor: moveExecutor)
    #expect(moveExecutor.executedScripts[0].contains("every window whose id is 42"))
    #expect(moveExecutor.executedScripts[0].contains("move tab 3 to before tab 1"))

    let closeExecutor = MockAppleScriptExecutor(results: [.string("Safari tab closed.")])
    #expect(
        try SafariAppleScriptTab.close(windowIdentifier: 42, tabIndex: 2, executor: closeExecutor) ==
        "Safari tab closed."
    )
    #expect(closeExecutor.executedScripts[0].contains("every window whose id is 42"))
    #expect(closeExecutor.executedScripts[0].contains("close tab 2"))
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
    #expect(executor.executedScripts[0].contains("every window whose id is 42"))
    #expect(executor.executedScripts[0].contains("do JavaScript"))
    #expect(executor.executedScripts[0].contains("in tab 2 of targetWindow"))
    #expect(executor.executedScripts[0].contains("COMPUTER_AUTOMATION_JAVASCRIPT_RESULT_NOT_TEXT"))
    #expect(executor.executedScripts[0].contains("computerAutomationSource"))
    #expect(executor.executedScripts[0].contains("(0, eval)(computerAutomationSource)"))
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
    [(1, 1, "https://example.com")],
    [(1, 1, "https://example.com"), (1, 2, "https://openai.com"), (2, 1, "https://swift.org")],
    []
])
func safariAppleScriptTabListsItems(rows: [(Int, Int, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeTabList(rows))])
    let items = try SafariAppleScriptTab.list(executor: executor)
    let expected = rows.map { SafariAppleScriptTabRecord(windowIndex: $0.0, index: $0.1, url: $0.2) }
    #expect(items == expected)
}

@Test func safariAppleScriptTabListsStructuredItemsWithTitles() async throws {
    let executor = MockAppleScriptExecutor(
        results: [
            .descriptor(
                makeStructuredTabList([
                    (1, 1, "https://example.com/a|b", "Example | Home"),
                    (2, 3, "", "")
                ])
            )
        ]
    )

    #expect(
        try SafariAppleScriptTab.list(executor: executor) ==
        [
            SafariAppleScriptTabRecord(windowIndex: 1, index: 1, url: "https://example.com/a|b", title: "Example | Home"),
            SafariAppleScriptTabRecord(windowIndex: 2, index: 3, url: "", title: "")
        ]
    )
}

@Test func safariAppleScriptTabParseListSkipsMalformedRowsAndPreservesURLs() async throws {
    let descriptor = NSAppleEventDescriptor.list()
    descriptor.insert(NSAppleEventDescriptor(string: "1|1|https://example.com"), at: 1)
    descriptor.insert(NSAppleEventDescriptor(string: "bad row"), at: 2)
    descriptor.insert(NSAppleEventDescriptor(string: "2|3|https://example.com/a|b"), at: 3)

    #expect(
        SafariAppleScriptTab.parseTabList(descriptor) ==
        [
            SafariAppleScriptTabRecord(windowIndex: 1, index: 1, url: "https://example.com"),
            SafariAppleScriptTabRecord(windowIndex: 2, index: 3, url: "https://example.com/a|b")
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
    #expect(executor.executedScripts[0].contains("sidebarIdentifierMatches(currentIdentifier, 57189)"))
    #expect(executor.executedScripts[0].contains("SidebarLibraryItemTabGroup"))
    #expect(executor.executedScripts[0].contains("名称未設定"))
}
