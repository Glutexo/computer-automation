import AutomationFoundation

public enum SafariAppleScriptModule: ModuleModel {
    public static let descriptor = ModuleDescriptor(
        name: "safari-applescript",
        abstract: "Safari AppleScript automation models.",
        models: [
            SafariAppleScriptApplication.descriptor,
            SafariAppleScriptWindow.descriptor,
            SafariAppleScriptTab.descriptor,
            SafariAppleScriptApplicationMenuBar.descriptor,
            SafariAppleScriptMenu.descriptor,
            SafariAppleScriptMenuItem.descriptor
        ]
    )

    public static func execute(commandName: String, arguments: [String]) throws -> String {
        throw CLIError.unknownCommand(moduleName: descriptor.name, commandName: commandName)
    }
}
