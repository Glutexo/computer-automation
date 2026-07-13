import ComputerAutomationKit
import Darwin
import Foundation

@main
struct ComputerAutomationLiveSafariRegressionApp {
    private static let cliModeArgument = "--computer-automation-cli"

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())

        if arguments.first == cliModeArgument {
            runCLI(arguments: Array(arguments.dropFirst()))
            return
        }

        do {
            let commandRunner = try LiveSafariCommandRunner.load(
                defaultExecutableURL: try currentExecutableURL(),
                defaultArgumentPrefix: [cliModeArgument]
            )
            try LiveSafariRegression(commandRunner: commandRunner).run()
            print("Live Safari critical flows completed.")
        } catch {
            fputs("Live Safari regression failed: \(errorDescription(error))\n", stderr)
            exit(1)
        }
    }

    private static func runCLI(arguments: [String]) {
        do {
            let output = try ComputerAutomationCLI.run(arguments: arguments)
            if !output.isEmpty {
                print(output)
            }
        } catch {
            let message = ComputerAutomationErrorRenderer.message(for: error)
            fputs("CLI error: \(message)\n", stderr)
            exit(1)
        }
    }

    private static func currentExecutableURL() throws -> URL {
        guard let executableURL = Bundle.main.executableURL else {
            throw LiveSafariRegressionError.executableURLUnavailable
        }
        return executableURL
    }
}

private struct LiveSafariRegression {
    let commandRunner: LiveSafariCommandRunner

