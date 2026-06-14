import Testing
import Foundation
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

@Test func safariDatabaseModuleExposesDatabaseEntityMetadata() async throws {
    #expect(SafariDatabaseModule.descriptor.name == "safari-database")
    #expect(
        SafariDatabaseModule.descriptor.models ==
        [
            SafariDatabaseProfile.descriptor,
            SafariDatabaseWindow.descriptor,
            SafariDatabaseTabGroup.descriptor
        ]
    )
    #expect(SafariDatabaseProfile.descriptor.name == "profile")
    #expect(SafariDatabaseWindow.descriptor.name == "window")
    #expect(SafariDatabaseTabGroup.descriptor.name == "tab-group")
}

@Test func safariModuleExposesApplicationModelMetadata() async throws {
    #expect(SafariModule.descriptor.name == "safari")
    #expect(
        SafariModule.descriptor.models ==
        [
            SafariApplication.descriptor,
            SafariProfile.descriptor,
            SafariWindow.descriptor,
            SafariTabGroup.descriptor,
            SafariTabList.descriptor,
            SafariTab.descriptor
        ]
    )
    #expect(SafariApplication.descriptor.name == "application")
    #expect(SafariApplication.bundleIdentifier == "com.apple.Safari")
    #expect(
        SafariApplication.descriptor.commands ==
        [
            SafariApplicationLaunchCommand.descriptor,
            SafariApplicationRunningCommand.descriptor,
            SafariApplicationQuitCommand.descriptor
        ]
    )
    #expect(SafariApplicationLaunchCommand.descriptor.operation == .create)
    #expect(SafariApplicationRunningCommand.descriptor.operation == .read)
    #expect(SafariApplicationQuitCommand.descriptor.operation == .delete)
    #expect(SafariProfile.descriptor.name == "profile")
    #expect(
        SafariProfile.descriptor.commands ==
        [
            SafariProfileListCommand.descriptor,
            SafariProfileFindCommand.descriptor,
            SafariProfileResolveCommand.descriptor
        ]
    )
    #expect(SafariProfileListCommand.descriptor.operation == .read)
    #expect(SafariProfileFindCommand.descriptor.operation == .read)
    #expect(SafariProfileResolveCommand.descriptor.operation == .read)
    #expect(SafariWindow.descriptor.name == "window")
    #expect(
        SafariWindow.descriptor.commands ==
        [
            SafariWindowOpenCommand.descriptor,
            SafariWindowOpenPrivateCommand.descriptor,
            SafariWindowOpenTabGroupCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowSetTabGroupCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )
    #expect(SafariWindowOpenCommand.descriptor.operation == .create)
    #expect(SafariWindowOpenPrivateCommand.descriptor.operation == .create)
    #expect(SafariWindowOpenCommand.descriptor.arguments.count == 1)
    #expect(SafariWindowOpenCommand.descriptor.arguments[0].name == "profile")
    #expect(!SafariWindowOpenCommand.descriptor.arguments[0].isRequired)
    #expect(SafariWindowListCommand.descriptor.operation == .read)
    #expect(SafariWindowCloseCommand.descriptor.operation == .delete)
    #expect(SafariTabGroup.descriptor.name == "tab-group")
    #expect(
        SafariTabGroup.descriptor.commands ==
        [
            SafariTabGroupCreateCommand.descriptor,
            SafariTabGroupEnsureCommand.descriptor,
            SafariTabGroupListCommand.descriptor,
            SafariTabGroupFindCommand.descriptor,
            SafariTabGroupResolveCommand.descriptor,
            SafariTabGroupDeleteCommand.descriptor
        ]
    )
    #expect(SafariTabGroupCreateCommand.descriptor.operation == .create)
    #expect(SafariTabGroupEnsureCommand.descriptor.operation == .create)
    #expect(SafariTabGroupListCommand.descriptor.operation == .read)
    #expect(SafariTabGroupDeleteCommand.descriptor.operation == .delete)
    #expect(SafariTabList.descriptor.name == "tab-list")
    #expect(
        SafariTabList.descriptor.commands ==
        [
            SafariTabListTabGroupTabsCommand.descriptor,
            SafariTabListWindowTabsCommand.descriptor
        ]
    )
    #expect(SafariTabListTabGroupTabsCommand.descriptor.operation == .read)
    #expect(SafariTabListWindowTabsCommand.descriptor.operation == .read)
    #expect(SafariTab.descriptor.name == "tab")
    #expect(
        SafariTab.descriptor.commands ==
        [
            SafariTabOpenCommand.descriptor,
            SafariTabListCommand.descriptor,
            SafariTabFindCommand.descriptor,
            SafariTabResolveCommand.descriptor,
            SafariTabExecuteJavaScriptCommand.descriptor,
            SafariTabSetURLCommand.descriptor,
            SafariTabCloseCommand.descriptor
        ]
    )
    #expect(SafariTabOpenCommand.descriptor.operation == .create)
    #expect(SafariTabListCommand.descriptor.operation == .read)
    #expect(SafariTabSetURLCommand.descriptor.operation == .update)
    #expect(SafariTabCloseCommand.descriptor.operation == .delete)
    #expect(SafariUserInterfaceModule.descriptor.models == [
        SafariApplicationMenuBar.descriptor,
        SafariSidebar.descriptor,
        SafariToolbar.descriptor,
        SafariToolbarItem.descriptor,
        SafariMenu.descriptor,
        SafariFileMenu.descriptor,
        SafariMenuItem.descriptor
    ])
    #expect(SafariApplicationMenuBar.descriptor.commands == [SafariApplicationMenuBarListCommand.descriptor])
    #expect(SafariApplicationMenuBarListCommand.descriptor.operation == .read)
    #expect(SafariSidebar.descriptor.commands.isEmpty)
    #expect(SafariToolbar.descriptor.commands.isEmpty)
    #expect(SafariToolbarItem.descriptor.commands.isEmpty)
    #expect(SafariMenu.descriptor.commands == [SafariMenuListItemsCommand.descriptor])
    #expect(SafariMenuListItemsCommand.descriptor.operation == .read)
    #expect(SafariMenuListItemsCommand.descriptor.arguments.count == 1)
    #expect(SafariFileMenu.descriptor.commands == [SafariFileMenuListCommand.descriptor])
    #expect(SafariFileMenuListCommand.descriptor.operation == .read)
    #expect(SafariMenuItem.descriptor.commands == [SafariMenuItemListChildItemsCommand.descriptor])
    #expect(SafariMenuItemListChildItemsCommand.descriptor.operation == .read)
    #expect(SafariMenuItemListChildItemsCommand.descriptor.arguments.count == 2)
    #expect(SafariAppleScriptModule.descriptor.models == [
        SafariAppleScriptApplication.descriptor,
        SafariAppleScriptWindow.descriptor,
        SafariAppleScriptTab.descriptor,
        SafariAppleScriptSidebar.descriptor,
        SafariAppleScriptApplicationMenuBar.descriptor,
        SafariAppleScriptToolbar.descriptor,
        SafariAppleScriptToolbarItem.descriptor,
        SafariAppleScriptMenu.descriptor,
        SafariAppleScriptMenuItem.descriptor
    ])
}

