// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SwiftWebServer",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "SwiftWebServer",
            targets: ["SwiftWebServer"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftWebServer",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftWebServerTests",
            dependencies: ["SwiftWebServer"]
        ),
    ]
)
