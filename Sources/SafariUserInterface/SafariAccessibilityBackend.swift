import AppKit
import ApplicationServices
import Foundation
import SafariAppleScript

struct SafariAccessibilityApplication {
    let element: AXUIElement
    private let activation: () -> Void

    init(element: AXUIElement, activate: @escaping () -> Void = {}) {
        self.element = element
        self.activation = activate
    }

    func activate() {
        activation()
    }
}

struct SafariAccessibilityBackend {
    typealias ApplicationLookup = () -> [SafariAccessibilityApplication]
    typealias AttributeReader = (String, AXUIElement) -> CFTypeRef?
    typealias AttributeWriter = (String, CFTypeRef, AXUIElement) -> Bool
    typealias ActionPerformer = (String, AXUIElement) -> Bool

    let applications: ApplicationLookup
    let readAttribute: AttributeReader
    let writeAttribute: AttributeWriter
    let performAction: ActionPerformer
    let polling: SafariAXPolling

    init(
        applications: @escaping ApplicationLookup,
        readAttribute: @escaping AttributeReader = SafariAX.copyAttributeValue,
        writeAttribute: @escaping AttributeWriter = { attribute, value, element in
            AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
        },
        performAction: @escaping ActionPerformer = { action, element in
            AXUIElementPerformAction(element, action as CFString) == .success
        },
        polling: SafariAXPolling = SafariAXPolling()
    ) {
        self.applications = applications
        self.readAttribute = readAttribute
        self.writeAttribute = writeAttribute
        self.performAction = performAction
        self.polling = polling
    }

    static var live: SafariAccessibilityBackend {
        SafariAccessibilityBackend(
            applications: {
                NSRunningApplication
                    .runningApplications(withBundleIdentifier: "com.apple.Safari")
                    .sorted { lhs, rhs in lhs.isActive && !rhs.isActive }
                    .map { application in
                        SafariAccessibilityApplication(
                            element: AXUIElementCreateApplication(application.processIdentifier),
                            activate: {
                                application.activate(options: [.activateIgnoringOtherApps])
                            }
                        )
                    }
            }
        )
    }

    func requiredElementValue(
        for attribute: String,
        on element: AXUIElement,
        error: SafariUserInterfaceError
    ) throws -> AXUIElement {
        try SafariAX.requiredElementValue(
            for: attribute,
            on: element,
            error: error,
            readAttribute: readAttribute
        )
    }

    func elementValue(for attribute: String, on element: AXUIElement) -> AXUIElement? {
        SafariAX.elementValue(for: attribute, on: element, readAttribute: readAttribute)
    }

    func elements(for attribute: String, on element: AXUIElement) -> [AXUIElement] {
        SafariAX.elements(for: attribute, on: element, readAttribute: readAttribute)
    }

    func stringValue(for attribute: String, on element: AXUIElement) -> String {
        SafariAX.stringValue(for: attribute, on: element, readAttribute: readAttribute)
    }

    func booleanValue(for attribute: String, on element: AXUIElement) -> Bool {
        SafariAX.booleanValue(for: attribute, on: element, readAttribute: readAttribute)
    }

    func setAttribute(_ attribute: String, to value: CFTypeRef, on element: AXUIElement) -> Bool {
        writeAttribute(attribute, value, element)
    }

    func perform(_ action: String, on element: AXUIElement) -> Bool {
        performAction(action, element)
    }
}

enum SafariUserInterfaceBackend {
    case accessibility(SafariAccessibilityBackend)
    case appleScript(SafariAppleScriptExecuting)
}
