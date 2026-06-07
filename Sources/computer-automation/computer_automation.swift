import Darwin
import AutomationFoundation
import Safari

@main
struct ComputerAutomationApp {
    static func main() {
        do {
            let output = try run(arguments: Array(CommandLine.arguments.dropFirst()))
            if !output.isEmpty {
                print(output)
            }
        } catch {
            fputs("CLI error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws -> String {
        let modules = [SafariModule.descriptor]
        let executableName = "computer-automation"

        guard let firstArgument = arguments.first else {
            throw CLIError.missingModule
        }

        if firstArgument == "--complete" {
            let suggestions = CompletionEngine.suggestions(for: Array(arguments.dropFirst()), modules: modules)
            return suggestions.map(\.value).joined(separator: "\n")
        }

        if firstArgument == "--completion-script" {
            guard arguments.count >= 2 else {
                throw CLIError.missingShellName
            }

            switch arguments[1] {
            case "zsh":
                return ShellCompletionScriptRenderer.zsh(executableName: executableName)
            default:
                throw CLIError.unsupportedShell(arguments[1])
            }
        }

        if firstArgument == "--install-completion" {
            guard arguments.count >= 2 else {
                throw CLIError.missingShellName
            }

            switch arguments[1] {
            case "zsh":
                let result = try ShellCompletionInstaller.installZsh(executableName: executableName)
                var lines = ["Installed zsh completion to \(result.filePath)"]
                if result.requiresFpathUpdate {
                    lines.append("Add this directory to fpath: \(result.directoryPath)")
                    lines.append("Then run: autoload -Uz compinit && compinit")
                }
                return lines.joined(separator: "\n")
            default:
                throw CLIError.unsupportedShell(arguments[1])
            }
        }

        let moduleName = firstArgument
        guard let module = modules.first(where: { $0.name == moduleName }) else {
            throw CLIError.unknownModule(moduleName)
        }

        guard arguments.count >= 2 else {
            throw CLIError.missingCommand(moduleName: module.name)
        }

        let commandName = arguments[1]
        let commandArguments = Array(arguments.dropFirst(2))

        switch module.name {
        case SafariModule.descriptor.name:
            return try SafariModule.execute(commandName: commandName, arguments: commandArguments)
        default:
            throw CLIError.unknownModule(moduleName)
        }
    }
}
