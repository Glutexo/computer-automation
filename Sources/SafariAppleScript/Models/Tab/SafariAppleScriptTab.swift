import AppKit
import AutomationFoundation

public struct SafariAppleScriptTabRecord: Equatable, Sendable {
    public let windowIndex: Int
    public let index: Int
    public let url: String
    public let title: String

    public init(windowIndex: Int, index: Int, url: String, title: String = "") {
        self.windowIndex = windowIndex
        self.index = index
        self.url = url
        self.title = title
    }
}

public enum SafariAppleScriptTab: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "tab",
        abstract: "AppleScript access to Safari tabs.",
        commands: []
    )

    public static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptTabRecord] {
        let script = """
        tell application "Safari"
            set output to {}
            set windowIndex to 0
            repeat with currentWindow in every window
                set windowIndex to windowIndex + 1
                set tabIndex to 0
                repeat with currentTab in every tab of currentWindow
                    set tabIndex to tabIndex + 1
                    set tabURL to ""
                    try
                        set tabURL to URL of currentTab
                    on error
                        set tabURL to ""
                    end try
                    set tabName to ""
                    try
                        set tabName to name of currentTab
                    on error
                        set tabName to ""
                    end try
                    copy {(windowIndex as text), (tabIndex as text), tabURL, tabName} to end of output
                end repeat
            end repeat
            return output
        end tell
        """

        let descriptor = try executor.execute(script: script)
        return parseTabList(descriptor)
    }

    public static func open(
        windowIndex: Int,
        url: String? = nil,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let lines: [String]
        if let url, !url.isEmpty {
            lines = [
                "tell application \"Safari\"",
                "    activate",
                "    if (count of windows) < \(windowIndex) then error \"Window index out of range.\"",
                "    tell window \(windowIndex)",
                "        set newTab to make new tab at end of tabs",
                "        set current tab to newTab",
                "        set URL of newTab to \(appleScriptStringLiteral(url))",
                "    end tell",
                "end tell"
            ]
        } else {
            lines = [
                "tell application \"Safari\"",
                "    activate",
                "    if (count of windows) < \(windowIndex) then error \"Window index out of range.\"",
                "    tell window \(windowIndex)",
                "        set newTab to make new tab at end of tabs",
                "        set current tab to newTab",
                "    end tell",
                "end tell"
            ]
        }

        let script = lines.joined(separator: "\n")

        _ = try executor.execute(script: script)
    }

    public static func setURL(
        windowIndex: Int,
        tabIndex: Int,
        url: String,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari"
            if (count of windows) < \(windowIndex) then error "Window index out of range."
            tell window \(windowIndex)
                if (count of tabs) < \(tabIndex) then error "Tab index out of range."
                set URL of tab \(tabIndex) to \(appleScriptStringLiteral(url))
            end tell
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func close(
        windowIndex: Int,
        tabIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> String {
        let script = """
        tell application "Safari"
            if (count of windows) < \(windowIndex) then error "Window index out of range."
            tell window \(windowIndex)
                if (count of tabs) < \(tabIndex) then error "Tab index out of range."
                close tab \(tabIndex)
                return "Safari tab closed."
            end tell
        end tell
        """

        return try executor.execute(script: script)?.stringValue ?? "Safari tab closed."
    }

    public static func parseTabList(_ descriptor: NSAppleEventDescriptor?) -> [SafariAppleScriptTabRecord] {
        guard let descriptor else {
            return []
        }

        if descriptor.descriptorType != typeAEList {
            let rawValue = descriptor.stringValue ?? ""
            return rawValue.isEmpty ? [] : parseTabLines([rawValue])
        }

        guard descriptor.numberOfItems > 0 else {
            return []
        }

        var records: [SafariAppleScriptTabRecord] = []
        var legacyLines: [String] = []
        for index in 1...descriptor.numberOfItems {
            guard let item = descriptor.atIndex(index) else {
                continue
            }

            if let record = parseTabItem(item) {
                records.append(record)
            } else if let line = item.stringValue {
                legacyLines.append(line)
            }
        }

        return records + parseTabLines(legacyLines)
    }

    private static func parseTabItem(_ descriptor: NSAppleEventDescriptor) -> SafariAppleScriptTabRecord? {
        guard
            descriptor.numberOfItems >= 3,
            let rawWindowIndex = descriptor.atIndex(1)?.stringValue,
            let windowIndex = Int(rawWindowIndex),
            let rawTabIndex = descriptor.atIndex(2)?.stringValue,
            let tabIndex = Int(rawTabIndex),
            let url = descriptor.atIndex(3)?.stringValue
        else {
            return nil
        }

        return SafariAppleScriptTabRecord(
            windowIndex: windowIndex,
            index: tabIndex,
            url: url,
            title: descriptor.atIndex(4)?.stringValue ?? ""
        )
    }

    private static func parseTabLines(_ lines: [String]) -> [SafariAppleScriptTabRecord] {
        lines.compactMap { line in
            let components = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard
                components.count == 3,
                let windowIndex = Int(components[0]),
                let tabIndex = Int(components[1])
            else {
                return nil
            }

            return SafariAppleScriptTabRecord(
                windowIndex: windowIndex,
                index: tabIndex,
                url: components[2]
            )
        }
    }

    private static func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
