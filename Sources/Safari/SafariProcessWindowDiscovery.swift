import Foundation
import SafariAppleScript
import SafariUserInterface

struct SafariProcessWindowRecord: Equatable, Sendable {
    let processIdentifier: pid_t
    let window: SafariAppleScriptWindowRecord
}

enum SafariProcessWindowDiscovery {
    static func list(
        listWindowServerWindows: () throws -> [SafariWindowServerWindowRecord] = SafariWindowServerWindow.listWindows,
        listScriptWindows: (pid_t) throws -> [SafariAppleScriptWindowRecord] = { processIdentifier in
            try SafariAppleScriptWindow.list(processIdentifier: processIdentifier)
        }
    ) throws -> [SafariProcessWindowRecord] {
        let windowServerWindows = try listWindowServerWindows()
        var processOrder: [pid_t] = []
        var windowIdentifiersByProcess: [pid_t: Set<Int>] = [:]

        for window in windowServerWindows {
            if windowIdentifiersByProcess[window.processIdentifier] == nil {
                processOrder.append(window.processIdentifier)
            }
            windowIdentifiersByProcess[window.processIdentifier, default: []]
                .insert(window.windowIdentifier)
        }

        return try processOrder.flatMap { processIdentifier in
            let liveWindowIdentifiers = windowIdentifiersByProcess[processIdentifier] ?? []
            let scriptedWindows = try listScriptWindows(processIdentifier)
            let selectedWindows = selectLiveWindows(
                from: scriptedWindows,
                windowIdentifiers: liveWindowIdentifiers
            )

            return selectedWindows.map {
                SafariProcessWindowRecord(processIdentifier: processIdentifier, window: $0)
            }
        }
    }

    static func selectLiveWindows(
        from scriptedWindows: [SafariAppleScriptWindowRecord],
        windowIdentifiers: Set<Int>
    ) -> [SafariAppleScriptWindowRecord] {
        scriptedWindows.filter {
            windowIdentifiers.contains($0.identifier) && $0.tabCount != 0
        }
    }
}
