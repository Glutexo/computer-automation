import AppKit
import AutomationFoundation
import SafariAppleScript

public struct SafariToolbarItemRecord: Equatable, Sendable {
    public let index: Int
    public let role: String
    public let identifier: String?
    public let title: String?
    public let description: String?

    public init(index: Int, role: String, identifier: String? = nil, title: String? = nil, description: String? = nil) {
        self.index = index
        self.role = role
        self.identifier = identifier
        self.title = title
        self.description = description
    }

    init(_ record: SafariAppleScriptToolbarItemRecord) {
        self.init(
            index: record.index,
            role: record.role,
            identifier: record.identifier,
            title: record.title,
            description: record.description
        )
    }
}

public enum SafariToolbar: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "toolbar",
        abstract: "Safari front-window toolbar items.",
        commands: []
    )

    public static func listItems(
        executor: SafariAppleScriptExecuting = SafariAppleScriptExecutor()
    ) throws -> [SafariToolbarItemRecord] {
        do {
            return try SafariAppleScriptToolbar.listItems(executor: executor).map(SafariToolbarItemRecord.init)
        } catch {
            throw SafariUserInterfaceError.toolbarUnavailable
        }
    }

    static func format(_ item: SafariToolbarItemRecord) -> String {
        "\(item.index)|\(item.role)|\(item.identifier ?? "")|\(item.title ?? "")|\(item.description ?? "")"
    }
}
