// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "computer-automation",
    targets: [
        .target(
            name: "Safari"
        ),
        .executableTarget(
            name: "computer-automation",
            dependencies: ["Safari"]
        ),
        .testTarget(
            name: "computer-automationTests",
            dependencies: ["Safari"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
