# AcMind

Local-first AI 信息中枢 — 将碎片化信息蒸馏为结构化知识，导出到 Obsidian Vault。

## 功能概览

- **多源采集**：剪贴板、语音、截图、网页、PDF、DOCX 等 12 种内容类型
- **AI 蒸馏**：支持本地模型（Ollama）和云端 API（OpenAI 兼容），自动分层路由
- **Obsidian 导出**：生成带 Frontmatter 的 Markdown，直接写入 Vault
- **Capsule 悬浮窗**：独立的快速采集入口
- **知识卡片**：蒸馏结果以知识卡片形式管理，支持搜索和标签

## 环境要求

- **Xcode** >= 15.0
- **macOS** >= 14.0 (Sonoma)
- **Swift** >= 5.9
- **Ollama**（可选）— 用于本地 AI 蒸馏

## 快速开始

```bash
# 解析 Swift 依赖
swift package resolve

# 构建 Debug 版本
swift build

# 运行应用（macOS）
open .build/debug/AcMind.app
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `swift build` | 构建 Debug 版本 |
| `swift build -c release` | 构建 Release 版本 |
| `swift test --parallel` | 运行测试 |
| `bash scripts/build.sh` | 完整构建（含 Xcode） |
| `bash scripts/build.sh --release` | Release 构建 |
| `bash scripts/build.sh --release --package` | Release + DMG 打包 |
| `bash scripts/build.sh --clean` | 清理构建产物 |

## 项目结构

```
AcMind.xcodeproj/     # Xcode 项目
App/                  # SwiftUI 应用入口
├── AcMindApp.swift   # 应用入口
├── AppDelegate.swift # 生命周期管理
├── ServiceContainer.swift # DI 容器
└── ViewModels/       # 视图模型
AcMindKit/            # Swift Package 核心库
├── Models/           # 数据实体
├── Protocols/        # 服务抽象接口
└── Services/         # 业务逻辑实现
    ├── AI/           # Ollama + OpenAI + 任务队列
    ├── Input/        # 采集 + 剪贴板
    ├── Storage/      # SQLite 持久化
    ├── Workflow/     # 蒸馏 + 导出
    ├── Knowledge/    # 知识库 + 搜索
    ├── Voice/        # 录音 + ASR + 润色
    └── Settings/     # 配置 + 权限 + 快捷键
Features/             # 原生视图
├── Native/           # Agent/Inbox/Schedule/Settings/Capsule
└── Companion/        # Companion 浮层
Design/               # 设计系统
Resources/            # 资源文件
scripts/              # 构建脚本
docs/                 # 文档
```

详细架构说明以源码结构和设计系统为准，当前仓库里的 `docs/Design/` 只保留了少量参考资料。

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | SwiftUI + AppKit |
| 语言 | Swift 5.9 (strict concurrency) |
| 构建 | Xcode + SPM |
| 数据库 | GRDB.swift (SQLite) |
| 并发 | Swift Actor |
| CI | GitHub Actions |

## License

MIT
