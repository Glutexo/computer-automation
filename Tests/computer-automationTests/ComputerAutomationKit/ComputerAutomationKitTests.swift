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

@Test func concreteCommandDescriptorsExposeExpectedArgumentMetadata() async throws {
    let windowOpen = SafariWindowOpenCommand.descriptor.arguments
    #expect(windowOpen.count == 1)
    #expect(windowOpen[0].name == "profile")
    #expect(windowOpen[0].kind == .positional)
    #expect(!windowOpen[0].isRequired)
    #expect(windowOpen[0].completionSuggestions.isEmpty)

    let openTabGroupWindow = SafariWindowOpenTabGroupCommand.descriptor.arguments
    #expect(openTabGroupWindow.count == 1)
    #expect(openTabGroupWindow[0].name == "tab-group-identifier")
    #expect(openTabGroupWindow[0].kind == .positional)
    #expect(openTabGroupWindow[0].isRequired)

    let setWindowTabGroup = SafariWindowSetTabGroupCommand.descriptor.arguments
    #expect(setWindowTabGroup.count == 2)
    #expect(setWindowTabGroup[0].name == "window-index")
    #expect(setWindowTabGroup[1].name == "tab-group-identifier")

    let createTabGroup = SafariTabGroupCreateCommand.descriptor.arguments
    #expect(createTabGroup.count == 2)
    #expect(createTabGroup[0].name == "window-index")
    #expect(createTabGroup[1].name == "name")

    let ensureTabGroup = SafariTabGroupEnsureCommand.descriptor.arguments
    #expect(ensureTabGroup == SafariTabGroupFindCommand.descriptor.arguments)

    let findProfile = SafariProfileFindCommand.descriptor.arguments
    #expect(findProfile.count == 1)
    #expect(findProfile[0].name == "name")
    #expect(findProfile[0].kind == .positional)
    #expect(findProfile[0].isRequired)

    let resolveProfile = SafariProfileResolveCommand.descriptor.arguments
    #expect(resolveProfile == findProfile)

    let findTabGroup = SafariTabGroupFindCommand.descriptor.arguments
    #expect(findTabGroup.count == 2)
    #expect(findTabGroup[0].name == "profile")
    #expect(findTabGroup[0].kind == .positional)
    #expect(findTabGroup[0].isRequired)
    #expect(findTabGroup[1].name == "name")
    #expect(findTabGroup[1].kind == .positional)
    #expect(findTabGroup[1].isRequired)

    let resolveTabGroup = SafariTabGroupResolveCommand.descriptor.arguments
    #expect(resolveTabGroup == findTabGroup)

    let menuItems = SafariMenuListItemsCommand.descriptor.arguments
    #expect(menuItems.count == 1)
    #expect(menuItems[0].name == "menu-bar-item-index")
    #expect(menuItems[0].kind == .positional)
    #expect(menuItems[0].isRequired)
    #expect(menuItems[0].completionSuggestions.isEmpty)

    let childItems = SafariMenuItemListChildItemsCommand.descriptor.arguments
    #expect(childItems.count == 2)
    #expect(childItems[0].name == "menu-bar-item-index")
    #expect(childItems[0].kind == .positional)
    #expect(childItems[0].isRequired)
    #expect(childItems[1].name == "menu-item-index")
    #expect(childItems[1].kind == .positional)
    #expect(childItems[1].isRequired)
    #expect(childItems[1].completionSuggestions.isEmpty)

    let tabOpen = SafariTabOpenCommand.descriptor.arguments
    #expect(tabOpen.count == 3)
    #expect(tabOpen[0].name == "window-index")
    #expect(tabOpen[0].kind == .positional)
    #expect(tabOpen[0].isRequired)
    #expect(tabOpen[1].name == "window-id")
    #expect(tabOpen[1].kind == .option)
    #expect(!tabOpen[1].isRequired)
    #expect(tabOpen[1].valueName == "window-id")
    #expect(tabOpen[2].name == "url")
    #expect(tabOpen[2].kind == .positional)
    #expect(!tabOpen[2].isRequired)

    let setTabURL = SafariTabSetURLCommand.descriptor.arguments
    #expect(setTabURL.count == 4)
    #expect(setTabURL[0].name == "window-index")
    #expect(setTabURL[1].name == "window-id")
    #expect(setTabURL[1].kind == .option)
    #expect(setTabURL[2].name == "tab-index")
    #expect(setTabURL[3].name == "url")

    let findTab = SafariTabFindCommand.descriptor.arguments
    #expect(findTab.count == 5)
    #expect(findTab[0].name == "url")
    #expect(findTab[0].kind == .positional)
    #expect(findTab[0].isRequired)
    #expect(findTab[1].name == "prefix")
    #expect(findTab[1].kind == .option)
    #expect(!findTab[1].isRequired)
    #expect(findTab[2].name == "window-id")
    #expect(findTab[3].name == "window-index")
    #expect(findTab[4].name == "profile")
    #expect(findTab[2].valueName == "window-id")
    #expect(findTab[3].valueName == "window-index")
    #expect(findTab[4].valueName == "profile")

    let resolveTab = SafariTabResolveCommand.descriptor.arguments
    #expect(resolveTab == findTab)

    let executeJavaScript = SafariTabExecuteJavaScriptCommand.descriptor.arguments
    #expect(executeJavaScript.count == 5)
    #expect(executeJavaScript[0].name == "window-id")
    #expect(executeJavaScript[1].name == "tab-index")
    #expect(executeJavaScript[2].name == "javascript")
    #expect(!executeJavaScript[2].isRequired)
    #expect(executeJavaScript[3].name == "stdin")
    #expect(executeJavaScript[3].kind == .option)
    #expect(!executeJavaScript[3].isRequired)
    #expect(executeJavaScript[4].name == "file")
    #expect(executeJavaScript[4].kind == .option)
    #expect(!executeJavaScript[4].isRequired)
    #expect(executeJavaScript[4].valueName == "path")

    let closeTab = SafariTabCloseCommand.descriptor.arguments
    #expect(closeTab.count == 3)
    #expect(closeTab[0].name == "window-index")
    #expect(closeTab[1].name == "window-id")
    #expect(closeTab[1].kind == .option)
    #expect(closeTab[2].name == "tab-index")

    let windowTabs = SafariTabListWindowTabsCommand.descriptor.arguments
    #expect(windowTabs.count == 2)
    #expect(windowTabs[0].name == "window-index")
    #expect(windowTabs[0].kind == .positional)
    #expect(windowTabs[0].isRequired)
    #expect(windowTabs[1].name == "window-id")
    #expect(windowTabs[1].kind == .option)
    #expect(!windowTabs[1].isRequired)
    #expect(windowTabs[1].valueName == "window-id")

    let closeWindow = SafariWindowCloseCommand.descriptor.arguments
    #expect(closeWindow.count == 1)
    #expect(closeWindow[0].name == "window-id")
    #expect(closeWindow[0].kind == .option)
    #expect(!closeWindow[0].isRequired)
    #expect(closeWindow[0].valueName == "window-id")

    let ensureTabListURLs = SafariTabListEnsureURLsCommand.descriptor.arguments
    #expect(ensureTabListURLs.count == 5)
    #expect(ensureTabListURLs[0].name == "window-index")
    #expect(ensureTabListURLs[0].kind == .option)
    #expect(!ensureTabListURLs[0].isRequired)
    #expect(ensureTabListURLs[1].name == "window-id")
    #expect(ensureTabListURLs[1].kind == .option)
    #expect(!ensureTabListURLs[1].isRequired)
    #expect(ensureTabListURLs[2].name == "tab-group-profile")
    #expect(ensureTabListURLs[2].kind == .option)
    #expect(!ensureTabListURLs[2].isRequired)
    #expect(ensureTabListURLs[3].name == "tab-group-name")
    #expect(ensureTabListURLs[3].kind == .option)
    #expect(!ensureTabListURLs[3].isRequired)
    #expect(ensureTabListURLs[4].name == "url")
    #expect(ensureTabListURLs[4].kind == .positional)
    #expect(ensureTabListURLs[4].isRequired)
    #expect(ensureTabListURLs[4].isRepeating)

    let reorderTabListURLs = SafariTabListReorderURLsCommand.descriptor.arguments
    #expect(reorderTabListURLs == ensureTabListURLs)

    let tabGroupTabs = SafariTabListTabGroupTabsCommand.descriptor.arguments
    #expect(tabGroupTabs.count == 1)
    #expect(tabGroupTabs[0].name == "tab-group-identifier")
    #expect(tabGroupTabs[0].kind == .positional)
    #expect(tabGroupTabs[0].isRequired)

    let deleteTabGroup = SafariTabGroupDeleteCommand.descriptor.arguments
    #expect(deleteTabGroup.count == 3)
    #expect(deleteTabGroup[0].name == "tab-group-identifier")
    #expect(!deleteTabGroup[0].isRequired)
    #expect(deleteTabGroup[1].name == "profile")
    #expect(deleteTabGroup[1].kind == .option)
    #expect(deleteTabGroup[1].valueName == "profile")
    #expect(deleteTabGroup[2].name == "name")
    #expect(deleteTabGroup[2].kind == .option)
    #expect(deleteTabGroup[2].valueName == "name")
}

