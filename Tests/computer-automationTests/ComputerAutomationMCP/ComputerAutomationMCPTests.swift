import Foundation
import MCP
import Testing
@testable import AutomationFoundation
@testable import ComputerAutomationKit
@testable import ComputerAutomationMCP

@Test func readOnlyMCPModeOmitsEveryMutatingCommand() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .readOnly)
    let names = Set(catalog.availableTools.map(\.name))

    #expect(names.contains("safari_running"))
    #expect(names.contains("safari_windows"))
    #expect(names.contains("safari_find_tab"))
    #expect(names.contains("safari_ui_menu_items"))
    #expect(!names.contains("safari_launch"))
    #expect(!names.contains("safari_close_window"))
    #expect(!names.contains("safari_execute_tab_javascript"))
    #expect(catalog.availableTools.allSatisfy { $0.isReadOnly })
}

@Test func mutationEnabledMCPModeExposesEveryCommandWithUniqueNames() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .allCommands)
    let expectedCount = ComputerAutomationCLI.modules.reduce(0) { count, module in
        count + module.commands.count
    }
    let names = catalog.availableTools.map(\.name)

    #expect(names.count == expectedCount)
    #expect(Set(names).count == names.count)
    #expect(names.contains("safari_launch"))
    #expect(names.contains("safari_delete_tab_group"))
    #expect(names.contains("safari_execute_tab_javascript"))
}

@Test func javascriptMCPToolIsMutatingAndAcceptsOnlyInlineSource() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .allCommands)
    let tool = try catalog.tool(named: "safari_execute_tab_javascript")

    #expect(!tool.isReadOnly)
    #expect(tool.arguments.map(\.name) == ["window-id", "tab-index", "javascript"])
    #expect(tool.arguments.allSatisfy { $0.isRequired })
    #expect(tool.mcpTool().annotations.readOnlyHint == false)
    #expect(tool.mcpTool().annotations.destructiveHint == true)

    #expect(throws: ComputerAutomationMCPToolError.self) {
        try tool.cliArguments(from: [
            "windowId": 42,
            "tabIndex": 1,
            "file": "/tmp/script.js"
        ])
    }
}

@Test func MCPToolSchemaUsesTypedCamelCaseArguments() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .readOnly)
    let tool = try catalog.tool(named: "safari_find_tab").mcpTool()
    let schema = try #require(tool.inputSchema.objectValue)
    let properties = try #require(schema["properties"]?.objectValue)

    #expect(properties["url"]?.objectValue?["type"] == "string")
    #expect(properties["prefix"]?.objectValue?["type"] == "boolean")
    #expect(properties["windowId"]?.objectValue?["type"] == "integer")
    #expect(properties["windowIndex"]?.objectValue?["type"] == "integer")
    #expect(properties["profile"]?.objectValue?["type"] == "string")
    #expect(schema["additionalProperties"] == false)
    #expect(schema["required"]?.arrayValue == ["url"])
}

@Test func numericCommandArgumentsPublishIntegerMetadata() throws {
    let integerNames: Set<String> = [
        "window-index",
        "window-id",
        "tab-index",
        "tab-group-identifier",
        "menu-bar-item-index",
        "menu-item-index"
    ]
    let arguments = ComputerAutomationCLI.modules.flatMap { module in
        module.commands.flatMap(\.arguments)
    }

    for argument in arguments where integerNames.contains(argument.name) {
        #expect(argument.valueType == .integer)
    }
}

@Test func MCPToolSchemaRepresentsMutuallyExclusiveAddressAlternatives() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .allCommands)
    let tool = try catalog.tool(named: "safari_open_tab")
    let schema = try #require(tool.mcpTool().inputSchema.objectValue)
    let allOf = try #require(schema["allOf"]?.arrayValue)
    let oneOf = try #require(allOf.first?.objectValue?["oneOf"]?.arrayValue)

    #expect(oneOf.count == 2)
    #expect(oneOf.contains { $0.objectValue?["required"]?.arrayValue == ["windowId"] })
    #expect(oneOf.contains { $0.objectValue?["required"]?.arrayValue == ["windowIndex"] })
}

