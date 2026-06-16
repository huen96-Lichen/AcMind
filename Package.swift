// swift-tools-version:5.9
import Foundation
import PackageDescription

// MARK: - AcMind Package Configuration
//
// ⚠️ 本 Package 可独立构建和发布，不依赖旧桌面前端运行时。
// 旧前端代码已完全移除。
//
// 构建方式：
//   swift build                          # Debug 构建
//   swift build -c Release               # Release 构建
//   scripts/build.sh                     # 完整构建 + 签名 + 打包
//
// 详见仓库内的 Swift 构建与交接文档。

let package = Package(
    name: "AcMind",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // 核心库：可被其他 Swift 包或 Xcode target 引用
        .library(
            name: "AcMindKit",
            targets: ["AcMindKit"]
        ),
        .executable(
            name: "AcMindSystemStatusHelper",
            targets: ["AcMindSystemStatusHelper"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.18.0"),
    ],
    targets: [
        .target(
            name: "AcMindHIDBridge",
            path: "AcMindKit/Services/SystemStatus/HIDBridge",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        ),
        // 核心库：Models + Protocols + Services
        .target(
            name: "AcMindKit",
            dependencies: [
                "AcMindHIDBridge",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            path: "AcMindKit",
            exclude: [
                "Services/SystemStatus/HIDBridge",
                "Services/SystemStatus/HelperTool"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "AcMindSystemStatusHelper",
            dependencies: ["AcMindKit"],
            path: "AcMindKit/Services/SystemStatus/HelperTool"
        ),
        // 单元测试
        .testTarget(
            name: "AcMindKitTests",
            dependencies: ["AcMindKit"],
            path: "AcMindKitTests"
        ),
    ]
)
