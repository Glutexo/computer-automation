import Testing
@testable import AutomationFoundation
@testable import Safari

@Test func safariModuleExposesLaunchCommandMetadata() async throws {
    #expect(SafariModule.descriptor.name == "safari")
    #expect(SafariModule.descriptor.commands == [SafariLaunchCommand.descriptor])
    #expect(SafariLaunchCommand.descriptor.name == "launch")
    #expect(SafariLaunchCommand.bundleIdentifier == "com.apple.Safari")
}

@Test func completionEngineSuggestsModulesAndCommands() async throws {
    let modules = [SafariModule.descriptor]

    #expect(
        CompletionEngine.suggestions(for: [], modules: modules) ==
        [CompletionSuggestion(value: "safari", abstract: "Automation commands for Safari.")]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari"], modules: modules) ==
        [CompletionSuggestion(value: "launch", abstract: "Launch Safari.")]
    )

    #expect(
        CompletionEngine.suggestions(for: ["safari", "la"], modules: modules) ==
        [CompletionSuggestion(value: "launch", abstract: "Launch Safari.")]
    )
}
