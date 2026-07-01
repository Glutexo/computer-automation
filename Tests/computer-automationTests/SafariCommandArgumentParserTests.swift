import Foundation
import Testing
@testable import Safari
@testable import SafariAppleScript

@Test func safariWindowAddressArgumentParserParsesWindowIdentifierOptionForms() async throws {
    let spaced = try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
        ["--window-id", "42", "https://example.com"],
        allowEmptyIdentifierAfterOption: false,
        allowEmptyIdentifierInEqualsForm: false,
        missingOptionValue: SafariTabCommandError.missingOptionValue,
        unknownOption: SafariTabCommandError.unknownOption,
        invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
    )
    #expect(spaced.windowIdentifier == 42)
    #expect(spaced.positionalArguments == ["https://example.com"])

    let equals = try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
        ["--window-id=43", "https://example.com"],
        allowEmptyIdentifierAfterOption: false,
        allowEmptyIdentifierInEqualsForm: false,
        missingOptionValue: SafariTabCommandError.missingOptionValue,
        unknownOption: SafariTabCommandError.unknownOption,
        invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
    )
    #expect(equals.windowIdentifier == 43)
    #expect(equals.positionalArguments == ["https://example.com"])
}

@Test func safariWindowAddressArgumentParserPreservesWindowIdentifierErrors() async throws {
    #expect(throws: SafariTabCommandError.missingOptionValue("--window-id")) {
        try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            ["--window-id", ""],
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
    }

    #expect(throws: SafariTabCommandError.missingOptionValue("--window-id")) {
        try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            ["--window-id="],
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("0")) {
        try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            ["--window-id", "0"],
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
    }

    #expect(throws: SafariTabCommandError.invalidWindowIdentifier("0")) {
        try SafariWindowAddressArgumentParser.parseWindowIdentifierArguments(
            ["--window-id", "0", "--window-id"],
            allowEmptyIdentifierAfterOption: false,
            allowEmptyIdentifierInEqualsForm: false,
            missingOptionValue: SafariTabCommandError.missingOptionValue,
            unknownOption: SafariTabCommandError.unknownOption,
            invalidWindowIdentifier: SafariTabCommandError.invalidWindowIdentifier
        )
    }
}

@Test func safariWindowAddressArgumentParserParsesRequiredAddressForms() async throws {
    let indexed = try SafariWindowAddressArgumentParser.parseRequiredAddress(
        positionalArguments: ["2", "https://example.com"],
        windowIdentifier: nil,
        missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
        invalidWindowIndex: SafariTabCommandError.invalidWindowIndex
    )
    #expect(indexed.address == .index(2))
    #expect(indexed.remainingArguments == ["https://example.com"])

    let identified = try SafariWindowAddressArgumentParser.parseRequiredAddress(
        positionalArguments: ["https://example.com"],
        windowIdentifier: 42,
        missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
        invalidWindowIndex: SafariTabCommandError.invalidWindowIndex
    )
    #expect(identified.address == .identifier(42))
    #expect(identified.remainingArguments == ["https://example.com"])
}

@Test func safariTabAddressArgumentParserParsesIndexAndIdentifierForms() async throws {
    let indexed = try SafariTabAddressArgumentParser.parseRequiredAddress(
        positionalArguments: ["2", "3", "https://example.com"],
        windowIdentifier: nil,
        missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
        missingTabAddress: { SafariTabCommandError.missingTabAddress },
        invalidWindowIndex: SafariTabCommandError.invalidWindowIndex,
        invalidTabAddress: SafariTabCommandError.invalidTabAddress
    )
    #expect(indexed.address == .index(2))
    #expect(indexed.tabIndex == 3)
    #expect(indexed.remainingArguments == ["https://example.com"])

    let identified = try SafariTabAddressArgumentParser.parseRequiredAddress(
        positionalArguments: ["3", "https://example.com"],
        windowIdentifier: 42,
        missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
        missingTabAddress: { SafariTabCommandError.missingTabAddress },
        invalidWindowIndex: SafariTabCommandError.invalidWindowIndex,
        invalidTabAddress: SafariTabCommandError.invalidTabAddress
    )
    #expect(identified.address == .identifier(42))
    #expect(identified.tabIndex == 3)
    #expect(identified.remainingArguments == ["https://example.com"])

    #expect(throws: SafariTabCommandError.invalidTabAddress("42", "x")) {
        try SafariTabAddressArgumentParser.parseRequiredAddress(
            positionalArguments: ["x"],
            windowIdentifier: 42,
            missingWindowIndex: { SafariTabCommandError.missingWindowIndex },
            missingTabAddress: { SafariTabCommandError.missingTabAddress },
            invalidWindowIndex: SafariTabCommandError.invalidWindowIndex,
            invalidTabAddress: SafariTabCommandError.invalidTabAddress
        )
    }
}

@Test func safariTabListAddressedURLsParserParsesWindowAndTabGroupContexts() async throws {
    let indexed = try SafariTabListAddressedURLsArguments.parse([
        "--window-index=2",
        "https://example.com"
    ])
    #expect(indexed.context == .window(.index(2)))
    #expect(indexed.urls == ["https://example.com"])

    let identified = try SafariTabListAddressedURLsArguments.parse([
        "--window-id",
        "42",
        "https://example.com"
    ])
    #expect(identified.context == .window(.identifier(42)))
    #expect(identified.urls == ["https://example.com"])

    let tabGroup = try SafariTabListAddressedURLsArguments.parse([
        "--tab-group-profile=Twisto",
        "--tab-group-name",
        "Focus",
        "https://example.com"
    ])
    #expect(tabGroup.context == .tabGroup(profileName: "Twisto", name: "Focus"))
    #expect(tabGroup.urls == ["https://example.com"])
}

@Test func safariTabListAddressedURLsParserPreservesWindowOptionErrors() async throws {
    #expect(throws: SafariTabListCommandError.missingOptionValue("--window-id")) {
        try SafariTabListAddressedURLsArguments.parse([
            "--window-id=",
            "https://example.com"
        ])
    }

    #expect(throws: SafariTabCommandError.invalidWindowIndex("0")) {
        try SafariTabListAddressedURLsArguments.parse([
            "--window-index",
            "0",
            "https://example.com"
        ])
    }
}

@Test func safariWindowAddressCommandsUseSharedEqualsFormParsing() async throws {
    var openedWindowIdentifier: Int?
    let openCommand = SafariTabOpenCommand(
        executor: ParserTestAppleScriptExecutor(),
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        openTabByIdentifier: { windowIdentifier, _, _ in openedWindowIdentifier = windowIdentifier }
    )
    #expect(try openCommand.execute(arguments: ["--window-id=42"]) == "Safari tab opened in window id 42.")
    #expect(openedWindowIdentifier == 42)
}

private final class ParserTestAppleScriptExecutor: SafariAppleScriptExecuting {
    func execute(script: String) throws -> NSAppleEventDescriptor? {
        nil
    }
}