@Test func completionEngineSuggestsModulesAndCommands() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: [], modules: modules) ==
        [
            CompletionSuggestion(value: "safari", abstract: "Automation commands for Safari."),
            CompletionSuggestion(value: "safari-ui", abstract: "Safari user interface automation models.")
        ]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari"], modules: modules) ==
        [
            CompletionSuggestion(value: "launch", abstract: "Launch Safari."),
            CompletionSuggestion(value: "running", abstract: "Report whether Safari is currently running."),
            CompletionSuggestion(value: "quit", abstract: "Quit Safari if it is running."),
            CompletionSuggestion(value: "profiles", abstract: "List available Safari profiles."),
            CompletionSuggestion(value: "find-profile", abstract: "Find Safari profiles by name."),
            CompletionSuggestion(value: "resolve-profile", abstract: "Resolve exactly one Safari profile by name."),
            CompletionSuggestion(value: "open-window", abstract: "Open a new Safari browser window."),
            CompletionSuggestion(value: "open-private-window", abstract: "Open a new private Safari browser window."),
            CompletionSuggestion(value: "open-tab-group-window", abstract: "Open a new Safari window for a saved tab group."),
            CompletionSuggestion(value: "windows", abstract: "List open Safari browser windows."),
            CompletionSuggestion(value: "set-window-tab-group", abstract: "Switch a Safari window to a saved tab group."),
            CompletionSuggestion(value: "close-window", abstract: "Close the front Safari browser window."),
            CompletionSuggestion(value: "create-tab-group", abstract: "Create a new saved Safari tab group in a specific window."),
            CompletionSuggestion(value: "ensure-tab-group", abstract: "Create or reuse a saved Safari tab group by profile and name."),
            CompletionSuggestion(value: "tab-groups", abstract: "List saved Safari tab groups."),
            CompletionSuggestion(value: "find-tab-group", abstract: "Find saved Safari tab groups by profile and name."),
            CompletionSuggestion(value: "resolve-tab-group", abstract: "Resolve exactly one saved Safari tab group by profile and name."),
            CompletionSuggestion(value: "delete-tab-group", abstract: "Delete a saved Safari tab group."),
            CompletionSuggestion(value: "tab-group-tabs", abstract: "List tabs stored in a saved Safari tab group."),
            CompletionSuggestion(value: "window-tabs", abstract: "List Safari tabs in a specific window."),
            CompletionSuggestion(value: "open-tab", abstract: "Open a new Safari tab in a specific window."),
            CompletionSuggestion(value: "tabs", abstract: "List Safari browser tabs across all open windows."),
            CompletionSuggestion(value: "find-tab", abstract: "Find Safari tabs by URL."),
            CompletionSuggestion(value: "resolve-tab", abstract: "Resolve exactly one Safari tab by URL."),
            CompletionSuggestion(value: "execute-tab-javascript", abstract: "Execute JavaScript in a concrete Safari tab."),
            CompletionSuggestion(value: "set-tab-url", abstract: "Update the URL of a Safari tab."),
            CompletionSuggestion(value: "close-tab", abstract: "Close a Safari tab.")
        ]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari", "la"], modules: modules) ==
        [CompletionSuggestion(value: "launch", abstract: "Launch Safari.")]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari-ui"], modules: modules) ==
        [
            CompletionSuggestion(value: "menu-bar-items", abstract: "List Safari application menu bar items."),
            CompletionSuggestion(value: "menu-items", abstract: "List items for a Safari application menu."),
            CompletionSuggestion(value: "file-menu-items", abstract: "List Safari File menu items."),
            CompletionSuggestion(value: "menu-item-children", abstract: "List child menu items for a Safari menu item.")
        ]
    )
}

@Test func commandArgumentDescriptorDefaultsToRequiredWithoutSuggestions() async throws {
    let descriptor = CommandArgumentDescriptor(name: "profile", kind: .positional)

    #expect(descriptor.name == "profile")
    #expect(descriptor.kind == .positional)
    #expect(descriptor.isRequired)
    #expect(descriptor.completionSuggestions.isEmpty)
}

@Test func moduleDescriptorFlattensCommandsInModelOrder() async throws {
    let firstCommand = CommandDescriptor(name: "first", abstract: "First", operation: .read)
    let secondCommand = CommandDescriptor(name: "second", abstract: "Second", operation: .create)
    let thirdCommand = CommandDescriptor(name: "third", abstract: "Third", operation: .delete)
    let module = ModuleDescriptor(
        name: "test-module",
        abstract: "Test module.",
        models: [
            ModelDescriptor(name: "alpha", abstract: "Alpha", commands: [firstCommand, secondCommand]),
            ModelDescriptor(name: "beta", abstract: "Beta", commands: [thirdCommand])
        ]
    )

    #expect(module.commands == [firstCommand, secondCommand, thirdCommand])
}

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
    #expect(tabOpen.count == 2)
    #expect(tabOpen[0].name == "window-index")
    #expect(tabOpen[0].kind == .positional)
    #expect(tabOpen[0].isRequired)
    #expect(tabOpen[1].name == "url")
    #expect(tabOpen[1].kind == .positional)
    #expect(!tabOpen[1].isRequired)

    let setTabURL = SafariTabSetURLCommand.descriptor.arguments
    #expect(setTabURL.count == 3)
    #expect(setTabURL[0].name == "window-index")
    #expect(setTabURL[1].name == "tab-index")
    #expect(setTabURL[2].name == "url")

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

    let closeTab = SafariTabCloseCommand.descriptor.arguments
    #expect(closeTab.count == 2)
    #expect(closeTab[0].name == "window-index")
    #expect(closeTab[1].name == "tab-index")

    let windowTabs = SafariTabListWindowTabsCommand.descriptor.arguments
    #expect(windowTabs.count == 1)
    #expect(windowTabs[0].name == "window-index")
    #expect(windowTabs[0].kind == .positional)
    #expect(windowTabs[0].isRequired)

    let tabGroupTabs = SafariTabListTabGroupTabsCommand.descriptor.arguments
    #expect(tabGroupTabs.count == 1)
    #expect(tabGroupTabs[0].name == "tab-group-identifier")
    #expect(tabGroupTabs[0].kind == .positional)
    #expect(tabGroupTabs[0].isRequired)

    let deleteTabGroup = SafariTabGroupDeleteCommand.descriptor.arguments
    #expect(deleteTabGroup.count == 1)
    #expect(deleteTabGroup[0].name == "tab-group-identifier")
}

@Test func completionEngineFiltersCommandsUsingSecondTokenForDeeperInput() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: ["safari", "cl", "ignored"], modules: modules) ==
        [
            CompletionSuggestion(value: "close-window", abstract: "Close the front Safari browser window."),
            CompletionSuggestion(value: "close-tab", abstract: "Close a Safari tab.")
        ]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari", ""], modules: modules) ==
        SafariModule.descriptor.commands.map {
            CompletionSuggestion(value: $0.name, abstract: $0.abstract)
        }
    )
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

@Test func cliRendersZshCompletionScript() async throws {
    let output = try ComputerAutomationCLI.run(arguments: ["--completion-script", "zsh"])
    #expect(output.contains("#compdef computer-automation"))
    #expect(output.contains("computer-automation --complete"))
}

@Test func completionEngineReturnsNoSuggestionsForUnknownModule() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(CompletionEngine.suggestions(for: ["unknown"], modules: modules).isEmpty)
    #expect(CompletionEngine.suggestions(for: ["unknown", "anything"], modules: modules).isEmpty)
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

@Test func safariDatabaseOpenErrorsExplainFullDiskAccessRequirement() async throws {
    let error = SafariTabGroupCommandError.databaseOpenFailed(path: "/protected/SafariTabs.db")

    #expect(error.localizedDescription.contains("Grant Full Disk Access"))
    #expect(error.localizedDescription.contains("/protected/SafariTabs.db"))
}

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
        listWindows: { _ in windowLists.removeFirst() }
    )

    #expect(try command.execute(arguments: ["Twisto"]) == "Safari window opened for profile Twisto.\nwindow-id|44")
    #expect(receivedProfileName == "Twisto")
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
    var selectedTabGroupName: String?
    let command = SafariWindowOpenTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        openWindow: { profileName, _ in receivedProfileName = profileName },
        selectTabGroup: { tabGroupName, _ in selectedTabGroupName = tabGroupName }
    )

    #expect(try command.execute(arguments: ["1000"]) == "Safari window opened for tab group Focus.")
    #expect(receivedProfileName == "Twisto")
    #expect(selectedTabGroupName == "Focus")
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
    var focusedWindowIndex: Int?
    var selectedTabGroupName: String?
    let command = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Work")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { windowIndex, _ in focusedWindowIndex = windowIndex },
        selectTabGroup: { tabGroupName, _ in selectedTabGroupName = tabGroupName }
    )

    #expect(try command.execute(arguments: ["2", "1000"]) == "Safari window 2 switched to tab group Focus.")
    #expect(focusedWindowIndex == 2)
    #expect(selectedTabGroupName == "Focus")
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
    var focusedWindowIndex: Int?
    var selectedTabGroupName: String?

    let command = SafariWindowSetTabGroupCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 1, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Focus — Start Page")]
        },
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")]
        },
        focusWindow: { windowIndex, _ in focusedWindowIndex = windowIndex },
        selectTabGroup: { tabGroupName, _ in selectedTabGroupName = tabGroupName }
    )

    #expect(try command.execute(arguments: ["1", "1000"]) == "Safari window 1 switched to tab group Focus.")
    #expect(focusedWindowIndex == 1)
    #expect(selectedTabGroupName == "Focus")
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
        }
    )

    #expect(groups == [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")])
}

