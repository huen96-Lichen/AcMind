// swift-tools-version:5.9
import Foundation
import PackageDescription

// MARK: - AcMind Package Configuration
//
// ⚠️ 本 Package 可独立构建和发布，不依赖 Electron 运行时。
// Electron 代码已归档到 src.legacy/ 作为参考实现。
//
// 构建方式：
//   swift build                          # Debug 构建
//   swift build -c Release               # Release 构建
//   scripts/build.sh                     # 完整构建 + 签名 + 打包
//
// 详见 docs/electron-decommission-guide.md

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
    ],
    dependencies: [],
    targets: [
        // 核心库：Models + Protocols + Services
        .target(
            name: "AcMindKit",
            dependencies: [],
            path: "AcMindKit",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        // 单元测试
        .testTarget(
            name: "AcMindKitTests",
            dependencies: ["AcMindKit"],
            path: "AcMindKitTests"
        ),
    ]
)