@Test func cliRejectsMissingModule() async throws {
    #expect(throws: CLIError.missingModule) {
        try ComputerAutomationCLI.run(arguments: [])
    }
}

@Test func cliRejectsUnknownModule() async throws {
    #expect(throws: CLIError.unknownModule("unknown")) {
        try ComputerAutomationCLI.run(arguments: ["unknown"])
    }
}

@Test(arguments: ["safari", "safari-ui"])
func cliRejectsMissingCommand(module: String) async throws {
    #expect(throws: CLIError.missingCommand(moduleName: module)) {
        try ComputerAutomationCLI.run(arguments: [module])
    }
}

@Test(arguments: ["--completion-script", "--install-completion"])
func cliRejectsMissingShellName(flag: String) async throws {
    #expect(throws: CLIError.missingShellName) {
        try ComputerAutomationCLI.run(arguments: [flag])
    }
}

@Test(arguments: ["--completion-script", "--install-completion"])
func cliRejectsUnsupportedShell(flag: String) async throws {
    #expect(throws: CLIError.unsupportedShell("fish")) {
        try ComputerAutomationCLI.run(arguments: [flag, "fish"])
    }
}

@Test func cliReturnsTopLevelCompletionSuggestions() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--complete"])
    #expect(output.contains("safari"))
    #expect(output.contains("safari-ui"))
}