@Test func safariTabGroupEnsureCommandReusesSingleExistingGroup() async throws {
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { profileName, name in
            #expect(profileName == "Twisto")
            #expect(name == "Focus")
            return [SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")]
        },
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
    var focusedWindowIndexes: [Int] = []
    var listWindowCallCount = 0
    let command = SafariTabGroupEnsureCommand(
        executor: MockAppleScriptExecutor(),
        findTabGroups: { _, _ in [] },
        listWindows: {
            listWindowCallCount += 1
            if listWindowCallCount == 1 {
                return []
            }
            return [
                SafariWindowRecord(identifier: 42, index: 3, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Start Page")
            ]
        },
        focusWindow: { windowIndex, _ in focusedWindowIndexes.append(windowIndex) },
        openWindow: { profileName, _ in openedProfileName = profileName },
        createTabGroup: { windowIndex, name in
            #expect(windowIndex == 3)
            #expect(name == "Focus")
            return SafariTabGroupRecord(identifier: 10, profileName: "Twisto", name: "Focus")
        }
    )

    let output = try command.executeJSON(arguments: ["Twisto", "Focus"])
    let object = try jsonObject(output)
    let tabGroup = try #require(object["tabGroup"] as? [String: Any])

    #expect(openedProfileName == "Twisto")
    #expect(focusedWindowIndexes == [3])
    #expect(object["status"] as? String == "created")
    #expect(tabGroup["identifier"] as? Int == 10)
    #expect(tabGroup["profileName"] as? String == "Twisto")
    #expect(tabGroup["name"] as? String == "Focus")
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
    var focusedWindowIndex: Int?
    var didCreateEmptyTabGroup = false
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
        focusWindow: { windowIndex, _ in focusedWindowIndex = windowIndex },
        createEmptyTabGroup: { _ in didCreateEmptyTabGroup = true },
        renameTabGroup: { currentName, newName, _ in
            renamedSourceName = currentName
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(focusedWindowIndex == 2)
    #expect(didCreateEmptyTabGroup)
    #expect(renamedSourceName == "Senza nome")
    #expect(renamedTargetName == "Inbox")
}

@Test func safariTabGroupCreateCommandRejectsInvalidArgumentsAndStates() async throws {
    let command = SafariTabGroupCreateCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { [] },
        listTabGroups: { [] },
        focusWindow: { _, _ in Issue.record("focusWindow should not be called") },
        createEmptyTabGroup: { _ in Issue.record("createEmptyTabGroup should not be called") },
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
        createEmptyTabGroup: { _ in Issue.record("createEmptyTabGroup should not be called") },
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
        createEmptyTabGroup: { _ in Issue.record("createEmptyTabGroup should not be called") },
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
        createEmptyTabGroup: { _ in },
        renameTabGroup: { _, _, _ in Issue.record("renameTabGroup should not be called") },
        sleep: { _ in }
    )

    #expect(throws: SafariTabGroupCommandError.createdTabGroupNotFound(profileName: "Twisto")) {
        try command.execute(arguments: ["2", "Inbox"])
    }
}

@Test func safariTabGroupCreateCommandUsesSelectedTabGroupProfileWhenWindowProfileIsUnknown() async throws {
    var focusedWindowIndex: Int?
    var didCreateEmptyTabGroup = false
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
        focusWindow: { windowIndex, _ in focusedWindowIndex = windowIndex },
        createEmptyTabGroup: { _ in didCreateEmptyTabGroup = true },
        renameTabGroup: { currentName, newName, _ in
            renamedSourceName = currentName
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(focusedWindowIndex == 2)
    #expect(didCreateEmptyTabGroup)
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
        createEmptyTabGroup: { _ in },
        renameTabGroup: { currentName, newName, _ in
            renamedSourceName = currentName
            renamedTargetName = newName
        },
        sleep: { _ in }
    )

    #expect(try command.execute(arguments: ["2", "Inbox"]) == "1001|Twisto|Inbox")
    #expect(renamedSourceName == nil)
    #expect(renamedTargetName == nil)
}

@Test func safariTabGroupDeleteCommandFormatsResolvedGroup() async throws {
    var focusedWindowIndexes: [Int] = []
    var openedProfiles: [String?] = []
    var selectedNames: [String] = []

    var deleted = false
    var deleteWindowPollCount = 0
    let deleteCommand = SafariTabGroupDeleteCommand(
        executor: MockAppleScriptExecutor(),
        listTabGroups: { [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")] },
        listWindows: {
            deleteWindowPollCount += 1
            if deleteWindowPollCount == 1 {
                return []
            }
            return [SafariWindowRecord(identifier: 12, index: 1, isPrivate: false, profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Twisto")]
        },
        focusWindow: { index, _ in focusedWindowIndexes.append(index) },
        openWindow: { profile, _ in openedProfiles.append(profile) },
        selectTabGroup: { name, _ in selectedNames.append(name) },
        deleteSelectedTabGroup: { _ in deleted = true }
    )
    #expect(try deleteCommand.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(openedProfiles == [])
    #expect(selectedNames.suffix(1).first == "Inbox")
    #expect(focusedWindowIndexes.suffix(1).first == 1)
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
        deleteSelectedTabGroup: { _ in }
    )
    #expect(throws: SafariTabGroupCommandError.missingTabGroupIdentifier) {
        try deleteCommand.execute(arguments: [])
    }
    #expect(throws: SafariTabGroupCommandError.invalidTabGroupIdentifier("x")) {
        try deleteCommand.execute(arguments: ["x"])
    }
}

@Test func safariTabGroupDeleteCommandFallsBackToSingleUnscopedWindow() async throws {
    let executor = MockAppleScriptExecutor()
    var focusedWindowIndex: Int?
    var openedProfileName: String?
    var selectedName: String?
    var didDelete = false

    let command = SafariTabGroupDeleteCommand(
        executor: executor,
        listTabGroups: {
            [SafariTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Inbox")]
        },
        listWindows: {
            [SafariWindowRecord(identifier: 10, index: 2, isPrivate: false, profileName: "", selectedTabGroupIdentifier: nil, tabGroupName: nil, name: "Front")]
        },
        focusWindow: { index, _ in focusedWindowIndex = index },
        openWindow: { profileName, _ in openedProfileName = profileName },
        selectTabGroup: { name, _ in selectedName = name },
        deleteSelectedTabGroup: { _ in didDelete = true }
    )

    #expect(try command.execute(arguments: ["1000"]) == "1000|Twisto|Inbox")
    #expect(focusedWindowIndex == 2)
    #expect(openedProfileName == nil)
    #expect(selectedName == "Inbox")
    #expect(didDelete)
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
        closeFrontWindow: { _ in input.1 }
    )

    #expect(try command.execute(arguments: []) == input.2)
}

@Test func safariWindowCloseCommandPropagatesCloseFailure() async throws {
    let command = SafariWindowCloseCommand(
        executor: MockAppleScriptExecutor(),
        isRunning: { true },
        closeFrontWindow: { _ in throw SafariAppleScriptError.scriptCompilationFailed }
    )

    #expect(throws: SafariAppleScriptError.scriptCompilationFailed) {
        try command.execute(arguments: [])
    }
}

@Test func safariTabOpenCommandRejectsMissingWindowIndex() async throws {
    let command = SafariTabOpenCommand(
        executor: MockAppleScriptExecutor(),
        openTab: { _, _, _ in Issue.record("openTab should not be called") }
    )

    #expect(throws: SafariTabCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }
}

@Test func safariTabOpenCommandRejectsInvalidWindowIndex() async throws {
    let command = SafariTabOpenCommand(
        executor: MockAppleScriptExecutor(),
        openTab: { _, _, _ in Issue.record("openTab should not be called") }
    )

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try command.execute(arguments: ["0"])
    }
}

