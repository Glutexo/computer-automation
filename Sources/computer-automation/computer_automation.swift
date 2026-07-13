import Darwin
import Foundation
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
            let message = ComputerAutomationErrorRenderer.message(for: error)
            fputs("CLI error: \(message)\n", stderr)
            exit(1)
        }
    }
}
