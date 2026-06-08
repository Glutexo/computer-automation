import AppKit
import AutomationFoundation

public struct SafariAppleScriptMenuItemRecord: Equatable, Sendable {
    public let index: Int
    public let title: String
    public let commandCharacter: String?
    public let commandModifiers: String?

    public init(
        index: Int,
        title: String,
        commandCharacter: String? = nil,
        commandModifiers: String? = nil
    ) {
        self.index = index
        self.title = title
        self.commandCharacter = commandCharacter
        self.commandModifiers = commandModifiers
    }
}

public enum SafariAppleScriptMenuItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu-item",
        abstract: "AppleScript access to a Safari menu item.",
        commands: []
    )

    public static func listChildItems(
        menuBarItemIndex: Int,
        menuItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptMenuItemRecord] {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                tell menu 1 of menu item \(menuItemIndex) of menu 1 of menu bar item \(menuBarItemIndex) of menu bar 1
                    set outputItems to {}
                    repeat with itemIndex from 1 to count of menu items
                        set currentItem to menu item itemIndex
                        set currentName to name of currentItem
                        if currentName is missing value then set currentName to ""
                        set currentChar to value of attribute "AXMenuItemCmdChar" of currentItem
                        if currentChar is missing value then set currentChar to ""
                        set currentModifiers to value of attribute "AXMenuItemCmdModifiers" of currentItem
                        if currentModifiers is missing value then set currentModifiers to ""
                        copy {(itemIndex as text), currentName, (currentChar as text), (currentModifiers as text)} to end of outputItems
                    end repeat
                    return outputItems
                end tell
            end tell
        end tell
        """

        let result = try executor.execute(script: script)
        return parseRecordsWithKeyboardShortcut(from: result)
    }

    public static func parseRecordsWithIndexAndTitle(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariAppleScriptMenuItemRecord] {
        parseRecords(from: descriptor, expectedFieldCount: 2)
    }

    public static func parseRecordsWithKeyboardShortcut(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariAppleScriptMenuItemRecord] {
        parseRecords(from: descriptor, expectedFieldCount: 4)
    }

    private static func parseRecords(
        from descriptor: NSAppleEventDescriptor?,
        expectedFieldCount: Int
    ) -> [SafariAppleScriptMenuItemRecord] {
        guard let descriptor, descriptor.numberOfItems > 0 else {
            return []
        }

        var records: [SafariAppleScriptMenuItemRecord] = []

        for descriptorIndex in 1...descriptor.numberOfItems {
            guard
                let itemDescriptor = descriptor.atIndex(descriptorIndex),
                itemDescriptor.numberOfItems >= expectedFieldCount,
                let rawIndex = itemDescriptor.atIndex(1)?.stringValue,
                let index = Int(rawIndex),
                let title = itemDescriptor.atIndex(2)?.stringValue
            else {
                continue
            }

            let commandCharacter = normalized(itemDescriptor.atIndex(3)?.stringValue)
            let commandModifiers = normalized(itemDescriptor.atIndex(4)?.stringValue)

            records.append(
                SafariAppleScriptMenuItemRecord(
                    index: index,
                    title: title,
                    commandCharacter: commandCharacter,
                    commandModifiers: commandModifiers
                )
            )
        }

        return records
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value, value != "missing value", !value.isEmpty else {
            return nil
        }
        return value
    }
}