@Test func safariTabOpenCommandFormatsMessages() async throws {
    var received: (Int, String?)?
    let command = SafariTabOpenCommand(
        executor: MockAppleScriptExecutor(),
        openTab: { windowIndex, url, _ in received = (windowIndex, url) }
    )

    #expect(try command.execute(arguments: ["2"]) == "Safari tab opened in window 2.")
    #expect(received?.0 == 2)
    #expect(received?.1 == nil)

    #expect(try command.execute(arguments: ["2", "https://example.com"]) == "Safari tab opened in window 2 with URL https://example.com.")
    #expect(received?.0 == 2)
    #expect(received?.1 == "https://example.com")
}

@Test(arguments: [
    [],
    [SafariTabRecord(windowIndex: 1, index: 1, url: "https://example.com")],
    [
        SafariTabRecord(windowIndex: 1, index: 1, url: "https://example.com"),
        SafariTabRecord(windowIndex: 1, index: 2, url: "https://openai.com"),
        SafariTabRecord(windowIndex: 2, index: 1, url: "")
    ]
])
func safariTabListCommandFormatsTabRows(tabs: [SafariTabRecord]) async throws {
    let command = SafariTabListCommand(
        executor: MockAppleScriptExecutor(),
        listTabs: { _ in tabs }
    )

    let output = try command.execute(arguments: [])
    let expected = tabs.map { "\($0.windowIndex)|\($0.index)|\($0.url)" }.joined(separator: "\n")
    #expect(output == expected)
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

@Test func safariTabFindCommandFormatsExactURLMatches() async throws {
    let command = SafariTabFindCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { url, matchMode, windowIdentifier, windowIndex, profileName, _ in
            #expect(url == "https://example.com")
            #expect(matchMode == .exact)
            #expect(windowIdentifier == nil)
            #expect(windowIndex == nil)
            #expect(profileName == nil)
            return [
                SafariTabMatchRecord(
                    windowIdentifier: 42,
                    windowIndex: 1,
                    tabIndex: 2,
                    url: "https://example.com",
                    title: "Example"
                )
            ]
        }
    )

    #expect(try command.execute(arguments: ["https://example.com"]) == "42|1|2|https://example.com|Example")
}

@Test func safariTabFindCommandFormatsJSONWithoutEscapedDelimiterAmbiguity() async throws {
    let command = SafariTabFindCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { _, _, _, _, _, _ in
            [
                SafariTabMatchRecord(
                    windowIdentifier: 42,
                    windowIndex: 1,
                    tabIndex: 2,
                    url: "https://example.com/a|b",
                    title: "Example | Home"
                )
            ]
        }
    )

    let output = try command.executeJSON(arguments: ["https://example.com", "--prefix"])
    let object = try jsonObject(output)
    let matches = try #require(object["matches"] as? [[String: Any]])
    let match = try #require(matches.first)

    #expect(object["query"] as? String == "https://example.com")
    #expect(object["matchMode"] as? String == "prefix")
    #expect(match["windowId"] as? Int == 42)
    #expect(match["windowIndex"] as? Int == 1)
    #expect(match["tabIndex"] as? Int == 2)
    #expect(match["url"] as? String == "https://example.com/a|b")
    #expect(match["title"] as? String == "Example | Home")
}

@Test func safariTabFindCommandParsesPrefixWindowAndProfileFilters() async throws {
    let command = SafariTabFindCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { url, matchMode, windowIdentifier, windowIndex, profileName, _ in
            #expect(url == "https://example.com")
            #expect(matchMode == .prefix)
            #expect(windowIdentifier == 42)
            #expect(windowIndex == 3)
            #expect(profileName == "Twisto")
            return []
        }
    )

    #expect(
        try command.execute(arguments: [
            "https://example.com",
            "--prefix",
            "--window-id=42",
            "--window-index", "3",
            "--profile=Twisto"
        ]) == ""
    )
}

@Test func safariTabFindCommandRejectsInvalidArguments() async throws {
    let command = SafariTabFindCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { _, _, _, _, _, _ in Issue.record("findTabs should not be called"); return [] }
    )

    #expect(throws: SafariTabCommandError.missingURL) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("x")) {
        try command.execute(arguments: ["https://example.com", "--window-id", "x"])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try command.execute(arguments: ["https://example.com", "--window-index=0"])
    }

    #expect(throws: SafariTabCommandError.missingOptionValue("--profile")) {
        try command.execute(arguments: ["https://example.com", "--profile"])
    }

    #expect(throws: SafariTabCommandError.missingOptionValue("--profile")) {
        try command.execute(arguments: ["https://example.com", "--profile", "--prefix"])
    }

    #expect(throws: SafariTabCommandError.unknownOption("--unknown")) {
        try command.execute(arguments: ["https://example.com", "--unknown"])
    }

    #expect(throws: SafariTabCommandError.unexpectedArgument("extra")) {
        try command.execute(arguments: ["https://example.com", "extra"])
    }
}

@Test func safariTabResolveCommandFormatsSingleMatch() async throws {
    let command = SafariTabResolveCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { url, matchMode, windowIdentifier, windowIndex, profileName, _ in
            #expect(url == "https://example.com")
            #expect(matchMode == .prefix)
            #expect(windowIdentifier == 42)
            #expect(windowIndex == nil)
            #expect(profileName == "Twisto")
            return [
                SafariTabMatchRecord(
                    windowIdentifier: 42,
                    windowIndex: 1,
                    tabIndex: 2,
                    url: "https://example.com/path",
                    title: "Example"
                )
            ]
        }
    )

    #expect(
        try command.execute(arguments: ["https://example.com", "--prefix", "--window-id=42", "--profile=Twisto"]) ==
        "42|1|2|https://example.com/path|Example"
    )
}

@Test func safariTabResolveCommandReturnsJSONSingleMatch() async throws {
    let command = SafariTabResolveCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { _, _, _, _, _, _ in
            [
                SafariTabMatchRecord(
                    windowIdentifier: 42,
                    windowIndex: 1,
                    tabIndex: 2,
                    url: "https://example.com/a|b",
                    title: "Example | Home"
                )
            ]
        }
    )

    let output = try command.executeJSON(arguments: ["https://example.com", "--prefix"])
    let object = try jsonObject(output)
    let match = try #require(object["match"] as? [String: Any])

    #expect(object["query"] as? String == "https://example.com")
    #expect(object["matchMode"] as? String == "prefix")
    #expect(match["windowId"] as? Int == 42)
    #expect(match["windowIndex"] as? Int == 1)
    #expect(match["tabIndex"] as? Int == 2)
    #expect(match["url"] as? String == "https://example.com/a|b")
    #expect(match["title"] as? String == "Example | Home")
}

@Test func safariTabResolveCommandRequiresExactlyOneMatch() async throws {
    let noMatches = SafariTabResolveCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { _, _, _, _, _, _ in [] }
    )

    #expect(throws: SafariTabCommandError.resolveNoMatch("https://example.com")) {
        try noMatches.execute(arguments: ["https://example.com"])
    }

    let multipleMatches = SafariTabResolveCommand(
        executor: MockAppleScriptExecutor(),
        findTabs: { _, _, _, _, _, _ in
            [
                SafariTabMatchRecord(windowIdentifier: 42, windowIndex: 1, tabIndex: 1, url: "https://example.com"),
                SafariTabMatchRecord(windowIdentifier: 43, windowIndex: 2, tabIndex: 1, url: "https://example.com")
            ]
        }
    )

    #expect(throws: SafariTabCommandError.resolveAmbiguous("https://example.com", 2)) {
        try multipleMatches.execute(arguments: ["https://example.com"])
    }
}

