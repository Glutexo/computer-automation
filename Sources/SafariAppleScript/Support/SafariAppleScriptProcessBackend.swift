import Foundation
import ScriptingBridge

struct SafariAppleScriptProcessBackend {
    let listWindows: (pid_t) throws -> [SafariAppleScriptWindowRecord]
    let listTabs: (pid_t, Set<Int>) throws -> [SafariAppleScriptTabRecord]
    let focusWindow: (pid_t, Int) throws -> Void

    init(
        listWindows: @escaping (pid_t) throws -> [SafariAppleScriptWindowRecord],
        listTabs: @escaping (pid_t, Set<Int>) throws -> [SafariAppleScriptTabRecord],
        focusWindow: @escaping (pid_t, Int) throws -> Void = { _, _ in }
    ) {
        self.listWindows = listWindows
        self.listTabs = listTabs
        self.focusWindow = focusWindow
    }

    static var live: SafariAppleScriptProcessBackend {
        SafariAppleScriptProcessBackend(
            listWindows: { processIdentifier in
                try SafariScriptingBridgeSession(processIdentifier: processIdentifier).windows()
            },
            listTabs: { processIdentifier, windowIdentifiers in
                try SafariScriptingBridgeSession(processIdentifier: processIdentifier)
                    .tabs(windowIdentifiers: windowIdentifiers)
            },
            focusWindow: { processIdentifier, windowIdentifier in
                try SafariScriptingBridgeSession(processIdentifier: processIdentifier)
                    .focusWindow(windowIdentifier)
            }
        )
    }

    static func executionError(
        for error: Error,
        processIdentifier: pid_t
    ) -> SafariAppleScriptError {
        let error = error as NSError
        let appleScriptErrorNumber = (error.userInfo["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue
        if error.code == -1712 || appleScriptErrorNumber == -1712 {
            return .requestTimedOut(processIdentifier: processIdentifier)
        }

        return .executionFailed(error.localizedDescription)
    }
}

private final class SafariScriptingBridgeSession: NSObject, SBApplicationDelegate {
    private static let timeoutTicks = 5 * 60

    private enum Code {
        static let windows: DescType = 0x6377_696E // cwin
        static let tabs: DescType = 0x6254_6162 // bTab
        static let currentTab: AEKeyword = 0x6354_6162 // cTab
        static let identifier: AEKeyword = 0x4944_2020 // ID__
        static let index: AEKeyword = 0x7069_6478 // pidx
        static let name: AEKeyword = 0x706E_616D // pnam
        static let url: AEKeyword = 0x7055_524C // pURL
    }

    private let application: SBApplication
    private let processIdentifier: pid_t
    private var lastError: Error?

    init(processIdentifier: pid_t) throws {
        guard let application = SBApplication(processIdentifier: processIdentifier) else {
            throw SafariAppleScriptError.executionFailed("Safari process \(processIdentifier) is unavailable.")
        }

        self.application = application
        self.processIdentifier = processIdentifier
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

    func tabs(windowIdentifiers: Set<Int>) throws -> [SafariAppleScriptTabRecord] {
        let windows = try elements(code: Code.windows, on: application)
        var records: [SafariAppleScriptTabRecord] = []

        for (windowOffset, window) in windows.enumerated() {
            let windowIdentifier = try requiredIntegerProperty(Code.identifier, on: window)
            guard windowIdentifiers.contains(windowIdentifier) else {
                continue
            }
            let tabs = try elements(code: Code.tabs, on: window)

            for (tabOffset, tab) in tabs.enumerated() {
                records.append(
                    SafariAppleScriptTabRecord(
                        windowIdentifier: windowIdentifier,
                        windowIndex: windowOffset + 1,
                        index: tabOffset + 1,
                        url: try optionalStringProperty(Code.url, on: tab),
                        title: try optionalStringProperty(Code.name, on: tab)
                    )
                )
            }
        }

        return records
    }

    func focusWindow(_ windowIdentifier: Int) throws {
        let windows = try elements(code: Code.windows, on: application)
        var targetWindow: SBObject?

        for window in windows where try requiredIntegerProperty(Code.identifier, on: window) == windowIdentifier {
            targetWindow = window
            break
        }

        guard let targetWindow else {
            throw SafariAppleScriptError.executionFailed(
                "Safari window \(windowIdentifier) is unavailable in the requested process."
            )
        }

        lastError = nil
        application.activate()
        try throwLastErrorIfNeeded()
        targetWindow.property(withCode: Code.index).setTo(1)
        try throwLastErrorIfNeeded()
    }

    private func windowRecord(_ window: SBObject) throws -> SafariAppleScriptWindowRecord {
        SafariAppleScriptWindowRecord(
            identifier: try requiredIntegerProperty(Code.identifier, on: window),
            name: try optionalStringProperty(Code.name, on: window),
            currentTabName: try optionalCurrentTabName(on: window),
            tabCount: try elements(code: Code.tabs, on: window).count
        )
    }

    private func optionalCurrentTabName(on window: SBObject) throws -> String? {
        lastError = nil
        let value = window.property(withCode: Code.currentTab).get()
        try throwLastTimeoutIfNeeded()
        guard let currentTab = value as? SBObject else {
            lastError = nil
            return nil
        }
        lastError = nil
        let name = try optionalStringProperty(Code.name, on: currentTab)
        return name.isEmpty ? nil : name
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

    private func optionalStringProperty(_ code: AEKeyword, on object: SBObject) throws -> String {
        lastError = nil
        let value = object.property(withCode: code).get()
        try throwLastTimeoutIfNeeded()
        lastError = nil
        return value as? String ?? ""
    }

    private func throwLastTimeoutIfNeeded() throws {
        guard let lastError else {
            return
        }
        self.lastError = nil

        let error = SafariAppleScriptProcessBackend.executionError(
            for: lastError,
            processIdentifier: processIdentifier
        )
        if case .requestTimedOut = error {
            throw error
        }
    }

    private func throwLastErrorIfNeeded() throws {
        guard let lastError else {
            return
        }
        self.lastError = nil
        throw SafariAppleScriptProcessBackend.executionError(
            for: lastError,
            processIdentifier: processIdentifier
        )
    }
}
