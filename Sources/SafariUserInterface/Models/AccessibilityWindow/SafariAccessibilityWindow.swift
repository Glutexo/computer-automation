import ApplicationServices
import AutomationFoundation
import Foundation

public enum SafariAccessibilityWindow: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "accessibility-window",
        abstract: "A focused Safari window addressed through Accessibility.",
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
