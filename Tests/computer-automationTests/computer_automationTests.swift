import Testing
import Foundation
@testable import AutomationFoundation
@testable import Safari

@Test func safariModuleExposesApplicationModelMetadata() async throws {
    #expect(SafariModule.descriptor.name == "safari")
    #expect(SafariModule.descriptor.models == [SafariApplication.descriptor])
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
            CompletionSuggestion(value: "quit", abstract: "Quit Safari if it is running.")
        ]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari", "la"], modules: modules) ==
        [CompletionSuggestion(value: "launch", abstract: "Launch Safari.")]
    )
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
