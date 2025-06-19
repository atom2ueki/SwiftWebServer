// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "SwiftWebServer",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftWebServer",
            targets: ["SwiftWebServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.50.0")
    ],
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
