import Foundation
import ScriptingBridge

struct SafariAppleScriptProcessBackend {
    let listWindows: (pid_t) throws -> [SafariAppleScriptWindowRecord]
    let listTabs: (pid_t) throws -> [SafariAppleScriptTabRecord]

    static var live: SafariAppleScriptProcessBackend {
        SafariAppleScriptProcessBackend(
            listWindows: { processIdentifier in
                try SafariScriptingBridgeSession(processIdentifier: processIdentifier).windows()
            },
            listTabs: { processIdentifier in
                try SafariScriptingBridgeSession(processIdentifier: processIdentifier).tabs()
            }
        )
    }
}

private final class SafariScriptingBridgeSession: NSObject, SBApplicationDelegate {
    private static let timeoutTicks = 10 * 60

    private enum Code {
        static let windows: DescType = 0x6377_696E // cwin
        static let tabs: DescType = 0x6254_6162 // bTab
        static let identifier: AEKeyword = 0x4944_2020 // ID__
        static let name: AEKeyword = 0x706E_616D // pnam
        static let url: AEKeyword = 0x7055_524C // pURL
    }

    private let application: SBApplication
    private var lastError: Error?

    init(processIdentifier: pid_t) throws {
        guard let application = SBApplication(processIdentifier: processIdentifier) else {
            throw SafariAppleScriptError.executionFailed("Safari process \(processIdentifier) is unavailable.")
        }

        self.application = application
        super.init()
        application.timeout = Self.timeoutTicks
        application.delegate = self
    }

    func eventDidFail(
        _ event: UnsafePointer<AppleEvent>,
        withError error: any Error
    ) -> Any? {
        lastError = error
        return nil
    }

    func windows() throws -> [SafariAppleScriptWindowRecord] {
        let windows = try elements(code: Code.windows, on: application)
        return try windows.map(windowRecord)
    }

    func tabs() throws -> [SafariAppleScriptTabRecord] {
        let windows = try elements(code: Code.windows, on: application)
        var records: [SafariAppleScriptTabRecord] = []

        for (windowOffset, window) in windows.enumerated() {
            let windowIdentifier = try requiredIntegerProperty(Code.identifier, on: window)
            let tabs = try elements(code: Code.tabs, on: window)

            for (tabOffset, tab) in tabs.enumerated() {
                records.append(
                    SafariAppleScriptTabRecord(
                        windowIdentifier: windowIdentifier,
                        windowIndex: windowOffset + 1,
                        index: tabOffset + 1,
                        url: optionalStringProperty(Code.url, on: tab),
                        title: optionalStringProperty(Code.name, on: tab)
                    )
                )
            }
        }

        return records
    }

    private func windowRecord(_ window: SBObject) throws -> SafariAppleScriptWindowRecord {
        SafariAppleScriptWindowRecord(
            identifier: try requiredIntegerProperty(Code.identifier, on: window),
            name: optionalStringProperty(Code.name, on: window)
        )
    }

    private func elements(code: DescType, on object: SBObject) throws -> [SBObject] {
        lastError = nil
        let elements = object.elementArray(withCode: code)
        let count = elements.count
        try throwLastErrorIfNeeded()

        return try (0..<count).map { index in
            guard let element = elements.object(at: index) as? SBObject else {
                throw SafariAppleScriptError.executionFailed("Safari returned an invalid scripting object.")
            }
            return element
        }
    }

    private func requiredIntegerProperty(_ code: AEKeyword, on object: SBObject) throws -> Int {
        lastError = nil
        let value = object.property(withCode: code).get()
        try throwLastErrorIfNeeded()

        guard let number = value as? NSNumber else {
            throw SafariAppleScriptError.executionFailed("Safari returned an invalid scripting property.")
        }
        return number.intValue
    }

    private func optionalStringProperty(_ code: AEKeyword, on object: SBObject) -> String {
        lastError = nil
        let value = object.property(withCode: code).get()
        lastError = nil
        return value as? String ?? ""
    }

    private func throwLastErrorIfNeeded() throws {
        guard let lastError else {
            return
        }
        self.lastError = nil
        throw SafariAppleScriptError.executionFailed(lastError.localizedDescription)
    }
}