    func run() throws {
        let configuration = try LiveSafariTestConfiguration.load()
        let token = UUID().uuidString.lowercased()
        let groupName = "\(configuration.groupNamePrefix)-\(token)"
        let urls = try configuration.urls(token: token)

        var cleanup = LiveSafariCleanup(commandRunner: commandRunner)
        defer {
            cleanup.run()
        }

        let openWindowOutput = try cleanup.runCLIJSON(["--json", "safari", "open-window", configuration.profileName])
        let windowIdentifier = try intValue(openWindowOutput, forKey: "windowId")
        cleanup.trackWindow(identifier: windowIdentifier)

        try expectEqual(
            try stringValue(openWindowOutput, forKey: "profileName"),
            configuration.profileName,
            "opened window profile"
        )

        let windowsOutput = try cleanup.runCLIJSON(["--json", "safari", "windows"])
        let windows = try objectArray(windowsOutput, forKey: "windows")
        let openedWindow = try required(window(in: windows, identifier: windowIdentifier), "opened Safari window")
        try expectEqual(
            try stringValue(openedWindow, forKey: "profileName"),
            configuration.profileName,
            "listed window profile"
        )

        _ = try cleanup.runCLI(["safari", "open-tab", "--window-id", String(windowIdentifier), urls.first])

        let windowTabsAfterOpen = try cleanup.runCLIJSON(["--json", "safari", "window-tabs", "--window-id", String(windowIdentifier)])
        let openedTab = try required(
            tab(in: try objectArray(windowTabsAfterOpen, forKey: "tabs"), url: urls.first),
            "opened Safari tab"
        )
        let openedTabIndex = try intValue(openedTab, forKey: "tabIndex")

        _ = try cleanup.runCLI([
            "safari",
            "set-tab-url",
            "--window-id",
            String(windowIdentifier),
            String(openedTabIndex),
            urls.second
        ])

        let resolvedTabOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "resolve-tab",
            urls.second,
            "--window-id",
            String(windowIdentifier)
        ])
        let resolvedTab = try objectValue(resolvedTabOutput, forKey: "match")
        try expectEqual(try intValue(resolvedTab, forKey: "windowId"), windowIdentifier, "resolved tab window id")

        let resolvedTabIndex = try intValue(resolvedTab, forKey: "tabIndex")
        let javaScriptOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "execute-tab-javascript",
            String(windowIdentifier),
            String(resolvedTabIndex),
            "String(6 * 7)"
        ])
        try expectEqual(try stringValue(javaScriptOutput, forKey: "result"), "42", "JavaScript result")

        let windowsBeforeGroupCreation = try objectArray(
            cleanup.runCLIJSON(["--json", "safari", "windows"]),
            forKey: "windows"
        )
        let windowIdentifiersBeforeGroupCreation = Set(try windowsBeforeGroupCreation.map {
            try intValue($0, forKey: "identifier")
        })

        let createdGroupOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "ensure-tab-group",
            configuration.profileName,
            groupName
        ])
        let createdGroup = try objectValue(createdGroupOutput, forKey: "tabGroup")
        let tabGroupIdentifier = try intValue(createdGroup, forKey: "identifier")
        cleanup.trackTabGroup(identifier: tabGroupIdentifier)

        try expectEqual(try stringValue(createdGroupOutput, forKey: "status"), "created", "created tab-group status")
        try expectEqual(
            try stringValue(createdGroup, forKey: "profileName"),
            configuration.profileName,
            "created tab-group profile"
        )
        try expectEqual(try stringValue(createdGroup, forKey: "name"), groupName, "created tab-group name")

        let reusedGroupOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "ensure-tab-group",
            configuration.profileName,
            groupName
        ])
        let reusedGroup = try objectValue(reusedGroupOutput, forKey: "tabGroup")
        try expectEqual(try stringValue(reusedGroupOutput, forKey: "status"), "reused", "reused tab-group status")
        try expectEqual(
            try intValue(reusedGroup, forKey: "identifier"),
            tabGroupIdentifier,
            "reused tab-group identifier"
        )

        let windowsAfterGroupCreation = try objectArray(
            cleanup.runCLIJSON(["--json", "safari", "windows"]),
            forKey: "windows"
        )
        let groupCreationWindowIdentifiers = Set(try windowsAfterGroupCreation.map {
            try intValue($0, forKey: "identifier")
        })
        .subtracting(windowIdentifiersBeforeGroupCreation)
        let groupCreationWindowIdentifier = try required(
            groupCreationWindowIdentifiers.first,
            "new saved tab-group creation window"
        )
        try expectEqual(groupCreationWindowIdentifiers.count, 1, "saved tab-group creation window count")
        _ = try cleanup.runCLI([
            "safari",
            "close-window",
            "--window-id",
            String(groupCreationWindowIdentifier)
        ])
        cleanup.forgetWindow(identifier: groupCreationWindowIdentifier)

        let baselineWindows = try liveSafariWindowStates(
            try objectArray(
                cleanup.runCLIJSON(["--json", "safari", "windows"]),
                forKey: "windows"
            )
        )

        let ensuredURLsOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "ensure-tab-list-urls",
            "--tab-group-profile",
            configuration.profileName,
            "--tab-group-name",
            groupName,
            urls.first,
            urls.second
        ])
        let addedURLs = Set(try stringArray(ensuredURLsOutput, forKey: "addedURLs"))
        try require(
            addedURLs.isSuperset(of: [urls.first, urls.second]),
            "Expected ensured URLs to include both live regression URLs."
        )
        let ensuredURLsContext = try objectValue(ensuredURLsOutput, forKey: "context")
        let ensuredURLsWindowIdentifier = try intValue(ensuredURLsContext, forKey: "windowIdentifier")
        try require(
            baselineWindows[ensuredURLsWindowIdentifier] == nil,
            "Expected saved-group URL ensure to use a new operation-owned Safari window."
        )
        try expectBaselineWindowStatesUnchanged(
            baselineWindows,
            currentWindows: try liveSafariWindowStates(
                try objectArray(
                    cleanup.runCLIJSON(["--json", "safari", "windows"]),
                    forKey: "windows"
                )
            ),
            operation: "saved-group URL ensure"
        )
        _ = try cleanup.runCLI([
            "safari",
            "close-window",
            "--window-id",
            String(ensuredURLsWindowIdentifier)
        ])
        cleanup.forgetWindow(identifier: ensuredURLsWindowIdentifier)

        let reorderedURLsOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "reorder-tab-list-urls",
            "--tab-group-profile",
            configuration.profileName,
            "--tab-group-name",
            groupName,
            urls.second,
            urls.first
        ])
        try require(
            try stringArray(reorderedURLsOutput, forKey: "missingURLs").isEmpty,
            "Expected reordered saved tab group to report no missing URLs."
        )
        let reorderedURLsContext = try objectValue(reorderedURLsOutput, forKey: "context")
        let reorderedURLsWindowIdentifier = try intValue(reorderedURLsContext, forKey: "windowIdentifier")
        try require(
            baselineWindows[reorderedURLsWindowIdentifier] == nil,
            "Expected saved-group URL reorder to use a new operation-owned Safari window."
        )
        try expectBaselineWindowStatesUnchanged(
            baselineWindows,
            currentWindows: try liveSafariWindowStates(
                try objectArray(
                    cleanup.runCLIJSON(["--json", "safari", "windows"]),
                    forKey: "windows"
                )
            ),
            operation: "saved-group URL reorder"
        )

        let tabGroupTabsOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "tab-group-tabs",
            String(tabGroupIdentifier)
        ])
        let tabGroupURLs = try objectArray(tabGroupTabsOutput, forKey: "tabs").map { tab in
            try stringValue(tab, forKey: "url")
        }
        try expectEqual(Array(tabGroupURLs.prefix(2)), [urls.second, urls.first], "saved tab-group URL order")

        let deletedGroupOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "delete-tab-group",
            String(tabGroupIdentifier)
        ])
        let deletedGroup = try objectValue(deletedGroupOutput, forKey: "tabGroup")
        try expectEqual(
            try intValue(deletedGroup, forKey: "identifier"),
            tabGroupIdentifier,
            "deleted tab-group identifier"
        )
        cleanup.forgetTabGroup(identifier: tabGroupIdentifier)

        let findDeletedGroupOutput = try cleanup.runCLIJSON([
            "--json",
            "safari",
            "find-tab-group",
            configuration.profileName,
            groupName
        ])
        try require(
            try objectArray(findDeletedGroupOutput, forKey: "matches").isEmpty,
            "Expected deleted tab group lookup to return no matches."
        )
    }
}

