import ComputerAutomationMCP
import Darwin
import Foundation

@main
struct ComputerAutomationMCPApp {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] {
            print(Self.help)
            return
        }

        do {
            let configuration = try ComputerAutomationMCPConfiguration.parse(arguments: arguments)
            try await ComputerAutomationMCPServer.run(mode: configuration.mode)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "An unexpected error occurred."
            fputs("MCP server error: \(message)\n", stderr)
            exit(1)
        }
    }

    private static let help = """
        Usage: computer-automation-mcp [--allow-mutations]

        Run the local Computer Automation MCP server over standard input/output.
        By default, only read-only tools are exposed. Pass --allow-mutations to
        expose tools that can change Safari state.
        """
}
