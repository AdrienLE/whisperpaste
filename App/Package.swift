// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "WhisperpasteAppPkg",
    platforms: [ .macOS(.v12) ],
    products: [
        .executable(name: "WhisperpasteApp", targets: ["WhisperpasteApp"])
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "WhisperpasteApp",
            dependencies: [
                .product(name: "WhisperpasteCore", package: "whisperpaste")
            ],
            path: "Sources/Whisper2App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
