import Testing
import Foundation
import ApplicationServices
import SQLite3
@testable import AutomationFoundation
@testable import SafariAppleScript
@testable import SafariDatabase
@testable import Safari
@testable import SafariUserInterface
@testable import ComputerAutomationKit

@Test func safariDatabaseModuleExposesDatabaseEntityMetadata() async throws {
    #expect(SafariDatabaseModule.descriptor.name == "safari-database")
    #expect(
        SafariDatabaseModule.descriptor.models ==
        [
            SafariDatabaseProfile.descriptor,
            SafariDatabaseWindow.descriptor,
            SafariDatabaseTabGroup.descriptor
        ]
    )
    #expect(SafariDatabaseProfile.descriptor.name == "profile")
    #expect(SafariDatabaseWindow.descriptor.name == "window")
    #expect(SafariDatabaseTabGroup.descriptor.name == "tab-group")
}

@Test func safariModuleExposesApplicationModelMetadata() async throws {
    #expect(SafariModule.descriptor.name == "safari")
    #expect(
        SafariModule.descriptor.models ==
        [
            SafariApplication.descriptor,
            SafariProfile.descriptor,
            SafariWindow.descriptor,
            SafariTabGroup.descriptor,
            SafariTabList.descriptor,
            SafariTab.descriptor
        ]
    )
    #expect(SafariApplication.descriptor.name == "application")
    #expect(SafariApplication.bundleIdentifier == "com.apple.Safari")
    #expect(
        SafariApplication.descriptor.commands ==
        [
            SafariApplicationLaunchCommand.descriptor,
            SafariApplicationRunningCommand.descriptor,
            SafariApplicationQuitCommand.descriptor
        ]
    )
    #expect(SafariApplicationLaunchCommand.descriptor.operation == .create)
    #expect(SafariApplicationRunningCommand.descriptor.operation == .read)
    #expect(SafariApplicationQuitCommand.descriptor.operation == .delete)
    #expect(SafariProfile.descriptor.name == "profile")
    #expect(
        SafariProfile.descriptor.commands ==
        [
            SafariProfileListCommand.descriptor,
            SafariProfileFindCommand.descriptor,
            SafariProfileResolveCommand.descriptor
        ]
    )
    #expect(SafariProfileListCommand.descriptor.operation == .read)
    #expect(SafariProfileFindCommand.descriptor.operation == .read)
    #expect(SafariProfileResolveCommand.descriptor.operation == .read)
    #expect(SafariWindow.descriptor.name == "window")
    #expect(
        SafariWindow.descriptor.commands ==
        [
            SafariWindowOpenCommand.descriptor,
            SafariWindowOpenPrivateCommand.descriptor,
            SafariWindowOpenTabGroupCommand.descriptor,
            SafariWindowListCommand.descriptor,
            SafariWindowSetTabGroupCommand.descriptor,
            SafariWindowCloseCommand.descriptor
        ]
    )
    #expect(SafariWindowOpenCommand.descriptor.operation == .create)
    #expect(SafariWindowOpenPrivateCommand.descriptor.operation == .create)
    #expect(SafariWindowOpenCommand.descriptor.arguments.count == 1)
    #expect(SafariWindowOpenCommand.descriptor.arguments[0].name == "profile")
    #expect(!SafariWindowOpenCommand.descriptor.arguments[0].isRequired)
    #expect(SafariWindowListCommand.descriptor.operation == .read)
    #expect(SafariWindowCloseCommand.descriptor.operation == .delete)
    #expect(SafariTabGroup.descriptor.name == "tab-group")
    #expect(
        SafariTabGroup.descriptor.commands ==
        [
            SafariTabGroupCreateCommand.descriptor,
            SafariTabGroupEnsureCommand.descriptor,
            SafariTabGroupListCommand.descriptor,
            SafariTabGroupSidebarListCommand.descriptor,
            SafariTabGroupFindCommand.descriptor,
            SafariTabGroupResolveCommand.descriptor,
            SafariTabGroupRenameCommand.descriptor,
            SafariTabGroupDeleteCommand.descriptor
        ]
    )
    #expect(SafariTabGroupCreateCommand.descriptor.operation == .create)
    #expect(SafariTabGroupEnsureCommand.descriptor.operation == .create)
    #expect(SafariTabGroupListCommand.descriptor.operation == .read)
    #expect(SafariTabGroupSidebarListCommand.descriptor.operation == .read)
    #expect(!SafariTabGroupSidebarListCommand.descriptor.isReadOnly)
    #expect(SafariTabGroupRenameCommand.descriptor.operation == .update)
    #expect(SafariTabGroupDeleteCommand.descriptor.operation == .delete)
    #expect(SafariTabList.descriptor.name == "tab-list")
    #expect(
        SafariTabList.descriptor.commands ==
        [
            SafariTabListEnsureURLsCommand.descriptor,
            SafariTabListReorderURLsCommand.descriptor,
            SafariTabListTabGroupTabsCommand.descriptor,
            SafariTabListWindowTabsCommand.descriptor
        ]
    )
    #expect(SafariTabListEnsureURLsCommand.descriptor.operation == .update)
    #expect(SafariTabListReorderURLsCommand.descriptor.operation == .update)
    #expect(SafariTabListTabGroupTabsCommand.descriptor.operation == .read)
    #expect(SafariTabListWindowTabsCommand.descriptor.operation == .read)
    #expect(SafariTab.descriptor.name == "tab")
    #expect(
        SafariTab.descriptor.commands ==
        [
            SafariTabOpenCommand.descriptor,
            SafariTabListCommand.descriptor,
            SafariTabFindCommand.descriptor,
            SafariTabResolveCommand.descriptor,
            SafariTabExecuteJavaScriptCommand.descriptor,
            SafariTabSetURLCommand.descriptor,
            SafariTabCloseCommand.descriptor
        ]
    )
    #expect(SafariTabOpenCommand.descriptor.operation == .create)
    #expect(SafariTabListCommand.descriptor.operation == .read)
    #expect(SafariTabListCommand.descriptor.isReadOnly)
    #expect(!SafariTabExecuteJavaScriptCommand.descriptor.isReadOnly)
    #expect(SafariTabSetURLCommand.descriptor.operation == .update)
    #expect(SafariTabCloseCommand.descriptor.operation == .delete)
    #expect(SafariUserInterfaceModule.descriptor.models == [
        SafariApplicationMenuBar.descriptor,
        SafariAccessibilityWindow.descriptor,
        SafariWindowServerWindow.descriptor,
        SafariSidebar.descriptor,
        SafariMenu.descriptor,
        SafariFileMenu.descriptor,
        SafariMenuItem.descriptor
    ])
    #expect(SafariApplicationMenuBar.descriptor.commands == [SafariApplicationMenuBarListCommand.descriptor])
    #expect(SafariApplicationMenuBarListCommand.descriptor.operation == .read)
    #expect(SafariSidebar.descriptor.commands.isEmpty)
    #expect(SafariMenu.descriptor.commands == [SafariMenuListItemsCommand.descriptor])
    #expect(SafariMenuListItemsCommand.descriptor.operation == .read)
    #expect(SafariMenuListItemsCommand.descriptor.arguments.count == 1)
    #expect(SafariFileMenu.descriptor.commands == [SafariFileMenuListCommand.descriptor])
    #expect(SafariFileMenuListCommand.descriptor.operation == .read)
    #expect(SafariMenuItem.descriptor.commands == [SafariMenuItemListChildItemsCommand.descriptor])
    #expect(SafariMenuItemListChildItemsCommand.descriptor.operation == .read)
    #expect(SafariMenuItemListChildItemsCommand.descriptor.arguments.count == 2)
    #expect(SafariAppleScriptModule.descriptor.models == [
        SafariAppleScriptApplication.descriptor,
        SafariAppleScriptWindow.descriptor,
        SafariAppleScriptTab.descriptor,
        SafariAppleScriptSidebar.descriptor,
        SafariAppleScriptApplicationMenuBar.descriptor,
        SafariAppleScriptMenu.descriptor,
        SafariAppleScriptMenuItem.descriptor
    ])
}

