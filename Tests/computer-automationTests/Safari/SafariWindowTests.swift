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

@Test func safariWindowParsesAppleScriptListOutput() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "1|Start Page"), at: 1)
    listDescriptor.insert(NSAppleEventDescriptor(string: "2|OpenAI"), at: 2)

    #expect(
        SafariWindow.parseWindowList(
            listDescriptor,
            profilesByWindowIdentifier: [
                1: "Glutexo",
                2: "Twisto"
            ],
            privateWindowIdentifiers: [2]
        ) ==
        [
            SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page"),
            SafariWindowRecord(identifier: 2, index: 2, isPrivate: true, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "OpenAI")
        ]
    )
}

@Test(arguments: [
    ("Glutexo", [1: "Glutexo"], [SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Glutexo")]),
    ("Glutexo — Start Page", [:], [SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Glutexo — Start Page")]),
    ("Unknown", [:], [SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Unknown")])
])
func safariWindowParseWindowListPreservesOrderingAndKnownProfileMapping(
    title: String,
    mappings: [Int: String],
    expected: [SafariWindowRecord]
) async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "1|\(title)"), at: 1)

    #expect(
        SafariWindow.parseWindowList(listDescriptor, profilesByWindowIdentifier: mappings) == expected
    )
}

@Test func safariWindowListFallsBackToAppleScriptFieldsWhenDatabaseIsUnavailable() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "42|Start Page"), at: 1)

    let windows = try SafariWindow.list(
        executor: MockAppleScriptExecutor(results: [.descriptor(listDescriptor)]),
        databasePath: "/protected/SafariTabs.db",
        isRunning: { true }
    )

    #expect(
        windows == [
            SafariWindowRecord(identifier: 42, index: 1, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page")
        ]
    )
}

@Test func safariWindowOpenCommandOpensUnprofiledWindow() async throws {
    let executor = MockAppleScriptExecutor()
    var receivedProfileName: String?
    var windowLists = [
        [SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")],
        [
            SafariAppleScriptWindowRecord(identifier: 42, name: "Start Page"),
            SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")
        ]
    ]
    let command = SafariWindowOpenCommand(
        executor: executor,
        listProfiles: { [] },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        listWindows: { _ in windowLists.removeFirst() }
    )

    #expect(try command.execute(arguments: []) == "Safari window opened.\nwindow-id|42")
    #expect(receivedProfileName == nil)
}

@Test func safariWindowOpenCommandRejectsUnknownProfile() async throws {
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Glutexo", identifier: "1")] },
        openWindow: { _, _ in Issue.record("openWindow should not be called") }
    )

    #expect(throws: SafariWindowCommandError.profileNotFound("Twisto")) {
        try command.execute(arguments: ["Twisto"])
    }
}

@Test func safariWindowOpenCommandWrapsProfileWindowOpenFailure() async throws {
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Twisto", identifier: "1")] },
        openWindow: { _, _ in throw SafariUserInterfaceError.profileWindowMenuItemNotFound("Twisto") }
    )

    #expect(throws: SafariWindowCommandError.profileMenuItemNotFound("Twisto")) {
        try command.execute(arguments: ["Twisto"])
    }
}

@Test func safariWindowOpenCommandFallsBackToMenuWhenProfileDatabaseIsUnavailable() async throws {
    var receivedProfileName: String?
    var windowLists = [
        [SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")],
        [
            SafariAppleScriptWindowRecord(identifier: 43, name: "Twisto"),
            SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")
        ]
    ]
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { throw SafariProfileCommandError.databaseOpenFailed(path: "/protected/SafariTabs.db") },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        listWindows: { _ in windowLists.removeFirst() }
    )

    #expect(try command.execute(arguments: ["Twisto"]) == "Safari window opened for profile Twisto.\nwindow-id|43")
    #expect(receivedProfileName == "Twisto")
}

@Test func safariWindowOpenCommandFormatsProfileLaunchMessage() async throws {
    var receivedProfileName: String?
    var windowLists = [
        [SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")],
        [
            SafariAppleScriptWindowRecord(identifier: 44, name: "Twisto"),
            SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")
        ]
    ]
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Twisto", identifier: "1")] },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        listWindows: { _ in windowLists.removeFirst() },
        listResolvedWindows: {
            [
                SafariWindowRecord(identifier: 44, index: 1, isPrivate: false, profileName: "Twisto", name: "Twisto"),
                SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Glutexo", name: "Existing")
            ]
        }
    )

    #expect(try command.execute(arguments: ["Twisto"]) == "Safari window opened for profile Twisto.\nwindow-id|44")
    #expect(receivedProfileName == "Twisto")
}

