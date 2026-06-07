import AppKit
import AutomationFoundation
import SafariAppleScript

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

    init(_ record: SafariAppleScriptMenuItemRecord) {
        self.init(
            index: record.index,
            title: record.title,
            commandCharacter: record.commandCharacter,
            commandModifiers: record.commandModifiers
        )
    }
}

public enum SafariMenuItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu-item",
        abstract: "A Safari menu item.",
        commands: [
            SafariMenuItemListChildItemsCommand.descriptor
        ]
    )

    public static func listChildItems(
        menuBarItemIndex: Int,
        menuItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariMenuItemRecord] {
        do {
            return try SafariAppleScriptMenuItem.listChildItems(
                menuBarItemIndex: menuBarItemIndex,
                menuItemIndex: menuItemIndex,
                executor: executor
            ).map(SafariMenuItemRecord.init)
        } catch {
            throw SafariUserInterfaceError.menuItemChildrenUnavailable(
                menuBarItemIndex: menuBarItemIndex,
                menuItemIndex: menuItemIndex
            )
        }
    }

    static func parseRecordsWithIndexAndTitle(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariMenuItemRecord] {
        SafariAppleScriptMenuItem.parseRecordsWithIndexAndTitle(from: descriptor).map(SafariMenuItemRecord.init)
    }

    static func parseRecordsWithKeyboardShortcut(
        from descriptor: NSAppleEventDescriptor?
    ) -> [SafariMenuItemRecord] {
        SafariAppleScriptMenuItem.parseRecordsWithKeyboardShortcut(from: descriptor).map(SafariMenuItemRecord.init)
    }

    static func format(_ item: SafariMenuItemRecord) -> String {
        let commandCharacter = item.commandCharacter ?? ""
        let commandModifiers = item.commandModifiers ?? ""
        return "\(item.index)|\(item.title)|\(commandCharacter)|\(commandModifiers)"
    }

    static func formatIndexAndTitle(_ item: SafariMenuItemRecord) -> String {
        "\(item.index)|\(item.title)"
    }
}
