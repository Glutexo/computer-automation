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

@Test func safariTabOpenCommandTargetsWindowIdentifier() async throws {
    var received: (Int, String?)?
    let command = SafariTabOpenCommand(
        executor: MockAppleScriptExecutor(),
        openTab: { _, _, _ in Issue.record("openTab should not be called") },
        openTabByIdentifier: { windowIdentifier, url, _ in received = (windowIdentifier, url) }
    )

    #expect(
        try command.execute(arguments: ["--window-id", "42", "https://example.com"]) ==
        "Safari tab opened in window id 42 with URL https://example.com."
    )
    #expect(received?.0 == 42)
    #expect(received?.1 == "https://example.com")
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
                SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com", title: "Home"),
                SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 2, url: "https://example.com/path", title: "Path"),
                SafariTabRecord(windowIdentifier: 43, windowIndex: 2, index: 1, url: "https://example.com", title: "Other window"),
                SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 3, url: "https://openai.com", title: "Other URL")
            ]
        },
        listWindows: { _ in
            [
                SafariWindowRecord(identifier: 43, index: 1, profileName: "Glutexo", name: "Glutexo"),
                SafariWindowRecord(identifier: 42, index: 2, profileName: "Twisto", name: "Twisto")
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

@Test func safariTabListAcrossProcessesAssignsGlobalWindowIndexesAndFiltersStaleWindows() async throws {
    let windows = [
        SafariProcessWindowRecord(
            processIdentifier: 4317,
            window: SafariAppleScriptWindowRecord(identifier: 42, name: "Glutexo")
        ),
        SafariProcessWindowRecord(
            processIdentifier: 9000,
            window: SafariAppleScriptWindowRecord(identifier: 42, name: "Twisto")
        )
    ]
    var queriedProcesses: [pid_t] = []

    let tabs = try SafariTab.listAcrossRunningProcesses(
        isRunning: { true },
        discoverWindows: { windows },
        listTabs: { processIdentifier in
            queriedProcesses.append(processIdentifier)
            if processIdentifier == 4317 {
                return [
                    SafariAppleScriptTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com", title: "Example"),
                    SafariAppleScriptTabRecord(windowIdentifier: 99, windowIndex: 2, index: 1, url: "https://stale.example", title: "Stale")
                ]
            }
            return [
                SafariAppleScriptTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://swift.org", title: "Swift")
            ]
        }
    )

    #expect(queriedProcesses == [4317, 9000])
    #expect(
        tabs == [
            SafariTabRecord(processId: 4317, windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com", title: "Example"),
            SafariTabRecord(processId: 9000, windowIdentifier: 42, windowIndex: 2, index: 1, url: "https://swift.org", title: "Swift")
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

    let unsupportedResult = SafariTabExecuteJavaScriptCommand(
        executor: MockAppleScriptExecutor(),
        executeJavaScript: { _, _, _, _ in
            throw SafariAppleScriptTabJavaScriptError.unsupportedResult(windowIdentifier: 42, tabIndex: 2)
        }
    )
    #expect(throws: SafariTabCommandError.javaScriptResultUnsupported(windowIdentifier: 42, tabIndex: 2)) {
        try unsupportedResult.execute(arguments: ["42", "2", "({ a: 1 })"])
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

@Test func safariTabSetURLCommandTargetsWindowIdentifier() async throws {
    var received: (Int, Int, String)?
    let command = SafariTabSetURLCommand(
        executor: MockAppleScriptExecutor(),
        setURL: { _, _, _, _ in Issue.record("setURL should not be called") },
        setURLByIdentifier: { windowIdentifier, tabIndex, url, _ in received = (windowIdentifier, tabIndex, url) }
    )

    #expect(
        try command.execute(arguments: ["--window-id=42", "3", "https://example.com"]) ==
        "Safari tab URL updated for window id 42 tab 3."
    )
    #expect(received?.0 == 42)
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

@Test func safariTabCloseCommandTargetsWindowIdentifier() async throws {
    var received: (Int, Int)?
    let command = SafariTabCloseCommand(
        executor: MockAppleScriptExecutor(),
        closeTab: { _, _, _ in Issue.record("closeTab should not be called"); return "" },
        closeTabByIdentifier: { windowIdentifier, tabIndex, _ in
            received = (windowIdentifier, tabIndex)
            return "Safari tab closed."
        }
    )

    #expect(try command.execute(arguments: ["--window-id", "42", "2"]) == "Safari tab closed.")
    #expect(received?.0 == 42)
    #expect(received?.1 == 2)
}

@Test func safariTabParseTabListMapsAppleScriptRecords() async throws {
    let descriptor = makeTabList([(42, 1, 1, "https://example.com"), (84, 2, 1, "")])
    #expect(
        SafariTab.parseTabList(descriptor) ==
        [
            SafariTabRecord(windowIdentifier: 42, windowIndex: 1, index: 1, url: "https://example.com"),
            SafariTabRecord(windowIdentifier: 84, windowIndex: 2, index: 1, url: "")
        ]
    )
}

@Test func safariTabMatchesLiveTabsAgainstSelectedTabGroupTabs() async throws {
    let liveTabs = [
        SafariTabRecord(windowIdentifier: 42, windowIndex: 2, index: 1, url: "https://example.com"),
        SafariTabRecord(windowIdentifier: 42, windowIndex: 2, index: 2, url: "https://changed.example"),
        SafariTabRecord(windowIdentifier: 42, windowIndex: 2, index: 3, url: "https://extra.example")
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
