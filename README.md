# AcMind

AcMind 是一款面向 macOS 的 local-first AI 信息整理工作台，基于 SwiftUI + AppKit 构建。

## 当前入口

- `App/`：应用入口、状态、启动和窗口管理
- `AcMindKit/`：模型、协议和服务层
- `Features/`：Native 与 Companion 视图
- `Shared/DesignSystem/`：共享设计系统
- `Resources/`：图标、资源和 Info.plist
- `scripts/`：构建与辅助脚本
- `docs/`：架构说明和迁移记录

## 构建与测试

```bash
swift package resolve
swift build
swift test --parallel
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `swift build` | 构建 Debug 版本 |
| `swift build -c release` | 构建 Release 版本 |
| `swift test --parallel` | 运行测试 |
| `swift test --list-tests` | 列出可发现的测试 |
| `bash scripts/build.sh` | 完整构建 |
| `bash scripts/build.sh --release` | Release 构建 |
| `bash scripts/build.sh --release --package` | Release + DMG 打包 |
| `bash scripts/build.sh --clean` | 清理构建产物 |

## 结构说明

当前仓库的主线实现已经从 Electron 迁移到 Swift 原生架构。仓库里如果仍出现历史迁移残留路径，那些内容不应作为新代码入口。

当前数据库层直接基于 SQLite3 封装，不再依赖 GRDB.swift 作为主实现。

## 说明

- 需要 macOS 14 或更高版本。
- Ollama 是可选能力，用于本地 AI 路由。
- `docs/Design/` 仅保留少量参考材料，当前架构以源码为准。
