import Testing
import Foundation
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

@Test func safariModuleExposesApplicationModelMetadata() async throws {
    #expect(SafariModule.descriptor.name == "safari")
    #expect(
        SafariModule.descriptor.models ==
        [
            SafariApplication.descriptor,
            SafariProfile.descriptor,
            SafariWindow.descriptor
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
    #expect(SafariProfile.descriptor.commands == [SafariProfileListCommand.descriptor])
    #expect(SafariProfileListCommand.descriptor.operation == .read)
    #expect(SafariWindow.descriptor.name == "window")
    #expect(
        SafariWindow.descriptor.commands ==
        [
            SafariWindowOpenCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )
    #expect(SafariWindowOpenCommand.descriptor.operation == .create)
    #expect(SafariWindowOpenCommand.descriptor.arguments.count == 1)
    #expect(SafariWindowOpenCommand.descriptor.arguments[0].name == "profile")
    #expect(!SafariWindowOpenCommand.descriptor.arguments[0].isRequired)
    #expect(SafariWindowListCommand.descriptor.operation == .read)
    #expect(SafariWindowCloseCommand.descriptor.operation == .delete)
    #expect(SafariUserInterfaceModule.descriptor.models == [
        SafariApplicationMenuBar.descriptor,
        SafariMenu.descriptor,
        SafariFileMenu.descriptor,
        SafariMenuItem.descriptor
    ])
    #expect(SafariApplicationMenuBar.descriptor.commands == [SafariApplicationMenuBarListCommand.descriptor])
    #expect(SafariApplicationMenuBarListCommand.descriptor.operation == .read)
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
        SafariAppleScriptApplicationMenuBar.descriptor,
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
            CompletionSuggestion(value: "open-window", abstract: "Open a new Safari browser window."),
            CompletionSuggestion(value: "windows", abstract: "List open Safari browser windows."),
            CompletionSuggestion(value: "close-window", abstract: "Close the front Safari browser window.")
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
}

