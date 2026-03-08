// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OpenPaw",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "OpenPaw",
            dependencies: ["HighlightSwift"],
            path: "Sources/OpenPaw"
        ),
        .testTarget(
            name: "OpenPawTests",
            dependencies: ["OpenPaw"],
            path: "Tests/OpenPawTests"
        )
    ]
)
