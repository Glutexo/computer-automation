public enum CLIError: Error, Equatable {
    case missingModule
    case missingCommand(moduleName: String)
    case unknownModule(String)
    case unknownCommand(moduleName: String, commandName: String)
    case missingShellName
    case missingHomeDirectory
    case unsupportedShell(String)
}
