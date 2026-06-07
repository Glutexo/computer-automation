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

public enum SafariAppleScriptError: Error {
    case scriptCompilationFailed
    case executionFailed(String)
}
