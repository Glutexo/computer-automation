import AppKit
import AutomationFoundation

public struct SafariAppleScriptToolbarItemRecord: Equatable, Sendable {
    public let index: Int
    public let role: String
    public let identifier: String?
    public let title: String?
    public let description: String?

    public init(index: Int, role: String, identifier: String? = nil, title: String? = nil, description: String? = nil) {
        self.index = index
        self.role = role
        self.identifier = identifier
        self.title = title
        self.description = description
    }
}

public enum SafariAppleScriptToolbar: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "toolbar",
        abstract: "AppleScript access to Safari toolbar items.",
        commands: []
    )

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptToolbarItemRecord] {
        let script = """
        tell application "Safari" to activate
        delay 0.1
        tell application "System Events"
            tell process "Safari"
                if (count of windows) is 0 then
                    return {}
                end if
                tell toolbar 1 of front window
                    set outputItems to {}
                    repeat with itemIndex from 1 to count of UI elements
                        set currentItem to UI element itemIndex
                        set currentRole to value of attribute "AXRole" of currentItem
                        if currentRole is missing value then set currentRole to ""
                        set currentIdentifier to ""
                        try
                            set currentIdentifier to value of attribute "AXIdentifier" of currentItem
                            if currentIdentifier is missing value then set currentIdentifier to ""
                        end try
                        set currentTitle to ""
                        try
                            set currentTitle to title of currentItem
                            if currentTitle is missing value then set currentTitle to ""
                        end try
                        set currentDescription to ""
                        try
                            set currentDescription to value of attribute "AXDescription" of currentItem
                            if currentDescription is missing value then set currentDescription to ""
                        end try
                        copy {(itemIndex as text), (currentRole as text), (currentIdentifier as text), (currentTitle as text), (currentDescription as text)} to end of outputItems
                    end repeat
                    return outputItems
                end tell
            end tell
        end tell
        """

        let result = try executor.execute(script: script)
        return parseItemList(result)
    }

    public static func parseItemList(_ descriptor: NSAppleEventDescriptor?) -> [SafariAppleScriptToolbarItemRecord] {
        guard let descriptor, descriptor.numberOfItems > 0 else {
            return []
        }

        var items: [SafariAppleScriptToolbarItemRecord] = []

        for descriptorIndex in 1...descriptor.numberOfItems {
            guard
                let itemDescriptor = descriptor.atIndex(descriptorIndex),
                itemDescriptor.numberOfItems >= 5,
                let rawIndex = itemDescriptor.atIndex(1)?.stringValue,
                let index = Int(rawIndex),
                let role = itemDescriptor.atIndex(2)?.stringValue
            else {
                continue
            }

            items.append(
                SafariAppleScriptToolbarItemRecord(
                    index: index,
                    role: role,
                    identifier: normalized(itemDescriptor.atIndex(3)?.stringValue),
                    title: normalized(itemDescriptor.atIndex(4)?.stringValue),
                    description: normalized(itemDescriptor.atIndex(5)?.stringValue)
                )
            )
        }

        return items
    }

    static func normalized(_ value: String?) -> String? {
        guard let value, value != "missing value", !value.isEmpty else {
            return nil
        }
        return value
    }
}
