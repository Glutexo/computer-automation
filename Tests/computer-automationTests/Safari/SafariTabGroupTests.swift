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

@Test(arguments: [
    [],
    [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")],
    [
        SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
        SafariTabGroupRecord(identifier: 11, profileName: "Glutexo", name: "Research")
    ]
])
func safariTabGroupListCommandFormatsRows(groups: [SafariTabGroupRecord]) async throws {
    let command = SafariTabGroupListCommand(listTabGroups: { groups })
    let output = try command.execute(arguments: [])
    let expected = groups.map { "\($0.identifier)|\($0.profileName)|\($0.name)" }.joined(separator: "\n")
    #expect(output == expected)
}

@Test func safariTabGroupSidebarListCommandFormatsAndFiltersExactRows() async throws {
    let groups = [
        SafariTabGroupSidebarRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
        SafariTabGroupSidebarRecord(identifier: nil, profileName: "Twisto", name: "Inbox"),
        SafariTabGroupSidebarRecord(identifier: 11, profileName: "Twisto", name: "Focus later")
    ]
    let command = SafariTabGroupSidebarListCommand { profileName in
        #expect(profileName == "Twisto")
        return groups
    }

    #expect(
        try command.execute(arguments: ["Twisto"]) ==
        "10|Twisto|Focus\n|Twisto|Inbox\n11|Twisto|Focus later"
    )
    #expect(try command.execute(arguments: ["Twisto", "Focus"]) == "10|Twisto|Focus")

    let object = try jsonObject(command.executeJSON(arguments: ["Twisto", "Inbox"]))
    let tabGroups = try #require(object["tabGroups"] as? [[String: Any]])
    #expect(object["profileName"] as? String == "Twisto")
    #expect(object["name"] as? String == "Inbox")
    #expect(tabGroups.count == 1)
    #expect(tabGroups[0]["identifier"] is NSNull)
    #expect(tabGroups[0]["profileName"] as? String == "Twisto")
    #expect(tabGroups[0]["name"] as? String == "Inbox")
}

@Test func safariTabGroupSidebarListCommandRejectsInvalidArguments() async throws {
    let command = SafariTabGroupSidebarListCommand { _ in
        Issue.record("listTabGroups should not be called")
        return []
    }

    #expect(throws: SafariTabGroupCommandError.missingProfileName) {
        try command.execute(arguments: [])
    }
    #expect(throws: SafariTabGroupCommandError.emptyProfileName) {
        try command.execute(arguments: [""])
    }
    #expect(throws: SafariTabGroupCommandError.emptyTabGroupName) {
        try command.execute(arguments: ["Twisto", ""])
    }
    #expect(throws: SafariTabGroupCommandError.unexpectedArgument("extra")) {
        try command.execute(arguments: ["Twisto", "Focus", "extra"])
    }
}

@Test func safariTabGroupSidebarAccessClosesItsOperationWindowOnSuccessAndFailure() async throws {
    let executor = MockAppleScriptExecutor()
    let window = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    var openedProfiles: [String] = []
    var closedIdentifiers: [Int] = []

    let result: String = try SafariTabGroupSidebarAccess.withNewWindowForProfile(
        profileName: "Twisto",
        executor: executor,
        listWindows: { [window] },
        openWindow: { profileName, _, listWindows in
            openedProfiles.append(profileName)
            let listedWindows = try listWindows()
            #expect(listedWindows == [window])
            return window
        },
        closeWindow: { identifier, _ in closedIdentifiers.append(identifier) },
        operation: { "listed" }
    )

    #expect(result == "listed")
    #expect(openedProfiles == ["Twisto"])
    #expect(closedIdentifiers == [42])

    #expect(throws: SafariTabGroupCommandError.sidebarUnavailable) {
        try SafariTabGroupSidebarAccess.withNewWindowForProfile(
            profileName: "Twisto",
            executor: executor,
            listWindows: { [window] },
            openWindow: { _, _, _ in window },
            closeWindow: { identifier, _ in closedIdentifiers.append(identifier) },
            operation: { throw SafariTabGroupCommandError.sidebarUnavailable }
        ) as String
    }
    #expect(closedIdentifiers == [42, 42])
}

@Test func safariTabGroupListCommandPropagatesFailure() async throws {
    let command = SafariTabGroupListCommand(
        listTabGroups: { throw SafariTabGroupCommandError.queryPreparationFailed }
    )

    #expect(throws: SafariTabGroupCommandError.queryPreparationFailed) {
        try command.execute(arguments: [])
    }
}

@Test func safariTabGroupFindCommandFormatsMatchingRows() async throws {
    let command = SafariTabGroupFindCommand(
        findTabGroups: { profileName, name in
            #expect(profileName == "Twisto")
            #expect(name == "Focus")
            return [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
            ]
        }
    )

    #expect(try command.execute(arguments: ["Twisto", "Focus"]) == "10|Twisto|Focus")
}