@Test func safariWindowOpenCommandFallsBackToExistingProfileWindowWhenMenuOpenDoesNotCreateWindow() async throws {
    var receivedProfileName: String?
    var focusedWindowIdentifiers: [Int] = []
    var didOpenNewDocument = false
    var resolvedWindowLists = [
        [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "Twisto", name: "Twisto — Existing work")],
        [
            SafariWindowRecord(identifier: 42, index: 1, isPrivate: false, profileName: "Twisto", name: "Twisto — Start Page"),
            SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", name: "Twisto — Existing work")
        ]
    ]
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Twisto", identifier: "1")] },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        listWindows: { _ in [SafariAppleScriptWindowRecord(identifier: 10, name: "Twisto — Existing work")] },
        listResolvedWindows: { resolvedWindowLists.removeFirst() },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifiers.append(windowIdentifier) },
        openNewDocument: { _ in didOpenNewDocument = true },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["Twisto"]) == "Safari window opened for profile Twisto.\nwindow-id|42")
    #expect(receivedProfileName == "Twisto")
    #expect(focusedWindowIdentifiers == [10])
    #expect(didOpenNewDocument)
}

@Test func safariWindowOpenCommandRejectsAndRollsBackWrongProfileWindow() async throws {
    var receivedProfileName: String?
    var closedWindowIdentifiers: [Int] = []
    var windowLists = [
        [SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")],
        [
            SafariAppleScriptWindowRecord(identifier: 45, name: "Twisto — Start Page"),
            SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")
        ],
        [
            SafariAppleScriptWindowRecord(identifier: 45, name: "Twisto — Start Page"),
            SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")
        ]
    ]
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Glutexo", identifier: "1")] },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        listWindows: { _ in
            if windowLists.count > 1 {
                return windowLists.removeFirst()
            }
            return windowLists[0]
        },
        listResolvedWindows: {
            [
                SafariWindowRecord(identifier: 45, index: 1, isPrivate: false, profileName: "Twisto", name: "Twisto — Start Page"),
                SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", name: "Existing")
            ]
        },
        closeWindow: { identifier, _ in closedWindowIdentifiers.append(identifier) }
    )

    #expect(
        throws: SafariWindowCommandError.openedWindowProfileMismatch(
            requestedProfileName: "Glutexo",
            observedWindowName: "Twisto — Start Page"
        )
    ) {
        try command.execute(arguments: ["Glutexo"])
    }
    #expect(receivedProfileName == "Glutexo")
    #expect(closedWindowIdentifiers == [45])
}

@Test func safariWindowOpenCommandRejectsMissingCreatedWindowIdentifier() async throws {
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        openWindow: { _, _ in },
        listWindows: { _ in [SafariAppleScriptWindowRecord(identifier: 10, name: "Existing")] }
    )

    #expect(throws: SafariWindowCommandError.openedWindowIdentifierNotFound) {
        try command.execute(arguments: [])
    }
}

@Test func safariWindowOpenPrivateCommandFormatsSuccessMessage() async throws {
    var didOpen = false
    let command = SafariWindowOpenPrivateCommand(
        executor: MockAppleScriptExecutor(),
        openPrivateWindow: { _ in didOpen = true }
    )

    #expect(try command.execute(arguments: []) == "Safari private window opened.")
    #expect(didOpen)
}

@Test func safariWindowOpenPrivateCommandWrapsUiFailure() async throws {
    let command = SafariWindowOpenPrivateCommand(
        executor: MockAppleScriptExecutor(),
        openPrivateWindow: { _ in throw SafariUserInterfaceError.privateWindowMenuItemNotFound }
    )

    #expect(throws: SafariWindowCommandError.privateWindowMenuItemNotFound) {
        try command.execute(arguments: [])
    }
}

