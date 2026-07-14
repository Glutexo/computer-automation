import ApplicationServices
import AutomationFoundation
import Foundation

public struct SafariAccessibilityWindowRecord: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let name: String

    public init(processIdentifier: pid_t, name: String) {
        self.processIdentifier = processIdentifier
        self.name = name
    }
}

public enum SafariAccessibilityWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "accessibility-window",
        abstract: "Safari windows addressed through Accessibility.",
        commands: []
    )

    public static func closeFocusedWindow(
        performClose: () throws -> Void
    ) throws {
        try closeFocusedWindow(
            performClose: performClose,
            accessibility: .live
        )
    }

    public static func listWindows() throws -> [SafariAccessibilityWindowRecord] {
        guard AXIsProcessTrusted() else {
            throw SafariUserInterfaceError.windowListUnavailable
        }
        return try listWindows(accessibility: .live)
    }

    static func listWindows(
        accessibility: SafariAccessibilityBackend
    ) throws -> [SafariAccessibilityWindowRecord] {
        try accessibility.applications().flatMap { application -> [SafariAccessibilityWindowRecord] in
            guard let processIdentifier = application.processIdentifier else {
                return []
            }

            return try accessibility.requiredElements(
                for: kAXWindowsAttribute,
                on: application.element,
                error: .windowListUnavailable
            ).map { window in
                SafariAccessibilityWindowRecord(
                    processIdentifier: processIdentifier,
                    name: accessibility.stringValue(for: kAXTitleAttribute, on: window)
                )
            }
        }
    }

    static func closeFocusedWindow(
        performClose: () throws -> Void,
        accessibility: SafariAccessibilityBackend
    ) throws {
        guard let focusedWindow = focusedSafariWindow(accessibility: accessibility) else {
            throw SafariUserInterfaceError.focusedWindowUnavailable
        }

        try closeCapturedWindow(
            performClose: performClose,
            isVisible: {
                accessibility.booleanValue(for: "AXVisible", on: focusedWindow)
            },
            pressCloseButton: {
                guard let closeButton = accessibility.elementValue(
                    for: kAXCloseButtonAttribute,
                    on: focusedWindow
                ) else {
                    return false
                }

                return accessibility.perform(kAXPressAction, on: closeButton)
            },
            sleep: accessibility.polling.sleep,
            maxAttempts: accessibility.polling.maxAttempts,
            interval: accessibility.polling.interval
        )
    }

    static func closeCapturedWindow(
        performClose: () throws -> Void,
        isVisible: () -> Bool,
        pressCloseButton: () -> Bool,
        sleep: (TimeInterval) -> Void = Thread.sleep,
        maxAttempts: Int = 10,
        interval: TimeInterval = 0.1
    ) throws {
        try performClose()

        if waitUntilNotVisible(
            isVisible: isVisible,
            sleep: sleep,
            maxAttempts: maxAttempts,
            interval: interval
        ) {
            return
        }

        guard pressCloseButton() else {
            throw SafariUserInterfaceError.windowCloseButtonUnavailable
        }

        guard waitUntilNotVisible(
            isVisible: isVisible,
            sleep: sleep,
            maxAttempts: maxAttempts,
            interval: interval
        ) else {
            throw SafariUserInterfaceError.windowCloseNotVerified
        }
    }

    private static func focusedSafariWindow(accessibility: SafariAccessibilityBackend) -> AXUIElement? {
        for application in accessibility.applications() {
            if let focusedWindow = accessibility.elementValue(
                for: kAXFocusedWindowAttribute,
                on: application.element
            ) {
                return focusedWindow
            }
        }

        return nil
    }

    private static func waitUntilNotVisible(
        isVisible: () -> Bool,
        sleep: (TimeInterval) -> Void,
        maxAttempts: Int,
        interval: TimeInterval
    ) -> Bool {
        for attempt in 0..<max(1, maxAttempts) {
            if !isVisible() {
                return true
            }

            if attempt < max(1, maxAttempts) - 1 {
                sleep(interval)
            }
        }

        return false
    }
}
