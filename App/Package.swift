// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Whisper2AppPkg",
    platforms: [ .macOS(.v12) ],
    products: [
        .executable(name: "Whisper2App", targets: ["Whisper2App"])
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "Whisper2App",
            dependencies: [
                .product(name: "Whisper2Core", package: "whisper2")
            ],
            path: "Sources/Whisper2App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech")
            ]
        )
    ]
)
