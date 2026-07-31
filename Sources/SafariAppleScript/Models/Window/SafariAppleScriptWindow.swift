import AppKit
import AutomationFoundation

public struct SafariAppleScriptWindowRecord: Equatable, Sendable {
    public let identifier: Int
    public let name: String
    public let currentTabName: String?
    public let tabCount: Int?

    public init(identifier: Int, name: String, currentTabName: String? = nil, tabCount: Int? = nil) {
        self.identifier = identifier
        self.name = name
        self.currentTabName = currentTabName
        self.tabCount = tabCount
    }
}

public enum SafariAppleScriptWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window",
        abstract: "AppleScript access to Safari windows.",
        commands: []
    )

    public static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariAppleScriptWindowRecord] {
        let script = """
        tell application "Safari"
            set output to {}
            repeat with currentWindow in every window
                set currentWindowName to ""
                try
                    set currentWindowName to name of currentWindow as string
                end try
                set selectedTabName to ""
                try
                    set selectedTabName to name of current tab of currentWindow as string
                end try
                copy {(id of currentWindow as string), currentWindowName, selectedTabName, (count of tabs of currentWindow as string)} to end of output
            end repeat
            return output
        end tell
        """

        let descriptor = try executor.execute(script: script)
        return parseWindowList(descriptor)
    }

    public static func list(
        processIdentifier: pid_t
    ) throws -> [SafariAppleScriptWindowRecord] {
        try list(processIdentifier: processIdentifier, backend: .live)
    }

    static func list(
        processIdentifier: pid_t,
        backend: SafariAppleScriptProcessBackend
    ) throws -> [SafariAppleScriptWindowRecord] {
        try backend.listWindows(processIdentifier)
    }

    public static func focus(
        windowIdentifier: Int,
        processIdentifier: pid_t
    ) throws {
        try focus(
            windowIdentifier: windowIdentifier,
            processIdentifier: processIdentifier,
            backend: .live
        )
    }

    static func focus(
        windowIdentifier: Int,
        processIdentifier: pid_t,
        backend: SafariAppleScriptProcessBackend
    ) throws {
        try backend.focusWindow(processIdentifier, windowIdentifier)
    }

    public static func openNewDocument(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari"
            activate
            make new document
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func focus(
        windowIndex: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari"
            activate
            set index of window \(windowIndex) to 1
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func focus(
        windowIdentifier: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari"
            activate
            set didFocusWindow to false
            repeat with currentWindow in every window
                if id of currentWindow is \(windowIdentifier) then
                    set index of currentWindow to 1
                    set didFocusWindow to true
                    exit repeat
                end if
            end repeat
            if didFocusWindow is false then error "Safari window \(windowIdentifier) does not exist."
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func closeFrontWindow(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> String {
        let script = """
        tell application "Safari"
            if (count of windows) is 0 then
                return "Safari has no open windows."
            end if
            close front window
            return "Safari front window closed."
        end tell
        """

        return try executor.execute(script: script)?.stringValue ?? "Safari front window closed."
    }

    public static func close(
        windowIdentifier: Int,
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws {
        let script = """
        tell application "Safari"
            set didCloseWindow to false
            repeat with currentWindow in every window
                if id of currentWindow is \(windowIdentifier) then
                    close currentWindow
                    set didCloseWindow to true
                    exit repeat
                end if
            end repeat
            if didCloseWindow is false then error "Safari window \(windowIdentifier) does not exist."
        end tell
        """

        _ = try executor.execute(script: script)
    }

    public static func parseWindowList(_ descriptor: NSAppleEventDescriptor?) -> [SafariAppleScriptWindowRecord] {
        guard let descriptor else {
            return []
        }

        if descriptor.descriptorType != typeAEList {
            let rawValue = descriptor.stringValue ?? ""
            return rawValue.isEmpty ? [] : parseWindowLines([rawValue])
        }

        guard descriptor.numberOfItems > 0 else {
            return []
        }

        var records: [SafariAppleScriptWindowRecord] = []
        for index in 1...descriptor.numberOfItems {
            guard let item = descriptor.atIndex(index) else {
                continue
            }

            if
                item.descriptorType == typeAEList,
                item.numberOfItems >= 3,
                let rawIdentifier = item.atIndex(1)?.stringValue,
                let identifier = Int(rawIdentifier)
            {
                let name = item.atIndex(2)?.stringValue ?? ""
                let currentTabName = item.atIndex(3)?.stringValue ?? ""
                let tabCount = item.numberOfItems >= 4
                    ? item.atIndex(4)?.stringValue.flatMap(Int.init)
                    : nil
                records.append(
                    SafariAppleScriptWindowRecord(
                        identifier: identifier,
                        name: name,
                        currentTabName: currentTabName.isEmpty ? nil : currentTabName,
                        tabCount: tabCount
                    )
                )
            } else if let line = item.stringValue, let record = parseWindowLine(line) {
                records.append(record)
            }
        }
        return records
    }

    private static func parseWindowLines(_ lines: [String]) -> [SafariAppleScriptWindowRecord] {
        lines.compactMap(parseWindowLine)
    }

    private static func parseWindowLine(_ line: String) -> SafariAppleScriptWindowRecord? {
        let components = line.split(separator: "|", maxSplits: 1).map(String.init)
        guard components.count == 2, let identifier = Int(components[0]) else {
            return nil
        }
        return SafariAppleScriptWindowRecord(identifier: identifier, name: components[1])
    }
}
