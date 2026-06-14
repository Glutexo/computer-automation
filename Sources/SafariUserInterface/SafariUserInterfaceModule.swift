import AutomationFoundation

public enum SafariUserInterfaceModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari-ui",
        abstract: "Safari user interface automation models.",
        models: [
            SafariApplicationMenuBar.descriptor,
            SafariSidebar.descriptor,
            SafariToolbar.descriptor,
            SafariToolbarItem.descriptor,
            SafariMenu.descriptor,
            SafariFileMenu.descriptor,
            SafariMenuItem.descriptor
        ]
    )

    public static func execute(commandName: String, arguments: [String]) throws -> String {
        try execute(commandName: commandName, arguments: arguments, outputFormat: .text)
    }

    public static func execute(
        commandName: String,
        arguments: [String],
        outputFormat: CommandOutputFormat = .text
    ) throws -> String {
        switch commandName {
        case SafariApplicationMenuBarListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariApplicationMenuBarListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariMenuListItemsCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariMenuListItemsCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariFileMenuListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariFileMenuListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariMenuItemListChildItemsCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariMenuItemListChildItemsCommand(), arguments: arguments, outputFormat: outputFormat)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