@Test func safariTabGroupFindCommandReturnsJSONMatches() async throws {
    let command = SafariTabGroupFindCommand(
        findTabGroups: { _, _ in
            [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus")
            ]
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto", "Focus"])
    let object = try jsonObject(output)
    let matches = try #require(object["matches"] as? [[String: Any]])

    #expect(object["profileName"] as? String == "Twisto")
    #expect(object["name"] as? String == "Focus")
    #expect(matches.count == 2)
    #expect(matches[0]["identifier"] as? Int == 10)
    #expect(matches[0]["profileName"] as? String == "Twisto")
    #expect(matches[0]["name"] as? String == "Focus")
}

@Test func safariTabGroupFindCommandRejectsInvalidArguments() async throws {
    let command = SafariTabGroupFindCommand(
        findTabGroups: { _, _ in Issue.record("findTabGroups should not be called"); return [] }
    )

    #expect(throws: SafariTabGroupCommandError.missingProfileName) {
        try command.execute(arguments: [])
    }
    #expect(throws: SafariTabGroupCommandError.emptyProfileName) {
        try command.execute(arguments: ["", "Focus"])
    }
    #expect(throws: SafariTabGroupCommandError.missingTabGroupName) {
        try command.execute(arguments: ["Twisto"])
    }
    #expect(throws: SafariTabGroupCommandError.emptyTabGroupName) {
        try command.execute(arguments: ["Twisto", ""])
    }
    #expect(throws: SafariTabGroupCommandError.unexpectedArgument("extra")) {
        try command.execute(arguments: ["Twisto", "Focus", "extra"])
    }
}

@Test func safariTabGroupResolveCommandFormatsSingleMatch() async throws {
    let command = SafariTabGroupResolveCommand(
        findTabGroups: { profileName, name in
            #expect(profileName == "Twisto")
            #expect(name == "Focus")
            return [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
            ]
        }
    )

    #expect(try command.execute(arguments: ["Twisto", "Focus"]) == "10|Twisto|Focus")
}

@Test func safariTabGroupResolveCommandReturnsJSONMatch() async throws {
    let command = SafariTabGroupResolveCommand(
        findTabGroups: { _, _ in
            [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")]
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto", "Focus"])
    let object = try jsonObject(output)
    let match = try #require(object["match"] as? [String: Any])

    #expect(object["profileName"] as? String == "Twisto")
    #expect(object["name"] as? String == "Focus")
    #expect(match["identifier"] as? Int == 10)
    #expect(match["profileName"] as? String == "Twisto")
    #expect(match["name"] as? String == "Focus")
}

@Test func safariTabGroupResolveCommandRequiresExactlyOneMatch() async throws {
    let noMatches = SafariTabGroupResolveCommand(findTabGroups: { _, _ in [] })
    #expect(
        throws: SafariTabGroupCommandError.tabGroupLookupNotFound(profileName: "Twisto", tabGroupName: "Focus")
    ) {
        try noMatches.execute(arguments: ["Twisto", "Focus"])
    }

    let multipleMatches = SafariTabGroupResolveCommand(
        findTabGroups: { _, _ in
            [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus")
            ]
        }
    )
    #expect(
        throws: SafariTabGroupCommandError.tabGroupLookupAmbiguous(
            profileName: "Twisto",
            tabGroupName: "Focus",
            count: 2
        )
    ) {
        try multipleMatches.execute(arguments: ["Twisto", "Focus"])
    }
}

@Test func safariTabGroupFindMatchesProfileAndNameExactly() async throws {
    let groups = try SafariTabGroup.find(
        profileName: "Twisto",
        name: "Focus",
        listTabGroups: {
            [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus later"),
                SafariTabGroupRecord(identifier: 12, profileName: "Glutexo", name: "Focus")
            ]
        },
        listProfiles: {
            [
                SafariProfileRecord(name: "Glutexo", identifier: "default-profile"),
                SafariProfileRecord(name: "Twisto", identifier: "work-profile")
            ]
        }
    )

    #expect(groups == [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")])
}

@Test func safariTabGroupFindMatchesDefaultProfileStoredWithoutName() async throws {
    let groups = try SafariTabGroup.find(
        profileName: "Glutexo",
        name: "Focus",
        listTabGroups: {
            [
                SafariTabGroupRecord(identifier: 10, profileName: "", name: "Focus"),
                SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus")
            ]
        },
        listProfiles: {
            [
                SafariProfileRecord(name: "Glutexo", identifier: "default-profile"),
                SafariProfileRecord(name: "Twisto", identifier: "work-profile")
            ]
        }
    )

    #expect(groups == [SafariTabGroupRecord(identifier: 10, profileName: "Glutexo", name: "Focus")])
}

@Test func safariTabGroupEnsureCommandReusesSingleExistingGroup() async throws {
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { profileName, name in
            #expect(profileName == "Twisto")
            #expect(name == "Focus")
            return [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")]
        },
        listProfiles: { [] },
        listWindows: {
            Issue.record("listWindows should not be called")
            return []
        },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        createTabGroup: { _, _ in
            Issue.record("createTabGroup should not be called")
            return SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus")
        }
    )

    #expect(try command.execute(arguments: ["Twisto", "Focus"]) == "Safari tab group reused.\n10|Twisto|Focus")
}

@Test func safariTabGroupEnsureCommandCreatesMissingGroupInProfileWindow() async throws {
    var openedProfileName: String?
    var focusedWindowIdentifiers: [Int] = []
    var listWindowCallCount = 0
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            if listWindowCallCount == 1 {
                return []
            }
            return [
                SafariWindowRecord(identifier: 42, index: 3, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page")
            ]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifiers.append(windowIdentifier) },
        openWindow: { profileName, _ in openedProfileName = profileName },
        createTabGroup: { windowIdentifier, name in
            #expect(windowIdentifier == 42)
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto", "Focus"])
    let object = try jsonObject(output)
    let tabGroup = try #require(object["tabGroup"] as? [String: Any])

    #expect(openedProfileName == "Twisto")
    #expect(focusedWindowIdentifiers == [42])
    #expect(object["status"] as? String == "created")
    #expect(tabGroup["identifier"] as? Int == 10)
    #expect(tabGroup["profileName"] as? String == "Twisto")
    #expect(tabGroup["name"] as? String == "Focus")
}

@Test func safariTabGroupEnsureCommandCreatesMissingGroupInNewProfileWindowWithoutReusingExistingWindow() async throws {
    var openedProfileName: String?
    var focusedWindowIdentifiers: [Int] = []
    var createdWindowIdentifier: Int?
    var listWindowCallCount = 0
    let existingWindow = SafariWindowRecord(
        identifier: 10,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Existing work"
    )
    let openedWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            if listWindowCallCount == 1 {
                return [existingWindow]
            }
            return [openedWindow, existingWindow]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifiers.append(windowIdentifier) },
        openWindow: { profileName, _ in openedProfileName = profileName },
        createTabGroup: { windowIdentifier, name in
            createdWindowIdentifier = windowIdentifier
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
        }
    )

    let result = try command.ensureOperation(profileName: "Twisto", name: "Focus")
    #expect(result.summary.status == .created)
    #expect(result.summary.tabGroup == SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"))
    #expect(result.createdWindow == openedWindow)
    #expect(openedProfileName == "Twisto")
    #expect(focusedWindowIdentifiers == [42])
    #expect(createdWindowIdentifier == 42)
}

