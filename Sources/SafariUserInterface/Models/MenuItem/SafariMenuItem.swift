import AutomationFoundation

public struct SafariMenuItemRecord: Equatable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public enum SafariMenuItem: ModelModel {
    public static let descriptor = ModelDescriptor(
        name: "menu-item",
        abstract: "A Safari menu item.",
        commands: []
    )
}
