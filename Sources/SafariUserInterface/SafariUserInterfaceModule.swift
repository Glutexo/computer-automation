import AutomationFoundation

public enum SafariUserInterfaceModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari-ui",
        abstract: "Safari user interface automation models.",
        models: [
            SafariApplicationMenuBar.descriptor,
            SafariFileMenu.descriptor,
            SafariMenuItem.descriptor
        ]
    )

    public static func execute(commandName: String, arguments: [String]) throws -> String {
        switch commandName {
        case SafariApplicationMenuBarListCommand.descriptor.name:
            return try SafariApplicationMenuBarListCommand().execute(arguments: arguments)
        case SafariFileMenuListCommand.descriptor.name:
            return try SafariFileMenuListCommand().execute(arguments: arguments)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
