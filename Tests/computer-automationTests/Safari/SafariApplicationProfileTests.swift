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

@Test(arguments: [(true, "true"), (false, "false")])
func safariApplicationRunningCommandReflectsRunningState(input: (Bool, String)) async throws {
    let command = SafariApplicationRunningCommand(isRunning: { input.0 })
    #expect(try command.execute(arguments: []) == input.1)
}

@Test func safariApplicationLaunchCommandLaunchesResolvedApplicationURL() async throws {
    let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
    var openedURL: URL?
    let command = SafariApplicationLaunchCommand(
        applicationURLProvider: { safariURL },
        openApplication: { openedURL = $0 }
    )

    #expect(try command.execute(arguments: []) == "Safari launched.")
    #expect(openedURL == safariURL)
}

@Test func safariApplicationLaunchCommandRejectsMissingApplicationURL() async throws {
    let command = SafariApplicationLaunchCommand(
        applicationURLProvider: { nil },
        openApplication: { _ in Issue.record("openApplication should not be called") }
    )

    #expect(throws: SafariApplicationCommandError.applicationNotFound) {
        try command.execute(arguments: [])
    }
}

@Test func safariProfileListCommandPropagatesProfileLoadingFailure() async throws {
    let command = SafariProfileListCommand(
        listProfiles: { throw SafariProfileCommandError.queryPreparationFailed }
    )

    #expect(throws: SafariProfileCommandError.queryPreparationFailed) {
        try command.execute(arguments: [])
    }
}

@Test(arguments: [0, 1, 3])
func safariApplicationQuitCommandTerminatesEveryRunningApplication(applicationCount: Int) async throws {
    let applications = (0..<applicationCount).map { _ in FakeRunningApplication() }
    let command = SafariApplicationQuitCommand(
        runningApplicationsProvider: { applications }
    )

    let output = try command.execute(arguments: [])

    if applicationCount == 0 {
        #expect(output == "Safari is not running.")
    } else {
        #expect(output == "Safari quit requested.")
    }

    let terminatedCount = applications.filter(\.didTerminate).count
    #expect(terminatedCount == applicationCount)
}

@Test(arguments: [
    [SafariProfileRecord(name: "Glutexo", identifier: "1")],
    [
        SafariProfileRecord(name: "Glutexo", identifier: "1"),
        SafariProfileRecord(name: "Twisto", identifier: "2")
    ],
    []
])
func safariProfileListCommandFormatsProfileNames(profiles: [SafariProfileRecord]) async throws {
    let command = SafariProfileListCommand(listProfiles: { profiles })
    let output = try command.execute(arguments: [])
    #expect(output == profiles.map(\.name).joined(separator: "\n"))
}

@Test func safariProfileFindCommandFormatsMatchingRows() async throws {
    let command = SafariProfileFindCommand(
        findProfiles: { name in
            #expect(name == "Twisto")
            return [
                SafariProfileRecord(name: "Twisto", identifier: "33782F17-8AAD-41EA-BCB5-71A1A8348C55")
            ]
        }
    )

    #expect(
        try command.execute(arguments: ["Twisto"]) ==
        "33782F17-8AAD-41EA-BCB5-71A1A8348C55|Twisto"
    )
}

@Test func safariProfileFindCommandReturnsJSONMatches() async throws {
    let command = SafariProfileFindCommand(
        findProfiles: { _ in
            [
                SafariProfileRecord(name: "Twisto", identifier: "profile-1"),
                SafariProfileRecord(name: "Twisto", identifier: "profile-2")
            ]
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto"])
    let object = try jsonObject(output)
    let matches = try #require(object["matches"] as? [[String: Any]])

    #expect(object["name"] as? String == "Twisto")
    #expect(matches.count == 2)
    #expect(matches[0]["identifier"] as? String == "profile-1")
    #expect(matches[0]["name"] as? String == "Twisto")
}

@Test func safariProfileFindCommandRejectsInvalidArguments() async throws {
    let command = SafariProfileFindCommand(
        findProfiles: { _ in Issue.record("findProfiles should not be called"); return [] }
    )

    #expect(throws: SafariProfileCommandError.missingProfileName) {
        try command.execute(arguments: [])
    }
    #expect(throws: SafariProfileCommandError.emptyProfileName) {
        try command.execute(arguments: [""])
    }
    #expect(throws: SafariProfileCommandError.unexpectedArgument("extra")) {
        try command.execute(arguments: ["Twisto", "extra"])
    }
}

@Test func safariProfileResolveCommandFormatsSingleMatch() async throws {
    let command = SafariProfileResolveCommand(
        findProfiles: { name in
            #expect(name == "Twisto")
            return [
                SafariProfileRecord(name: "Twisto", identifier: "33782F17-8AAD-41EA-BCB5-71A1A8348C55")
            ]
        }
    )

    #expect(
        try command.execute(arguments: ["Twisto"]) ==
        "33782F17-8AAD-41EA-BCB5-71A1A8348C55|Twisto"
    )
}

@Test func safariProfileResolveCommandReturnsJSONMatch() async throws {
    let command = SafariProfileResolveCommand(
        findProfiles: { _ in
            [SafariProfileRecord(name: "Twisto", identifier: "profile-1")]
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto"])
    let object = try jsonObject(output)
    let match = try #require(object["match"] as? [String: Any])

    #expect(object["name"] as? String == "Twisto")
    #expect(match["identifier"] as? String == "profile-1")
    #expect(match["name"] as? String == "Twisto")
}

@Test func safariProfileResolveCommandRequiresExactlyOneMatch() async throws {
    let noMatches = SafariProfileResolveCommand(findProfiles: { _ in [] })
    #expect(throws: SafariProfileCommandError.profileLookupNotFound(name: "Twisto")) {
        try noMatches.execute(arguments: ["Twisto"])
    }

    let multipleMatches = SafariProfileResolveCommand(
        findProfiles: { _ in
            [
                SafariProfileRecord(name: "Twisto", identifier: "profile-1"),
                SafariProfileRecord(name: "Twisto", identifier: "profile-2")
            ]
        }
    )
    #expect(throws: SafariProfileCommandError.profileLookupAmbiguous(name: "Twisto", count: 2)) {
        try multipleMatches.execute(arguments: ["Twisto"])
    }
}

@Test func safariProfileFindMatchesNameExactly() async throws {
    let profiles = try SafariProfile.find(
        name: "Twisto",
        listProfiles: {
            [
                SafariProfileRecord(name: "Twisto", identifier: "profile-1"),
                SafariProfileRecord(name: "Twisto later", identifier: "profile-2"),
                SafariProfileRecord(name: "Glutexo", identifier: "profile-3")
            ]
        }
    )

    #expect(profiles == [SafariProfileRecord(name: "Twisto", identifier: "profile-1")])
}
