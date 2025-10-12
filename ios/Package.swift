// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GhostTalk",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "GhostTalk",
            targets: ["GhostTalk"]
        )
    ],
    dependencies: [
        // SQLCipher for encrypted storage
        .package(url: "https://github.com/sqlcipher/sqlcipher.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "GhostTalk",
            dependencies: [],
            path: "GhostTalk"
        ),
        .testTarget(
            name: "GhostTalkTests",
            dependencies: ["GhostTalk"],
            path: "GhostTalkTests"
        )
    ]
)
