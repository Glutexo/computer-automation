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
            name: "SafariAppleScript",
            dependencies: ["AutomationFoundation"]
        ),
        .target(
            name: "SafariUserInterface",
            dependencies: ["AutomationFoundation", "SafariAppleScript"]
        ),
        .target(
            name: "Safari",
            dependencies: ["AutomationFoundation", "SafariAppleScript", "SafariUserInterface"]
        ),
        .executableTarget(
            name: "computer-automation",
            dependencies: ["AutomationFoundation", "SafariAppleScript", "Safari", "SafariUserInterface"]
        ),
        .testTarget(
            name: "computer-automationTests",
            dependencies: ["AutomationFoundation", "SafariAppleScript", "Safari", "SafariUserInterface"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