private struct LiveSafariTestConfiguration {
    let profileName: String
    let groupNamePrefix: String
    let firstURLOverride: String?
    let secondURLOverride: String?

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> LiveSafariTestConfiguration {
        LiveSafariTestConfiguration(
            profileName: try requiredEnvironmentValue("SAFARI_LIVE_TEST_PROFILE", in: environment),
            groupNamePrefix: try optionalEnvironmentValue(
                "SAFARI_LIVE_TEST_GROUP_PREFIX",
                in: environment
            ) ?? "computer-automation-live",
            firstURLOverride: try optionalEnvironmentValue("SAFARI_LIVE_TEST_URL_1", in: environment),
            secondURLOverride: try optionalEnvironmentValue("SAFARI_LIVE_TEST_URL_2", in: environment)
        )
    }

    func urls(token: String) throws -> (first: String, second: String) {
        let urls: (first: String, second: String) = (
            first: firstURLOverride ?? "https://example.com/?computer-automation-live=\(token)-1",
            second: secondURLOverride ?? "https://example.org/?computer-automation-live=\(token)-2"
        )

        guard urls.first != urls.second else {
            throw LiveSafariTestConfigurationError.duplicateURLs
        }

        return urls
    }

    private static func requiredEnvironmentValue(
        _ name: String,
        in environment: [String: String]
    ) throws -> String {
        guard let value = try optionalEnvironmentValue(name, in: environment) else {
            throw LiveSafariTestConfigurationError.missingEnvironmentValue(name)
        }

        return value
    }

    private static func optionalEnvironmentValue(
        _ name: String,
        in environment: [String: String]
    ) throws -> String? {
        guard let value = environment[name] else {
            return nil
        }

        guard !value.isEmpty else {
            throw LiveSafariTestConfigurationError.emptyEnvironmentValue(name)
        }

        return value
    }
}

private enum LiveSafariTestConfigurationError: Error, CustomStringConvertible {
    case missingEnvironmentValue(String)
    case emptyEnvironmentValue(String)
    case duplicateURLs

    var description: String {
        switch self {
        case .missingEnvironmentValue(let name):
            "Missing \(name). Set it before running the live Safari regression executable."
        case .emptyEnvironmentValue(let name):
            "\(name) must not be empty."
        case .duplicateURLs:
            "SAFARI_LIVE_TEST_URL_1 and SAFARI_LIVE_TEST_URL_2 must be different."
        }
    }
}

private struct LiveSafariCommandRunner {
    let executableURL: URL
    let argumentPrefix: [String]
    let packageRootURL: URL
    let timeout: TimeInterval

