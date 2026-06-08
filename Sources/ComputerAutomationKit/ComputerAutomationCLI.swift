import AutomationFoundation
import Safari
import SafariUserInterface

public enum ComputerAutomationCLI {
    public static let executableName = "computer-automation"
    public static let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    public static func run(arguments: [String]) throws -> String {
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
        case SafariUserInterfaceModule.descriptor.name:
            return try SafariUserInterfaceModule.execute(commandName: commandName, arguments: commandArguments)
        default:
            throw CLIError.unknownModule(moduleName)
        }
    }
}
