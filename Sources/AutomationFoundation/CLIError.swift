import Foundation

public enum CLIError: Error, Equatable, LocalizedError {
    case missingModule
    case missingCommand(moduleName: String)
    case unknownModule(String)
    case unknownCommand(moduleName: String, commandName: String)
    case missingShellName
    case missingHomeDirectory
    case unsupportedShell(String)

    public var errorDescription: String? {
        switch self {
        case .missingModule:
            "Missing module name. Run computer-automation --help to see available modules."
        case .missingCommand(let moduleName):
            "Missing command for module \(moduleName). Run computer-automation \(moduleName) --help to see available commands."
        case .unknownModule(let moduleName):
            "Unknown module \(moduleName). Run computer-automation --help to see available modules."
        case .unknownCommand(let moduleName, let commandName):
            "Unknown command \(commandName) for module \(moduleName). Run computer-automation \(moduleName) --help to see available commands."
        case .missingShellName:
            "Missing shell name. Specify zsh after the completion option."
        case .missingHomeDirectory:
            "Could not determine the home directory required to install shell completion."
        case .unsupportedShell(let shellName):
            "Unsupported shell \(shellName). The supported shell is zsh."
        }
    }
}