@Test func safariWindowOpenTabGroupCommandOpensProfileWindowAndSelectsGroup() async throws {
    var receivedProfileName: String?
    var selectedTabGroup: SafariTabGroupRecord?
    let command = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        selectTabGroup: { tabGroup, _ in selectedTabGroup = tabGroup }
    )

    #expect(try command.execute(arguments: ["1000"]) == "Safari window opened for tab group Focus.")
    #expect(receivedProfileName == "Twisto")
    #expect(selectedTabGroup?.identifier == 1000)
    #expect(selectedTabGroup?.profileName == "Twisto")
    #expect(selectedTabGroup?.name == "Focus")
}

@Test func safariWindowOpenTabGroupCommandRejectsMissingOrInvalidTabGroupIdentifier() async throws {
    let command = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: { [] },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.missingTabGroupIdentifier) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariWindowCommandError.invalidTabGroupIdentifier("x")) {
        try command.execute(arguments: ["x"])
    }
}

@Test func safariWindowOpenTabGroupCommandRejectsUnknownOrAmbiguousTabGroup() async throws {
    let missingCommand = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: { [] },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.tabGroupNotFound(1000)) {
        try missingCommand.execute(arguments: ["1000"])
    }

    let ambiguousCommand = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [
                SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus"),
                SafariTabGroupRecord(identifier: 1001, profileName: "Twisto", name: "Focus")
            ]
        },
        openWindow: { _, _ in Issue.record("openWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.ambiguousTabGroupName(profileName: "Twisto", tabGroupName: "Focus")) {
        try ambiguousCommand.execute(arguments: ["1000"])
    }
}

@Test func safariWindowOpenTabGroupCommandWrapsProfileWindowOpenFailure() async throws {
    let command = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        openWindow: { _, _ in throw SafariUserInterfaceError.profileWindowMenuItemNotFound("Twisto") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.profileMenuItemNotFound("Twisto")) {
        try command.execute(arguments: ["1000"])
    }
}

@Test func safariWindowSetTabGroupCommandFocusesWindowAndSelectsGroup() async throws {
    var focusedWindowIdentifier: Int?
    var selectedTabGroup: SafariTabGroupRecord?
    let command = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifier = windowIdentifier },
        selectTabGroup: { tabGroup, _ in selectedTabGroup = tabGroup }
    )

    #expect(try command.execute(arguments: ["2", "1000"]) == "Safari window 2 switched to tab group Focus.")
    #expect(focusedWindowIdentifier == 10)
    #expect(selectedTabGroup?.identifier == 1000)
    #expect(selectedTabGroup?.profileName == "Twisto")
    #expect(selectedTabGroup?.name == "Focus")
}

@Test func safariWindowSetTabGroupCommandRejectsMissingOrInvalidArguments() async throws {
    let command = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { [] },
        listTabGroups: { [] },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariWindowCommandError.invalidWindowIndex("x")) {
        try command.execute(arguments: ["x", "1000"])
    }

    #expect(throws: SafariWindowCommandError.missingTabGroupIdentifier) {
        try command.execute(arguments: ["1"])
    }

    #expect(throws: SafariWindowCommandError.invalidTabGroupIdentifier("x")) {
        try command.execute(arguments: ["1", "x"])
    }
}

@Test func safariWindowSetTabGroupCommandRejectsPrivateWindowAndProfileMismatch() async throws {
    let privateWindowCommand = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: true, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Private")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.privateWindowTabGroupSelectionUnsupported(1)) {
        try privateWindowCommand.execute(arguments: ["1", "1000"])
    }

    let mismatchCommand = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        selectTabGroup: { _, _ in Issue.record("selectTabGroup should not be called") }
    )

    #expect(throws: SafariWindowCommandError.windowTabGroupProfileMismatch(windowProfileName: "Glutexo", tabGroupProfileName: "Twisto")) {
        try mismatchCommand.execute(arguments: ["1", "1000"])
    }
}

@Test func safariWindowSetTabGroupCommandAllowsUnknownWindowProfile() async throws {
    var focusedWindowIdentifier: Int?
    var selectedTabGroup: SafariTabGroupRecord?

    let command = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Focus — Start Page")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { windowIdentifier, _ in focusedWindowIdentifier = windowIdentifier },
        selectTabGroup: { tabGroup, _ in selectedTabGroup = tabGroup }
    )

    #expect(try command.execute(arguments: ["1", "1000"]) == "Safari window 1 switched to tab group Focus.")
    #expect(focusedWindowIdentifier == 10)
    #expect(selectedTabGroup?.identifier == 1000)
    #expect(selectedTabGroup?.profileName == "Twisto")
    #expect(selectedTabGroup?.name == "Focus")
}

