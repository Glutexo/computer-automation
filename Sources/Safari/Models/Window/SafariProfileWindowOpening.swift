import Foundation
import SafariAppleScript

enum SafariProfileWindowOpening {
    static func openNewDocumentFromExistingProfileWindow(
        profileName: String,
        excluding existingWindowIdentifiers: Set<Int>,
        executor: SafariAppleScriptExecuting,
        listWindows: () throws -> [SafariWindowRecord],
        focusWindow: (Int, SafariAppleScriptExecuting) throws -> Void,
        openNewDocument: (SafariAppleScriptExecuting) throws -> Void,
        sleep: (TimeInterval) -> Void = Thread.sleep,
        maxAttempts: Int = 10,
        interval: TimeInterval = 0.1
    ) throws -> SafariWindowRecord? {
        guard let sourceWindow = try listWindows().first(where: {
            existingWindowIdentifiers.contains($0.identifier) && window($0, matchesProfileName: profileName)
        }) else {
            return nil
        }

        try focusWindow(sourceWindow.identifier, executor)
        try openNewDocument(executor)

        return try waitForNewProfileWindow(
            profileName: profileName,
            excluding: existingWindowIdentifiers,
            listWindows: listWindows,
            sleep: sleep,
            maxAttempts: maxAttempts,
            interval: interval
        )
    }

    static func waitForNewProfileWindow(
        profileName: String,
        excluding existingWindowIdentifiers: Set<Int>,
        listWindows: () throws -> [SafariWindowRecord],
        sleep: (TimeInterval) -> Void = Thread.sleep,
        maxAttempts: Int = 10,
        interval: TimeInterval = 0.1
    ) throws -> SafariWindowRecord? {
        for attempt in 0..<max(1, maxAttempts) {
            if let profileWindow = try listWindows().first(where: {
                !existingWindowIdentifiers.contains($0.identifier) && window($0, matchesProfileName: profileName)
            }) {
                return profileWindow
            }

            if attempt < max(1, maxAttempts) - 1 {
                sleep(interval)
            }
        }

        return nil
    }

    static func window(_ window: SafariWindowRecord, matchesProfileName profileName: String) -> Bool {
        !window.isPrivate &&
        (
            window.profileName == profileName ||
            windowTitle(window.name, matchesProfileNamed: profileName)
        )
    }

    private static func windowTitle(_ title: String, matchesProfileNamed profileName: String) -> Bool {
        title == profileName || title.hasPrefix("\(profileName) —") || title.hasPrefix("\(profileName) -")
    }
}
