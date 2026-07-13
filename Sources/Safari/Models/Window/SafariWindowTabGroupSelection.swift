enum SafariWindowTabGroupSelection {
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
}