@Test func safariTabFindMatchesURLsAndFiltersWindows() async throws {
    let matches = try SafariTab.find(
        url: "https://example.com",
        matchMode: .prefix,
        windowIdentifier: 42,
        windowIndex: 1,
        profileName: "Twisto",
        executor: MockAppleScriptExecutor(),
        isRunning: { true },
        listTabs: { _ in
            [
                SafariTabRecord(windowIndex: 1, index: 1, url: "https://example.com", title: "Home"),
                SafariTabRecord(windowIndex: 1, index: 2, url: "https://example.com/path", title: "Path"),
                SafariTabRecord(windowIndex: 2, index: 1, url: "https://example.com", title: "Other window"),
                SafariTabRecord(windowIndex: 1, index: 3, url: "https://openai.com", title: "Other URL")
            ]
        },
        listWindows: { _ in
            [
                SafariWindowRecord(identifier: 42, index: 1, profileName: "Twisto", name: "Twisto"),
                SafariWindowRecord(identifier: 43, index: 2, profileName: "Glutexo", name: "Glutexo")
            ]
        }
    )

    #expect(
        matches ==
        [
            SafariTabMatchRecord(windowIdentifier: 42, windowIndex: 1, tabIndex: 1, url: "https://example.com", title: "Home"),
            SafariTabMatchRecord(windowIdentifier: 42, windowIndex: 1, tabIndex: 2, url: "https://example.com/path", title: "Path")
        ]
    )
}

@Test func safariTabExecuteJavaScriptCommandReturnsScriptResult() async throws {
    var received: (Int, Int, String)?
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { windowIdentifier, tabIndex, javaScript, _ in
            received = (windowIdentifier, tabIndex, javaScript)
            return "ready"
        }
    )

    #expect(try command.execute(arguments: ["42", "2", "document.readyState"]) == "ready")
    #expect(received?.0 == 42)
    #expect(received?.1 == 2)
    #expect(received?.2 == "document.readyState")
}

@Test func safariTabExecuteJavaScriptCommandReadsScriptFromStandardInput() async throws {
    var receivedJavaScript: String?
    var didReadStandardInput = false
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, javaScript, _ in
            receivedJavaScript = javaScript
            return "ok"
        },
        readStandardInput: {
            didReadStandardInput = true
            return "document.body.dataset.state"
        }
    )

    #expect(try command.execute(arguments: ["42", "2", "--stdin"]) == "ok")
    #expect(didReadStandardInput)
    #expect(receivedJavaScript == "document.body.dataset.state")
}

@Test func safariTabExecuteJavaScriptCommandReadsScriptFromFile() async throws {
    var receivedPath: String?
    var receivedJavaScript: String?
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, javaScript, _ in
            receivedJavaScript = javaScript
            return "loaded"
        },
        readFile: { path in
            receivedPath = path
            return "document.querySelector('main').textContent"
        }
    )

    #expect(try command.execute(arguments: ["42", "2", "--file", "script.js"]) == "loaded")
    #expect(receivedPath == "script.js")
    #expect(receivedJavaScript == "document.querySelector('main').textContent")
}

@Test func safariTabExecuteJavaScriptCommandReadsScriptFromEqualsFileOption() async throws {
    var receivedPath: String?
    var receivedJavaScript: String?
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, javaScript, _ in
            receivedJavaScript = javaScript
            return "loaded"
        },
        readFile: { path in
            receivedPath = path
            return "document.title"
        }
    )

    #expect(try command.execute(arguments: ["42", "2", "--file=script.js"]) == "loaded")
    #expect(receivedPath == "script.js")
    #expect(receivedJavaScript == "document.title")
}

@Test func safariTabExecuteJavaScriptCommandReturnsJSONResult() async throws {
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in "Example | Home" }
    )

    let output = try command.executeJSON(arguments: ["42", "2", "document.title"])
    let object = try jsonObject(output)

    #expect(object["windowId"] as? Int == 42)
    #expect(object["tabIndex"] as? Int == 2)
    #expect(object["result"] as? String == "Example | Home")
}

@Test func safariTabExecuteJavaScriptCommandRejectsInvalidArguments() async throws {
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in Issue.record("executeJavaScript should not be called"); return "" }
    )

    #expect(throws: SafariTabCommandError.missingWindowIdentifier) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("x")) {
        try command.execute(arguments: ["x"])
    }

    #expect(throws: SafariTabCommandError.missingTabAddress) {
        try command.execute(arguments: ["42"])
    }

    #expect(throws: SafariTabCommandError.invalidTabAddress("42", "0")) {
        try command.execute(arguments: ["42", "0"])
    }

    #expect(throws: SafariTabCommandError.missingJavaScript) {
        try command.execute(arguments: ["42", "2"])
    }

    #expect(throws: SafariTabCommandError.missingJavaScript) {
        try command.execute(arguments: ["42", "2", ""])
    }

    #expect(throws: SafariTabCommandError.multipleJavaScriptSources) {
        try command.execute(arguments: ["42", "2", "document.title", "--stdin"])
    }

    #expect(throws: SafariTabCommandError.missingOptionValue("--file")) {
        try command.execute(arguments: ["42", "2", "--file"])
    }

    #expect(throws: SafariTabCommandError.missingOptionValue("--file")) {
        try command.execute(arguments: ["42", "2", "--file="])
    }

    #expect(throws: SafariTabCommandError.unexpectedArgument("extra")) {
        try command.execute(arguments: ["42", "2", "document.title", "extra"])
    }

    #expect(throws: SafariTabCommandError.unknownOption("--unknown")) {
        try command.execute(arguments: ["42", "2", "--unknown"])
    }
}

@Test func safariTabExecuteJavaScriptCommandWrapsFileReadFailures() async throws {
    let command = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in Issue.record("executeJavaScript should not be called"); return "" },
        readFile: { _ in throw SafariAppleScriptError.scriptCompilationFailed }
    )

    #expect(throws: SafariTabCommandError.javaScriptFileReadFailed("missing.js")) {
        try command.execute(arguments: ["42", "2", "--file", "missing.js"])
    }
}

@Test func safariTabExecuteJavaScriptCommandWrapsTransportFailures() async throws {
    let missingWindow = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in
            throw SafariAppleScriptTabJavaScriptError.windowNotFound(42)
        }
    )
    #expect(throws: SafariTabCommandError.javaScriptTargetWindowNotFound(42)) {
        try missingWindow.execute(arguments: ["42", "2", "document.title"])
    }

    let missingTab = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in
            throw SafariAppleScriptTabJavaScriptError.tabNotFound(windowIdentifier: 42, tabIndex: 2)
        }
    )
    #expect(throws: SafariTabCommandError.javaScriptTargetTabNotFound(windowIdentifier: 42, tabIndex: 2)) {
        try missingTab.execute(arguments: ["42", "2", "document.title"])
    }

    let failedScript = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in
            throw SafariAppleScriptTabJavaScriptError.executionFailed(windowIdentifier: 42, tabIndex: 2)
        }
    )
    #expect(throws: SafariTabCommandError.javaScriptExecutionFailed(windowIdentifier: 42, tabIndex: 2)) {
        try failedScript.execute(arguments: ["42", "2", "document.title"])
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

@Test func safariTabListWindowTabsCommandPropagatesFailure() async throws {
    let command = SafariTabListWindowTabsCommand(
        executor: MockAppleScriptExecutor(),
        listWindowTabs: { _, _ in throw SafariAppleScriptError.scriptCompilationFailed }
    )

    #expect(throws: SafariAppleScriptError.scriptCompilationFailed) {
        try command.execute(arguments: ["1"])
    }
}

@Test func safariTabSetURLCommandRejectsMissingAddressOrURL() async throws {
    let command = SafariTabSetURLCommand(
        executor: MockAppleScriptExecutor(),
        setURL: { _, _, _, _ in Issue.record("setURL should not be called") }
    )

    #expect(throws: SafariTabCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabCommandError.missingTabAddress) {
        try command.execute(arguments: ["1"])
    }

    #expect(throws: SafariTabCommandError.missingURL) {
        try command.execute(arguments: ["1", "2"])
    }
}

@Test func safariTabSetURLCommandRejectsInvalidIndices() async throws {
    let command = SafariTabSetURLCommand(
        executor: MockAppleScriptExecutor(),
        setURL: { _, _, _, _ in Issue.record("setURL should not be called") }
    )

    #expect(throws: SafariTabCommandError.invalidWindowIndex("x")) {
        try command.execute(arguments: ["x", "1", "https://example.com"])
    }

    #expect(throws: SafariTabCommandError.invalidTabAddress("2", "0")) {
        try command.execute(arguments: ["2", "0", "https://example.com"])
    }
}