@Test func safariTabGroupEnsureCommandFallsBackToExistingProfileWindowWhenMenuOpenDoesNotCreateWindow() async throws {
    var openedProfileName: String?
    var focusedWindowIdentifiers: [Int] = []
    var didOpenNewDocument = false
    var createdWindowIdentifier: Int?
    let existingWindow = SafariWindowRecord(
        identifier: 10,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Existing work"
    )
    let openedWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            if !didOpenNewDocument {
                return [existingWindow]
            }
            return [openedWindow, existingWindow]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifiers.append(windowIdentifier) },
        openWindow: { profileName, _ in openedProfileName = profileName },
        closeWindow: { _, _ in },
        openNewDocument: { _ in didOpenNewDocument = true },
        createTabGroup: { windowIdentifier, name in
            createdWindowIdentifier = windowIdentifier
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["Twisto", "Focus"]) == "Safari tab group created.\n10|Twisto|Focus")
    #expect(openedProfileName == "Twisto")
    #expect(focusedWindowIdentifiers == [10, 42])
    #expect(didOpenNewDocument)
    #expect(createdWindowIdentifier == 42)
}

@Test func safariTabGroupEnsureCommandRejectsWrongProfileNewWindow() async throws {
    var openedProfileName: String?
    var closedWindowIdentifiers: [Int] = []
    var didCreateTabGroup = false
    var listWindowCallCount = 0
    let wrongProfileWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [] : [wrongProfileWindow]
        },
        focusWindow: { _, _ in },
        openWindow: { profileName, _ in openedProfileName = profileName },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        createTabGroup: { _, _ in
            didCreateTabGroup = true
            return SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.windowForProfileNotFound("Glutexo")) {
        try command.execute(arguments: ["Glutexo", "Focus"])
    }
    #expect(openedProfileName == "Glutexo")
    #expect(closedWindowIdentifiers == [42])
    #expect(!didCreateTabGroup)
}

@Test func safariTabGroupEnsureCommandDoesNotFallbackAfterWrongProfileNewWindow() async throws {
    var closedWindowIdentifiers: [Int] = []
    var didOpenNewDocument = false
    var didCreateTabGroup = false
    var listWindowCallCount = 0
    let existingProfileWindow = SafariWindowRecord(
        identifier: 10,
        index: 2,
        isPrivate: false,
        profileName: "Glutexo",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Glutexo — Existing work"
    )
    let wrongProfileWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [existingProfileWindow] : [wrongProfileWindow, existingProfileWindow]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        openNewDocument: { _ in didOpenNewDocument = true },
        createTabGroup: { _, _ in
            didCreateTabGroup = true
            return SafariTabGroupRecord(identifier: 10, profileName: "Glutexo", name: "Focus")
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.windowForProfileNotFound("Glutexo")) {
        try command.execute(arguments: ["Glutexo", "Focus"])
    }
    #expect(closedWindowIdentifiers == [42])
    #expect(!didOpenNewDocument)
    #expect(!didCreateTabGroup)
}

@Test func safariTabGroupEnsureCommandDeletesWrongProfileCreatedGroup() async throws {
    var deletedTabGroupIdentifiers: [Int] = []
    var closedWindowIdentifiers: [Int] = []
    var listWindowCallCount = 0
    let openedWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Glutexo",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Glutexo — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [] : [openedWindow]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        createTabGroup: { windowIdentifier, name in
            #expect(windowIdentifier == 42)
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 99, profileName: "Twisto", name: "Focus")
        },
        deleteTabGroup: { identifier in deletedTabGroupIdentifiers.append(identifier) },
        sleep: { _ in }
    )

    #expect(
        throws: SafariTabGroupCommandError.createdTabGroupProfileMismatch(
            requestedProfileName: "Glutexo",
            createdProfileName: "Twisto"
        )
    ) {
        try command.execute(arguments: ["Glutexo", "Focus"])
    }
    #expect(deletedTabGroupIdentifiers == [99])
    #expect(closedWindowIdentifiers == [42])
}

