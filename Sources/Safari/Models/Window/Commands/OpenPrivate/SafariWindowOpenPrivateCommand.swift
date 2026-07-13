import AutomationFoundation
import Foundation
import SafariAppleScript
import SafariUserInterface

public struct SafariWindowOpenPrivateCommand: CommandModel, JSONCommandModel {
    public static let descriptor = CommandDescriptor(
        name: "open-private-window",
        abstract: "Open a new private Safari browser window.",
        operation: .create,
        arguments: []
    )

    private let executor: SafariAppleScriptExecuting
    private let openPrivateWindow: (SafariAppleScriptExecuting) throws -> Void
    private let listWindows: (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord]
    private let resolvePrivateState: (Int) -> Bool?
    private let closeWindow: (Int, SafariAppleScriptExecuting) throws -> Void
    private let sleep: (TimeInterval) -> Void

    public init() {
        self.executor = SafariAppleScriptExecutor()
        self.openPrivateWindow = SafariFileMenu.openPrivateWindow
        self.listWindows = SafariAppleScriptWindow.list
        self.resolvePrivateState = { windowIdentifier in
            try? SafariWindow.loadWindowStateByWindowIdentifier()[windowIdentifier]?.isPrivate
        }
        self.closeWindow = SafariAppleScriptWindow.close(windowIdentifier:executor:)
        self.sleep = Thread.sleep
    }

    init(
        executor: SafariAppleScriptExecuting,
        openPrivateWindow: @escaping (SafariAppleScriptExecuting) throws -> Void = SafariFileMenu.openPrivateWindow,
        listWindows: @escaping (SafariAppleScriptExecuting) throws -> [SafariAppleScriptWindowRecord] = SafariAppleScriptWindow.list,
        resolvePrivateState: @escaping (Int) -> Bool? = { _ in nil },
        closeWindow: @escaping (Int, SafariAppleScriptExecuting) throws -> Void = SafariAppleScriptWindow.close(windowIdentifier:executor:),
        sleep: @escaping (TimeInterval) -> Void = Thread.sleep
    ) {
        self.executor = executor
        self.openPrivateWindow = openPrivateWindow
        self.listWindows = listWindows
        self.resolvePrivateState = resolvePrivateState
        self.closeWindow = closeWindow
        self.sleep = sleep
    }

    public func execute(arguments: [String] = []) throws -> String {
        try openPrivateWindowResult().text
    }

    public func executeJSON(arguments: [String] = []) throws -> String {
        try CommandJSONEncoder.encode(openPrivateWindowResult())
    }

    private func openPrivateWindowResult() throws -> SafariWindowCreationResult {
        let existingWindowIdentifiers = try SafariWindowCreation.currentWindowIdentifiers(
            executor: executor,
            listWindows: listWindows
        )

        do {
            try openPrivateWindow(executor)
        } catch SafariUserInterfaceError.privateWindowMenuItemNotFound {
            try SafariWindowCreation.rollbackNewWindows(
                excluding: existingWindowIdentifiers,
                executor: executor,
                listWindows: listWindows,
                closeWindow: closeWindow
            )
            throw SafariWindowCommandError.privateWindowMenuItemNotFound
        } catch {
            try SafariWindowCreation.rollbackNewWindows(
                excluding: existingWindowIdentifiers,
                executor: executor,
                listWindows: listWindows,
                closeWindow: closeWindow
            )
            throw error
        }

        guard let window = try SafariWindowCreation.waitForNewWindow(
            excluding: existingWindowIdentifiers,
            executor: executor,
            listWindows: listWindows,
            sleep: sleep
        ) else {
            throw SafariWindowCommandError.openedWindowIdentifierNotFound
        }

        if resolvePrivateState(window.identifier) == false {
            try closeWindow(window.identifier, executor)
            throw SafariWindowCommandError.openedPrivateWindowStateMismatch(window.identifier)
        }

        return SafariWindowCreationResult(
            message: "Safari private window opened.",
            windowId: window.identifier,
            profileName: nil,
            isPrivate: true
        )
    }
}