    static func load(
        defaultExecutableURL: URL,
        defaultArgumentPrefix: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> LiveSafariCommandRunner {
        let packageRootURL = try packageRoot()
        let timeout = try commandTimeout(environment: environment)
        let commandTarget = try executableTarget(
            environment: environment,
            defaultExecutableURL: defaultExecutableURL,
            defaultArgumentPrefix: defaultArgumentPrefix,
            packageRootURL: packageRootURL
        )

        return LiveSafariCommandRunner(
            executableURL: commandTarget.executableURL,
            argumentPrefix: commandTarget.argumentPrefix,
            packageRootURL: packageRootURL,
            timeout: timeout
        )
    }

    func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = argumentPrefix + arguments
        process.currentDirectoryURL = packageRootURL

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
            }
            throw LiveSafariCommandRunnerError.commandTimedOut(
                arguments: arguments,
                timeout: timeout,
                executableURL: executableURL
            )
        }

        let output = String(decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: standardError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw LiveSafariCommandRunnerError.commandFailed(
                arguments: arguments,
                status: process.terminationStatus,
                output: output,
                errorOutput: errorOutput,
                executableURL: executableURL
            )
        }

        return output
    }

    private static func executableTarget(
        environment: [String: String],
        defaultExecutableURL: URL,
        defaultArgumentPrefix: [String],
        packageRootURL: URL
    ) throws -> (executableURL: URL, argumentPrefix: [String]) {
        if let rawPath = environment["SAFARI_LIVE_TEST_CLI"], !rawPath.isEmpty {
            let url = URL(fileURLWithPath: rawPath, relativeTo: rawPath.hasPrefix("/") ? nil : packageRootURL)
                .standardizedFileURL
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw LiveSafariCommandRunnerError.executableNotFound(url.path)
            }
            return (url, [])
        }

        return (defaultExecutableURL, defaultArgumentPrefix)
    }

    private static func commandTimeout(environment: [String: String]) throws -> TimeInterval {
        guard let rawValue = environment["SAFARI_LIVE_TEST_COMMAND_TIMEOUT_SECONDS"] else {
            return 120
        }

        guard let value = TimeInterval(rawValue), value > 0 else {
            throw LiveSafariCommandRunnerError.invalidTimeout(rawValue)
        }

        return value
    }

    private static func packageRoot() throws -> URL {
        var currentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while currentURL.path != "/" {
            if FileManager.default.fileExists(atPath: currentURL.appendingPathComponent("Package.swift").path) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        throw LiveSafariCommandRunnerError.packageRootNotFound
    }
}

private enum LiveSafariCommandRunnerError: Error, CustomStringConvertible {
    case packageRootNotFound
    case executableNotFound(String)
    case invalidTimeout(String)
    case commandTimedOut(arguments: [String], timeout: TimeInterval, executableURL: URL)
    case commandFailed(arguments: [String], status: Int32, output: String, errorOutput: String, executableURL: URL)

    var description: String {
        switch self {
        case .packageRootNotFound:
            "Could not locate Package.swift for the live Safari regression."
        case .executableNotFound(let path):
            "Could not find executable computer-automation at \(path)."
        case .invalidTimeout(let value):
            "SAFARI_LIVE_TEST_COMMAND_TIMEOUT_SECONDS must be a positive number, got \(value)."
        case .commandTimedOut(let arguments, let timeout, let executableURL):
            "Live Safari command timed out after \(timeout) seconds: \(executableURL.path) \(arguments.joined(separator: " "))"
        case .commandFailed(let arguments, let status, let output, let errorOutput, let executableURL):
            [
                "Live Safari command failed with status \(status): \(executableURL.path) \(arguments.joined(separator: " "))",
                "stdout:",
                output,
                "stderr:",
                errorOutput
            ].joined(separator: "\n")
        }
    }
}

private struct LiveSafariCleanup {
    let commandRunner: LiveSafariCommandRunner
    private var windowIdentifiers = Set<Int>()
    private var tabGroupIdentifiers = Set<Int>()

    init(commandRunner: LiveSafariCommandRunner) {
        self.commandRunner = commandRunner
    }

    mutating func runCLI(_ arguments: [String]) throws -> String {
        let existingWindowIdentifiers = try currentWindowIdentifiers()
        do {
            let output = try commandRunner.run(arguments)
            trackNewWindows(excluding: existingWindowIdentifiers)
            return output
        } catch {
            trackNewWindows(excluding: existingWindowIdentifiers)
            throw error
        }
    }

    mutating func runCLIJSON(_ arguments: [String]) throws -> [String: Any] {
        try jsonObject(from: runCLI(arguments))
    }

    mutating func trackWindow(identifier: Int) {
        windowIdentifiers.insert(identifier)
    }

    mutating func trackTabGroup(identifier: Int) {
        tabGroupIdentifiers.insert(identifier)
    }

    mutating func forgetTabGroup(identifier: Int) {
        tabGroupIdentifiers.remove(identifier)
    }

    mutating func forgetWindow(identifier: Int) {
        windowIdentifiers.remove(identifier)
    }

    func run() {
        for tabGroupIdentifier in tabGroupIdentifiers {
            do {
                _ = try commandRunner.run([
                    "safari",
                    "delete-tab-group",
                    String(tabGroupIdentifier)
                ])
            } catch {
                fputs("Failed to delete live Safari regression tab group \(tabGroupIdentifier): \(errorDescription(error))\n", stderr)
            }
        }

        for windowIdentifier in windowIdentifiers {
            do {
                _ = try commandRunner.run([
                    "safari",
                    "close-window",
                    "--window-id",
                    String(windowIdentifier)
                ])
            } catch {
                fputs("Failed to close live Safari regression window \(windowIdentifier): \(errorDescription(error))\n", stderr)
            }
        }
    }