@Test func safariTabSetURLCommandFormatsSuccessMessage() async throws {
    var received: (Int, Int, String)?
    let command = SafariTabSetURLCommand(
        executor: MockAppleScriptExecutor(),
        setURL: { windowIndex, tabIndex, url, _ in received = (windowIndex, tabIndex, url) }
    )

    #expect(
        try command.execute(arguments: ["2", "3", "https://example.com"]) ==
        "Safari tab URL updated for window 2 tab 3."
    )
    #expect(received?.0 == 2)
    #expect(received?.1 == 3)
    #expect(received?.2 == "https://example.com")
}

@Test func safariTabCloseCommandRejectsMissingOrInvalidAddress() async throws {
    let command = SafariTabCloseCommand(
        executor: MockAppleScriptExecutor(),
        closeTab: { _, _, _ in Issue.record("closeTab should not be called"); return "" }
    )

    #expect(throws: SafariTabCommandError.missingWindowIndex) {
        try command.execute(arguments: [])
    }

    #expect(throws: SafariTabCommandError.missingTabAddress) {
        try command.execute(arguments: ["1"])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("-1")) {
        try command.execute(arguments: ["-1", "1"])
    }

    #expect(throws: SafariTabCommandError.invalidTabAddress("2", "x")) {
        try command.execute(arguments: ["2", "x"])
    }
}

@Test func safariTabCloseCommandReturnsAppleScriptMessage() async throws {
    let command = SafariTabCloseCommand(
        executor: MockAppleScriptExecutor(),
        closeTab: { _, _, _ in "Safari tab closed." }
    )

    #expect(try command.execute(arguments: ["1", "2"]) == "Safari tab closed.")
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

@Test func safariAppleScriptTabSetURLExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptTab.setURL(windowIndex: 2, tabIndex: 3, url: "https://openai.com", executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("tell window 2"))
    #expect(executor.executedScripts[0].contains("set URL of tab 3"))
    #expect(executor.executedScripts[0].contains("https://openai.com"))
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
    #expect(executor.executedScripts[0].contains("document.querySelector(\\\"main\\\")"))
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

@Test func safariTabParseTabListMapsAppleScriptRecords() async throws {
    let descriptor = makeTabList([(1, 1, "https://example.com"), (2, 1, "")])
    #expect(
        SafariTab.parseTabList(descriptor) ==
        [
            SafariTabRecord(windowIndex: 1, index: 1, url: "https://example.com"),
            SafariTabRecord(windowIndex: 2, index: 1, url: "")
        ]
    )
}

@Test func safariTabMatchesLiveTabsAgainstSelectedTabGroupTabs() async throws {
    let liveTabs = [
        SafariTabRecord(windowIndex: 2, index: 1, url: "https://example.com"),
        SafariTabRecord(windowIndex: 2, index: 2, url: "https://changed.example"),
        SafariTabRecord(windowIndex: 2, index: 3, url: "https://extra.example")
    ]
    let selectedGroupTabs = [
        SafariTabGroupTabRecord(tabGroupIdentifier: 1000, index: 1, url: "https://example.com"),
        SafariTabGroupTabRecord(tabGroupIdentifier: 1000, index: 2, url: "https://openai.com")
    ]

    #expect(
        SafariTab.matchTabs(liveTabs, againstSelectedTabGroupTabs: selectedGroupTabs) ==
        [
            SafariWindowTabRecord(index: 1, selectedTabGroupTabIndex: 1, url: "https://example.com"),
            SafariWindowTabRecord(index: 2, selectedTabGroupTabIndex: nil, url: "https://changed.example"),
            SafariWindowTabRecord(index: 3, selectedTabGroupTabIndex: nil, url: "https://extra.example")
        ]
    )
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
        listTabs: { _ in
            [
                SafariAppleScriptTabRecord(windowIndex: 1, index: 1, url: "https://other.example"),
                SafariAppleScriptTabRecord(windowIndex: 2, index: 1, url: "https://example.com"),
                SafariAppleScriptTabRecord(windowIndex: 2, index: 2, url: "https://changed.example")
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
        listTabs: { _ in
            [SafariAppleScriptTabRecord(windowIndex: 1, index: 1, url: "https://example.com")]
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
        listTabs: { _ in [] },
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
        listTabs: { _ in [SafariAppleScriptTabRecord(windowIndex: 1, index: 1, url: "https://example.com")] },
        loadWindowStates: { _ in [:] },
        loadTabGroupTabs: { _, _ in [] }
    )

    #expect(missingWindowTabs.isEmpty)
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

@Test func safariAppleScriptWindowCloseFrontWindowReturnsScriptResult() async throws {
    let executor = MockAppleScriptExecutor(results: [.string("Safari front window closed.")])
    #expect(try SafariAppleScriptWindow.closeFrontWindow(executor: executor) == "Safari front window closed.")
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

@Test(arguments: [
    [(1, "AXButton", "", "", "Toggle sidebar"), (2, "AXMenuButton", "TabGroupPickerButton?TabGroup=Focus", "", "")],
    []
])
func safariAppleScriptToolbarListsItems(rows: [(Int, String, String, String, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeToolbarList(rows))])
    let items = try SafariAppleScriptToolbar.listItems(executor: executor)
    let expected = rows.map {
        SafariAppleScriptToolbarItemRecord(
            index: $0.0,
            role: $0.1,
            identifier: emptyToNil($0.2),
            title: emptyToNil($0.3),
            description: emptyToNil($0.4)
        )
    }
    #expect(items == expected)
    #expect(executor.executedScripts[0].contains("toolbar 1 of front window"))
}

@Test(arguments: [
    [(1, "Twisto", "", ""), (2, "Focus", "", "")],
    []
])
func safariAppleScriptToolbarItemListsChildItems(rows: [(Int, String, String, String)]) async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList(rows))])
    let items = try SafariAppleScriptToolbarItem.listChildItems(toolbarItemIndex: 2, executor: executor)
    let expected = rows.map {
        SafariAppleScriptMenuItemRecord(index: $0.0, title: $0.1, commandCharacter: emptyToNil($0.2), commandModifiers: emptyToNil($0.3))
    }
    #expect(items == expected)
    #expect(executor.executedScripts[0].contains("UI element 2 of toolbar 1"))
    #expect(executor.executedScripts[0].contains("AXShowMenu"))
}

@Test func safariAppleScriptToolbarItemClickChildItemExecutesExpectedScript() async throws {
    let executor = MockAppleScriptExecutor()
    try SafariAppleScriptToolbarItem.clickChildItem(toolbarItemIndex: 2, childItemIndex: 7, executor: executor)
    #expect(executor.executedScripts.count == 1)
    #expect(executor.executedScripts[0].contains("UI element 2 of toolbar 1"))
    #expect(executor.executedScripts[0].contains("click menu item 7"))
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

@Test func safariToolbarMapsAppleScriptItemsIntoUiModel() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeToolbarList([(1, "AXMenuButton", "TabGroupPickerButton?TabGroup=Focus", "", "")]))])
    let items = try SafariToolbar.listItems(executor: executor)
    #expect(items == [SafariToolbarItemRecord(index: 1, role: "AXMenuButton", identifier: "TabGroupPickerButton?TabGroup=Focus")])
}

@Test func safariToolbarWrapsAppleScriptFailure() async throws {
    let executor = MockAppleScriptExecutor(error: SafariAppleScriptError.scriptCompilationFailed)
    #expect(throws: SafariUserInterfaceError.toolbarUnavailable) {
        try SafariToolbar.listItems(executor: executor)
    }
}

@Test func safariToolbarItemMapsAppleScriptChildItemsIntoUiModel() async throws {
    let executor = MockAppleScriptExecutor(results: [.descriptor(makeShortcutList([(1, "Focus", "", "")]))])
    let items = try SafariToolbarItem.listChildItems(toolbarItemIndex: 2, executor: executor)
    #expect(items == [SafariMenuItemRecord(index: 1, title: "Focus")])
}

