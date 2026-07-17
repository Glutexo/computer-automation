import ComputerAutomationKit
import MCP

public actor ComputerAutomationMCPSerializedExecutor {
    private let dispatcher: ComputerAutomationMCPToolDispatcher

    public init(dispatcher: ComputerAutomationMCPToolDispatcher) {
        self.dispatcher = dispatcher
    }

    public func call(name: String, arguments: [String: Value]) throws -> CallTool.Result {
        try dispatcher.call(name: name, arguments: arguments)
    }
}

public enum ComputerAutomationMCPServer {
    public static let name = "computer-automation"
    public static let version = "0.1.0"

    public static func make(
        mode: ComputerAutomationMCPMode,
        executeCommand: @escaping ComputerAutomationMCPToolDispatcher.CommandExecutor = ComputerAutomationCLI.run
    ) async -> Server {
        let catalog = ComputerAutomationMCPToolCatalog(mode: mode)
        let executor = ComputerAutomationMCPSerializedExecutor(
            dispatcher: ComputerAutomationMCPToolDispatcher(
                catalog: catalog,
                executeCommand: executeCommand
            )
        )
        let server = Server(
            name: name,
            version: version,
            title: "Computer Automation",
            instructions: instructions(for: mode),
            capabilities: .init(tools: .init())
        )

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: catalog.availableTools.map { $0.mcpTool() })
        }

        await server.withMethodHandler(CallTool.self) { parameters in
            do {
                return try await executor.call(
                    name: parameters.name,
                    arguments: parameters.arguments ?? [:]
                )
            } catch ComputerAutomationMCPToolError.unknownTool(let name) {
                throw MCPError.invalidParams("Unknown tool \(name).")
            }
        }

        return server
    }

    public static func run(mode: ComputerAutomationMCPMode) async throws {
        let server = await make(mode: mode)
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }

    private static func instructions(for mode: ComputerAutomationMCPMode) -> String {
        switch mode {
        case .readOnly:
            "This local server exposes read-only Safari automation tools. Restart it with --allow-mutations to expose tools that change Safari state."
        case .allCommands:
            "This local server exposes read and mutation tools for Safari. Mutation tools can change or delete Safari state; obtain user approval before calling them."
        }
    }
}