@Test func cliReturnsModuleCompletionSuggestions() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--complete", "safari"])
    #expect(output.contains("open-window"))
    #expect(output.contains("find-profile"))
    #expect(output.contains("resolve-profile"))
    #expect(output.contains("open-private-window"))
    #expect(output.contains("ensure-tab-group"))
    #expect(output.contains("tab-groups"))
    #expect(output.contains("find-tab-group"))
    #expect(output.contains("resolve-tab-group"))
    #expect(output.contains("tab-group-tabs"))
    #expect(output.contains("open-tab"))
    #expect(output.contains("tabs"))
    #expect(output.contains("find-tab"))
    #expect(output.contains("resolve-tab"))
    #expect(output.contains("window-tabs"))
    #expect(output.contains("set-tab-url"))
    #expect(output.contains("close-tab"))
}

@Test func cliRendersTopLevelHelp() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--help"])

    #expect(output.contains("Usage: computer-automation <module> <command> [arguments]"))
    #expect(output.contains("safari\tAutomation commands for Safari."))
    #expect(output.contains("safari-ui\tSafari user interface automation models."))
}

@Test func cliRendersModuleHelp() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["safari", "--help"])

    #expect(output.contains("Usage: computer-automation safari <command> [arguments]"))
    #expect(output.contains("ensure-tab-list-urls\tEnsure requested URLs exist in a Safari tab list."))
    #expect(output.contains("open-tab-group-window\tOpen a new Safari window for a saved tab group."))
}

