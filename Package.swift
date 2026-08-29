// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MOVtoMP4",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MOVtoMP4", targets: ["MOVtoMP4"])
    ],
    targets: [
        .executableTarget(
            name: "MOVtoMP4",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "MOVtoMP4Tests",
            dependencies: ["MOVtoMP4"]
        )
    ]
)
