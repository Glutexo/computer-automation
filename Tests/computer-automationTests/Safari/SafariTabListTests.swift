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

@Test func safariSavedTabGroupWindowReadinessMakesSelectedIdentifierAuthoritative() async throws {
    let tabGroup = SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")
    let exactWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 1000,
        tabGroupName: "Other",
        name: "Other"
    )
    let contradictoryWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 1001,
        tabGroupName: "Focus",
        name: "Focus — Start Page"
    )
    let nameOnlyWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: "Focus",
        name: "Focus — Start Page"
    )

    #expect(SafariSavedTabGroupWindowReadiness.windowMatchesSelectedTabGroup(exactWindow, tabGroup: tabGroup))
    #expect(!SafariSavedTabGroupWindowReadiness.windowMatchesSelectedTabGroup(contradictoryWindow, tabGroup: tabGroup))
    #expect(SafariSavedTabGroupWindowReadiness.windowMatchesSelectedTabGroup(nameOnlyWindow, tabGroup: tabGroup))
}

@Test(arguments: [
    [],
    [SafariTabGroupTabRecord(tabGroupIdentifier: 10, index: 1, url: "https://example.com")],
    [
        SafariTabGroupTabRecord(tabGroupIdentifier: 10, index: 1, url: "https://example.com"),
        SafariTabGroupTabRecord(tabGroupIdentifier: 10, index: 2, url: "https://openai.com")
    ]
])
func safariTabListTabGroupTabsCommandFormatsRows(tabs: [SafariTabGroupTabRecord]) async throws {
    let command = SafariTabListTabGroupTabsCommand(listTabs: { _ in tabs })
    let output = try command.execute(arguments: ["10"])
    let expected = tabs.map { "\($0.index)|\($0.url)" }.joined(separator: "\n")
    #expect(output == expected)
}

@Test func safariTabListTabGroupTabsCommandRejectsMissingOrInvalidIdentifier() async throws {
    let command = SafariTabListTabGroupTabsCommand(listTabs: { _ in [] })

    #expect(throws: SafariTabGroupCommandError.missingTabGroupIdentifier) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabGroupCommandError.invalidTabGroupIdentifier("0")) {
        try command.execute(arguments: ["0"])
    }

    #expect(throws: SafariTabGroupCommandError.invalidTabGroupIdentifier("abc")) {
        try command.execute(arguments: ["abc"])
    }
}

@Test func safariTabListTabGroupTabsCommandPropagatesFailure() async throws {
    let command = SafariTabListTabGroupTabsCommand(
        listTabs: { _ in throw SafariTabGroupCommandError.queryPreparationFailed }
    )

    #expect(throws: SafariTabGroupCommandError.queryPreparationFailed) {
        try command.execute(arguments: ["10"])
    }
}

@Test func safariTabListEnsureURLsCommandAddsOnlyMissingWindowURLs() async throws {
    var openedURLs: [String?] = []
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { windowIndex, _ in
            #expect(windowIndex == 2)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")
            ]
        },
        listTabGroupTabs: { _ in [] },
        openTab: { windowIndex, url, _ in
            #expect(windowIndex == 2)
            openedURLs.append(url)
        }
    )

    let output = try command.execute(arguments: [
        "--window-index", "2",
        "https://example.com",
        "https://openai.com",
        "https://openai.com",
        "https://swift.org"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs ensured.
        context|window|2
        added|https://openai.com
        added|https://swift.org
        skipped|https://example.com
        skipped|https://openai.com
        """
    )
    #expect(openedURLs == ["https://openai.com", "https://swift.org"])
}

@Test func safariTabListEnsureURLsCommandUsesWindowIdentifierContext() async throws {
    var openedTabs: [(Int, String?)] = []
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")
            ]
        },
        listTabGroupTabs: { _ in [] },
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        openTabByIdentifier: { windowIdentifier, url, _ in openedTabs.append((windowIdentifier, url)) }
    )

    let output = try command.execute(arguments: [
        "--window-id", "42",
        "https://example.com",
        "https://openai.com"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs ensured.
        context|window-id|42
        added|https://openai.com
        skipped|https://example.com
        """
    )
    #expect(openedTabs.map(\.0) == [42])
    #expect(openedTabs.map(\.1) == ["https://openai.com"])
}

