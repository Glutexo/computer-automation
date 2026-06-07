public enum SafariUserInterfaceError: Error, Equatable {
    case profileWindowMenuItemNotFound(String)
    case missingMenuItemAddress
    case invalidMenuItemAddress(String, String)
    case menuItemChildrenUnavailable(menuBarItemIndex: Int, menuItemIndex: Int)
}
