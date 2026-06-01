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
| **依赖注入 (DI)** | `ServiceContainer` 中央容器，管理 11 个核心服务生命周期，支持可替换实现注入 |
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
- **旧桌面版 → Swift 数据迁移**: 已恢复为首次启动自动检查并执行，失败会记录日志并保留回退路径
- **`dist/`**: 为旧版前端构建产物，已不再参与主构建
- **`node_modules/`**: 旧版前端依赖，已不再使用

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

---

## 十二、任务单落地清单

### 12.1 已落地
| 项目 | 状态 | 说明 |
|---|---|---|
| WebView 迁移壳 | 已移除 | `WebViewPage` / `WebViewContainer` / `WebViewBridge` 已从主工程删除，工程元数据与 README 里的 WebView 入口也已同步清理 |
| Shelf 临时暂存区 | 已下线 | `ShelfService` 与主界面入口已移除，不再作为半成品功能暴露 |
| Workbench 项目列表 | 已接真实存储 | 项目、选择态、统计和编辑删除已接到本地存储，首次打开不再注入默认演示项目 |
| 最近工具记录 | 已持久化 | 最近使用记录已跨启动保存 |
| 最近工具恢复 | 已接通 | 清空最近使用后可恢复上一次历史记录 |
| 随身快捷键 | 已接真实设置 | 支持启用、编辑、保存、恢复默认值 |
| 灵动大陆显示配置 | 已接真实存储 | 配置页与胶囊/状态条共享同一份持久化显示设置 |
| 模型路由策略 | 已接真实路由 | `Settings` 中的策略会影响 `AgentModelRouter` 的实际选路 |
| 截图捕获开关 | 已接入口 | 菜单、快捷键、胶囊和 Notch 截图动作都会读取本地开关 |
| 说入法设备偏好 | 已明确降级 | 仍仅作为偏好保存，不再伪装为已生效输入源 |
| 说入法录音设备标签 | 已对齐 | `录音设备偏好` 明确标注为偏好项，避免误读成已接通的输入源切换 |
| 说入法输入开关 | 已接入口 | Fn、菜单、胶囊和 Notch 的说入法入口都会读取本地开关 |
| 旧桌面版迁移 | 已恢复 | 启动时自动检查旧库并迁移关键数据 |
| Notch 热图 | 已接真实数据 | 近 7 天收集箱数据会生成热力图，空态时保持空白而非样例数据 |
| 动态大陆权限概览 | 已接真实状态 | 配置页的权限状态卡现在直接读取运行时权限，而不是写死已授权 |
| 权限状态文案 | 已对齐 | `未接入` 已改为 `未确定`，避免把运行时权限状态写成未完成功能 |
| Agent / Notch 模型展示 | 已接真实配置 | 模型名现在从实际 provider / model 配置读取，不再写死 `GPT-5.5` 文案 |
| Notch Agent 状态项 | 已接真实状态 | 最近状态列表改为读取模型、说入法、截图和处理状态，不再含固定演示文案 |
| Agent 项目上下文 | 已接真实数据 | 右侧项目上下文改为读取工作台项目快照，不再写死固定 AcMind / PinMind 列表 |
| Notch 天气卡 | 已收回空状态 | 天气字段不再暴露为主路径数据，避免继续冒充已接入真实天气源 |
| Vault frontmatter 模板 | 已接通 | 模板已从设置页写入存储并影响导出结果 |
| 导出冲突记录 | 已对齐 | `ExportRecord.relativeFilePath` 现在记录冲突处理后的最终路径，而不是初始候选路径 |
| 导出闭环 | 已接通 | `ExportService` 已按真实配置构建 Markdown 和 frontmatter |
| 自动备份 | 已接通 | `autoBackupEnabled` 现在会驱动按周备份策略并落盘备份文件 |
| 窗口位置恢复 | 已接通 | `restoreWindowPosition` 现在会真正决定主窗口是否沿用 autosave 位置 |
| 仅在激活应用时采集 | 已接通 | `captureOnlyWhenAppActive` 现在会限制剪贴板自动监听只在应用激活时生效 |
| 本地优先模式 | 已接通 | `localFirstMode` 现在会优先选择本地 tier 的 AI Provider 作为默认运行时 |
| API Key 存储模式 | 已接通 | `apiKeyUsesKeychain` 现在会决定 SecretStore 是写入 Keychain 还是本地偏好存储 |
| 任务完成通知 | 已接通 | `notificationsEnabled` 与 `taskCompletedNotificationsEnabled` 现在会驱动采集完成的本地通知 |
| 诊断信息 | 已接通 | 设置页和复制诊断信息现在改为读取运行时版本、设备和硬件信息 |
| 关于页版本号 | 已接通 | 版本展示已改为运行时 bundle 版本与 build 号 |
| 日程编辑 / 删除 | 已补齐 | 今日待办与日程列表现在支持编辑、删除与状态持久化 |

### 12.2 仍保留为已弃用
| 项目 | 状态 | 说明 |
|---|---|---|
| WebView 路线 | 已弃用 | 不再作为主路径入口；相关工程引用已移除，仅保留历史记录 |
| Shelf 临时模型 | 已弃用 | 临时暂存壳已移除，不再推荐使用 |
| 样例数据入口 | 已弃用 | `CompanionSampleData`、`NotchDashboardData.sample` 等 sample data 已从主路径移除 |
| ToolUnavailablePanel | 已弃用 | 旧的“死接口”说明面板已移除，避免继续暗示半成品能力 |
| 更新可用通知 | 已降级 | 当前仅保留偏好字段，不再传入通知服务，也未接入真实更新检查与通知触发 |
