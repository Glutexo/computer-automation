import AutomationFoundation

public enum SafariDatabaseModule {
    public static let descriptor = ModuleDescriptor(
        name: "safari-database",
        abstract: "SafariTabs.db data models.",
        models: [
            SafariDatabaseProfile.descriptor,
            SafariDatabaseWindow.descriptor,
            SafariDatabaseTabGroup.descriptor
        ]
    )
}
