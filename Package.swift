// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CleanScope",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CleanScope", targets: ["CleanScope"])
    ],
    targets: [
        .executableTarget(
            name: "CleanScope",
            path: "Sources/CleanScope"
        )
    ]
)
