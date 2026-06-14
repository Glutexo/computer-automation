import SafariAppleScript
import SafariUserInterface

enum SafariWindowTabGroupSelection {
    static let tabGroupPickerIdentifierPrefix = "TabGroupPickerButton"

    static func resolveTabGroup(
        identifier: Int,
        from groups: [SafariTabGroupRecord]
    ) throws -> SafariTabGroupRecord {
        guard let group = groups.first(where: { $0.identifier == identifier }) else {
            throw SafariWindowCommandError.tabGroupNotFound(identifier)
        }

        let duplicates = groups.filter {
            $0.profileName == group.profileName && $0.name == group.name
        }

        guard duplicates.count == 1 else {
            throw SafariWindowCommandError.ambiguousTabGroupName(
                profileName: group.profileName,
                tabGroupName: group.name
            )
        }

        return group
    }

    static func selectTabGroup(
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let toolbarItems: [SafariToolbarItemRecord]
        do {
            toolbarItems = try SafariToolbar.listItems(executor: executor)
        } catch SafariUserInterfaceError.toolbarUnavailable {
            throw SafariWindowCommandError.tabGroupPickerUnavailable
        }

        guard let pickerItem = toolbarItems.first(where: {
            $0.identifier?.hasPrefix(tabGroupPickerIdentifierPrefix) == true
        }) else {
            throw SafariWindowCommandError.tabGroupPickerUnavailable
        }

        let childItems: [SafariMenuItemRecord]
        do {
            childItems = try SafariToolbarItem.listChildItems(
                toolbarItemIndex: pickerItem.index,
                executor: executor
            )
        } catch SafariUserInterfaceError.toolbarItemChildrenUnavailable {
            throw SafariWindowCommandError.tabGroupPickerUnavailable
        }

        guard let childItem = childItems.first(where: { $0.title == tabGroupName }) else {
            throw SafariWindowCommandError.tabGroupPickerItemNotFound(tabGroupName)
        }

        try SafariToolbarItem.clickChildItem(
            toolbarItemIndex: pickerItem.index,
            childItemIndex: childItem.index,
            executor: executor
        )
    }
}
