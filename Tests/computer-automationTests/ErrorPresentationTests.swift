import Foundation
import Testing
@testable import AutomationFoundation
@testable import ComputerAutomationKit
@testable import Safari
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import SafariUserInterface

private func expectHumanReadable(_ error: Error) {
    let description = (error as? LocalizedError)?.errorDescription?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(description?.isEmpty == false)
}

@Test(arguments: [
    CLIError.missingModule,
    .missingCommand(moduleName: "safari"),
    .unknownModule("unknown"),
    .unknownCommand(moduleName: "safari", commandName: "unknown"),
    .missingShellName,
    .missingHomeDirectory,
    .unsupportedShell("fish")
])
func cliErrorsHaveHumanReadableDescriptions(error: CLIError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    CommandArgumentError.unknownOption(commandName: "tabs", option: "--unknown"),
    .unexpectedArgument(commandName: "tabs", argument: "extra")
])
func commandArgumentErrorsHaveHumanReadableDescriptions(error: CommandArgumentError) {
    expectHumanReadable(error)
}

@Test(arguments: [SafariApplicationCommandError.applicationNotFound])
func safariApplicationErrorsHaveHumanReadableDescriptions(error: SafariApplicationCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariProfileCommandError.databaseOpenFailed(path: "/tmp/SafariTabs.db"),
    .queryPreparationFailed,
    .queryExecutionFailed,
    .missingProfileName,
    .emptyProfileName,
    .profileLookupNotFound(name: "Twisto"),
    .profileLookupAmbiguous(name: "Twisto", count: 2),
    .unexpectedArgument("extra")
])
func safariProfileErrorsHaveHumanReadableDescriptions(error: SafariProfileCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariWindowCommandError.databaseOpenFailed(path: "/tmp/SafariTabs.db"),
    .queryPreparationFailed,
    .queryExecutionFailed,
    .profileNotFound("Twisto"),
    .profileMenuItemNotFound("Twisto"),
    .privateWindowMenuItemNotFound,
    .missingWindowIndex,
    .missingWindowIdentifier,
    .invalidWindowIndex("x"),
    .invalidWindowIdentifier("x"),
    .missingTabGroupIdentifier,
    .invalidTabGroupIdentifier("x"),
    .tabGroupNotFound(1000),
    .ambiguousTabGroupName(profileName: "Twisto", tabGroupName: "Focus"),
    .privateWindowTabGroupSelectionUnsupported(1),
    .windowTabGroupProfileMismatch(windowProfileName: "A", tabGroupProfileName: "B"),
    .openedWindowIdentifierNotFound,
    .openedWindowProfileMismatch(requestedProfileName: "A", observedWindowName: "B"),
    .openedPrivateWindowStateMismatch(42),
    .tabGroupSelectionNotVerified(windowIdentifier: 42, tabGroupIdentifier: 1000)
])
func safariWindowErrorsHaveHumanReadableDescriptions(error: SafariWindowCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariTabGroupCommandError.databaseOpenFailed(path: "/tmp/SafariTabs.db"),
    .queryPreparationFailed,
    .queryExecutionFailed,
    .missingProfileName,
    .emptyProfileName,
    .missingWindowIndex,
    .invalidWindowIndex("x"),
    .missingTabGroupIdentifier,
    .invalidTabGroupIdentifier("x"),
    .missingTabGroupName,
    .emptyTabGroupName,
    .tabGroupNotFound(1000),
    .tabGroupLookupNotFound(profileName: "Twisto", tabGroupName: "Focus"),
    .tabGroupLookupAmbiguous(profileName: "Twisto", tabGroupName: "Focus", count: 2),
    .ambiguousTabGroupName(profileName: "Twisto", tabGroupName: "Focus"),
    .duplicateTabGroupName(profileName: "Twisto", tabGroupName: "Focus"),
    .privateWindowTabGroupMutationUnsupported(1),
    .createdTabGroupNotFound(profileName: "Twisto"),
    .createdTabGroupProfileMismatch(requestedProfileName: "A", createdProfileName: "B"),
    .tabGroupRenameNotVerified(identifier: 1000, expectedName: "Renamed"),
    .tabGroupDeletionNotVerified(1000),
    .windowForProfileNotFound("Twisto"),
    .sidebarUnavailable,
    .sidebarTabGroupNotFound("Focus"),
    .sidebarTabGroupIdentifierUnavailable(profileName: "Twisto", tabGroupName: "Focus"),
    .sidebarSelectedItemRenameUnavailable,
    .unexpectedArgument("extra")
])
func safariTabGroupErrorsHaveHumanReadableDescriptions(error: SafariTabGroupCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariTabCommandError.missingWindowIndex,
    .missingWindowIdentifier,
    .invalidWindowIndex("x"),
    .invalidWindowIdentifier("x"),
    .missingTabAddress,
    .invalidTabAddress("x", "y"),
    .missingURL,
    .missingJavaScript,
    .multipleJavaScriptSources,
    .javaScriptFileReadFailed("script.js"),
    .resolveNoMatch("https://example.com"),
    .resolveAmbiguous("https://example.com", 2),
    .javaScriptTargetWindowNotFound(42),
    .javaScriptTargetTabNotFound(windowIdentifier: 42, tabIndex: 2),
    .javaScriptResultUnsupported(windowIdentifier: 42, tabIndex: 2),
    .javaScriptExecutionFailed(windowIdentifier: 42, tabIndex: 2),
    .unknownOption("--unknown"),
    .missingOptionValue("--file"),
    .unexpectedArgument("extra")
])
func safariTabErrorsHaveHumanReadableDescriptions(error: SafariTabCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariTabListCommandError.missingContext,
    .multipleContexts,
    .missingTabGroupProfile,
    .emptyTabGroupProfile,
    .missingTabGroupName,
    .emptyTabGroupName,
    .missingURL,
    .emptyURL,
    .savedTabGroupSelectionNotLoaded(1000),
    .savedTabGroupOrderPersistenceNotVerified(1000),
    .unknownOption("--unknown"),
    .missingOptionValue("--window-id")
])
func safariTabListErrorsHaveHumanReadableDescriptions(error: SafariTabListCommandError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariUserInterfaceError.profileWindowMenuItemNotFound("Twisto"),
    .privateWindowMenuItemNotFound,
    .focusedWindowUnavailable,
    .windowListUnavailable,
    .windowCloseButtonUnavailable,
    .windowCloseNotVerified,
    .sidebarUnavailable,
    .sidebarTabGroupNotFound("Focus"),
    .sidebarSelectedItemRenameUnavailable,
    .menuItemDisabled("NewTabGroupWithTabsMenuItem"),
    .missingMenuAddress,
    .invalidMenuAddress("x"),
    .menuUnavailable(menuBarItemIndex: 3),
    .missingMenuItemAddress,
    .invalidMenuItemAddress("x", "y"),
    .menuItemChildrenUnavailable(menuBarItemIndex: 3, menuItemIndex: 27)
])
func safariUserInterfaceErrorsHaveHumanReadableDescriptions(error: SafariUserInterfaceError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariAppleScriptError.scriptCompilationFailed,
    .requestTimedOut(processIdentifier: 4317),
    .executionFailed("sensitive transport detail")
])
func safariAppleScriptErrorsHaveHumanReadableDescriptions(error: SafariAppleScriptError) {
    expectHumanReadable(error)
    #expect(!error.localizedDescription.contains("sensitive transport detail"))
}

