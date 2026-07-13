import AppKit
import AutomationFoundation

public enum SafariAppleScriptSidebar: ModelModel {
    private static let renameSelectedTabGroupMenuItemIdentifier = "RenameTabGroupMenuItem"

    public static let descriptor = ModelDescriptor(
        name: "sidebar",
        abstract: "AppleScript access to the Safari front-window sidebar.",
        commands: []
    )

    public static func selectItem(
        sidebarItemIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        \(sidebarBootstrapScript)
                set targetRow to row \(sidebarItemIndex) of outlineItem
                set targetCell to UI element 1 of targetRow
                set value of attribute "AXSelectedRows" of outlineItem to {targetRow}
                set value of attribute "AXSelectedCells" of outlineItem to {targetCell}
                set value of attribute "AXFocused" of outlineItem to true
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func selectTabGroup(
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        try selectTabGroup(matchingIdentifier: nil, named: tabGroupName, executor: executor)
    }

    public static func selectTabGroup(
        identifier tabGroupIdentifier: Int,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        try selectTabGroup(matchingIdentifier: tabGroupIdentifier, named: tabGroupName, executor: executor)
    }

    private static func selectTabGroup(
        matchingIdentifier tabGroupIdentifier: Int?,
        named tabGroupName: String,
        executor: SafariAppleScriptExecuting
    ) throws {
        let identifierMatchScript = tabGroupIdentifier.map { identifier in
            """
                    set sawStableTabGroupIdentifier to false
                    repeat with currentRow in rows of outlineItem
                        try
                            set currentCell to UI element 1 of currentRow
                            set currentIdentifier to ""
                            try
                                set currentIdentifier to value of attribute "AXIdentifier" of currentCell
                                if currentIdentifier is missing value then set currentIdentifier to ""
                            end try
                            if currentIdentifier is "" then
                                try
                                    set currentIdentifier to value of attribute "AXIdentifier" of UI element 1 of currentCell
                                    if currentIdentifier is missing value then set currentIdentifier to ""
                                end try
                            end if
                            set exposedTabGroupIdentifier to sidebarTabGroupIdentifier(currentIdentifier)
                            if exposedTabGroupIdentifier is not missing value then
                                set sawStableTabGroupIdentifier to true
                                if exposedTabGroupIdentifier is \(identifier) then
                                    set value of attribute "AXSelectedRows" of outlineItem to {currentRow}
                                    set value of attribute "AXSelectedCells" of outlineItem to {currentCell}
                                    set value of attribute "AXFocused" of outlineItem to true
                                    return
                                end if
                            end if
                        end try
                    end repeat
                    if sawStableTabGroupIdentifier then
                        error "Safari sidebar tab group identifier \(identifier) not found."
                    end if
            """
        } ?? ""

        let script = """
        \(sidebarIdentifierHandlerScript)
        tell application "Safari" to activate
        delay 0.1
        \(sidebarBootstrapScript)
        \(identifierMatchScript)
                repeat with currentRow in rows of outlineItem
                    try
                        set currentCell to UI element 1 of currentRow
                        set titleElement to value of attribute "AXTitleUIElement" of currentCell
                        set currentTitle to value of titleElement
                        if currentTitle is "\(appleScriptEscaped(tabGroupName))" then
                            set currentIdentifier to ""
                            try
                                set currentIdentifier to value of attribute "AXIdentifier" of currentCell
                                if currentIdentifier is missing value then set currentIdentifier to ""
                            end try
                            if currentIdentifier is "" then
                                try
                                    set currentIdentifier to value of attribute "AXIdentifier" of UI element 1 of currentCell
                                    if currentIdentifier is missing value then set currentIdentifier to ""
                                end try
                            end if
                            if currentIdentifier starts with "SidebarLibraryItemTabGroup" then
                                set value of attribute "AXSelectedRows" of outlineItem to {currentRow}
                                set value of attribute "AXSelectedCells" of outlineItem to {currentCell}
                                set value of attribute "AXFocused" of outlineItem to true
                                return
                            end if
                        end if
                    end try
                end repeat
                error "Safari sidebar tab group \(appleScriptEscaped(tabGroupName)) not found."
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func renameTabGroup(
        named currentName: String,
        to newName: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        \(sidebarBootstrapScript)
                repeat with currentRow in rows of outlineItem
                    try
                        set currentCell to UI element 1 of currentRow
                        set titleElement to value of attribute "AXTitleUIElement" of currentCell
                        set currentTitle to value of titleElement
                        if currentTitle is "\(appleScriptEscaped(currentName))" then
                            set currentIdentifier to ""
                            try
                                set currentIdentifier to value of attribute "AXIdentifier" of currentCell
                                if currentIdentifier is missing value then set currentIdentifier to ""
                            end try
                            if currentIdentifier is "" then
                                try
                                    set currentIdentifier to value of attribute "AXIdentifier" of UI element 1 of currentCell
                                    if currentIdentifier is missing value then set currentIdentifier to ""
                                end try
                            end if
                            if currentIdentifier starts with "SidebarLibraryItemTabGroup" then
                                set value of attribute "AXSelectedRows" of outlineItem to {currentRow}
                                set value of attribute "AXSelectedCells" of outlineItem to {currentCell}
                                set value of attribute "AXFocused" of outlineItem to true
                                delay 0.1
                                set renameField to titleElement
                                if value of attribute "AXRole" of renameField is not "AXTextField" then
                                    perform action "AXShowMenu" of renameField
                                    delay 0.1
                                    set renameMenuItem to missing value
                                    repeat with currentElement in entire contents
                                        try
                                            if value of attribute "AXRole" of currentElement is "AXMenuItem" and value of attribute "AXIdentifier" of currentElement is "\(renameSelectedTabGroupMenuItemIdentifier)" then
                                                set renameMenuItem to currentElement
                                                exit repeat
                                            end if
                                        end try
                                    end repeat
                                    if renameMenuItem is missing value then
                                        error "Sidebar tab group rename menu item not found."
                                    end if
                                    perform action "AXPress" of renameMenuItem
                                    delay 0.1
                                    set renameField to value of attribute "AXTitleUIElement" of currentCell
                                end if
                                if value of attribute "AXRole" of renameField is not "AXTextField" then
                                    error "Sidebar tab group is not editable."
                                end if
                                set value of renameField to "\(appleScriptEscaped(newName))"
                                perform action "AXConfirm" of renameField
                                return
                            end if
                        end if
                    end try
                end repeat
                error "Safari sidebar tab group \(appleScriptEscaped(currentName)) not found."
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    private static let sidebarBootstrapScript = """
    tell application "System Events"
        tell process "Safari"
            if (count of windows) is 0 then
                error "Safari has no open windows."
            end if
            if not (exists UI element 1 of UI element 1 of UI element 1 of front window) then
                set sidebarButton to missing value
                repeat with toolbarChild in UI elements of toolbar 1 of front window
                    try
                        if value of attribute "AXIdentifier" of toolbarChild is "SidebarButton" then
                            set sidebarButton to toolbarChild
                            exit repeat
                        end if
                    end try
                    try
                        repeat with nestedToolbarChild in UI elements of toolbarChild
                            if value of attribute "AXIdentifier" of nestedToolbarChild is "SidebarButton" then
                                set sidebarButton to nestedToolbarChild
                                exit repeat
                            end if
                        end repeat
                    end try
                    if sidebarButton is not missing value then exit repeat
                end repeat
                if sidebarButton is missing value then
                    error "Safari sidebar button not found."
                end if
                click sidebarButton
                delay 0.1
            end if
            if not (exists UI element 1 of UI element 1 of UI element 1 of front window) then
                error "Safari sidebar not available."
            end if
            set outlineItem to UI element 1 of UI element 1 of UI element 1 of front window
    """

    private static let sidebarIdentifierHandlerScript = """
    on sidebarTabGroupIdentifier(currentIdentifier)
        set identifierPrefix to "SidebarLibraryItemTabGroup"
        if currentIdentifier does not start with identifierPrefix then return missing value
        if (length of currentIdentifier) is less than or equal to (length of identifierPrefix) then return missing value

        set suffixText to text ((length of identifierPrefix) + 1) thru -1 of currentIdentifier
        set currentDigits to ""
        repeat with characterIndex from 1 to length of suffixText
            set currentCharacter to character characterIndex of suffixText
            if currentCharacter is in "0123456789" then
                set currentDigits to currentDigits & currentCharacter
            else if currentDigits is not "" then
                return currentDigits as integer
            end if
        end repeat

        if currentDigits is "" then return missing value
        return currentDigits as integer
    end sidebarTabGroupIdentifier
    """

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
