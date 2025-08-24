// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "whisper2",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "Whisper2Core", targets: ["Whisper2Core"])
    ],
    dependencies: [
        // No external dependencies in the skeleton.
    ],
    targets: [
        .target(
            name: "Whisper2Core",
            path: "Sources/Whisper2Core"
        ),
        .testTarget(
            name: "Whisper2CoreTests",
            dependencies: ["Whisper2Core"],
            path: "Tests/Whisper2CoreTests"
        )
    ]
)
