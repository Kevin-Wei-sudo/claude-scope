// swift-tools-version: 5.9

import PackageDescription
import Foundation

let isAppStoreBuild = ProcessInfo.processInfo.environment["APP_STORE"] == "1"

let packageDependencies: [Package.Dependency] = isAppStoreBuild
    ? []
    : [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.8.1")
    ]

let executableDependencies: [Target.Dependency] = isAppStoreBuild
    ? []
    : [
        .product(name: "Sparkle", package: "Sparkle")
    ]

let executableSwiftSettings: [SwiftSetting] = isAppStoreBuild
    ? [.define("APP_STORE")]
    : []

let package = Package(
    name: "ClaudeScope",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: "ClaudeScope",
            dependencies: executableDependencies,
            path: "Sources/ClaudeScope",
            resources: [
                .process("Resources")
            ],
            swiftSettings: executableSwiftSettings,
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "ClaudeScopeTests",
            dependencies: ["ClaudeScope"],
            path: "Tests/ClaudeScopeTests"
        )
    ]
)
