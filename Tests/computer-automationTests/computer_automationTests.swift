import Testing
import Foundation
import SQLite3
@testable import AutomationFoundation
@testable import Safari

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
    #expect(SafariWindowListCommand.descriptor.operation == .read)
    #expect(SafariWindowCloseCommand.descriptor.operation == .delete)
}

@Test func completionEngineSuggestsModulesAndCommands() async throws {
    let modules = [SafariModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: [], modules: modules) ==
        [CompletionSuggestion(value: "safari", abstract: "Automation commands for Safari.")]
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
}

@Test func safariWindowParsesAppleScriptListOutput() async throws {
    let listDescriptor = NSAppleEventDescriptor.list()
    listDescriptor.insert(NSAppleEventDescriptor(string: "1|Start Page"), at: 1)
    listDescriptor.insert(NSAppleEventDescriptor(string: "2|OpenAI"), at: 2)

    #expect(
        SafariWindow.parseWindowList(listDescriptor) ==
        [
            SafariWindowRecord(index: 1, name: "Start Page"),
            SafariWindowRecord(index: 2, name: "OpenAI")
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

private func openDatabase(at path: String) -> OpaquePointer? {
    var database: OpaquePointer?
    let result = sqlite3_open(path, &database)
    if result != SQLITE_OK {
        sqlite3_close(database)
        return nil
    }
    return database
}

@Test func zshCompletionScriptUsesCompletionEndpoint() async throws {
    let script = ShellCompletionScriptRenderer.zsh(executableName: "computer-automation")

    #expect(script.contains("#compdef computer-automation"))
    #expect(script.contains("computer-automation --complete"))
    #expect(script.contains("_computer_automation"))
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
