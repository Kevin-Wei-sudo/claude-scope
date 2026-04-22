// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClaudeScope",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeScope",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
