// swift-tools-version:5.10
// Swift 5.10 is the minimum because the package uses `nonisolated(unsafe)`
// (Swift 5.10) and `MainActor.assumeIsolated` (Swift 5.9). Older Swift
// toolchains cannot even parse this manifest's source set.
import PackageDescription

let package = Package(
    name: "SwiftWebServer",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
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
