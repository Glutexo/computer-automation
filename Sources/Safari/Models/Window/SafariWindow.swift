import AppKit
import AutomationFoundation

public struct SafariWindowRecord: Equatable {
    public let index: Int
    public let name: String

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

public enum SafariWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window",
        abstract: "Safari browser windows.",
        commands: [
            SafariWindowOpenCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )

    static func list(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariWindowRecord] {
        guard SafariApplication.isRunning() else {
            return []
        }

        let script = """
        tell application "Safari"
            set output to {}
            set windowIndex to 1
            repeat with currentWindow in every window
                set end of output to ((windowIndex as string) & "|" & (name of currentWindow as string))
                set windowIndex to windowIndex + 1
            end repeat
            return output
        end tell
        """

        let descriptor = try executor.execute(script: script)
        return parseWindowList(descriptor)
    }

    static func parseWindowList(_ descriptor: NSAppleEventDescriptor?) -> [SafariWindowRecord] {
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

    private static func parseWindowLines(_ lines: [String]) -> [SafariWindowRecord] {
        lines.compactMap { line in
            let components = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard components.count == 2, let index = Int(components[0]) else {
                return nil
            }
            return SafariWindowRecord(index: index, name: components[1])
        }
    }
}