@Test func safariToolbarItemWrapsAppleScriptFailure() async throws {
    let executor = MockAppleScriptExecutor(error: SafariAppleScriptError.scriptCompilationFailed)
    #expect(throws: SafariUserInterfaceError.toolbarItemChildrenUnavailable(toolbarItemIndex: 2)) {
        try SafariToolbarItem.listChildItems(toolbarItemIndex: 2, executor: executor)
    }
}

@Test func safariSidebarWrapsLookupFailures() async throws {
    let missingExecutor = MockAppleScriptExecutor(error: SafariAppleScriptError.executionFailed("not found"))
    #expect(throws: SafariUserInterfaceError.sidebarTabGroupNotFound("Focus")) {
        try SafariSidebar.selectTabGroup(named: "Focus", executor: missingExecutor)
    }
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

@Test func safariWindowLoadsProfilesByWindowIdentifier() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let databasePath = temporaryDirectory.appendingPathComponent("SafariTabs.db").path
    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (288, 0, 1, 'Twisto', 2);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 200, 288, NULL, 201),
        (3, 300, 288, 1.0, 301);
    """

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, setupSQL, nil, nil, nil) == SQLITE_OK)

    let profiles = try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
    #expect(
        profiles ==
        [
            1: "Glutexo",
            2: "Twisto"
        ]
    )
}

@Test func safariWindowLoadProfilesRejectsMissingDatabase() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: missingPath)
    }
}

@Test func safariWindowLoadProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "window")) {
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
    }
}

@Test func safariWindowLoadProfilesMapsMissingBookmarksToEmptyString() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (6, 0, 1, NULL, 2);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 200, 6, NULL, 201),
        (3, 300, 999, NULL, 301),
        (4, 400, 5, 1.0, 401);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath) ==
        [
            1: "Glutexo",
            2: "",
            3: ""
        ]
    )
}

@Test func safariWindowLoadProfilesFallsBackToSelectedTabGroupParentProfile() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (288, 0, 1, 'Twisto', 2),
        (1000, 288, 1, 'Focus', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 1);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 1000, NULL, NULL, NULL);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadProfilesByWindowIdentifier(databasePath: databasePath) ==
        [
            1: "Twisto"
        ]
    )
}

@Test func safariWindowLoadsPrivateStateByWindowIdentifier() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        subtype INTEGER
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_tab_group_id INTEGER,
        active_profile_id INTEGER,
        date_closed REAL,
        private_tab_group_id INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, subtype) VALUES
        (5, 0, 1, 'Glutexo', 2),
        (6, 0, 1, 'Twisto', 2),
        (1000, 6, 1, 'Focus', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 1);
    INSERT INTO windows (id, active_tab_group_id, active_profile_id, date_closed, private_tab_group_id) VALUES
        (1, 100, 5, NULL, 101),
        (2, 202, 6, NULL, 202),
        (3, 1000, 6, NULL, NULL),
        (4, 404, 5, 1.0, 404);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseWindow.loadStateByWindowIdentifier(databasePath: databasePath) ==
        [
            1: SafariDatabaseWindowStateRecord(profileName: "Glutexo", selectedTabGroupIdentifier: nil, tabGroupName: nil, isPrivate: false),
            2: SafariDatabaseWindowStateRecord(profileName: "Twisto", selectedTabGroupIdentifier: nil, tabGroupName: nil, isPrivate: true),
            3: SafariDatabaseWindowStateRecord(profileName: "Twisto", selectedTabGroupIdentifier: 1000, tabGroupName: "Focus", isPrivate: false)
        ]
    )
}

@Test func safariTabGroupListsSavedGroupsOnly() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, external_uuid, subtype) VALUES
        (5, 0, 1, 'Glutexo', 'profile-a', 2),
        (288, 0, 1, 'Twisto', 'profile-b', 2),
        (1000, 288, 1, 'Focus', 'group-1', 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', 'scope-1', 1),
        (1002, 1000, 0, 'OpenAI', 'page-1', 0),
        (1003, NULL, 1, 'Local', 'local-1', 0),
        (1004, NULL, 1, 'Private', 'private-1', 0),
        (1005, 288, 1, 'No Scope Group', 'group-2', 0),
        (1006, 999, 1, 'Wrong Parent Group', 'group-3', 0),
        (1007, 1006, 1, 'TopScopedBookmarkList', 'scope-2', 1);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.list(databasePath: databasePath) ==
        [
            SafariDatabaseTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")
        ]
    )
}

@Test func safariTabGroupRejectsMissingDatabaseOrSchema() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseTabGroup.list(databasePath: missingPath)
    }

    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "tab-group")) {
        try SafariDatabaseTabGroup.list(databasePath: databasePath)
    }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "tab-group")) {
        try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath)
    }
}

@Test func safariTabGroupListsTabsInBookmarkOrder() async throws {
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
        (1000, 5, 1, 'Focus', NULL, 0, 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (1002, 1000, 0, 'OpenAI', 'https://openai.com', 2, 0),
        (1003, 1000, 0, 'Example', 'https://example.com', 1, 0),
        (1004, 1000, 0, 'Empty URL', NULL, 3, 0),
        (2000, NULL, 1, 'Local', NULL, 0, 0),
        (2001, 2000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (2002, 2000, 0, 'Ignored Local Tab', 'https://ignored.local', 1, 0);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.listTabs(tabGroupIdentifier: 1000, databasePath: databasePath) ==
        [
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 1, url: "https://example.com"),
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 2, url: "https://openai.com"),
            SafariDatabaseTabGroupTabRecord(tabGroupIdentifier: 1000, index: 3, url: "")
        ]
    )
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

@Test func safariTabGroupDeleteRemovesGroupAndDescendants() async throws {
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
        (288, 0, 1, 'Twisto', NULL, 0, 2),
        (1000, 288, 1, 'Focus', NULL, 0, 0),
        (1001, 1000, 1, 'TopScopedBookmarkList', NULL, 0, 1),
        (1002, 1000, 0, 'OpenAI', 'https://openai.com', 1, 0),
        (2000, 288, 1, 'Inbox', NULL, 1, 0),
        (2001, 2000, 1, 'TopScopedBookmarkList', NULL, 0, 1);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseTabGroup.delete(tabGroupIdentifier: 1000, databasePath: databasePath) ==
        SafariDatabaseTabGroupRecord(identifier: 1000, profileName: "Twisto", name: "Focus")
    )
    #expect(try SafariDatabaseTabGroup.list(databasePath: databasePath) == [
        SafariDatabaseTabGroupRecord(identifier: 2000, profileName: "Twisto", name: "Inbox")
    ])

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    var statement: OpaquePointer?
    #expect(sqlite3_prepare_v2(database, "SELECT count(*) FROM bookmarks WHERE id IN (1000, 1001, 1002);", -1, &statement, nil) == SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    #expect(sqlite3_step(statement) == SQLITE_ROW)
    #expect(sqlite3_column_int(statement, 0) == 0)
}

@Test func safariProfileListsSubtypeTwoRootBookmarks() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let databasePath = temporaryDirectory.appendingPathComponent("SafariTabs.db").path
    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (parent, type, title, external_uuid, subtype) VALUES
        (0, 1, 'Glutexo', 'DefaultProfile', 2),
        (0, 1, 'Twisto', '33782F17-8AAD-41EA-BCB5-71A1A8348C55', 2),
        (0, 1, 'Bookmarks Folder', 'not-a-profile', 0),
        (15, 1, 'Nested Profile-Like Folder', 'nested', 2);
    """

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }

    let createResult = sqlite3_exec(database, setupSQL, nil, nil, nil)
    #expect(createResult == SQLITE_OK)

    let profiles = try SafariDatabaseProfile.list(databasePath: databasePath)
    #expect(
        profiles ==
        [
            SafariDatabaseProfileRecord(name: "Glutexo", identifier: "DefaultProfile"),
            SafariDatabaseProfileRecord(name: "Twisto", identifier: "33782F17-8AAD-41EA-BCB5-71A1A8348C55")
        ]
    )
}

@Test func safariProfileDatabasePathUsesProvidedHomeDirectory() async throws {
    #expect(
        SafariTabsDatabase.databasePath(homeDirectory: "/tmp/example-home") ==
        "/tmp/example-home/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db"
    )
}

@Test func safariProfileListAvailableProfilesRejectsMissingDatabase() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariDatabaseError.openFailed(path: missingPath)) {
        try SafariDatabaseProfile.list(databasePath: missingPath)
    }
}

