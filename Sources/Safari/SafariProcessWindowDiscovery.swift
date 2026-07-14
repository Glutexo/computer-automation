import Foundation
import SafariAppleScript
import SafariUserInterface

struct SafariProcessWindowRecord: Equatable, Sendable {
    let processIdentifier: pid_t
    let window: SafariAppleScriptWindowRecord
}

enum SafariProcessWindowDiscovery {
    static func list(
        listAccessibilityWindows: () throws -> [SafariAccessibilityWindowRecord] = SafariAccessibilityWindow.listWindows,
        listScriptWindows: (pid_t) throws -> [SafariAppleScriptWindowRecord] = { processIdentifier in
            try SafariAppleScriptWindow.list(processIdentifier: processIdentifier)
        }
    ) throws -> [SafariProcessWindowRecord] {
        let accessibilityWindows = try listAccessibilityWindows()
        var processOrder: [pid_t] = []
        var windowNamesByProcess: [pid_t: [String]] = [:]

        for window in accessibilityWindows {
            if windowNamesByProcess[window.processIdentifier] == nil {
                processOrder.append(window.processIdentifier)
            }
            windowNamesByProcess[window.processIdentifier, default: []].append(window.name)
        }

        return try processOrder.flatMap { processIdentifier in
            let windowNames = windowNamesByProcess[processIdentifier] ?? []
            let scriptedWindows = try listScriptWindows(processIdentifier)
            let selectedWindows = selectAccessibilityWindows(
                from: scriptedWindows,
                windowNames: windowNames
            )

            return selectedWindows.map {
                SafariProcessWindowRecord(processIdentifier: processIdentifier, window: $0)
            }
        }
    }

    static func selectAccessibilityWindows(
        from scriptedWindows: [SafariAppleScriptWindowRecord],
        windowNames: [String]
    ) -> [SafariAppleScriptWindowRecord] {
        guard !windowNames.isEmpty else {
            return []
        }

        var remainingNameCounts = windowNames.reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }

        return scriptedWindows.filter { window in
            guard let count = remainingNameCounts[window.name], count > 0 else {
                return false
            }
            remainingNameCounts[window.name] = count - 1
            return true
        }
    }
}
