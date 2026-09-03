import AutomationFoundation
import Foundation
import Safari
import SafariUserInterface

public enum ComputerAutomationCLI {
    public static let executableName = "computer-automation"
    public static let modules = [SafariModule.descriptor, SafariUserInterfaceModule.descriptor]

    public static func run(arguments: [String]) throws -> String {
        let outputFormat: CommandOutputFormat
        let effectiveArguments: [String]
        if arguments.first == "--json" {
            outputFormat = .json
            effectiveArguments = Array(arguments.dropFirst())
        } else {
            outputFormat = .text
            effectiveArguments = arguments
        }

        guard let firstArgument = effectiveArguments.first else {
            throw CLIError.missingModule
        }

        if effectiveArguments == ["--help"] {
            return topLevelHelp()
        }

        if firstArgument == "--complete" {
            let suggestions = CompletionEngine.suggestions(for: Array(effectiveArguments.dropFirst()), modules: modules)
            return suggestions.map(\.value).joined(separator: "\n")
        }

        if firstArgument == "--completion-script" {
            guard effectiveArguments.count >= 2 else {
                throw CLIError.missingShellName
            }

            switch effectiveArguments[1] {
            case "zsh":
                return ShellCompletionScriptRenderer.zsh(executableName: executableName)
            default:
                throw CLIError.unsupportedShell(effectiveArguments[1])
            }
        }

        if firstArgument == "--install-completion" {
            guard effectiveArguments.count >= 2 else {
                throw CLIError.missingShellName
            }

            switch effectiveArguments[1] {
            case "zsh":
                let result = try ShellCompletionInstaller.installZsh(executableName: executableName)
                var lines = ["Installed zsh completion to \(result.filePath)"]
                if result.requiresFpathUpdate {
                    lines.append("Add this directory to fpath: \(result.directoryPath)")
                    lines.append("Then run: autoload -Uz compinit && compinit")
                }
                return lines.joined(separator: "\n")
            default:
                throw CLIError.unsupportedShell(effectiveArguments[1])
            }
        }

        let moduleName = firstArgument
        guard let module = modules.first(where: { $0.name == moduleName }) else {
            throw CLIError.unknownModule(moduleName)
        }

        if Array(effectiveArguments.dropFirst()) == ["--help"] {
            return moduleHelp(module)
        }

        guard effectiveArguments.count >= 2 else {
            throw CLIError.missingCommand(moduleName: module.name)
        }

        let commandName = effectiveArguments[1]
        let commandArguments = Array(effectiveArguments.dropFirst(2))
        guard let command = module.commands.first(where: { $0.name == commandName }) else {
            throw CLIError.unknownCommand(moduleName: module.name, commandName: commandName)
        }

        if CommandArgumentPreflight.requestsHelp(commandArguments) {
            return CommandUsageRenderer.render(
                command: command,
                invocation: [executableName, module.name, command.name]
            )
        }

        try CommandArgumentPreflight.validate(command, arguments: commandArguments)

        switch module.name {
        case SafariModule.descriptor.name:
            return try SafariModule.execute(commandName: commandName, arguments: commandArguments, outputFormat: outputFormat)
        case SafariUserInterfaceModule.descriptor.name:
            return try SafariUserInterfaceModule.execute(commandName: commandName, arguments: commandArguments, outputFormat: outputFormat)
        default:
            throw CLIError.unknownModule(moduleName)
        }
    }

    private static func topLevelHelp() -> String {
        let moduleRows = modules.map { "  \($0.name)\t\($0.abstract)" }
        return ([
            "Usage: \(executableName) <module> <command> [arguments]",
            "",
            "Modules:"
        ] + moduleRows + [
            "",
            "Run \(executableName) <module> --help to list that module's commands."
        ]).joined(separator: "\n")
    }

    private static func moduleHelp(_ module: ModuleDescriptor) -> String {
        let commandRows = module.commands.map { "  \($0.name)\t\($0.abstract)" }
        return ([
            "Usage: \(executableName) \(module.name) <command> [arguments]",
            "",
            module.abstract,
            "",
            "Commands:"
        ] + commandRows + [
            "",
            "Run \(executableName) \(module.name) <command> --help for command usage."
        ]).joined(separator: "\n")
    }
}

public enum ComputerAutomationErrorRenderer {
    public static func message(for error: Error) -> String {
        if
            let description = (error as? LocalizedError)?.errorDescription?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty
        {
            return description
        }

        return "An unexpected error occurred."
    }
}