@Test(arguments: [
    [],
    [SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page")],
    [
        SafariWindowRecord(identifier: 1, index: 1, isPrivate: false, profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page"),
        SafariWindowRecord(identifier: 2, index: 2, isPrivate: true, profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", name: "OpenAI")
    ]
])
func safariWindowListCommandFormatsWindowRows(windows: [SafariWindowRecord]) async throws {
    let command = SafariWindowListCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { _ in windows }
    )

    let output = try command.execute(arguments: [])
    let expected = windows.map { "\($0.index)|\($0.isPrivate)|\($0.profileName)|\($0.selectedTabGroupIdentifier.map(String.init) ?? "")|\($0.tabGroupName ?? "")|\($0.name)" }.joined(separator: "\n")
    #expect(output == expected)
}

@Test func safariWindowListCommandPropagatesListFailure() async throws {
    let command = SafariWindowListCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { _ in throw SafariWindowCommandError.queryPreparationFailed }
    )

    #expect(throws: SafariWindowCommandError.queryPreparationFailed) {
        try command.execute(arguments: [])
    }
}

@Test(arguments: [
    (false, "ignored", "Safari is not running."),
    (true, "Safari front window closed.", "Safari front window closed."),
    (true, "Safari has no open windows.", "Safari has no open windows.")
])
func safariWindowCloseCommandRespectsRunningState(input: (Bool, String, String)) async throws {
    let command = SafariWindowCloseCommand(
        executor: MockAppleScriptExecutor(),
        isRunning: { input.0 },
        closeFrontWindow: { _ in input.1 },
        closeWindowByIdentifier: { _, _ in Issue.record("closeWindowByIdentifier should not be called") }
    )

    #expect(try command.execute(arguments: []) == input.2)
}

@Test func safariWindowCloseCommandPropagatesCloseFailure() async throws {
    let command = SafariWindowCloseCommand(
        executor: MockAppleScriptExecutor(),
        isRunning: { true },
        closeFrontWindow: { _ in throw SafariAppleScriptError.scriptCompilationFailed },
        closeWindowByIdentifier: { _, _ in Issue.record("closeWindowByIdentifier should not be called") }
    )

    #expect(throws: SafariAppleScriptError.scriptCompilationFailed) {
        try command.execute(arguments: [])
    }
}

@Test func safariWindowCloseCommandTargetsWindowIdentifier() async throws {
    var closedWindowIdentifier: Int?
    let command = SafariWindowCloseCommand(
        executor: MockAppleScriptExecutor(),
        isRunning: { true },
        closeFrontWindow: { _ in
            Issue.record("closeFrontWindow should not be called")
            return "unexpected"
        },
        closeWindowByIdentifier: { windowIdentifier, _ in
            closedWindowIdentifier = windowIdentifier
        }
    )

    #expect(try command.execute(arguments: ["--window-id", "42"]) == "Safari window 42 closed.")
    #expect(closedWindowIdentifier == 42)
}

@Test func safariWindowCloseCommandRejectsInvalidWindowIdentifierArguments() async throws {
    let command = SafariWindowCloseCommand(
        executor: MockAppleScriptExecutor(),
        isRunning: { true },
        closeFrontWindow: { _ in
            Issue.record("closeFrontWindow should not be called")
            return "unexpected"
        },
        closeWindowByIdentifier: { _, _ in Issue.record("closeWindowByIdentifier should not be called") }
    )

    #expect(throws: SafariWindowCommandError.missingWindowIdentifier) {
        try command.execute(arguments: ["--window-id"])
    }
    #expect(throws: SafariWindowCommandError.invalidWindowIdentifier("0")) {
        try command.execute(arguments: ["--window-id=0"])
    }
    #expect(throws: CommandArgumentError.unexpectedArgument(commandName: "close-window", argument: "extra")) {
        try command.execute(arguments: ["extra"])
    }
}