    private mutating func trackNewWindows(excluding existingWindowIdentifiers: Set<Int>) {
        do {
            windowIdentifiers.formUnion(try currentWindowIdentifiers().subtracting(existingWindowIdentifiers))
        } catch {
            fputs("Failed to track live Safari regression windows for cleanup: \(errorDescription(error))\n", stderr)
        }
    }

    private func currentWindowIdentifiers() throws -> Set<Int> {
        let windowsOutput = try jsonObject(from: commandRunner.run(["--json", "safari", "windows"]))
        return Set(try objectArray(windowsOutput, forKey: "windows").compactMap { window in
            window["identifier"] as? Int
        })
    }
}

private struct LiveSafariWindowState: Equatable {
    let identifier: Int
    let profileName: String?
    let selectedTabGroupIdentifier: Int?
    let tabGroupName: String?
}

private func liveSafariWindowStates(_ windows: [[String: Any]]) throws -> [Int: LiveSafariWindowState] {
    try Dictionary(uniqueKeysWithValues: windows.map { window in
        let identifier = try intValue(window, forKey: "identifier")
        return (
            identifier,
            LiveSafariWindowState(
                identifier: identifier,
                profileName: window["profileName"] as? String,
                selectedTabGroupIdentifier: window["selectedTabGroupIdentifier"] as? Int,
                tabGroupName: window["tabGroupName"] as? String
            )
        )
    })
}

private func expectBaselineWindowStatesUnchanged(
    _ baselineWindows: [Int: LiveSafariWindowState],
    currentWindows: [Int: LiveSafariWindowState],
    operation: String
) throws {
    let currentBaselineWindows = currentWindows.filter { baselineWindows[$0.key] != nil }
    try expectEqual(
        currentBaselineWindows,
        baselineWindows,
        "baseline Safari windows after \(operation)"
    )
}

private enum LiveSafariRegressionError: Error, CustomStringConvertible {
    case executableURLUnavailable
    case expectationFailed(String)

    var description: String {
        switch self {
        case .executableURLUnavailable:
            "Could not resolve the live Safari regression executable path."
        case .expectationFailed(let message):
            message
        }
    }
}

private func jsonObject(from value: String) throws -> [String: Any] {
    let data = Data(value.utf8)
    return try required(JSONSerialization.jsonObject(with: data) as? [String: Any], "top-level JSON object")
}

private func objectValue(_ object: [String: Any], forKey key: String) throws -> [String: Any] {
    try required(object[key] as? [String: Any], "JSON object field \(key)")
}

private func objectArray(_ object: [String: Any], forKey key: String) throws -> [[String: Any]] {
    try required(object[key] as? [[String: Any]], "JSON object array field \(key)")
}

private func stringArray(_ object: [String: Any], forKey key: String) throws -> [String] {
    try required(object[key] as? [String], "JSON string array field \(key)")
}

private func intValue(_ object: [String: Any], forKey key: String) throws -> Int {
    try required(object[key] as? Int, "JSON integer field \(key)")
}

private func stringValue(_ object: [String: Any], forKey key: String) throws -> String {
    try required(object[key] as? String, "JSON string field \(key)")
}

private func window(in windows: [[String: Any]], identifier: Int) -> [String: Any]? {
    windows.first { window in
        window["identifier"] as? Int == identifier
    }
}

private func tab(in tabs: [[String: Any]], url: String) -> [String: Any]? {
    tabs.first { tab in
        tab["url"] as? String == url
    }
}

private func required<T>(_ value: T?, _ description: String) throws -> T {
    guard let value else {
        throw LiveSafariRegressionError.expectationFailed("Expected \(description).")
    }
    return value
}

private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else {
        throw LiveSafariRegressionError.expectationFailed(message)
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ description: String) throws {
    guard actual == expected else {
        throw LiveSafariRegressionError.expectationFailed(
            "Expected \(description) to be \(expected), got \(actual)."
        )
    }
}

private func errorDescription(_ error: Error) -> String {
    if let error = error as? LiveSafariTestConfigurationError {
        return error.description
    }
    if let error = error as? LiveSafariCommandRunnerError {
        return error.description
    }
    if let error = error as? LiveSafariRegressionError {
        return error.description
    }
    return ComputerAutomationErrorRenderer.message(for: error)
}
