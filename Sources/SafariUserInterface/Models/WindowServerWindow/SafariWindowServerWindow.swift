import AppKit
import AutomationFoundation
import CoreGraphics
import Foundation

public struct SafariWindowServerWindowRecord: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let windowIdentifier: Int

    public init(processIdentifier: pid_t, windowIdentifier: Int) {
        self.processIdentifier = processIdentifier
        self.windowIdentifier = windowIdentifier
    }
}

public enum SafariWindowServerWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "window-server-window",
        abstract: "Live Safari windows addressed through WindowServer.",
        commands: []
    )

    public static func listWindows() throws -> [SafariWindowServerWindowRecord] {
        let processIdentifiers = Set(
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.apple.Safari")
                .map(\.processIdentifier)
        )

        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            throw SafariUserInterfaceError.windowListUnavailable
        }

        return records(
            safariProcessIdentifiers: processIdentifiers,
            windowInfo: windowInfo
        )
    }

    static func records(
        safariProcessIdentifiers: Set<pid_t>,
        windowInfo: [[String: Any]]
    ) -> [SafariWindowServerWindowRecord] {
        windowInfo.compactMap { info in
            guard
                let processNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
                safariProcessIdentifiers.contains(processNumber.int32Value),
                let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
                let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
                layerNumber.intValue == 0,
                let alphaNumber = info[kCGWindowAlpha as String] as? NSNumber,
                alphaNumber.doubleValue > 0,
                windowNumber.intValue > 0
            else {
                return nil
            }

            return SafariWindowServerWindowRecord(
                processIdentifier: processNumber.int32Value,
                windowIdentifier: windowNumber.intValue
            )
        }
    }
}
