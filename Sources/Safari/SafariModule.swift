import AutomationFoundation

public enum SafariModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari",
        abstract: "Automation commands for Safari.",
        models: [
            SafariApplication.descriptor,
            SafariProfile.descriptor
        ]
    )

    public static func execute(commandName: String, arguments: [String]) throws -> String {
        switch commandName {
        case SafariApplicationLaunchCommand.descriptor.name:
            return try SafariApplicationLaunchCommand().execute(arguments: arguments)
        case SafariApplicationRunningCommand.descriptor.name:
            return try SafariApplicationRunningCommand().execute(arguments: arguments)
        case SafariApplicationQuitCommand.descriptor.name:
            return try SafariApplicationQuitCommand().execute(arguments: arguments)
        case SafariProfileListCommand.descriptor.name:
            return try SafariProfileListCommand().execute(arguments: arguments)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