@Test func safariTabGroupEnsureCommandAcceptsDefaultProfileCreatedGroup() async throws {
    var shortcutRequests: [String] = []
    var focusedWindowIdentifiers: [Int] = []
    var listWindowCallCount = 0
    let openedWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Glutexo",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Glutexo — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: {
            [
                SafariProfileRecord(name: "Glutexo", identifier: "default-profile"),
                SafariProfileRecord(name: "Twisto", identifier: "work-profile")
            ]
        },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [] : [openedWindow]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifiers.append(windowIdentifier) },
        openWindow: { _, _ in Issue.record("openWindow should not be called when profile shortcut is available") },
        openProfileWindowShortcut: { profileName, profileNames, _ in
            shortcutRequests.append("\(profileName)|\(profileNames.joined(separator: ","))")
        },
        createTabGroup: { windowIdentifier, name in
            #expect(windowIdentifier == 42)
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 99, profileName: "", name: "Focus")
        }
    )

    #expect(try command.execute(arguments: ["Glutexo", "Focus"]) == "Safari tab group created.\n99|Glutexo|Focus")
    #expect(shortcutRequests == ["Glutexo|Glutexo,Twisto"])
    #expect(focusedWindowIdentifiers == [42])
}

@Test func safariTabGroupEnsureCommandClosesNewProfileWindowWhenCreateFails() async throws {
    var openedProfileName: String?
    var closedWindowIdentifiers: [Int] = []
    var listWindowCallCount = 0
    let openedWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [] : [openedWindow]
        },
        focusWindow: { _, _ in },
        openWindow: { profileName, _ in openedProfileName = profileName },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        createTabGroup: { _, _ in throw SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto") }
    )

    #expect(throws: SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto")) {
        try command.execute(arguments: ["Twisto", "Focus"])
    }
    #expect(openedProfileName == "Twisto")
    #expect(closedWindowIdentifiers == [42])
}

@Test func safariTabGroupEnsureJSONPropagatesDisabledCreateActionAfterClosingWindow() async throws {
    var closedWindowIdentifiers: [Int] = []
    var listWindowCallCount = 0
    let openedWindow = SafariWindowRecord(
        identifier: 5769,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    let expectedError = SafariUserInterfaceError.menuItemDisabled(
        SafariFileMenu.createTabGroupFromCurrentTabsMenuItemIdentifier
    )
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listProfiles: { [] },
        listWindows: {
            listWindowCallCount += 1
            return listWindowCallCount == 1 ? [] : [openedWindow]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) },
        createTabGroup: { _, _ in throw expectedError }
    )

    #expect(throws: expectedError) {
        try command.executeJSON(arguments: ["Twisto", "Focus"])
    }
    #expect(closedWindowIdentifiers == [5769])
}

@Test func safariTabGroupEnsureCommandRejectsAmbiguousExistingGroups() async throws {
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in
            [
                SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 11, profileName: "Twisto", name: "Focus")
            ]
        },
        listProfiles: { [] },
        listWindows: {
            Issue.record("listWindows should not be called")
            return []
        },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        createTabGroup: { _, _ in
            Issue.record("createTabGroup should not be called")
            return SafariTabGroupRecord(identifier: 12, profileName: "Twisto", name: "Focus")
        }
    )

    #expect(
        throws: SafariTabGroupCommandError.tabGroupLookupAmbiguous(
            profileName: "Twisto",
            tabGroupName: "Focus",
            count: 2
        )
    ) {
        try command.execute(arguments: ["Twisto", "Focus"])
    }
}

@Test func safariTabGroupCreateCommandCreatesAndRenamesGroupForWindowProfile() async throws {
    var focusedWindowIdentifier: Int?
    var didCreateTabGroupFromCurrentTabs = false
    var renamedIdentifier: Int?
    var renamedSourceName: String?
    var renamedTargetName: String?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }
            if pollCount == 2 {
                return [
                    SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                    SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Senza nome")
                ]
            }
            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Inbox")
            ]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifier = windowIdentifier },
        createTabGroupFromCurrentTabs: { _ in didCreateTabGroupFromCurrentTabs = true },
        renameTabGroup: { group, newName, _ in
            renamedIdentifier = group.identifier
            renamedSourceName = group.name
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(focusedWindowIdentifier == 10)
    #expect(didCreateTabGroupFromCurrentTabs)
    #expect(renamedIdentifier == 1001)
    #expect(renamedSourceName == "Senza nome")
    #expect(renamedTargetName == "Inbox")
}

@Test func safariTabGroupCreateCommandRejectsDisabledFileMenuActionWithoutPolling() async throws {
    var listTabGroupCallCount = 0
    let expectedError = SafariUserInterfaceError.menuItemDisabled(
        SafariFileMenu.createTabGroupFromCurrentTabsMenuItemIdentifier
    )
    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 5769, index: 1, profileName: "Twisto", name: "Twisto")]
        },
        listTabGroups: {
            listTabGroupCallCount += 1
            return []
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in throw expectedError },
        renameTabGroup: { _, _, _ in Issue.record("renameTabGroup should not be called") },
        sleep: { _ in Issue.record("sleep should not be called") }
    )

    #expect(throws: expectedError) {
        try command.execute(arguments: ["1", "Focus"])
    }
    #expect(listTabGroupCallCount == 1)
}

