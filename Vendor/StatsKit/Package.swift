// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StatsKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "StatsKit", targets: ["StatsKit"]),
    ],
    targets: [
        .target(name: "StatsKit", dependencies: [], path: "Sources/StatsKit"),
    ]
)
