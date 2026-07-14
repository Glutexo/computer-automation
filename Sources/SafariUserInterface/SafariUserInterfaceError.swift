import Foundation

public enum SafariUserInterfaceError: Error, Equatable, LocalizedError {
    case profileWindowMenuItemNotFound(String)
    case privateWindowMenuItemNotFound
    case focusedWindowUnavailable
    case windowListUnavailable
    case windowCloseButtonUnavailable
    case windowCloseNotVerified
    case sidebarUnavailable
    case sidebarTabGroupNotFound(String)
    case sidebarSelectedItemRenameUnavailable
    case menuItemDisabled(String)
    case missingMenuAddress
    case invalidMenuAddress(String)
    case menuUnavailable(menuBarItemIndex: Int)
    case missingMenuItemAddress
    case invalidMenuItemAddress(String, String)
    case menuItemChildrenUnavailable(menuBarItemIndex: Int, menuItemIndex: Int)

    public var errorDescription: String? {
        switch self {
        case .profileWindowMenuItemNotFound(let profileName):
            "Safari's File menu does not contain a new-window item for profile \(profileName). Verify the profile exists and retry."
        case .privateWindowMenuItemNotFound:
            "Safari's File menu does not expose the private-window command. Verify private browsing is available and retry."
        case .focusedWindowUnavailable:
            "The targeted Safari window could not be resolved through Accessibility. Grant Accessibility permission and retry."
        case .windowListUnavailable:
            "Safari windows could not be inspected through Accessibility. Grant Accessibility permission and retry."
        case .windowCloseButtonUnavailable:
            "Safari kept the targeted window visible and its Accessibility close button was unavailable. Close that exact window manually."
        case .windowCloseNotVerified:
            "Safari kept the targeted window visible after both the normal close action and Accessibility close-button fallback. Close that exact window manually."
        case .sidebarUnavailable:
            "Safari's visible sidebar could not be opened or inspected. Grant Accessibility permission to the calling app, then retry."
        case .sidebarTabGroupNotFound(let tabGroupName):
            "Safari's sidebar does not contain saved tab group \(tabGroupName). Open the expected profile and retry."
        case .sidebarSelectedItemRenameUnavailable:
            "Safari did not expose the inline name field for the newly created tab group."
        case .menuItemDisabled(let identifier):
            "Safari's File-menu action \(identifier) is disabled in the focused window. Safari cannot complete the requested tab-group change in that window."
        case .missingMenuAddress:
            "Missing Safari menu-bar item index. Run the command with --help for the required address."
        case .invalidMenuAddress(let value):
            "Invalid Safari menu-bar item index \(value). Use a positive integer."
        case .menuUnavailable(let menuBarItemIndex):
            "Safari menu-bar item \(menuBarItemIndex) could not be opened. Grant Accessibility permission and retry."
        case .missingMenuItemAddress:
            "Missing Safari menu item address. Run the command with --help for the required indexes."
        case .invalidMenuItemAddress(let menuBarItemIndex, let menuItemIndex):
            "Invalid Safari menu item address \(menuBarItemIndex), \(menuItemIndex). Use positive integer indexes."
        case .menuItemChildrenUnavailable(let menuBarItemIndex, let menuItemIndex):
            "Safari menu item \(menuBarItemIndex):\(menuItemIndex) does not expose a child menu."
        }
    }
}
