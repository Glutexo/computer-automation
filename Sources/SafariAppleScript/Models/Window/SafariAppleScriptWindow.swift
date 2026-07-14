import AppKit
import AutomationFoundation

public struct SafariAppleScriptWindowRecord: Equatable, Sendable {
    public let identifier: Int
    public let name: String

    public init(identifier: Int, name: String) {
        self.identifier = identifier
        self.name = name
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
                set end of output to ((id of currentWindow as string) & "|" & (name of currentWindow as string))
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

        var lines: [String] = []
        for index in 1...descriptor.numberOfItems {
            if let item = descriptor.atIndex(index)?.stringValue {
                lines.append(item)
            }
        }
        return parseWindowLines(lines)
    }

    private static func parseWindowLines(_ lines: [String]) -> [SafariAppleScriptWindowRecord] {
        lines.compactMap { line in
            let components = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard components.count == 2, let identifier = Int(components[0]) else {
                return nil
            }
            return SafariAppleScriptWindowRecord(identifier: identifier, name: components[1])
        }
    }
}
