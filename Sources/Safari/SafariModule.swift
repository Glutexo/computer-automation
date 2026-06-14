import AutomationFoundation

public enum SafariModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari",
        abstract: "Automation commands for Safari.",
        models: [
            SafariApplication.descriptor,
            SafariProfile.descriptor,
            SafariWindow.descriptor,
            SafariTabGroup.descriptor,
            SafariTab.descriptor
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
        case SafariApplicationLaunchCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariApplicationLaunchCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariApplicationRunningCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariApplicationRunningCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariApplicationQuitCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariApplicationQuitCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariProfileListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariProfileListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowOpenCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowOpenCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowOpenPrivateCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowOpenPrivateCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowOpenTabGroupCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowOpenTabGroupCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowSetTabGroupCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowSetTabGroupCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariWindowCloseCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariWindowCloseCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabGroupListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabGroupListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabGroupListTabsCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabGroupListTabsCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabGroupCreateCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabGroupCreateCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabGroupDeleteCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabGroupDeleteCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabOpenCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabOpenCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabListCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabListCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabFindCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabFindCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabExecuteJavaScriptCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabExecuteJavaScriptCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabListWindowTabsCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabListWindowTabsCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabSetURLCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabSetURLCommand(), arguments: arguments, outputFormat: outputFormat)
        case SafariTabCloseCommand.descriptor.name:
            return try CommandOutputRenderer.execute(SafariTabCloseCommand(), arguments: arguments, outputFormat: outputFormat)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
