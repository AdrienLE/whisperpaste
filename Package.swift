// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "whisperpaste",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "WhisperpasteCore", targets: ["WhisperpasteCore"])
    ],
    dependencies: [
        // No external dependencies in the skeleton.
    ],
    targets: [
        .target(
            name: "WhisperpasteCore",
            path: "Sources/Whisper2Core"
        ),
        .testTarget(
            name: "WhisperpasteCoreTests",
            dependencies: ["WhisperpasteCore"],
            path: "Tests/Whisper2CoreTests"
        )
    ]
)
