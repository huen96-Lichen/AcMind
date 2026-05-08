# AcMind 项目交接文档

> **生成日期**: 2026-05-09
> **项目版本**: v0.13.0
> **文档目的**: 为新接手开发者提供项目全景概览，快速上手开发与维护。

---

## 一、项目概述

| 项 | 值 |
|---|---|
| **项目名称** | AcMind |
| **定位** | Local-first AI 信息中枢 |
| **核心价值** | 将碎片化信息蒸馏为结构化知识，导出到 Obsidian Vault |
| **母品牌** | Acore（自 v0.11.0 统一为 AcMind） |
| **许可证** | MIT |
| **最低平台** | macOS 14.0 (Sonoma) |
| **最低 Xcode** | 15.0 |

---

## 二、技术栈

| 层 | 技术 |
|---|---|
| **语言** | Swift 5.9（strict concurrency） |
| **UI 框架** | SwiftUI + AppKit |
| **构建系统** | Xcode + SPM (Swift Package Manager) |
| **数据库** | GRDB.swift (SQLite)，链接系统 `sqlite3` |
| **并发模型** | Swift Actor，`@MainActor` 标注 |
| **CI** | GitHub Actions |
| **外部依赖** | 零第三方依赖（仅链接系统 sqlite3） |

---

## 三、项目架构

### 3.1 目录结构

```
AcMind/
├── AcMindKit/                  # 核心 Swift Package（可独立构建）
│   ├── Core/                   #   入口 AcMindKit.swift
│   ├── Models/                 #   数据实体（AgentMemory, SourceItem, KnowledgeCard 等）
│   ├── Protocols/              #   服务抽象接口
│   ├── Extensions/             #   UI 扩展
│   └── Services/               #   业务逻辑（7 个子模块）
│       ├── AI/                 #     Ollama + OpenAI 兼容 API + 任务队列
│       ├── Input/              #     采集 + 剪贴板
│       ├── Storage/            #     SQLite 持久化
│       ├── Workflow/           #     蒸馏 + 导出
│       ├── Knowledge/          #     知识库 + 搜索
│       ├── Voice/              #     录音 + ASR + 润色
│       └── Settings/           #     配置 + 权限 + 快捷键
├── App/                        # SwiftUI 应用入口层
│   ├── ViewModels/             #   MVVM ViewModel
│   ├── AcMindApp.swift         #   App 入口
│   ├── AppDelegate.swift       #   生命周期
│   ├── AppState.swift          #   全局状态（@Published + Combine）
│   ├── ServiceContainer.swift  #   DI 容器
│   └── ContentView.swift       #   根视图
├── Features/                   # 原生功能视图
│   ├── Agent/                  #   AI Agent
│   ├── Inbox/                  #   暂存池
│   ├── Schedule/               #   定时任务
│   ├── Settings/               #   设置页
│   └── Capsule/                #   悬浮窗
├── Design/                     # 设计系统
│   ├── AcMindDesignTokens.swift
│   └── AcMindTheme.swift
├── Resources/                  # 资源文件
├── AcMindKitTests/             # 单元测试
├── Package.swift               # SPM 配置
├── AcMind.entitlements         # 应用沙盒权限
└── build/                      # 构建配置（entitlements plist）
```

### 3.2 设计模式

| 模式 | 实现 |
|---|---|
| **依赖注入 (DI)** | `ServiceContainer` 中央容器，管理 11 个核心服务生命周期，支持 Mock 注入 |
| **协议驱动** | 所有服务通过 Protocol 抽象（`StorageServiceProtocol`, `AIRuntimeProtocol` 等） |
| **单例** | `ServiceContainer.shared`、`AppState.shared`、`AcMindKit.shared` |
| **MVVM** | App 层 ViewModel 分离 |
| **观察者** | `AppState` 通过 `@Published` + Combine 管理全局状态 |
| **阶段初始化** | 启动按固定顺序：存储 → 数据迁移 → 设置 → 权限 → 采集 → AI → UI |

---

## 四、核心服务清单

`ServiceContainer` 管理以下 11 个核心服务：

| # | 服务 | 职责 |
|---|---|---|
| 1 | `PermissionManager` | 权限管理（剪贴板、辅助功能、麦克风等） |
| 2 | `StorageService` | SQLite 持久化存储（GRDB） |
| 3 | `AssetStore` | 资产（文件）存储 |
| 4 | `SettingsService` | 设置管理（权限检查、快捷键、Provider 配置） |
| 5 | `AIRuntimeService` | AI 运行时（Ollama/OpenAI 自动路由） |
| 6 | `VoiceService` | 语音服务（录音、ASR、润色） |
| 7 | `CaptureService` | 采集服务（截图、文件导入等） |
| 8 | `ClipboardService` | 剪贴板监听 |
| 9 | `DistillService` | 蒸馏服务（AI 内容提炼） |
| 10 | `ExportService` | 导出服务（写入 Obsidian Vault） |
| 11 | `KnowledgeService` | 知识库服务（搜索、标签） |

---

## 五、主要功能模块

### 5.1 多源采集
支持 12 种内容类型：剪贴板、语音、截图、网页、PDF、DOCX 等。

### 5.2 AI 蒸馏
- **本地模型**: Ollama（自动检测本地服务）
- **云端 API**: OpenAI 兼容接口（支持自定义 endpoint）
- **自动路由**: 根据配置和模型可用性自动选择

