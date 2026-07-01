import ApplicationServices
import Foundation

struct SafariAXPolling {
    let maxAttempts: Int
    let interval: TimeInterval
    let sleep: (TimeInterval) -> Void

    init(
        maxAttempts: Int = 20,
        interval: TimeInterval = 0.1,
        sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.interval = interval
        self.sleep = sleep
    }

    func firstResult<T>(_ lookup: () throws -> T?) rethrows -> T? {
        for attempt in 0..<maxAttempts {
            if let result = try lookup() {
                return result
            }

            if attempt < maxAttempts - 1 {
                sleep(interval)
            }
        }

        return nil
    }
}

enum SafariAX {
    typealias AttributeReader = (String, AXUIElement) -> CFTypeRef?

    static func copyAttributeValue(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func requiredElementValue(
        for attribute: String,
        on element: AXUIElement,
        error: SafariUserInterfaceError,
        readAttribute: AttributeReader = copyAttributeValue
    ) throws -> AXUIElement {
        guard let value = readAttribute(attribute, element), let attributeElement = axElement(from: value) else {
            throw error
        }

        return attributeElement
    }

    static func elementValue(
        for attribute: String,
        on element: AXUIElement,
        readAttribute: AttributeReader = copyAttributeValue
    ) -> AXUIElement? {
        guard let value = readAttribute(attribute, element) else {
            return nil
        }

        return axElement(from: value)
    }

    static func elements(
        for attribute: String,
        on element: AXUIElement,
        readAttribute: AttributeReader = copyAttributeValue
    ) -> [AXUIElement] {
        guard
            let value = readAttribute(attribute, element),
            CFGetTypeID(value) == CFArrayGetTypeID(),
            let values = value as? [CFTypeRef]
        else {
            return []
        }

        return values.compactMap(axElement(from:))
    }

    static func stringValue(
        for attribute: String,
        on element: AXUIElement,
        readAttribute: AttributeReader = copyAttributeValue
    ) -> String {
        guard let value = readAttribute(attribute, element) else {
            return ""
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return ""
    }

    static func booleanValue(
        for attribute: String,
        on element: AXUIElement,
        readAttribute: AttributeReader = copyAttributeValue
    ) -> Bool {
        (readAttribute(attribute, element) as? Bool) ?? false
    }

    private static func axElement(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }
}