@Test func cliRendersZshCompletionScript() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--completion-script", "zsh"])
    #expect(output.contains("#compdef computer-automation"))
    #expect(output.contains("computer-automation --complete"))
}

@Test func cliDispatchesSafariRunningCommand() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["safari", "running"])
    #expect(output == "true" || output == "false")
}

@Test func cliDispatchesSafariCommandInJSONMode() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--json", "safari", "running"])
    let object = try jsonObject(output)

    #expect(object["running"] is Bool)
}

@Test func cliRendersCommandHelpBeforeDispatch() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["safari", "close-window", "--help"])

    #expect(output.contains("Usage: computer-automation safari close-window"))
    #expect(output.contains("Close a Safari browser window."))
}

@Test(arguments: [
    (
        ["safari", "open-tab", "--help"],
        "Usage: computer-automation safari open-tab (--window-id <window-id> | <window-index>) [<url>]"
    ),
    (
        ["safari", "window-tabs", "--help"],
        "Usage: computer-automation safari window-tabs (--window-id <window-id> | <window-index>)"
    ),
    (
        ["safari", "ensure-tab-list-urls", "--help"],
        "Usage: computer-automation safari ensure-tab-list-urls (--window-index <window-index> | --window-id <window-id> | --tab-group-profile <profile> --tab-group-name <name>) <url>..."
    ),
    (
        ["safari", "find-tab", "--help"],
        "Usage: computer-automation safari find-tab <url> [--prefix] [--window-id <window-id>] [--window-index <window-index>] [--profile <profile>]"
    ),
    (
        ["safari", "execute-tab-javascript", "--help"],
        "Usage: computer-automation safari execute-tab-javascript <window-id> <tab-index> (<javascript> | --stdin | --file <path>)"
    ),
    (
        ["safari", "delete-tab-group", "--help"],
        "Usage: computer-automation safari delete-tab-group (<tab-group-identifier> | --profile <profile> --name <name>)"
    )
])
func cliRendersSafariCommandUsageWithValuesAndAlternatives(
    input: ([String], String)
) async throws {
    let output = try ComputerAutomationCLI.run(arguments: input.0)

    #expect(output.contains(input.1))
}

@Test func cliRejectsUnknownCommandOptionBeforeDispatch() async throws {
    #expect(throws: CommandArgumentError.unknownOption(commandName: "close-window", option: "--bogus")) {
        try ComputerAutomationCLI.run(arguments: ["safari", "close-window", "--bogus"])
    }
}

@Test func cliRejectsUnexpectedArgumentForCommandWithoutArgumentsBeforeDispatch() async throws {
    #expect(throws: CommandArgumentError.unexpectedArgument(commandName: "close-window", argument: "extra")) {
        try ComputerAutomationCLI.run(arguments: ["safari", "close-window", "extra"])
    }
}

@Test func cliSurfacesUnknownSafariUiCommand() async throws {
    #expect(throws: CLIError.unknownCommand(moduleName: "safari-ui", commandName: "unknown")) {
        try ComputerAutomationCLI.run(arguments: ["safari-ui", "unknown"])
    }
}

@Test func safariModuleRejectsUnknownCommand() async throws {
    #expect(throws: CLIError.unknownCommand(moduleName: "safari", commandName: "unknown")) {
        try SafariModule.execute(commandName: "unknown", arguments: [])
    }
}

@Test func safariUserInterfaceModuleRejectsUnknownCommand() async throws {
    #expect(throws: CLIError.unknownCommand(moduleName: "safari-ui", commandName: "unknown")) {
        try SafariUserInterfaceModule.execute(commandName: "unknown", arguments: [])
    }
}

@Test func safariAppleScriptModuleRejectsUnknownCommand() async throws {
    #expect(throws: CLIError.unknownCommand(moduleName: "safari-applescript", commandName: "unknown")) {
        try SafariAppleScriptModule.execute(commandName: "unknown", arguments: [])
    }
}