@Test func architectureDocumentationCoversDescriptorInventory() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let architecture = try String(
        contentsOf: repositoryRoot.appendingPathComponent("docs/architecture.md"),
        encoding: .utf8
    )

    let modelInventories: [([ModelDescriptor], [String])] = [
        (
            SafariModule.descriptor.models,
            [
                "SafariApplication model",
                "SafariProfile model",
                "SafariWindow model",
                "SafariTabGroup model",
                "SafariTabList model",
                "SafariTab model"
            ]
        ),
        (
            SafariUserInterfaceModule.descriptor.models,
            [
                "SafariApplicationMenuBar model",
                "SafariAccessibilityWindow model",
                "SafariWindowServerWindow model",
                "SafariSidebar model",
                "SafariMenu model",
                "SafariFileMenu model",
                "SafariMenuItem model"
            ]
        ),
        (
            SafariAppleScriptModule.descriptor.models,
            [
                "SafariAppleScriptApplication model",
                "SafariAppleScriptWindow model",
                "SafariAppleScriptTab model",
                "SafariAppleScriptSidebar model",
                "SafariAppleScriptApplicationMenuBar model",
                "SafariAppleScriptMenu model",
                "SafariAppleScriptMenuItem model"
            ]
        ),
        (
            SafariDatabaseModule.descriptor.models,
            [
                "SafariDatabaseProfile model",
                "SafariDatabaseWindow model",
                "SafariDatabaseTabGroup model"
            ]
        )
    ]

    for (descriptors, documentedModels) in modelInventories {
        #expect(descriptors.count == documentedModels.count)
        for model in documentedModels {
            #expect(architecture.contains("\(model)\"]"))
        }
    }

    for command in SafariModule.descriptor.commands + SafariUserInterfaceModule.descriptor.commands {
        #expect(architecture.contains("\(command.name) command\"]"))
    }
}