@Test func safariTabGroupCreateCommandAcceptsDefaultProfileStoredWithoutName() async throws {
    var didCreateTabGroupFromCurrentTabs = false
    var renamedIdentifier: Int?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Glutexo")]
        },
        listTabGroups: {
            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "", name: "Focus")]
            }
            if pollCount == 2 {
                return [
                    SafariTabGroupRecord(identifier: 1000, profileName: "", name: "Focus"),
                    SafariTabGroupRecord(identifier: 1001, profileName: "", name: "Senza nome")
                ]
            }
            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "", name: "Inbox")
            ]
        },
        listProfiles: {
            [
                SafariProfileRecord(name: "Glutexo", identifier: "default-profile"),
                SafariProfileRecord(name: "Twisto", identifier: "work-profile")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in didCreateTabGroupFromCurrentTabs = true },
        renameTabGroup: { group, _, _ in renamedIdentifier = group.identifier },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Glutexo|Inbox")
    #expect(didCreateTabGroupFromCurrentTabs)
    #expect(renamedIdentifier == 1001)
}

@Test func safariTabGroupCreateCommandRejectsInvalidArgumentsAndStates() async throws {
    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { [] },
        listTabGroups: { [] },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        createTabGroupFromCurrentTabs: { _ in Issue.record("createTabGroupFromCurrentTabs should not be called") },
        renameTabGroup: { _, _, _ in
            Issue.record("renameTabGroup should not be called")
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabGroupCommandError.invalidWindowIndex("x")) {
        try command.execute(arguments: ["x", "Inbox"])
    }

    #expect(throws: SafariTabGroupCommandError.missingTabGroupName) {
        try command.execute(arguments: ["1"])
    }

    #expect(throws: SafariTabGroupCommandError.emptyTabGroupName) {
        try command.execute(arguments: ["1", "   "])
    }

    #expect(throws: SafariTabGroupCommandError.invalidWindowIndex("1")) {
        try command.execute(arguments: ["1", "Inbox"])
    }

    let privateWindowCommand = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: true, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Private")]
        },
        listTabGroups: { [] },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        createTabGroupFromCurrentTabs: { _ in Issue.record("createTabGroupFromCurrentTabs should not be called") },
        renameTabGroup: { _, _, _ in
            Issue.record("renameTabGroup should not be called")
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.privateWindowTabGroupMutationUnsupported(1)) {
        try privateWindowCommand.execute(arguments: ["1", "Inbox"])
    }

    let duplicateNameCommand = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        createTabGroupFromCurrentTabs: { _ in Issue.record("createTabGroupFromCurrentTabs should not be called") },
        renameTabGroup: { _, _, _ in
            Issue.record("renameTabGroup should not be called")
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.duplicateTabGroupName(profileName: "Twisto", tabGroupName: "Inbox")) {
        try duplicateNameCommand.execute(arguments: ["1", "Inbox"])
    }
}

@Test func safariTabGroupCreateCommandFailsWhenCreatedGroupDoesNotAppear() async throws {
    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { _, _, _ in Issue.record("renameTabGroup should not be called") },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto")) {
        try command.execute(arguments: ["2", "Inbox"])
    }
}

@Test func safariTabGroupCreateCommandUsesSelectedTabGroupProfileWhenWindowProfileIsUnknown() async throws {
    var focusedWindowIdentifier: Int?
    var didCreateTabGroupFromCurrentTabs = false
    var renamedIdentifier: Int?
    var renamedSourceName: String?
    var renamedTargetName: String?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", name: "Focus — Start Page")]
        },
        listTabGroups: {
            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }
            if pollCount == 2 {
                return [
                    SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                    SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Senza nome")
                ]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Inbox")
            ]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifier = windowIdentifier },
        createTabGroupFromCurrentTabs: { _ in didCreateTabGroupFromCurrentTabs = true },
        renameTabGroup: { group, newName, _ in
            renamedIdentifier = group.identifier
            renamedSourceName = group.name
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(focusedWindowIdentifier == 10)
    #expect(didCreateTabGroupFromCurrentTabs)
    #expect(renamedIdentifier == 1001)
    #expect(renamedSourceName == "Senza nome")
    #expect(renamedTargetName == "Inbox")
}

@Test func safariTabGroupCreateCommandSkipsRenameWhenSafariAlreadyCreatesExpectedName() async throws {
    var renamedSourceName: String?
    var renamedTargetName: String?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Inbox")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { group, newName, _ in
            renamedSourceName = group.name
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(renamedSourceName == nil)
    #expect(renamedTargetName == nil)
}

@Test func safariTabGroupCreateCommandWaitsForDelayedRenamePersistence() async throws {
    var renamedSourceName: String?
    var renamedTargetName: String?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }
            if pollCount < 14 {
                return [
                    SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                    SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Senza nome")
                ]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Inbox")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { group, newName, _ in
            renamedSourceName = group.name
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(renamedSourceName == "Senza nome")
    #expect(renamedTargetName == "Inbox")
    #expect(pollCount == 14)
}

