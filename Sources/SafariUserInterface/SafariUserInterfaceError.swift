public enum SafariUserInterfaceError: Error, Equatable {
    case profileWindowMenuItemNotFound(String)
    case missingMenuAddress
    case invalidMenuAddress(String)
    case menuUnavailable(menuBarItemIndex: Int)
    case missingMenuItemAddress
    case invalidMenuItemAddress(String, String)
    case menuItemChildrenUnavailable(menuBarItemIndex: Int, menuItemIndex: Int)
}
