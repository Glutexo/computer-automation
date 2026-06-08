import AutomationFoundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenPrivateCommand: CommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-private-window",
        abstract: "Open a new private Safari browser window.",
        operation: .create,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let openPrivateWindow: (SafariAppleScriptExecuting) throws -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.openPrivateWindow = SafariFileMenu.openPrivateWindow
    }

    init(
        executor: SafariAppleScriptExecuting,
        openPrivateWindow: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openPrivateWindow
    ) {
        self.executor = executor
        self.openPrivateWindow = openPrivateWindow
    }

    public func execute(arguments: [String] = []) throws -> String {
        do {
            try openPrivateWindow(executor)
        } catch SafariUserInterfaceError.privateWindowMenuItemNotFound {
            throw SafariWindowCommandError.privateWindowMenuItemNotFound
        }

        return "Safari private window opened."
    }
}