@Test func safariTabGroupCreateCommandRejectsWrongProfileCreatedGroup() async throws {
    var deletedCurrentGroup = false
    var renamedSourceName: String?
    var renamedTargetName: String?
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            if deletedCurrentGroup {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "", name: "名称未設定")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { group, newName, _ in
            renamedSourceName = group.name
            renamedTargetName = newName
        },
        deleteCurrentTabGroup: { _ in deletedCurrentGroup = true },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto")) {
        try command.execute(arguments: ["2", "Inbox"])
    }
    #expect(deletedCurrentGroup)
    #expect(renamedSourceName == nil)
    #expect(renamedTargetName == nil)
}

@Test func safariTabGroupCreateCommandRollsBackCreatedGroupWhenRenameFails() async throws {
    var deletedCurrentGroup = false
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            if deletedCurrentGroup {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Senza nome")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { _, _, _ in throw SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable },
        deleteCurrentTabGroup: { _ in deletedCurrentGroup = true },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable) {
        try command.execute(arguments: ["2", "Inbox"])
    }
    #expect(deletedCurrentGroup)
}

@Test func safariTabGroupCreateCommandAcceptsVerifiedRollbackWhenDeleteUIThrows() async throws {
    var deletedCurrentGroup = false
    var pollCount = 0

    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            if deletedCurrentGroup {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            pollCount += 1
            if pollCount == 1 {
                return [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
            }

            return [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Senza nome")
            ]
        },
        focusWindow: { _, _ in },
        createTabGroupFromCurrentTabs: { _ in },
        renameTabGroup: { _, _, _ in throw SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable },
        deleteCurrentTabGroup: { _ in
            deletedCurrentGroup = true
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)
        },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable) {
        try command.execute(arguments: ["2", "Inbox"])
    }
    #expect(deletedCurrentGroup)
}

@Test func safariTabGroupDeleteCommandFormatsResolvedGroup() async throws {
    var focusedWindowIdentifiers: [Int] = []
    var openedProfiles: [String?] = []
    var selectedIdentifiers: [Int] = []
    var selectedNames: [String] = []

    var deleted = false
    var deleteWindowPollCount = 0
    let deleteCommand = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            deleted ? [] : [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Inbox")
            ]
        },
        listWindows: {
            deleteWindowPollCount += 1
            if deleteWindowPollCount == 1 {
                return []
            }
            return [SafariWindowRecord(identifier: 12, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Twisto")]
        },
        focusWindow: { identifier, _ in focusedWindowIdentifiers.append(identifier) },
        openWindow: { profile, _ in openedProfiles.append(profile) },
        selectTabGroup: { group, _ in
            selectedIdentifiers.append(group.identifier)
            selectedNames.append(group.name)
        },
        deleteSelectedTabGroup: { _ in deleted = true },
        sleep: { _ in }
    )
    #expect(try deleteCommand.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(openedProfiles == [])
    #expect(selectedIdentifiers.suffix(1).first == 1000)
    #expect(selectedNames.suffix(1).first == "Inbox")
    #expect(focusedWindowIdentifiers.suffix(1).first == 12)
    #expect(deleted)
}

@Test func safariTabGroupDeleteCommandAcceptsVerifiedDeletionWhenDeleteUIThrows() async throws {
    var deleted = false
    let deleteCommand = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            deleted ? [] : [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 12, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Inbox", name: "Inbox")]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in },
        selectTabGroup: { _, _ in },
        deleteSelectedTabGroup: { _ in
            deleted = true
            throw SafariUserInterfaceError.menuUnavailable(menuBarItemIndex: 0)
        },
        sleep: { _ in }
    )

    #expect(try deleteCommand.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(deleted)
}

@Test func safariTabGroupDeleteCommandRejectsMissingOrInvalidArguments() async throws {
    let deleteCommand = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: { [] },
        listWindows: { [] },
        focusWindow: { _, _ in },
        openWindow: { _, _ in },
        selectTabGroup: { _, _ in },
        deleteSelectedTabGroup: { _ in },
        sleep: { _ in }
    )
    #expect(throws: SafariTabGroupCommandError.missingTabGroupIdentifier) {
        try deleteCommand.execute(arguments: [])
    }
    #expect(throws: SafariTabGroupCommandError.invalidTabGroupIdentifier("x")) {
        try deleteCommand.execute(arguments: ["x"])
    }
    #expect(throws: SafariTabGroupCommandError.missingTabGroupName) {
        try deleteCommand.execute(arguments: ["--profile", "Twisto"])
    }
    #expect(throws: SafariTabGroupCommandError.missingProfileName) {
        try deleteCommand.execute(arguments: ["--profile", "--name", "Focus"])
    }
    #expect(throws: SafariTabGroupCommandError.missingTabGroupName) {
        try deleteCommand.execute(arguments: ["--name", "--profile", "Twisto"])
    }
    #expect(throws: SafariTabGroupCommandError.missingProfileName) {
        try deleteCommand.execute(arguments: ["--name", "Focus"])
    }
    #expect(throws: SafariTabGroupCommandError.emptyProfileName) {
        try deleteCommand.execute(arguments: ["--profile=", "--name=Focus"])
    }
    #expect(throws: SafariTabGroupCommandError.emptyTabGroupName) {
        try deleteCommand.execute(arguments: ["--profile=Twisto", "--name="])
    }
    #expect(throws: SafariTabGroupCommandError.unexpectedArgument("1000")) {
        try deleteCommand.execute(arguments: ["1000", "--profile", "Twisto", "--name", "Focus"])
    }
}

