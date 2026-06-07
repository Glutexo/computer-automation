import AutomationFoundation

public enum SafariModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari",
        abstract: "Automation commands for Safari.",
        commands: [
            SafariLaunchCommand.descriptor
        ]
    )

    public static func execute(commandName: String, arguments: [String]) throws -> String {
        switch commandName {
        case SafariLaunchCommand.descriptor.name:
            return try SafariLaunchCommand().execute(arguments: arguments)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