@Test func safariProfileListAvailableProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariDatabaseError.queryPreparationFailed(modelName: "profile")) {
        try SafariDatabaseProfile.list(databasePath: databasePath)
    }
}

@Test func safariProfileListAvailableProfilesSkipsRowsWithNullFieldsAndPreservesOrder() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent INTEGER,
        type INTEGER,
        title TEXT,
        external_uuid TEXT,
        subtype INTEGER
    );
    INSERT INTO bookmarks (id, parent, type, title, external_uuid, subtype) VALUES
        (10, 0, 1, 'Beta', 'beta-id', 2),
        (11, 0, 1, NULL, 'missing-title', 2),
        (12, 0, 1, 'Gamma', NULL, 2),
        (13, 0, 1, 'Alpha', 'alpha-id', 2),
        (14, 1, 1, 'Nested', 'nested-id', 2);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariDatabaseProfile.list(databasePath: databasePath) ==
        [
            SafariDatabaseProfileRecord(name: "Beta", identifier: "beta-id"),
            SafariDatabaseProfileRecord(name: "Alpha", identifier: "alpha-id")
        ]
    )
}

private func openDatabase(at path: String) -> OpaquePointer? {
    var database: OpaquePointer?
    let result = sqlite3_open(path, &database)
    if result != SQLITE_OK {
        sqlite3_close(database)
        return nil
    }
    return database
}

private func makeTemporaryDatabase() throws -> String {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let databasePath = temporaryDirectory.appendingPathComponent("Test.db").path
    let database = try #require(openDatabase(at: databasePath))
    sqlite3_close(database)
    return databasePath
}

private func executeSQL(_ sql: String, at databasePath: String) throws {
    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK)
}

private func makeIndexTitleList(_ rows: [(Int, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

private func makeShortcutList(_ rows: [(Int, String, String, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

private func makeToolbarList(_ rows: [(Int, String, String, String, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        item.insert(NSAppleEventDescriptor(string: row.4), at: 5)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

private func makeSidebarList(_ rows: [(Int, String, String, String, Bool)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: row.1), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        item.insert(NSAppleEventDescriptor(string: row.4 ? "true" : "false"), at: 5)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

private func makeTabList(_ rows: [(Int, Int, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        listDescriptor.insert(
            NSAppleEventDescriptor(string: "\(row.0)|\(row.1)|\(row.2)"),
            at: offset + 1
        )
    }

    return listDescriptor
}

private func makeStructuredTabList(_ rows: [(Int, Int, String, String)]) -> NSAppleEventDescriptor {
    let listDescriptor = NSAppleEventDescriptor.list()

    for (offset, row) in rows.enumerated() {
        let item = NSAppleEventDescriptor.list()
        item.insert(NSAppleEventDescriptor(string: String(row.0)), at: 1)
        item.insert(NSAppleEventDescriptor(string: String(row.1)), at: 2)
        item.insert(NSAppleEventDescriptor(string: row.2), at: 3)
        item.insert(NSAppleEventDescriptor(string: row.3), at: 4)
        listDescriptor.insert(item, at: offset + 1)
    }

    return listDescriptor
}

private func jsonObject(_ value: String) throws -> [String: Any] {
    let data = Data(value.utf8)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func emptyToNil(_ value: String) -> String? {
    value.isEmpty ? nil : value
}

private func normalizedShortcut(_ value: String) -> String? {
    value.isEmpty || value == "missing value" ? nil : value
}

private final class MockAppleScriptExecutor: SafariAppleScriptExecuting {
    enum Result {
        case none
        case string(String)
        case descriptor(NSAppleEventDescriptor)
    }

    var executedScripts: [String] = []
    private var results: [Result]
    private let error: Error?

    init(results: [Result] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func execute(script: String) throws -> NSAppleEventDescriptor? {
        executedScripts.append(script)

        if let error {
            throw error
        }

        guard !results.isEmpty else {
            return nil
        }

        let nextResult = results.removeFirst()
        switch nextResult {
        case .none:
            return nil
        case .string(let value):
            return NSAppleEventDescriptor(string: value)
        case .descriptor(let descriptor):
            return descriptor
        }
    }
}

private final class FakeRunningApplication: SafariApplicationTerminating {
    private(set) var didTerminate = false

    func terminate() -> Bool {
        didTerminate = true
        return true
    }
}

@Test func zshCompletionScriptUsesCompletionEndpoint() async throws {
    let script = ShellCompletionScriptRenderer.zsh(executableName: "computer-automation")

    #expect(script.contains("#compdef computer-automation"))
    #expect(script.contains("computer-automation --complete"))
    #expect(script.contains("_computer_automation"))
}

@Test func zshCompletionInstallerParsesFpathContracts() async throws {
    #expect(ShellCompletionInstaller.parseFpath(nil).isEmpty)
    #expect(ShellCompletionInstaller.parseFpath("").isEmpty)
    #expect(
        ShellCompletionInstaller.parseFpath("/usr/share/zsh/site-functions:/Users/test/.zsh/completions") ==
        ["/usr/share/zsh/site-functions", "/Users/test/.zsh/completions"]
    )
}

@Test func zshCompletionInstallerPrefersExistingZfuncDirectory() async throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let zfuncDirectory = temporaryDirectory.appendingPathComponent(".zfunc", isDirectory: true)
    try fileManager.createDirectory(at: zfuncDirectory, withIntermediateDirectories: true)

    let resolved = ShellCompletionInstaller.resolveZshDirectory(
        homeDirectory: temporaryDirectory.path,
        fileManager: fileManager
    )

    #expect(resolved == zfuncDirectory.path)
}

@Test func zshCompletionInstallerFallsBackToZshCompletionsDirectory() async throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let resolved = ShellCompletionInstaller.resolveZshDirectory(
        homeDirectory: temporaryDirectory.path,
        fileManager: fileManager
    )

    #expect(resolved == temporaryDirectory.appendingPathComponent(".zsh/completions").path)
}

@Test func zshCompletionInstallerWritesScriptToCompletionPath() async throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let result = try ShellCompletionInstaller.installZsh(
        executableName: "computer-automation",
        environment: ["HOME": temporaryDirectory.path, "FPATH": ""],
        fileManager: fileManager
    )

    #expect(result.filePath == temporaryDirectory.appendingPathComponent(".zsh/completions/_computer-automation").path)
    #expect(result.directoryPath == temporaryDirectory.appendingPathComponent(".zsh/completions").path)
    #expect(result.requiresFpathUpdate)
    #expect(fileManager.fileExists(atPath: result.filePath))

    let script = try String(contentsOfFile: result.filePath, encoding: .utf8)
    #expect(script.contains("computer-automation --complete"))
}

@Test func zshCompletionInstallerSkipsFpathUpdateWhenDirectoryAlreadyConfigured() async throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let completionDirectory = temporaryDirectory.appendingPathComponent(".zsh/completions").path
    let result = try ShellCompletionInstaller.installZsh(
        executableName: "computer-automation",
        environment: ["HOME": temporaryDirectory.path, "FPATH": "/usr/share/zsh/site-functions:\(completionDirectory)"],
        fileManager: fileManager
    )

    #expect(!result.requiresFpathUpdate)
}

@Test func zshCompletionInstallerRejectsMissingHomeDirectory() async throws {
    #expect(throws: CLIError.missingHomeDirectory) {
        try ShellCompletionInstaller.installZsh(
            executableName: "computer-automation",
            environment: [:],
            fileManager: .default
        )
    }
}

@Test func zshCompletionInstallerPropagatesFilesystemFailure() async throws {
    let fileManager = FileManager.default
    let temporaryDirectory = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let homeFile = temporaryDirectory.appendingPathComponent("home-file")
    try Data("not a directory".utf8).write(to: homeFile)

    do {
        _ = try ShellCompletionInstaller.installZsh(
            executableName: "computer-automation",
            environment: ["HOME": homeFile.path, "FPATH": ""],
            fileManager: fileManager
        )
        Issue.record("Expected completion installation to fail when HOME points to a file.")
    } catch {
        #expect(error is CocoaError)
    }
}