@Test func safariTabGroupDeleteCommandUsesSidebarProfileAndNameAddress() async throws {
    var requestedAddress: (String, String)?
    let expected = SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")
    let command = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: { Issue.record("listTabGroups should not be called"); return [] },
        listWindows: { Issue.record("listWindows should not be called"); return [] },
        deleteSidebarTabGroup: { profileName, tabGroupName in
            requestedAddress = (profileName, tabGroupName)
            return expected
        },
        sleep: { _ in }
    )

    #expect(
        try command.execute(arguments: ["--name=Inbox", "--profile", "Twisto"]) ==
        "1000|Twisto|Inbox"
    )
    #expect(requestedAddress?.0 == "Twisto")
    #expect(requestedAddress?.1 == "Inbox")
}

@Test func safariTabGroupSidebarAccessDeletesOneExactNamedRowAndVerifiesReadback() async throws {
    let executor = MockAppleScriptExecutor()
    let window = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    var rows = [
        SafariSidebarTabGroupRecord(identifier: 1000, name: "Inbox"),
        SafariSidebarTabGroupRecord(identifier: 1001, name: "Focus")
    ]
    var selected: (Int, String)?
    var closedWindowIdentifier: Int?

    let deleted = try SafariTabGroupSidebarAccess.deleteTabGroup(
        profileName: "Twisto",
        named: "Inbox",
        executor: executor,
        listWindows: { [window] },
        openWindow: { profileName, _, _ in
            #expect(profileName == "Twisto")
            return window
        },
        closeWindow: { identifier, _ in closedWindowIdentifier = identifier },
        listSidebarTabGroups: { _ in rows },
        selectTabGroup: { identifier, name, _ in selected = (identifier, name) },
        deleteSelectedTabGroup: { _ in
            rows.removeAll { $0.identifier == 1000 }
        },
        sleep: { _ in },
        maxAttempts: 1
    )

    #expect(deleted == SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox"))
    #expect(selected?.0 == 1000)
    #expect(selected?.1 == "Inbox")
    #expect(closedWindowIdentifier == 42)
    #expect(rows == [SafariSidebarTabGroupRecord(identifier: 1001, name: "Focus")])
}

@Test func safariTabGroupSidebarAccessFailsClosedForAmbiguousOrUnidentifiedRows() async throws {
    let executor = MockAppleScriptExecutor()
    let window = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    var rows = [
        SafariSidebarTabGroupRecord(identifier: 1000, name: "Inbox"),
        SafariSidebarTabGroupRecord(identifier: 1001, name: "Inbox")
    ]
    var closeCount = 0
    var selectCount = 0
    var deleteCount = 0

    func delete() throws -> SafariTabGroupRecord {
        try SafariTabGroupSidebarAccess.deleteTabGroup(
            profileName: "Twisto",
            named: "Inbox",
            executor: executor,
            listWindows: { [window] },
            openWindow: { _, _, _ in window },
            closeWindow: { _, _ in closeCount += 1 },
            listSidebarTabGroups: { _ in rows },
            selectTabGroup: { _, _, _ in selectCount += 1 },
            deleteSelectedTabGroup: { _ in deleteCount += 1 },
            sleep: { _ in },
            maxAttempts: 1
        )
    }

    #expect(
        throws: SafariTabGroupCommandError.tabGroupLookupAmbiguous(
            profileName: "Twisto",
            tabGroupName: "Inbox",
            count: 2
        )
    ) {
        try delete()
    }

    rows = [SafariSidebarTabGroupRecord(identifier: nil, name: "Inbox")]
    #expect(
        throws: SafariTabGroupCommandError.sidebarTabGroupIdentifierUnavailable(
            profileName: "Twisto",
            tabGroupName: "Inbox"
        )
    ) {
        try delete()
    }

    #expect(closeCount == 2)
    #expect(selectCount == 0)
    #expect(deleteCount == 0)
}