@Test func safariTabListEnsureURLsCommandReturnsStructuredJSONForWindowContext() async throws {
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in
            [SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")]
        },
        listTabGroupTabs: { _ in [] },
        openTab: { _, _, _ in }
    )

    let output = try command.executeJSON(arguments: [
        "--window-index=1",
        "https://example.com",
        "https://openai.com"
    ])
    let object = try jsonObject(output)
    let context = try #require(object["context"] as? [String: Any])

    #expect(context["kind"] as? String == "window")
    #expect(context["windowIndex"] as? Int == 1)
    #expect(object["addedURLs"] as? [String] == ["https://openai.com"])
    #expect(object["skippedURLs"] as? [String] == ["https://example.com"])
}

@Test func safariTabListEnsureURLsCommandOpensNewWindowForReusedGroupWithoutRepurposingExistingWindow() async throws {
    var openedProfiles: [String] = []
    var selectedTabGroups: [String] = []
    var openedTabs: [(Int, String?)] = []
    var listedWindowTabsCount = 0
    var sleptIntervals: [TimeInterval] = []
    let existingWindow = SafariWindowRecord(
        identifier: 10,
        index: 2,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 999,
        tabGroupName: "Unrelated",
        name: "Unrelated"
    )
    let operationWindow = SafariWindowRecord(
        identifier: 42,
        index: 3,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 1000,
        tabGroupName: "Focus",
        name: "Focus"
    )

    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            #expect(profileName == "Twisto")
            #expect(name == "Focus")
            return SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .reused,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                )
            )
        },
        listWindowTabs: { _, _ in [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            listedWindowTabsCount += 1
            if listedWindowTabsCount == 1 {
                return [
                    SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "favorites://")
                ]
            }

            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://example.com")
            ]
        },
        listTabGroupTabs: { identifier in
            #expect(identifier == 1000)
            return [
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 1, url: "https://example.com")
            ]
        },
        listWindows: { [operationWindow, existingWindow] },
        openNewWindowForProfile: { profileName in
            openedProfiles.append(profileName)
            return operationWindow
        },
        selectTabGroup: { group, _ in selectedTabGroups.append("\(group.identifier)|\(group.profileName)|\(group.name)") },
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        openTabByIdentifier: { windowIdentifier, url, _ in openedTabs.append((windowIdentifier, url)) },
        sleep: { sleptIntervals.append($0) }
    )

    let output = try command.execute(arguments: [
        "--tab-group-profile", "Twisto",
        "--tab-group-name", "Focus",
        "https://example.com",
        "https://openai.com"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs ensured.
        context|tab-group|1000|Twisto|Focus|3
        tab-group|reused|1000|Twisto|Focus
        added|https://openai.com
        skipped|https://example.com
        """
    )
    #expect(openedProfiles == ["Twisto"])
    #expect(selectedTabGroups == ["1000|Twisto|Focus"])
    #expect(listedWindowTabsCount == 2)
    #expect(sleptIntervals == [0.25])
    #expect(openedTabs.map(\.0) == [42])
    #expect(openedTabs.map(\.1) == ["https://openai.com"])
}

@Test func safariTabListEnsureURLsCommandSeedsNewGroupBeforeCreation() async throws {
    let operationWindow = SafariWindowRecord(
        processId: 43782,
        identifier: 42,
        index: 3,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 1000,
        tabGroupName: "Focus",
        name: "Focus"
    )
    var setURLs: [(Int, Int, String)] = []
    var openedURLs: [(Int, String?)] = []
    var focusedProcess: pid_t?
    var tabReadCount = 0

    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in
            Issue.record("unprepared ensure should not be called")
            throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto")
        },
        ensureTabGroupWithPreparation: { profileName, name, prepareNewWindow in
            try prepareNewWindow(operationWindow)
            return SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .created,
                    tabGroup: SafariTabGroupRecord(
                        identifier: 1000,
                        profileName: profileName,
                        name: name
                    )
                ),
                createdWindow: operationWindow
            )
        },
        listWindowTabs: { _, _ in [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            tabReadCount += 1
            if tabReadCount == 1 {
                return [
                    SafariWindowTabRecord(
                        index: 1,
                        selectedTabGroupTabIndex: nil,
                        url: "favorites://"
                    )
                ]
            }

            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://example.com"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: 2, url: "https://openai.com")
            ]
        },
        listTabGroupTabs: { identifier in
            [
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 1, url: "https://example.com"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 2, url: "https://openai.com")
            ]
        },
        listWindows: { [operationWindow] },
        focusWindowInProcess: { windowIdentifier, processIdentifier, _ in
            #expect(windowIdentifier == 42)
            focusedProcess = processIdentifier
        },
        selectTabGroup: { _, _ in Issue.record("newly created seeded group should remain selected") },
        selectTabGroupInProcess: { _, _, _ in
            Issue.record("newly created seeded group should remain selected")
        },
        openTabByIdentifier: { windowIdentifier, url, _ in
            openedURLs.append((windowIdentifier, url))
        },
        setTabURLByIdentifier: { windowIdentifier, tabIndex, url, _ in
            setURLs.append((windowIdentifier, tabIndex, url))
        }
    )

    let output = try command.execute(arguments: [
        "--tab-group-profile", "Twisto",
        "--tab-group-name", "Focus",
        "https://example.com",
        "https://openai.com"
    ])

    #expect(output.contains("tab-group|created|1000|Twisto|Focus"))
    #expect(output.contains("added|https://example.com"))
    #expect(output.contains("added|https://openai.com"))
    #expect(focusedProcess == 43782)
    #expect(setURLs.map(\.0) == [42])
    #expect(setURLs.map(\.1) == [1])
    #expect(setURLs.map(\.2) == ["https://example.com"])
    #expect(openedURLs.map(\.0) == [42])
    #expect(openedURLs.map(\.1) == ["https://openai.com"])
}

@Test func safariTabListEnsureURLsCommandDeletesCreatedTabGroupWhenSelectionFails() async throws {
    var deletedTabGroupIdentifiers: [Int] = []
    var closedWindowIdentifiers: [Int] = []
    let createdWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        name: "Twisto"
    )
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .created,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                ),
                createdWindow: createdWindow
            )
        },
        listWindowTabs: { _, _ in [] },
        listTabGroupTabs: { _ in [] },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        selectTabGroup: { _, _ in throw SafariTabGroupCommandError.sidebarUnavailable },
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        deleteTabGroup: { identifier in deletedTabGroupIdentifiers.append(identifier) }
    )

    #expect(throws: SafariTabGroupCommandError.sidebarUnavailable) {
        try command.execute(arguments: [
            "--tab-group-profile", "Twisto",
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }
    #expect(deletedTabGroupIdentifiers == [1000])
    #expect(closedWindowIdentifiers == [42])
}

@Test func safariTabListEnsureURLsCommandClosesOnlyNewWindowWhenReusedGroupSelectionFails() async throws {
    var deletedTabGroupIdentifiers: [Int] = []
    var closedWindowIdentifiers: [Int] = []
    let operationWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        name: "Twisto"
    )
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .reused,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                )
            )
        },
        listWindowTabs: { _, _ in [] },
        listTabGroupTabs: { _ in [] },
        openNewWindowForProfile: { _ in operationWindow },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        selectTabGroup: { _, _ in throw SafariTabGroupCommandError.sidebarUnavailable },
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        deleteTabGroup: { identifier in deletedTabGroupIdentifiers.append(identifier) }
    )

    #expect(throws: SafariTabGroupCommandError.sidebarUnavailable) {
        try command.execute(arguments: [
            "--tab-group-profile", "Twisto",
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }
    #expect(deletedTabGroupIdentifiers.isEmpty)
    #expect(closedWindowIdentifiers == [42])
}

@Test func safariTabListEnsureURLsCommandReturnsStructuredJSONForTabGroupContext() async throws {
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .created,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                ),
                createdWindow: SafariWindowRecord(
                    identifier: 42,
                    index: 1,
                    isPrivate: false,
                    profileName: profileName,
                    selectedTabGroupIdentifier: 1000,
                    tabGroupName: name,
                    name: name
                )
            )
        },
        listWindowTabs: { _, _ in [] },
        listWindowTabsByIdentifier: { _, _ in [] },
        listTabGroupTabs: { _ in [] },
        listWindows: {
            [
                SafariWindowRecord(
                    identifier: 42,
                    index: 1,
                    isPrivate: false,
                    profileName: "Twisto",
                    selectedTabGroupIdentifier: 1000,
                    tabGroupName: "Focus",
                    name: "Focus"
                )
            ]
        },
        selectTabGroup: { _, _ in },
        openTab: { _, _, _ in },
        openTabByIdentifier: { _, _, _ in }
    )

    let output = try command.executeJSON(arguments: [
        "--tab-group-profile=Twisto",
        "--tab-group-name=Focus",
        "https://example.com"
    ])
    let object = try jsonObject(output)
    let context = try #require(object["context"] as? [String: Any])
    let tabGroupSummary = try #require(object["tabGroup"] as? [String: Any])
    let tabGroup = try #require(tabGroupSummary["tabGroup"] as? [String: Any])

    #expect(context["kind"] as? String == "tabGroup")
    #expect(context["windowIndex"] as? Int == 1)
    #expect(context["tabGroupIdentifier"] as? Int == 1000)
    #expect(context["profileName"] as? String == "Twisto")
    #expect(context["name"] as? String == "Focus")
    #expect(tabGroupSummary["status"] as? String == "created")
    #expect(tabGroup["identifier"] as? Int == 1000)
    #expect(object["addedURLs"] as? [String] == ["https://example.com"])
    #expect(object["skippedURLs"] as? [String] == [])
}

@Test func safariTabListEnsureURLsCommandRejectsInvalidArguments() async throws {
    let command = SafariTabListEnsureURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in [] },
        listTabGroupTabs: { _ in [] },
        openTab: { _, _, _ in Issue.record("openTab should not be called") }
    )

    #expect(throws: SafariTabListCommandError.missingURL) {
        try command.execute(arguments: ["--window-index", "1"])
    }

    #expect(throws: SafariTabListCommandError.missingContext) {
        try command.execute(arguments: ["https://example.com"])
    }

    #expect(throws: SafariTabListCommandError.multipleContexts) {
        try command.execute(arguments: [
            "--window-index", "1",
            "--window-id", "42",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.multipleContexts) {
        try command.execute(arguments: [
            "--window-id", "42",
            "--tab-group-profile", "Twisto",
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingTabGroupName) {
        try command.execute(arguments: [
            "--tab-group-profile", "Twisto",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingTabGroupProfile) {
        try command.execute(arguments: [
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try command.execute(arguments: [
            "--window-index=0",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("0")) {
        try command.execute(arguments: [
            "--window-id=0",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingOptionValue("--window-index")) {
        try command.execute(arguments: [
            "--window-index",
            "--tab-group-name",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingOptionValue("--window-id")) {
        try command.execute(arguments: [
            "--window-id=",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.unknownOption("--unknown")) {
        try command.execute(arguments: [
            "--unknown",
            "https://example.com"
        ])
    }
}

@Test func safariTabListReorderURLsCommandMovesRequestedWindowURLOccurrencesToPrefix() async throws {
    var moves: [String] = []
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { windowIndex, _ in
            #expect(windowIndex == 2)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://b.example"),
                SafariWindowTabRecord(index: 3, selectedTabGroupTabIndex: nil, url: "https://a.example"),
                SafariWindowTabRecord(index: 4, selectedTabGroupTabIndex: nil, url: "https://c.example"),
                SafariWindowTabRecord(index: 5, selectedTabGroupTabIndex: nil, url: "https://d.example")
            ]
        },
        listTabGroupTabs: { _ in [] },
        moveTab: { windowIndex, sourceIndex, destinationIndex, _ in
            moves.append("\(windowIndex)|\(sourceIndex)|\(destinationIndex)")
        }
    )

    let output = try command.execute(arguments: [
        "--window-index", "2",
        "https://c.example",
        "https://a.example",
        "https://a.example",
        "https://missing.example"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs reordered.
        context|window|2
        moved|https://c.example|4|1
        moved|https://a.example|4|3
        unchanged|https://a.example|2
        missing|https://missing.example
        extra|https://b.example|4
        extra|https://d.example|5
        """
    )
    #expect(moves == ["2|4|1", "2|4|3"])
}

