# AcMind

AcMind 是一款面向 macOS 的本地优先电脑助手。

它不是单纯的 AI 对话壳，而是把“采集、识别、整理、导出、监控、常驻交互”放在同一套桌面工作流里：

- 通过灵动大陆、桌面胶囊、热角和全局快捷键，提供常驻式入口
- 通过说入法，把语音直接转成可用文本并写回当前工作流
- 通过系统状态监控，持续查看 CPU、内存、磁盘、网络、电池和活跃进程
- 通过采集与蒸馏链路，把剪贴板、语音、截图、网页、PDF、DOCX 等内容整理成结构化知识
- 通过 Obsidian 导出，把结果直接写入 Vault

## 这款软件在做什么

AcMind 的核心定位是“电脑助手 + 知识中枢”：

1. 作为电脑助手，它负责常驻唤起、系统监控、快捷入口、语音输入、热角触发、桌面胶囊和灵动大陆。
2. 作为知识中枢，它负责多源采集、AI 蒸馏、知识卡片管理、搜索、标签和导出。
3. 作为本地优先应用，它优先支持本地模型和本地存储，同时兼容 OpenAI-compatible 云端接口。

## 主要功能

### 常驻桌面能力

- 灵动大陆：展开 / 收起两种形态，带顶部导航、页面切换和系统事件 HUD
- 桌面胶囊：轻量常驻入口，适合快速查看和触发
- 热角：支持屏幕角落触发动作与可视化覆盖区域
- 全局快捷键：统一接入主窗口、采集、语音和页面切换
- 状态栏菜单：提供应用级的快速控制入口

### 说入法

- 支持 Fn 长按、单击切换、双击锁定等触发模式
- 支持录音、ASR 转写、自动润色、连续输入和静音检测
- 支持多种输出方式：复制到剪贴板、自动粘贴、询问
- 支持写入收集箱，便于后续蒸馏或整理

### 系统状态监控

- CPU 使用率
- 内存占用
- 磁盘占用
- 网络上下行速率
- 电池电量与供电状态
- 活跃进程列表

### 采集与知识整理

- 剪贴板采集
- 截图与区域截图
- 语音录入
- 网页内容处理
- PDF / DOCX 等文档输入
- AI 蒸馏为结构化 Markdown
- 导出到 Obsidian Vault

### 原生工作台

- 首页
- Agent
- 收集箱
- 剪贴板
- 日程
- 工具台
- 灵动大陆配置
- 系统状态
- 说入法
- 设置

## 环境要求

- Xcode >= 15.0
- macOS >= 14.0 (Sonoma)
- Swift >= 5.9
- Ollama（可选，用于本地 AI 推理）

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
|---|---|
| `swift build` | 构建 Debug 版本 |
| `swift build -c release` | 构建 Release 版本 |
| `swift test --parallel` | 运行测试 |
| `bash scripts/build.sh` | 完整构建（含 Xcode） |
| `bash scripts/build.sh --release` | Release 构建 |
| `bash scripts/build.sh --release --package` | Release + DMG 打包 |
| `bash scripts/build.sh --clean` | 清理构建产物 |

## 项目结构

```text
AcMind.xcodeproj/     # Xcode 工程
App/                  # 应用入口、生命周期、全局状态、视图模型
AcMindKit/            # 核心业务库
├── Models/           # 数据模型
├── Protocols/        # 抽象接口
└── Services/         # 业务服务
    ├── AI/           # Provider 路由、聊天、蒸馏、任务队列
    ├── Agent/        # Agent 相关路由与能力编排
    ├── Hotkeys/      # 热键与输入监控
    ├── Input/        # 采集、剪贴板、上下文捕获
    ├── Knowledge/    # 知识卡片与搜索
    ├── Permissions/  # 权限管理
    ├── Settings/     # 配置与偏好
    ├── Storage/      # SQLite / 文件存储 / 迁移
    ├── Sync/         # 云同步
    ├── SystemStatus/ # 系统状态采样
    ├── UI/           # 灵动大陆、热角等 UI 规则
    ├── Voice/        # 录音、ASR、润色、说入法
    └── Workflow/     # 蒸馏与导出
Features/             # 主要界面
├── Companion/        # 灵动大陆、桌面胶囊、常驻交互
├── Native/           # 原生页面与工作台
├── Sidebar/          # 侧边栏
Design/               # 设计系统
Resources/            # 资源文件
Vendor/               # 第三方依赖
docs/                 # 架构与交接文档
scripts/              # 构建脚本
```

## 技术栈

| 层 | 技术 |
|---|---|
| UI | SwiftUI + AppKit |
| 语言 | Swift 5.9 / strict concurrency |
| 构建 | Xcode + Swift Package Manager |
| 数据库 | GRDB.swift / SQLite |
| AI | Ollama、OpenAI-compatible API、WhisperKit、其他本地 ASR 实现 |
| 并发 | Swift Concurrency / Actor |

## 架构说明

更多模型调用与路由说明见：

- [docs/model-invocation-architecture.md](</Volumes/White Atlas/03_Projects/AcMind/docs/model-invocation-architecture.md>)
- [docs/acmind-handoff-2026-05-13.md](</Volumes/White Atlas/03_Projects/AcMind/docs/acmind-handoff-2026-05-13.md>)

## 许可证

MIT