@Test func MCPToolTranslatesNamedValuesIntoCLIArguments() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .allCommands)
    let findTab = try catalog.tool(named: "safari_find_tab")
    let findArguments = try findTab.cliArguments(from: [
        "url": "https://example.com",
        "prefix": true,
        "windowId": 42,
        "profile": "Twisto"
    ])

    #expect(findArguments == [
        "--prefix",
        "--window-id", "42",
        "--profile", "Twisto",
        "https://example.com"
    ])

    let ensureURLs = try catalog.tool(named: "safari_ensure_tab_list_urls")
    let ensureArguments = try ensureURLs.cliArguments(from: [
        "windowId": 42,
        "url": ["https://example.com", "https://openai.com"]
    ])

    #expect(ensureArguments == [
        "--window-id", "42",
        "https://example.com", "https://openai.com"
    ])
}

@Test func MCPToolRejectsMissingOrConflictingAddressAlternatives() throws {
    let catalog = ComputerAutomationMCPToolCatalog(mode: .allCommands)
    let tool = try catalog.tool(named: "safari_open_tab")

    #expect(throws: ComputerAutomationMCPToolError.self) {
        try tool.cliArguments(from: ["url": "https://example.com"])
    }
    #expect(throws: ComputerAutomationMCPToolError.self) {
        try tool.cliArguments(from: [
            "windowId": 42,
            "windowIndex": 1,
            "url": "https://example.com"
        ])
    }
}

@Test func MCPDispatcherCallsJSONCLIRouterAndReturnsStructuredContent() throws {
    let recorder = MCPArgumentRecorder(output: #"{"running":true}"#)
    let dispatcher = ComputerAutomationMCPToolDispatcher(
        catalog: ComputerAutomationMCPToolCatalog(mode: .readOnly),
        executeCommand: recorder.execute
    )

    let result = try dispatcher.call(name: "safari_running")

    #expect(recorder.arguments == ["--json", "safari", "running"])
    #expect(result.isError == false)
    #expect(result.structuredContent?.objectValue?["running"] == true)
    guard case .text(let text, _, _) = try #require(result.content.first) else {
        Issue.record("Expected text compatibility content")
        return
    }
    #expect(text == #"{"running":true}"#)
}

@Test func MCPDispatcherReturnsToolErrorWhenMutationsAreDisabled() throws {
    let recorder = MCPArgumentRecorder(output: #"{"message":"launched"}"#)
    let dispatcher = ComputerAutomationMCPToolDispatcher(
        catalog: ComputerAutomationMCPToolCatalog(mode: .readOnly),
        executeCommand: recorder.execute
    )

    let result = try dispatcher.call(name: "safari_launch")

    #expect(result.isError == true)
    #expect(recorder.arguments == nil)
    guard case .text(let text, _, _) = try #require(result.content.first) else {
        Issue.record("Expected mutation-disabled error text")
        return
    }
    #expect(text.contains("--allow-mutations"))
}

@Test func MCPServerCompletesAnInMemoryProtocolRoundTrip() async throws {
    let recorder = MCPArgumentRecorder(output: #"{"running":false}"#)
    let transports = await InMemoryTransport.createConnectedPair()
    let server = await ComputerAutomationMCPServer.make(
        mode: .readOnly,
        executeCommand: recorder.execute
    )
    try await server.start(transport: transports.server)

    let client = Client(name: "computer-automation-tests", version: "1.0.0")
    try await client.connect(transport: transports.client)

    let (tools, _) = try await client.listTools()
    #expect(tools.contains { $0.name == "safari_running" })
    #expect(!tools.contains { $0.name == "safari_launch" })

    let context: RequestContext<CallTool.Result> = try await client.callTool(name: "safari_running")
    let result = try await context.value
    #expect(result.isError == false)
    #expect(result.structuredContent?.objectValue?["running"] == false)
    #expect(recorder.arguments == ["--json", "safari", "running"])

    await client.disconnect()
    await server.stop()
}

@Test func MCPConfigurationDefaultsToReadOnlyAndRequiresExplicitMutationFlag() throws {
    #expect(try ComputerAutomationMCPConfiguration.parse(arguments: []).mode == .readOnly)
    #expect(
        try ComputerAutomationMCPConfiguration.parse(arguments: ["--allow-mutations"]).mode
            == .allCommands
    )
    #expect(throws: ComputerAutomationMCPConfigurationError.unknownArgument("--unknown")) {
        try ComputerAutomationMCPConfiguration.parse(arguments: ["--unknown"])
    }
}

private final class MCPArgumentRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let output: String
    private var recordedArguments: [String]?

    var arguments: [String]? {
        lock.withLock { recordedArguments }
    }

    init(output: String) {
        self.output = output
    }

    func execute(_ arguments: [String]) throws -> String {
        lock.withLock {
            recordedArguments = arguments
        }
        return output
    }
}
