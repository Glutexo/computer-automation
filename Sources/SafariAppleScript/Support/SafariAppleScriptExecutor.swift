import AppKit
import Foundation

public protocol SafariAppleScriptExecuting {
    func execute(script: String) throws -> NSAppleEventDescriptor?
}

public struct SafariAppleScriptExecutor: SafariAppleScriptExecuting {
    public init() {}

    public func execute(script: String) throws -> NSAppleEventDescriptor? {
        guard let appleScript = NSAppleScript(source: script) else {
            throw SafariAppleScriptError.scriptCompilationFailed
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error {
            throw SafariAppleScriptError.executionFailed(error.description)
        }

        return result
    }
}

public enum SafariAppleScriptError: Error, Equatable, LocalizedError {
    case scriptCompilationFailed
    case requestTimedOut(processIdentifier: pid_t)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scriptCompilationFailed:
            "Could not prepare the Safari automation request."
        case .requestTimedOut(let processIdentifier):
            "Safari process \(processIdentifier) did not respond in time. Close any stuck Safari dialog and retry."
        case .executionFailed:
            "Safari automation failed. Ensure the calling app has Automation permission for Safari and System Events, then retry."
        }
    }
}
