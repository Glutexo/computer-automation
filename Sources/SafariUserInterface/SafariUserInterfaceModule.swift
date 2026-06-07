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
        throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
    }
}
