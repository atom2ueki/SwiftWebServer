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
            targets: ["SwiftWebServerCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftWebServerCore",
            dependencies: [],
            path: "Sources/SwiftWebServerCore"
        ),
        .testTarget(
            name: "SwiftWebServerTests",
            dependencies: ["SwiftWebServerCore"],
            path: "SwiftWebServerTests"
        ),
    ]
)