### 5.3 Obsidian 导出
生成带 Frontmatter 的 Markdown 文件，直接写入用户指定的 Vault 目录。

### 5.4 内容状态流转

```
inbox → distilling → distilled → exported
```

### 5.5 Capsule 悬浮窗
独立的快速采集入口，支持全局快捷键唤起。

### 5.6 语音能力
录音 → ASR（Whisper API / 本地 CLI）→ AI 润色，完整语音输入链路。

---

## 六、权限需求

| 权限 | 用途 |
|---|---|
| `app-sandbox` | 启用 App Sandbox |
| `network.client` | 出站网络（AI API 调用） |
| `network.server` | 入站网络（本地服务） |
| `files.user-selected.read-write` | 用户选择的文件读写 |
| `files.downloads.read-write` | 下载目录读写 |
| `assets.pictures.read-write` | 图片库读写 |
| `personal-information.photos-library` | 照片库访问 |
| `automation.apple-events` | AppleScript/Apple Events 自动化 |
| `temporary-exception.files.home-relative-path.read-write` | `~/Library/Application Support/AcMind/` |
| `cs.allow-jit` | 允许 JIT 编译 |
| `cs.allow-unsigned-executable-memory` | 允许无签名可执行内存 |
| `cs.disable-library-validation` | 禁用库验证 |

---

## 七、构建与开发

### 7.1 构建命令

```bash
# 开发构建
swift build

# 发布构建
swift build -c release

# 使用构建脚本（推荐）
bash scripts/build.sh [--release] [--package] [--clean]
```

### 7.2 测试

```bash
swift test --parallel
```

### 7.3 Xcode 项目
- 项目文件: `AcMind.xcodeproj/project.pbxproj`
- Entitlements: `AcMind.entitlements`
- 构建配置: `build/entitlements.mac.plist`

---

## 八、设计系统

统一设计令牌（`AcMindDesignTokens.swift`）：

| 维度 | 规范 |
|---|---|
| **布局** | 侧边栏 240pt，内容间距 28pt，卡片圆角 16pt |
| **颜色** | NSColor 语义色 + success/warning/error/info |
| **字体** | 28pt 大标题 → 11pt 小注释，含等宽字体 |
| **阴影** | 三级（small / medium / large） |
| **动画** | quick(0.15s) / standard(0.25s) / smooth(spring) |
| **样式扩展** | `.acmindCardStyle()` / `.acmindPageStyle()` / `.acmindCapsuleStyle()` / `.sidebarItemStyle()` |

---

## 九、版本历史（关键节点）

| 版本 | 日期 | 里程碑 |
|---|---|---|
| v0.2.2 | 2026-04-29 | 审阅页产品化，导出闭环 |
| v0.3.0 | 2026-05-01 | 语音输入与录音工作流 |
| v0.4.0 | 2026-05-01 | 今日知识流首页 |
| v0.5.0~0.9.0 | 2026-05-03 | Pin Pool 体系（全链路打通） |
| v0.10.0 | 2026-05-03 | 语音能力深化（Whisper ASR） |
| v0.11.0 | 2026-05-05 | Acore 品牌统一，导航收束为 6 项 |
| v0.12.0 | 2026-05-05 | Phase 1 核心收集主链路（废弃 pinPool，统一 sourceItems） |
| v0.13.0 | 2026-05-05 | Phase 2 整理链路打通（distill 真实 IPC、批量整理、进度追踪） |

---

## 十、已知事项与注意事项

### 10.1 历史遗留
- **Electron → Swift 数据迁移**: 代码中存在 Electron 版本的迁移逻辑，当前已暂时禁用
- **`dist/` 和 `dist-electron/`**: 为旧版 Electron 构建产物，可考虑清理
- **`node_modules/`**: 旧版 Electron 依赖，不再使用

### 10.2 开发注意
- 项目使用 **strict concurrency**，所有并发代码需遵循 Swift 6 并发模型
- 服务通过 `ServiceContainer` 注入，新增服务需在容器中注册
- AI 路由逻辑在 `AIRuntimeService` 中，新增 Provider 需实现 `AIRuntimeProtocol`
- 导出逻辑与 Obsidian Vault 路径耦合，路径配置在 `SettingsService` 中管理

### 10.3 关键协议接口

| 协议 | 用途 |
|---|---|
| `StorageServiceProtocol` | 存储服务抽象 |
| `VoiceServiceProtocol` | 语音服务抽象 |
| `SettingsServiceProtocol` | 设置服务抽象 |
| `AIRuntimeProtocol` | AI 运行时抽象 |
| `CaptureServiceProtocol` | 采集服务抽象 |

---

## 十一、关键文件索引

| 文件 | 路径 |
|---|---|
| README | `README.md` |
| SPM 配置 | `Package.swift` |
| 变更日志 | `CHANGELOG.md` |
| 应用权限 | `AcMind.entitlements` |
| App 入口 | `App/AcMindApp.swift` |
| DI 容器 | `App/ServiceContainer.swift` |
| 全局状态 | `App/AppState.swift` |
| 核心模块 | `AcMindKit/Core/AcMindKit.swift` |
| 设计令牌 | `Design/AcMindDesignTokens.swift` |
| 主题 | `Design/AcMindTheme.swift` |
| 规划文档 | `.trae/documents/` |
