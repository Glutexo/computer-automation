import AppKit
import AutomationFoundation

public struct SafariMenuItemRecord: Equatable {
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

public enum SafariMenuItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu-item",
        abstract: "A Safari menu item.",
        commands: []
    )

    static func parseRecordsWithIndexAndTitle(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariMenuItemRecord] {
        parseRecords(from: descriptor, expectedFieldCount: 2)
    }

    static func parseRecordsWithKeyboardShortcut(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariMenuItemRecord] {
        parseRecords(from: descriptor, expectedFieldCount: 4)
    }

    static func format(_ item: SafariMenuItemRecord) -> String {
        let commandCharacter = item.commandCharacter ?? ""
        let commandModifiers = item.commandModifiers ?? ""
        return "\(item.index)|\(item.title)|\(commandCharacter)|\(commandModifiers)"
    }

    static func formatIndexAndTitle(_ item: SafariMenuItemRecord) -> String {
        "\(item.index)|\(item.title)"
    }

    private static func parseRecords(
        from descriptor: NSAppleEventDescriptor?,
        expectedFieldCount: Int
    ) -> [SafariMenuItemRecord] {
        guard let descriptor, descriptor.numberOfItems > 0 else {
            return []
        }

        var records: [SafariMenuItemRecord] = []

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
                SafariMenuItemRecord(
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
