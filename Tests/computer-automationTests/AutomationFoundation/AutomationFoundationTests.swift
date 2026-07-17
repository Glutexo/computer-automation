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

@Test func stableIdentifierMatchingMakesObservedIdentifiersAuthoritative() async throws {
    let identifiedRows: [(identifier: Int?, name: String)] = [
        (identifier: 10, name: "Focus"),
        (identifier: 11, name: "Focus")
    ]

    let exactMatch = StableIdentifierMatching.resolve(
        requestedIdentifier: 11,
        from: identifiedRows,
        identifier: { $0.identifier },
        fallback: { $0.name == "Focus" }
    )
    let contradictoryMatch = StableIdentifierMatching.resolve(
        requestedIdentifier: 12,
        from: identifiedRows,
        identifier: { $0.identifier },
        fallback: { $0.name == "Focus" }
    )
    let fallbackMatch = StableIdentifierMatching.resolve(
        requestedIdentifier: 12,
        from: [(identifier: nil, name: "Focus")],
        identifier: { $0.identifier },
        fallback: { $0.name == "Focus" }
    )

    #expect(exactMatch?.identifier == 11)
    #expect(contradictoryMatch == nil)
    #expect(fallbackMatch?.name == "Focus")
    #expect(StableIdentifierMatching.matches(requestedIdentifier: 11, observedIdentifier: 11, fallback: false))
    #expect(!StableIdentifierMatching.matches(requestedIdentifier: 11, observedIdentifier: 10, fallback: true))
    #expect(StableIdentifierMatching.matches(requestedIdentifier: 11, observedIdentifier: nil, fallback: true))
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
            CompletionSuggestion(value: "close-window", abstract: "Close a Safari browser window."),
            CompletionSuggestion(value: "create-tab-group", abstract: "Create a new saved Safari tab group in a specific window."),
            CompletionSuggestion(value: "ensure-tab-group", abstract: "Create or reuse a saved Safari tab group by profile and name."),
            CompletionSuggestion(value: "tab-groups", abstract: "List saved Safari tab groups."),
            CompletionSuggestion(value: "find-tab-group", abstract: "Find saved Safari tab groups by profile and name."),
            CompletionSuggestion(value: "resolve-tab-group", abstract: "Resolve exactly one saved Safari tab group by profile and name."),
            CompletionSuggestion(value: "delete-tab-group", abstract: "Delete a saved Safari tab group."),
            CompletionSuggestion(value: "ensure-tab-list-urls", abstract: "Ensure requested URLs exist in a Safari tab list."),
            CompletionSuggestion(value: "reorder-tab-list-urls", abstract: "Reorder Safari tab lists to match requested URL order."),
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
    #expect(descriptor.valueType == .string)
    #expect(descriptor.isRequired)
    #expect(descriptor.valueName == nil)
    #expect(!descriptor.isRepeating)
    #expect(descriptor.completionSuggestions.isEmpty)
}

@Test func commandDescriptorDerivesReadOnlySafetyWithExplicitOverride() async throws {
    let read = CommandDescriptor(name: "read", abstract: "Read", operation: .read)
    let create = CommandDescriptor(name: "create", abstract: "Create", operation: .create)
    let activeRead = CommandDescriptor(
        name: "active-read",
        abstract: "Execute active content",
        operation: .read,
        isReadOnly: false
    )

    #expect(read.isReadOnly)
    #expect(!create.isReadOnly)
    #expect(!activeRead.isReadOnly)
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

@Test func completionEngineFiltersCommandsUsingSecondTokenForDeeperInput() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: ["safari", "cl", "ignored"], modules: modules) ==
        [
            CompletionSuggestion(value: "close-window", abstract: "Close a Safari browser window."),
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

@Test func completionEngineReturnsNoSuggestionsForUnknownModule() async throws {
    let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    #expect(CompletionEngine.suggestions(for: ["unknown"], modules: modules).isEmpty)
    #expect(CompletionEngine.suggestions(for: ["unknown", "anything"], modules: modules).isEmpty)
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