@Test func safariTabGroupDeleteCommandFallsBackToSingleUnscopedWindow() async throws {
    let executor = MockAppleScriptExecutor()
    var focusedWindowIdentifier: Int?
    var openedProfileName: String?
    var selectedIdentifier: Int?
    var selectedName: String?
    var didDelete = false

    let command = SafariTabGroupDeleteCommand(
        executor: executor,
        listTabGroups: {
            didDelete ? [] : [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Front")]
        },
        focusWindow: { identifier, _ in focusedWindowIdentifier = identifier },
        openWindow: { profileName, _ in openedProfileName = profileName },
        selectTabGroup: { group, _ in
            selectedIdentifier = group.identifier
            selectedName = group.name
        },
        deleteSelectedTabGroup: { _ in didDelete = true },
        deleteCurrentTabGroup: { _ in Issue.record("deleteCurrentTabGroup should not be called") },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(focusedWindowIdentifier == 10)
    #expect(openedProfileName == nil)
    #expect(selectedIdentifier == 1000)
    #expect(selectedName == "Inbox")
    #expect(didDelete)
}

@Test func safariTabGroupSidebarAccessPrefersProfileShortcutWhenAvailable() async throws {
    let existingWindow = SafariWindowRecord(
        identifier: 10,
        index: 1,
        isPrivate: false,
        profileName: "Glutexo",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Glutexo — Start Page"
    )
    let shortcutWindow = SafariWindowRecord(
        identifier: 42,
        index: 1,
        isPrivate: false,
        profileName: "Twisto",
        selectedTabGroupIdentifier: nil,
        tabGroupName: nil,
        name: "Twisto — Start Page"
    )
    var didOpenWindow = false
    var shortcutRequests: [String] = []
    var focusedWindowIdentifiers: [Int] = []
    var sleptIntervals: [TimeInterval] = []
    var didUseShortcut = false

    let focusedWindow = try SafariTabGroupSidebarAccess.focusWindowForProfile(
        profileName: "Twisto",
        executor: MockAppleScriptExecutor(),
        listWindows: {
            didUseShortcut ? [shortcutWindow, existingWindow] : [existingWindow]
        },
        focusWindow: { identifier, _ in focusedWindowIdentifiers.append(identifier) },
        openWindow: { _, _ in didOpenWindow = true },
        profileNames: {
            ["Glutexo", "Twisto"]
        },
        openProfileWindowShortcut: { profileName, profileNames, _ in
            shortcutRequests.append("\(profileName)|\(profileNames.joined(separator: ","))")
            didUseShortcut = true
        },
        sleep: { sleptIntervals.append($0) }
    )

    #expect(focusedWindow == shortcutWindow)
    #expect(!didOpenWindow)
    #expect(shortcutRequests == ["Twisto|Glutexo,Twisto"])
    #expect(focusedWindowIdentifiers == [42])
    #expect(sleptIntervals.isEmpty)
}

@Test func safariTabGroupDeleteCommandFallsBackToCurrentGroupDeleteWhenSidebarSelectionFails() async throws {
    var focusedWindowIdentifier: Int?
    var selectedIdentifier: Int?
    var selectedName: String?
    var didDeleteSelectedGroup = false
    var didDeleteCurrentGroup = false

    let command = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            didDeleteCurrentGroup ? [] : [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Inbox — Start Page")]
        },
        focusWindow: { identifier, _ in focusedWindowIdentifier = identifier },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { group, _ in
            selectedIdentifier = group.identifier
            selectedName = group.name
            throw SafariTabGroupCommandError.sidebarTabGroupNotFound(group.name)
        },
        deleteSelectedTabGroup: { _ in didDeleteSelectedGroup = true },
        deleteCurrentTabGroup: { _ in didDeleteCurrentGroup = true },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(focusedWindowIdentifier == 10)
    #expect(selectedIdentifier == 1000)
    #expect(selectedName == "Inbox")
    #expect(!didDeleteSelectedGroup)
    #expect(didDeleteCurrentGroup)
}

@Test func safariTabGroupDeleteCommandRejectsNameFallbackForContradictoryWindowIdentifier() async throws {
    var didDeleteCurrentGroup = false
    let command = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [
                SafariWindowRecord(
                    identifier: 10,
                    index: 2,
                    isPrivate: false,
                    profileName: "Twisto",
                    selectedTabGroupIdentifier: 1001,
                    tabGroupName: "Inbox",
                    name: "Inbox — Start Page"
                )
            ]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { group, _ in
            throw SafariTabGroupCommandError.sidebarTabGroupNotFound(group.name)
        },
        deleteSelectedTabGroup: { _ in Issue.record("deleteSelectedTabGroup should not be called") },
        deleteCurrentTabGroup: { _ in didDeleteCurrentGroup = true },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.sidebarTabGroupNotFound("Inbox")) {
        try command.execute(arguments: ["1000"])
    }
    #expect(!didDeleteCurrentGroup)
}

@Test func safariTabGroupDeleteCommandFallsBackToCurrentGroupDeleteWhenSidebarDeletionFails() async throws {
    var focusedWindowIdentifier: Int?
    var selectedIdentifier: Int?
    var selectedName: String?
    var didDeleteSelectedGroup = false
    var didDeleteCurrentGroup = false

    let command = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            didDeleteCurrentGroup ? [] : [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Inbox — Start Page")]
        },
        focusWindow: { identifier, _ in focusedWindowIdentifier = identifier },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { group, _ in
            selectedIdentifier = group.identifier
            selectedName = group.name
        },
        deleteSelectedTabGroup: { _ in
            didDeleteSelectedGroup = true
            throw SafariTabGroupCommandError.sidebarSelectedItemRenameUnavailable
        },
        deleteCurrentTabGroup: { _ in didDeleteCurrentGroup = true },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(focusedWindowIdentifier == 10)
    #expect(selectedIdentifier == 1000)
    #expect(selectedName == "Inbox")
    #expect(didDeleteSelectedGroup)
    #expect(didDeleteCurrentGroup)
}

@Test func safariTabGroupDeleteCommandRejectsUnverifiedDeletion() async throws {
    var didDelete = false
    let command = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Inbox", name: "Inbox — Start Page")]
        },
        focusWindow: { _, _ in },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { _, _ in },
        deleteSelectedTabGroup: { _ in didDelete = true },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.tabGroupDeletionNotVerified(1000)) {
        try command.execute(arguments: ["1000"])
    }
    #expect(didDelete)
}

@Test func safariTabGroupListTabsIgnoresUnknownOrUnsavedGroups() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        url TEXT,
        order_index INTEGER NOT NULL,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, url, order_index, subtype) VALUES
        (5, 0, 1, 'Glutexo', NULL, 0, 2),
        (1000, NULL, 1, 'Local', NULL, 0, 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (1002, 1000, 0, 'Local Tab', 'https://local.example', 1, 0);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 9999, databasePath: databasePath).isEmpty)
    #expect(try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath).isEmpty)
}