@Test func completionEngineFiltersCommandsUsingSecondTokenForDeeperInput() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: ["safari", "cl", "ignored"], modules: modules) ==
        [CompletionSuggestion(value: "close-window", abstract: "Close the front Safari browser window.")]
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
    let output = try ComputerAutomationCLI.run(arguments: ["--complete", "safari-ui"])
    #expect(output.contains("menu-bar-items"))
    #expect(output.contains("menu-items"))
    #expect(output.contains("file-menu-items"))
    #expect(output.contains("menu-item-children"))
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
            ]
        ) ==
        [
            SafariWindowRecord(identifier: 1, index: 1, profileName: "Glutexo", name: "Start Page"),
            SafariWindowRecord(identifier: 2, index: 2, profileName: "Twisto", name: "OpenAI")
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
    ("Glutexo", [1: "Glutexo"], [SafariWindowRecord(identifier: 1, index: 1, profileName: "Glutexo", name: "Glutexo")]),
    ("Glutexo — Start Page", [:], [SafariWindowRecord(identifier: 1, index: 1, profileName: "", name: "Glutexo — Start Page")]),
    ("Unknown", [:], [SafariWindowRecord(identifier: 1, index: 1, profileName: "", name: "Unknown")])
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

@Test func safariWindowOpenCommandOpensUnprofiledWindow() async throws {
    let executor = MockAppleScriptExecutor()
    var receivedProfileName: String?
    let command = SafariWindowOpenCommand(
        executor: executor,
        listProfiles: { [] },
        openWindow: { profileName, _ in receivedProfileName = profileName }
    )

    #expect(try command.execute(arguments: []) == "Safari window opened.")
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

@Test func safariWindowOpenCommandFormatsProfileLaunchMessage() async throws {
    var receivedProfileName: String?
    let command = SafariWindowOpenCommand(
        executor: MockAppleScriptExecutor(),
        listProfiles: { [SafariProfileRecord(name: "Twisto", identifier: "1")] },
        openWindow: { profileName, _ in receivedProfileName = profileName }
    )

    #expect(try command.execute(arguments: ["Twisto"]) == "Safari window opened for profile Twisto.")
    #expect(receivedProfileName == "Twisto")
}

@Test(arguments: [
    [],
    [SafariWindowRecord(identifier: 1, index: 1, profileName: "Glutexo", name: "Start Page")],
    [
        SafariWindowRecord(identifier: 1, index: 1, profileName: "Glutexo", name: "Start Page"),
        SafariWindowRecord(identifier: 2, index: 2, profileName: "Twisto", name: "OpenAI")
    ]
])
func safariWindowListCommandFormatsWindowRows(windows: [SafariWindowRecord]) async throws {
    let command = SafariWindowListCommand(
        executor: MockAppleScriptExecutor(),
        listWindows: { _ in windows }
    )

    let output = try command.execute(arguments: [])
    let expected = windows.map { "\($0.index)|\($0.profileName)|\($0.name)" }.joined(separator: "\n")
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
        title TEXT
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_profile_id INTEGER,
        date_closed REAL
    );
    INSERT INTO bookmarks (id, title) VALUES
        (5, 'Glutexo'),
        (288, 'Twisto');
    INSERT INTO windows (id, active_profile_id, date_closed) VALUES
        (1, 5, NULL),
        (2, 288, NULL),
        (3, 288, 1.0);
    """

    let database = try #require(openDatabase(at: databasePath))
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, setupSQL, nil, nil, nil) == SQLITE_OK)

    let profiles = try SafariWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
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

    #expect(throws: SafariWindowCommandError.databaseOpenFailed(path: missingPath)) {
        try SafariWindow.loadProfilesByWindowIdentifier(databasePath: missingPath)
    }
}

@Test func safariWindowLoadProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariWindowCommandError.queryPreparationFailed) {
        try SafariWindow.loadProfilesByWindowIdentifier(databasePath: databasePath)
    }
}

@Test func safariWindowLoadProfilesMapsMissingBookmarksToEmptyString() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    let setupSQL = """
    CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT
    );
    CREATE TABLE windows (
        id INTEGER PRIMARY KEY,
        active_profile_id INTEGER,
        date_closed REAL
    );
    INSERT INTO bookmarks (id, title) VALUES
        (5, 'Glutexo'),
        (6, NULL);
    INSERT INTO windows (id, active_profile_id, date_closed) VALUES
        (1, 5, NULL),
        (2, 6, NULL),
        (3, 999, NULL),
        (4, 5, 1.0);
    """

    try executeSQL(setupSQL, at: databasePath)

    #expect(
        try SafariWindow.loadProfilesByWindowIdentifier(databasePath: databasePath) ==
        [
            1: "Glutexo",
            2: "",
            3: ""
        ]
    )
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

    let profiles = try SafariProfile.listAvailableProfiles(databasePath: databasePath)
    #expect(
        profiles ==
        [
            SafariProfileRecord(name: "Glutexo", identifier: "DefaultProfile"),
            SafariProfileRecord(name: "Twisto", identifier: "33782F17-8AAD-41EA-BCB5-71A1A8348C55")
        ]
    )
}

@Test func safariProfileDatabasePathUsesProvidedHomeDirectory() async throws {
    #expect(
        SafariProfile.databasePath(homeDirectory: "/tmp/example-home") ==
        "/tmp/example-home/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db"
    )
}

@Test func safariProfileListAvailableProfilesRejectsMissingDatabase() async throws {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Missing.db")
        .path

    #expect(throws: SafariProfileCommandError.databaseOpenFailed(path: missingPath)) {
        try SafariProfile.listAvailableProfiles(databasePath: missingPath)
    }
}

@Test func safariProfileListAvailableProfilesRejectsMissingSchema() async throws {
    let databasePath = try makeTemporaryDatabase()
    defer { try? FileManager.default.removeItem(atPath: databasePath) }

    #expect(throws: SafariProfileCommandError.queryPreparationFailed) {
        try SafariProfile.listAvailableProfiles(databasePath: databasePath)
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
        try SafariProfile.listAvailableProfiles(databasePath: databasePath) ==
        [
            SafariProfileRecord(name: "Beta", identifier: "beta-id"),
            SafariProfileRecord(name: "Alpha", identifier: "alpha-id")
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
