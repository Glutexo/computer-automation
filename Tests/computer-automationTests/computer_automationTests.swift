import Testing
@testable import Safari

@Test func example() async throws {
    #expect(SafariLaunchCommand.name == "launch")
    #expect(SafariLaunchCommand.bundleIdentifier == "com.apple.Safari")
}