@Test(arguments: [
    SafariAppleScriptTabJavaScriptError.windowNotFound(42),
    .tabNotFound(windowIdentifier: 42, tabIndex: 2),
    .unsupportedResult(windowIdentifier: 42, tabIndex: 2),
    .executionFailed(windowIdentifier: 42, tabIndex: 2)
])
func safariAppleScriptJavaScriptErrorsHaveHumanReadableDescriptions(error: SafariAppleScriptTabJavaScriptError) {
    expectHumanReadable(error)
}

@Test(arguments: [
    SafariDatabaseError.openFailed(path: "/tmp/SafariTabs.db"),
    .queryPreparationFailed(modelName: "window"),
    .queryExecutionFailed(modelName: "window")
])
func safariDatabaseErrorsHaveHumanReadableDescriptions(error: SafariDatabaseError) {
    expectHumanReadable(error)
}

@Test func cliErrorRendererNeverFallsBackToRawErrorDescriptions() {
    struct UnknownError: Error {}

    #expect(ComputerAutomationErrorRenderer.message(for: UnknownError()) == "An unexpected error occurred.")
    #expect(
        ComputerAutomationErrorRenderer.message(for: SafariUserInterfaceError.sidebarUnavailable) ==
        SafariUserInterfaceError.sidebarUnavailable.localizedDescription
    )
}