@Test func safariTabListReorderURLsCommandUsesWindowIdentifierContext() async throws {
    var moves: [String] = []
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://b.example")
            ]
        },
        listTabGroupTabs: { _ in [] },
        moveTab: { _, _, _, _ in Issue.record("moveTab should not be called") },
        moveTabByIdentifier: { windowIdentifier, sourceIndex, destinationIndex, _ in
            moves.append("\(windowIdentifier)|\(sourceIndex)|\(destinationIndex)")
        }
    )

    let output = try command.execute(arguments: [
        "--window-id=42",
        "https://b.example"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs reordered.
        context|window-id|42
        moved|https://b.example|2|1
        extra|https://a.example|2
        """
    )
    #expect(moves == ["42|2|1"])
}

@Test func safariTabListReorderURLsCommandReturnsStructuredJSONForWindowContext() async throws {
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in
            [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://b.example")
            ]
        },
        listTabGroupTabs: { _ in [] },
        moveTab: { _, _, _, _ in }
    )

    let output = try command.executeJSON(arguments: [
        "--window-index=1",
        "https://b.example",
        "https://missing.example"
    ])
    let object = try jsonObject(output)
    let context = try #require(object["context"] as? [String: Any])
    let moved = try #require(object["moved"] as? [[String: Any]])
    let unchanged = try #require(object["unchanged"] as? [[String: Any]])
    let extra = try #require(object["extra"] as? [[String: Any]])

    #expect(context["kind"] as? String == "window")
    #expect(context["windowIndex"] as? Int == 1)
    #expect(moved.count == 1)
    #expect(moved[0]["url"] as? String == "https://b.example")
    #expect(moved[0]["fromIndex"] as? Int == 2)
    #expect(moved[0]["toIndex"] as? Int == 1)
    #expect(unchanged.isEmpty)
    #expect(object["missingURLs"] as? [String] == ["https://missing.example"])
    #expect(extra.count == 1)
    #expect(extra[0]["url"] as? String == "https://a.example")
    #expect(extra[0]["index"] as? Int == 2)
}

@Test func safariTabListReorderURLsCommandOpensNewWindowForReusedGroupAndVerifiesOrder() async throws {
    var openedProfiles: [String] = []
    var selectedTabGroups: [String] = []
    var moves: [String] = []
    var listedWindowTabsCount = 0
    var sleptIntervals: [TimeInterval] = []
    let existingWindow = SafariWindowRecord(
        identifier: 10,
        index: 2,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 999,
        tabGroupName: "Unrelated",
        name: "Unrelated"
    )
    let operationWindow = SafariWindowRecord(
        identifier: 42,
        index: 3,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: 1000,
        tabGroupName: "Focus",
        name: "Focus"
    )

    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .reused,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                )
            )
        },
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            listedWindowTabsCount += 1
            if listedWindowTabsCount == 1 {
                return [
                    SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "favorites://")
                ]
            }

            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: 2, url: "https://b.example"),
                SafariWindowTabRecord(index: 3, selectedTabGroupTabIndex: 3, url: "https://c.example")
            ]
        },
        listTabGroupTabs: { identifier in
            #expect(identifier == 1000)
            return [
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 1, url: "https://c.example"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 2, url: "https://a.example"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 3, url: "https://b.example")
            ]
        },
        listWindows: { [operationWindow, existingWindow] },
        openNewWindowForProfile: { profileName in
            openedProfiles.append(profileName)
            return operationWindow
        },
        selectTabGroup: { group, _ in selectedTabGroups.append("\(group.identifier)|\(group.profileName)|\(group.name)") },
        moveTab: { _, _, _, _ in Issue.record("moveTab should not be called") },
        moveTabByIdentifier: { windowIdentifier, sourceIndex, destinationIndex, _ in
            moves.append("\(windowIdentifier)|\(sourceIndex)|\(destinationIndex)")
        },
        sleep: { sleptIntervals.append($0) }
    )

    let output = try command.execute(arguments: [
        "--tab-group-profile", "Twisto",
        "--tab-group-name", "Focus",
        "https://c.example",
        "https://a.example"
    ])

    #expect(
        output ==
        """
        Safari tab list URLs reordered.
        context|tab-group|1000|Twisto|Focus|3
        tab-group|reused|1000|Twisto|Focus
        moved|https://c.example|3|1
        unchanged|https://a.example|2
        extra|https://b.example|3
        """
    )
    #expect(openedProfiles == ["Twisto"])
    #expect(selectedTabGroups == ["1000|Twisto|Focus"])
    #expect(listedWindowTabsCount == 2)
    #expect(sleptIntervals == [0.25])
    #expect(moves == ["42|3|1"])
}

@Test func safariTabListReorderURLsCommandVerifiesSavedStartPageAsEmptyStoredURL() async throws {
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .reused,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                )
            )
        },
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: 2, url: "https://b.example"),
                SafariWindowTabRecord(index: 3, selectedTabGroupTabIndex: 3, url: "favorites://")
            ]
        },
        listTabGroupTabs: { identifier in
            [
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 1, url: "https://b.example"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 2, url: "https://a.example"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 3, url: "")
            ]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 42, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", name: "Focus")]
        },
        openNewWindowForProfile: { _ in
            SafariWindowRecord(identifier: 42, index: 1, isPrivate: false, profileName: "Twisto", name: "Focus")
        },
        selectTabGroup: { _, _ in },
        moveTab: { _, _, _, _ in Issue.record("moveTab should not be called") },
        moveTabByIdentifier: { _, _, _, _ in }
    )

    let output = try command.execute(arguments: [
        "--tab-group-profile", "Twisto",
        "--tab-group-name", "Focus",
        "https://b.example",
        "https://a.example"
    ])

    #expect(output.contains("moved|https://b.example|2|1"))
    #expect(output.contains("extra|favorites://|3"))
}

@Test func safariTabListReorderURLsCommandRejectsUnverifiedSavedTabGroupPersistence() async throws {
    var deletedTabGroupIdentifiers: [Int] = []
    var closedWindowIdentifiers: [Int] = []
    let createdWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        name: "Focus"
    )
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { profileName, name in
            SafariTabGroupEnsureOperationResult(
                summary: SafariTabGroupEnsureSummary(
                    status: .created,
                    tabGroup: SafariTabGroupRecord(identifier: 1000, profileName: profileName, name: name)
                ),
                createdWindow: createdWindow
            )
        },
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 42)
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://a.example"),
                SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: 2, url: "https://b.example")
            ]
        },
        listTabGroupTabs: { identifier in
            [
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 1, url: "https://a.example"),
                SafariTabGroupTabRecord(tabGroupIdentifier: identifier, index: 2, url: "https://b.example")
            ]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 42, index: 1, isPrivate: false, profileName: "Twisto", name: "Focus")]
        },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        selectTabGroup: { _, _ in },
        moveTab: { _, _, _, _ in Issue.record("moveTab should not be called") },
        moveTabByIdentifier: { _, _, _, _ in },
        deleteTabGroup: { identifier in deletedTabGroupIdentifiers.append(identifier) }
    )

    #expect(throws: SafariTabListCommandError.savedTabGroupOrderPersistenceNotVerified(1000)) {
        try command.execute(arguments: [
            "--tab-group-profile", "Twisto",
            "--tab-group-name", "Focus",
            "https://b.example"
        ])
    }
    #expect(deletedTabGroupIdentifiers == [1000])
    #expect(closedWindowIdentifiers == [42])
}

@Test func safariTabListReorderURLsCommandRejectsInvalidArguments() async throws {
    let command = SafariTabListReorderURLsCommand(
        executor: MockAppleScriptExecutor(),
        ensureTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "unused") },
        listWindowTabs: { _, _ in [] },
        listTabGroupTabs: { _ in [] },
        moveTab: { _, _, _, _ in Issue.record("moveTab should not be called") }
    )

    #expect(throws: SafariTabListCommandError.missingURL) {
        try command.execute(arguments: ["--window-index", "1"])
    }

    #expect(throws: SafariTabListCommandError.missingContext) {
        try command.execute(arguments: ["https://example.com"])
    }

    #expect(throws: SafariTabListCommandError.multipleContexts) {
        try command.execute(arguments: [
            "--window-index", "1",
            "--window-id", "42",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.multipleContexts) {
        try command.execute(arguments: [
            "--window-id", "42",
            "--tab-group-profile", "Twisto",
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingTabGroupName) {
        try command.execute(arguments: [
            "--tab-group-profile", "Twisto",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingTabGroupProfile) {
        try command.execute(arguments: [
            "--tab-group-name", "Focus",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try command.execute(arguments: [
            "--window-index=0",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("0")) {
        try command.execute(arguments: [
            "--window-id=0",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingOptionValue("--window-index")) {
        try command.execute(arguments: [
            "--window-index",
            "--tab-group-name",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.missingOptionValue("--window-id")) {
        try command.execute(arguments: [
            "--window-id=",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabListCommandError.unknownOption("--unknown")) {
        try command.execute(arguments: [
            "--unknown",
            "https://example.com"
        ])
    }
}

@Test(arguments: [
    [],
    [SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com")],
    [
        SafariTabRecord(processId: 4317, windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com"),
        SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 2, url: "https://openai.com"),
        SafariTabRecord(windowIdentifier: 84, windowIndex: 2, index: 1, url: "")
    ]
])
func safariTabListCommandFormatsTabRows(tabs: [SafariTabRecord]) async throws {
    let command = SafariTabListCommand(
        executor: MockAppleScriptExecutor(),
        listTabs: { _ in tabs }
    )

    let output = try command.execute(arguments: [])
    let expected = tabs.map {
        "\($0.windowIdentifier)|\($0.windowIndex)|\($0.index)|\($0.url)|\($0.processId.map(String.init) ?? "")"
    }.joined(separator: "\n")
    #expect(output == expected)

    let object = try jsonObject(try command.executeJSON(arguments: []))
    let jsonTabs = try #require(object["tabs"] as? [[String: Any]])
    #expect(jsonTabs.compactMap { $0["windowId"] as? Int } == tabs.map(\.windowIdentifier))
    #expect(jsonTabs.compactMap { $0["processId"] as? Int } == tabs.compactMap(\.processId).map(Int.init))
}

@Test func safariTabListCommandPropagatesListFailure() async throws {
    let command = SafariTabListCommand(
        executor: MockAppleScriptExecutor(),
        listTabs: { _ in throw SafariAppleScriptError.scriptCompilationFailed }
    )

    #expect(throws: SafariAppleScriptError.scriptCompilationFailed) {
        try command.execute(arguments: [])
    }
}

@Test(arguments: [
    [],
    [SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")],
    [
        SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://example.com"),
        SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://openai.com")
    ]
])
func safariTabListWindowTabsCommandFormatsRows(tabs: [SafariWindowTabRecord]) async throws {
    let command = SafariTabListWindowTabsCommand(
        executor: MockAppleScriptExecutor(),
        listWindowTabs: { _, _ in tabs }
    )

    let output = try command.execute(arguments: ["2"])
    let expected = tabs.map { "\($0.index)|\($0.selectedTabGroupTabIndex.map(String.init) ?? "")|\($0.url)" }.joined(separator: "\n")
    #expect(output == expected)
}

@Test func safariTabListWindowTabsCommandRejectsMissingOrInvalidWindowIndex() async throws {
    let command = SafariTabListWindowTabsCommand(
        executor: MockAppleScriptExecutor(),
        listWindowTabs: { _, _ in [] }
    )

    #expect(throws: SafariTabCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try command.execute(arguments: ["0"])
    }
}

@Test func safariTabListWindowTabsCommandTargetsWindowIdentifier() async throws {
    var receivedWindowIdentifier: Int?
    let command = SafariTabListWindowTabsCommand(
        executor: MockAppleScriptExecutor(),
        listWindowTabs: { _, _ in Issue.record("listWindowTabs should not be called"); return [] },
        listWindowTabsByIdentifier: { windowIdentifier, _ in
            receivedWindowIdentifier = windowIdentifier
            return [
                SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")
            ]
        }
    )

    #expect(try command.execute(arguments: ["--window-id=42"]) == "1||https://example.com")
    #expect(receivedWindowIdentifier == 42)

    let object = try jsonObject(try command.executeJSON(arguments: ["--window-id", "42"]))
    #expect(object["windowId"] as? Int == 42)
    #expect(object["windowIndex"] == nil)
}

@Test func safariTabListWindowTabsCommandPropagatesFailure() async throws {
    let command = SafariTabListWindowTabsCommand(
        executor: MockAppleScriptExecutor(),
        listWindowTabs: { _, _ in throw SafariAppleScriptError.scriptCompilationFailed }
    )

    #expect(throws: SafariAppleScriptError.scriptCompilationFailed) {
        try command.execute(arguments: ["1"])
    }
}

@Test func safariTabListWindowTabsUsesSelectedSavedTabGroupContext() async throws {
    let tabs = try SafariTab.listWindowTabs(
        windowIndex: 2,
        executor: MockAppleScriptExecutor(),
        databasePath: "/tmp/ignored",
        isRunning: { true },
        listWindows: { _ in
            [
                SafariAppleScriptWindowRecord(identifier: 10, name: "First"),
                SafariAppleScriptWindowRecord(identifier: 20, name: "Second")
            ]
        },
        listTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 20)
            return [
                SafariAppleScriptWindowTabRecord(index: 1, url: "https://example.com"),
                SafariAppleScriptWindowTabRecord(index: 2, url: "https://changed.example")
            ]
        },
        loadWindowStates: { _ in
            [
                20: SafariWindowState(profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", isPrivate: false)
            ]
        },
        loadTabGroupTabs: { identifier, _ in
            #expect(identifier == 1000)
            return [
                SafariTabGroupTabRecord(tabGroupIdentifier: 1000, index: 1, url: "https://example.com"),
                SafariTabGroupTabRecord(tabGroupIdentifier: 1000, index: 2, url: "https://openai.com")
            ]
        }
    )

    #expect(
        tabs ==
        [
            SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://example.com"),
            SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://changed.example")
        ]
    )
}

@Test func safariTabListWindowTabsSkipsSelectedTabGroupMatchingForPrivateWindow() async throws {
    let tabs = try SafariTab.listWindowTabs(
        windowIndex: 1,
        executor: MockAppleScriptExecutor(),
        databasePath: "/tmp/ignored",
        isRunning: { true },
        listWindows: { _ in
            [SafariAppleScriptWindowRecord(identifier: 10, name: "Private")]
        },
        listTabsByIdentifier: { windowIdentifier, _ in
            #expect(windowIdentifier == 10)
            return [SafariAppleScriptWindowTabRecord(index: 1, url: "https://example.com")]
        },
        loadWindowStates: { _ in
            [
                10: SafariWindowState(profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", isPrivate: true)
            ]
        },
        loadTabGroupTabs: { _, _ in
            Issue.record("Private windows should not load selected tab group tabs")
            return []
        }
    )

    #expect(
        tabs ==
        [SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: nil, url: "https://example.com")]
    )
}

@Test func safariTabListWindowTabsReturnsEmptyForMissingWindowOrStoppedSafari() async throws {
    let stoppedTabs = try SafariTab.listWindowTabs(
        windowIndex: 1,
        executor: MockAppleScriptExecutor(),
        databasePath: "/tmp/ignored",
        isRunning: { false },
        listWindows: { _ in [] },
        listTabsByIdentifier: { _, _ in [] },
        loadWindowStates: { _ in [:] },
        loadTabGroupTabs: { _, _ in [] }
    )

    #expect(stoppedTabs.isEmpty)

    let missingWindowTabs = try SafariTab.listWindowTabs(
        windowIndex: 2,
        executor: MockAppleScriptExecutor(),
        databasePath: "/tmp/ignored",
        isRunning: { true },
        listWindows: { _ in [SafariAppleScriptWindowRecord(identifier: 10, name: "Only")] },
        listTabsByIdentifier: { _, _ in
            Issue.record("Missing window should not list tabs")
            return []
        },
        loadWindowStates: { _ in [:] },
        loadTabGroupTabs: { _, _ in [] }
    )

    #expect(missingWindowTabs.isEmpty)
}
