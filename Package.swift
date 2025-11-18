// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterDocs",
    platforms: [
        .macOS(.v15)  // macOS 15 Sequoia - Latest 2024/2025
    ],
    products: [
        .executable(
            name: "BetterDocs",
            targets: ["BetterDocs"]
        ),
    ],
    dependencies: [
        // Swift Markdown for parsing .md files (Apple official)
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "BetterDocs",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "BetterDocs/Sources"
            // TODO: Enable strict concurrency after fixing actor isolation issues
            // swiftSettings: [
            //     .enableUpcomingFeature("StrictConcurrency"),
            //     .enableExperimentalFeature("StrictConcurrency"),
            // ]
        ),
        .testTarget(
            name: "BetterDocsTests",
            dependencies: ["BetterDocs"],
            path: "BetterDocs/Tests"
        )
    ],
    swiftLanguageModes: [.v6]  // Swift 6 language mode
)
