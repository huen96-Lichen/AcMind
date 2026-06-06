// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "ISTatStyle",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ISTatStyle",
            path: ".",
            exclude: ["Package.swift"]
        )
    ]
)
