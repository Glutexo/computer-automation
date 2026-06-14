// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "computer-automation",
    platforms: [
        .macOS(.v10_15)
    ],
    targets: [
        .target(
            name: "AutomationFoundation"
        ),
        .target(
            name: "SafariDatabase",
            dependencies: ["AutomationFoundation"]
        ),
        .target(
            name: "SafariAppleScript",
            dependencies: ["AutomationFoundation"]
        ),
        .target(
            name: "SafariUserInterface",
            dependencies: ["AutomationFoundation", "SafariAppleScript"]
        ),
        .target(
            name: "Safari",
            dependencies: ["AutomationFoundation", "SafariAppleScript", "SafariDatabase", "SafariUserInterface"]
        ),
        .target(
            name: "ComputerAutomationKit",
            dependencies: ["AutomationFoundation", "Safari", "SafariUserInterface"]
        ),
        .executableTarget(
            name: "computer-automation",
            dependencies: ["ComputerAutomationKit"]
        ),
        .testTarget(
            name: "computer-automationTests",
            dependencies: ["AutomationFoundation", "SafariAppleScript", "SafariDatabase", "Safari", "SafariUserInterface", "ComputerAutomationKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
