enum SafariWindowTabGroupSelection {
    static func resolveTabGroup(
        identifier: Int,
        from groups: [SafariTabGroupRecord]
    ) throws -> SafariTabGroupRecord {
        guard let group = groups.first(where: { $0.identifier == identifier }) else {
            throw SafariWindowCommandError.tabGroupNotFound(identifier)
        }

        return group
    }
}
