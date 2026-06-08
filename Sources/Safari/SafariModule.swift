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
        switch commandName {
        case SafariApplicationLaunchCommand.descriptor.name:
            return try SafariApplicationLaunchCommand().execute(arguments: arguments)
        case SafariApplicationRunningCommand.descriptor.name:
            return try SafariApplicationRunningCommand().execute(arguments: arguments)
        case SafariApplicationQuitCommand.descriptor.name:
            return try SafariApplicationQuitCommand().execute(arguments: arguments)
        case SafariProfileListCommand.descriptor.name:
            return try SafariProfileListCommand().execute(arguments: arguments)
        case SafariWindowOpenCommand.descriptor.name:
            return try SafariWindowOpenCommand().execute(arguments: arguments)
        case SafariWindowOpenPrivateCommand.descriptor.name:
            return try SafariWindowOpenPrivateCommand().execute(arguments: arguments)
        case SafariWindowListCommand.descriptor.name:
            return try SafariWindowListCommand().execute(arguments: arguments)
        case SafariWindowCloseCommand.descriptor.name:
            return try SafariWindowCloseCommand().execute(arguments: arguments)
        case SafariTabGroupListCommand.descriptor.name:
            return try SafariTabGroupListCommand().execute(arguments: arguments)
        case SafariTabGroupListTabsCommand.descriptor.name:
            return try SafariTabGroupListTabsCommand().execute(arguments: arguments)
        case SafariTabOpenCommand.descriptor.name:
            return try SafariTabOpenCommand().execute(arguments: arguments)
        case SafariTabListCommand.descriptor.name:
            return try SafariTabListCommand().execute(arguments: arguments)
        case SafariTabSetURLCommand.descriptor.name:
            return try SafariTabSetURLCommand().execute(arguments: arguments)
        case SafariTabCloseCommand.descriptor.name:
            return try SafariTabCloseCommand().execute(arguments: arguments)
        default:
            throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
        }
    }
}
