import Darwin
import ComputerAutomationKit

@main
struct ComputerAutomationApp {
    static func main() {
        do {
            let output = try ComputerAutomationCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
            if !output.isEmpty {
                print(output)
            }
        } catch {
            fputs("CLI error: \(error)\n", stderr)
            exit(1)
        }
    }
}
