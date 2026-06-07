import AppKit
import Foundation

protocol SafariAppleScriptExecuting {
    func execute(script: String) throws -> NSAppleEventDescriptor?
}

struct SafariAppleScriptExecutor: SafariAppleScriptExecuting {
    func execute(script: String) throws -> NSAppleEventDescriptor? {
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

enum SafariAppleScriptError: Error {
    case scriptCompilationFailed
    case executionFailed(String)
}
