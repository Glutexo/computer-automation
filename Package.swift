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
            name: "Safari",
            dependencies: ["AutomationFoundation"]
        ),
        .executableTarget(
            name: "computer-automation",
            dependencies: ["AutomationFoundation", "Safari"]
        ),
        .testTarget(
            name: "computer-automationTests",
            dependencies: ["AutomationFoundation", "Safari"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
