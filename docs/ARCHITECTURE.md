# AcMind 架构文档

> 最后更新：2026-05-07
> ⚠️ **迁移边界已冻结**，详见 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)

## 产品定位

AcMind 是一个 **local-first 桌面知识中枢**，核心链路为：

```
收集 → 暂存 → 整理 → 确认 → 导出 → 沉淀
```

AcMind 不是 16 个参考项目的源码拼接，而是从 pinmind-main / pinstack-main / markitdown-main 等资产来源中吸收符合主线的能力，构建统一的模块化架构。当前工程由 pinmind-main 演进而来，已完成 PinMind → AcMind 全量命名迁移。

## 命名约定：PinMind → AcMind（迁移已完成）

原工程由 pinmind-main 演进而来，代码中曾存在大量 PinMind legacy 命名。Phase 0.5 已完成全量迁移：

| 层 | 旧命名（已废弃） | 新命名（当前） | 状态 |
|---|---|---|---|
| Preload API | `window.pinmind` | `window.acmind` | ✅ 已迁移，`window.pinmind` 保留为 deprecated 兼容别名 |
| 数据库文件 | `pinmind.db` | `acmind.db` | ✅ 已迁移，启动时自动重命名旧文件 |
| sourceApp 字段 | `'PinMind'` | `'AcMind'` | ✅ 已迁移 |
| CSS 类名 | `pinmind-*` | `acmind-*` | ✅ 已迁移 |
| 自定义事件 | `pinmind:*` | `acmind:*` | ✅ 已迁移 |
| 文件注释 | `// PinMind ...` | `// AcMind ...` | ✅ 已迁移 |
| npm scripts | `pinmind:dev` 等 | `acmind:dev` 等 | ✅ 已迁移 |
| bundleId | `com.pinmind.app` | `com.acmind.app` | ✅ 已迁移 |
| 品牌资产 | `pinmind-logo-mark.*` | `acmind-logo-mark.*` | ✅ 已迁移 |
| 设置标识 | `pinmind-inbox` | `acmind-inbox` | ✅ 已迁移，加载时自动迁移旧值 |

**规则**：所有代码统一使用 AcMind 命名。`window.pinmind` 仅作为 deprecated 兼容别名保留，新代码不得使用。

## 总体架构

### 当前架构：Electron 三层（逐步废弃）

AcMind 当前是一个 Electron 桌面应用，采用三层架构：

```
┌─────────────────────────────────────────────┐
│  Renderer (React + Vite)                    │
│  - 页面、组件、设计系统                       │
│  - 通过 window.acmind.* 调用主进程（legacy 命名）│
├─────────────────────────────────────────────┤
│  Preload (contextBridge)                    │
│  - 安全暴露 IPC 接口                          │
│  - contextIsolation: true                   │
├─────────────────────────────────────────────┤
│  Main Process (Node.js + esbuild)           │
│  - 业务服务、数据库、文件系统                   │
│  - AI 蒸馏、采集、导出、调度                    │
└─────────────────────────────────────────────┘
```

### 目标架构：Swift 原生（迁移主线）

> 已冻结（2026-05-07），完整迁移计划见 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)

```
┌─────────────────────────────────────────────────────────┐
│  App Shell (SwiftUI + AppKit)                           │
│  - NavigationSplitView 主布局                            │
│  - AppDelegate 状态栏/通知/生命周期                       │
│  - ServiceContainer DI 容器                             │
├─────────────────────────────────────────────────────────┤
│  Features (SwiftUI Views + ViewModels)                  │
│  - Agent / Inbox / Schedule / Workbench / Tools / Settings │
│  - CapsulePanel (NSPanel 浮动入口)                      │
├─────────────────────────────────────────────────────────┤
│  AcMindKit (独立 Swift Package)                          │
│  - Models: 数据实体 (Codable + Sendable)                │
│  - Protocols: 服务抽象接口                               │
│  - Services: 业务逻辑实现 (actor 并发)                   │
│    ├── AI/         Ollama + OpenAI + 任务队列            │
│    ├── Input/      采集 + 剪贴板                         │
│    ├── Storage/    SQLite 持久化 + 资产管理               │
│    ├── Workflow/   蒸馏 + 导出                           │
│    ├── Knowledge/  知识库 + 搜索                          │
│    ├── Voice/      录音 + ASR + 润色                      │
│    └── Settings/   配置 + 权限 + 快捷键                   │
├─────────────────────────────────────────────────────────┤
│  Platform (Apple Native Frameworks)                     │
│  - CoreGraphics / AVFoundation / Vision / Security       │
│  - WebKit (过渡期 WebView 桥接)                          │
└─────────────────────────────────────────────────────────┘
```

### 过渡策略

- **P1**：存储层重写（JSON → SQLite）+ 核心链路（AI 蒸馏/导出）
- **P2**：导航六件套原生实现（Agent/Inbox/Schedule/Workbench/Tools/Settings）
- **P3**：过渡模块填充（Knowledge/Voice/Search）
- **P4**：清理收尾，移除 Electron 依赖

## 模块结构

AcMind 内部划分为以下模块：

| 模块 | 职责 |
|---|---|
| **Capsule** | 桌面胶囊 / 常驻入口 / 快速输入 / 快速拖拽 |
| **Capture** | 截图 / 贴图 / OCR / 标注 / 录音 / 语音采集 |
| **Clipboard** | 剪贴板历史 / 智能卡片 / 重新复制 / 转 Markdown |
| **Shelf** | 文件临时架 / 拖拽暂存 / 批量暂存 |
| **Inbox** | 统一收集箱 / SourceItem 列表 / 状态流转 |
| **Distill** | AI 整理 / 摘要 / 标签 / 分类 / 结构化草稿 |
| **Export** | Markdown 输出 / Obsidian / iCloud / frontmatter |
| **AI Runtime** | 本地/云端模型 / Action Registry / 任务队列 |
| **Settings** | 权限 / 快捷键 / 外观 / 存储 / Provider 配置 |
| **Design System** | 视觉 Token / 基础组件 / 图标 / 布局 |
| **Storage** | SQLite / 文件资产 / 索引 / 迁移 |

模块详细边界见 [MODULE_BOUNDARIES.md](./MODULE_BOUNDARIES.md)。

## 主链路

```
用户操作 → Capsule(轻入口)
         → Capture(截图/剪贴板/文件/网页/语音)
         → Inbox(SourceItem 统一入口)
         → Shelf(临时暂存，可选)
         → Distill(AI 整理)
         → 用户审核
         → Export(Markdown / Obsidian / iCloud)
         → 沉淀到知识库
```

## 进程关系

- **主进程**：所有业务逻辑、数据库、文件系统、AI 调用
- **渲染进程**：UI 展示，通过 IPC 调用主进程
- **Preload**：安全桥接层，contextIsolation: true

## local-first 原则

- 所有数据存储在本地 SQLite
- 文件资产存储在本地文件系统
- AI 可选本地模型（Ollama）或云端模型
- 不依赖云端服务即可完整使用
- 导出目标为本地 Markdown 文件

## 主进程服务层

### 采集服务 (capture/)

12 种采集适配器通过注册表模式管理：

- `manualTextAdapter` — 手动输入
- `clipboardTextAdapter` — 剪贴板监听
- `screenshotAdapter` — 截图采集
- `webpageAdapter` — 网页采集
- `fileAdapter` — 文件采集
- `imageAdapter` / `audioAdapter` / `videoAdapter` — 媒体采集

### 策略系统 (strategy/)

每种内容类型对应一个策略，负责后处理和元数据提取。策略注册表统一管理 12 种策略类型。

### AI 蒸馏 (distiller/)

```
内容 → tierRouter(选择模型层级) → distiller(mock/real) → 蒸馏结果
```

- `tierRouter` — 根据配置和内容类型选择 local_light / cloud_standard / cloud_advanced
- `mockDistiller` — 本地规则蒸馏（不依赖 AI）
- `realDistiller` — 调用 Ollama / OpenAI 兼容 API

### 导出服务 (exporter/)

将蒸馏结果写入 Obsidian Vault：

- `markdownBuilder` — 生成 Frontmatter + Markdown
- `safeWrite` — 安全写入（防冲突、防覆盖）
- `exportStatus` — 导出状态跟踪

### 管线 (pipeline/)

内容状态机驱动完整处理流程：

```
pending → capturing → captured → parsing → parsed → distilling → distilled → exporting → exported
```

## 数据存储

使用 better-sqlite3，WAL 模式，核心表：

| 表 | 用途 |
|---|---|
| `source_items` | 采集内容 |
| `capture_items` | 采集任务 |
| `distilled_outputs` | 蒸馏结果 |
| `export_records` | 导出记录 |
| `knowledge_cards` | 知识卡片 |
| `ai_tasks` | AI 任务队列 |
| `asset_files` | 资产文件（Phase 0 新增） |
| `clipboard_items` | 剪贴板历史（Phase 0 新增） |
| `shelf_items` | 文件临时架（Phase 0 新增） |
| `ai_actions` | AI 动作定义（Phase 0 新增） |
| `pin_pool_items` | Pin 池（legacy，Phase 1B 起迁移到 shelf_items） |

数据库路径：`{storageRoot}/acmind.db`（启动时自动将旧 `pinmind.db` 重命名），schema 版本通过 `_migration` 表管理（当前 v14）。

数据模型详细定义见 [DATA_MODEL.md](./DATA_MODEL.md)。

## IPC 通信

所有主进程 ↔ 渲染进程通信通过 IPC channel 进行，channel 定义在 `src/shared/types.ts` 的 `IPC_CHANNELS` 中。

IPC 分组：

- `capsule.*` — 胶囊控制
- `capture.*` — 采集操作
- `clipboard.*` — 剪贴板管理（Phase 0 新增）
- `shelf.*` — 文件临时架（Phase 0 新增）
- `inbox.*` — 收集箱操作
- `distill.*` — 蒸馏操作
- `export.*` — 导出操作
- `aiRuntime.*` — AI 运行时（Phase 0 新增）
- `settings.*` — 设置管理

渲染进程通过 `window.acmind.*` 调用，preload 层使用 `contextBridge` 安全暴露。

## IPC 命名空间

### 目标命名空间（AcMind）

| 命名空间 | 模块 | 状态 |
|---|---|---|
| `capsule.*` | Capsule | 已有（legacy: capsule.*） |
| `capture.*` | Capture | 已有（legacy: capture.*） |
| `clipboard.*` | Clipboard | Phase 0 新增 |
| `shelf.*` | Shelf | Phase 0 新增 |
| `inbox.*` | Inbox | 已有（legacy: captureInbox.*） |
| `distill.*` | Distill | 已有（legacy: distill.*） |
| `export.*` | Export | 已有（legacy: export.*） |
| `aiRuntime.*` | AI Runtime | Phase 0 新增 |
| `settings.*` | Settings | 已有（legacy: settings.*） |

### Legacy 命名空间（保留，不删除）

| Legacy 命名 | 对应 AcMind 模块 | 处理方式 |
|---|---|---|
| `sourceItems.*` | inbox.* | 保留，Phase 1 起新 UI 优先用 inbox.* |
| `pinPool.*` | shelf.* | 保留，Phase 1B 起新 UI 优先用 shelf.* |
| `providers.*` | aiRuntime.* | 保留，Phase 4 起新 UI 优先用 aiRuntime.* |
| `aiTasks.*` | aiRuntime.* | 保留，Phase 4 起新 UI 优先用 aiRuntime.* |
| `captureInbox.*` | inbox.* | 保留，Phase 1 起新 UI 优先用 inbox.* |

**原则**：旧接口不删除，新接口逐步补齐。Phase 1 起新增 UI 优先调用新命名空间。旧接口在代码中标记为 `// legacy`。

## 旧主链路与新主链路

### 旧主链路（当前运行中）

```
Capsule → CaptureService → CapturePipeline → Distiller → Exporter → Obsidian
```

这条链路是 pinmind-main 遗留的完整管线，当前可正常运行。

### 新主链路（Phase 1 起逐步建立）

```
Capsule → Capture / Clipboard / Shelf → Inbox → Distill → Export → 沉淀
```

新主链路的核心变化：
- Clipboard 和 Shelf 作为独立模块，不再嵌入 Capture
- Inbox 作为统一入口，取代 CapturePipeline 的隐式状态机
- Distill 和 Export 解耦，支持独立触发

**过渡策略**：旧主链路保持运行，新主链路逐步替换。Phase 1A 先建立 Clipboard UI，Phase 1B 建立 Shelf UI，Phase 2 统一 Inbox。

## 安全模型

- `contextIsolation: true` — 渲染进程无法直接访问 Node.js API
- `nodeIntegration: false` — 禁用 Node.js 集成
- CSP 策略 — 生产环境严格限制资源加载
- preload 脚本 — 唯一的 IPC 桥接层

## 日志系统

自研 5 通道 JSON-lines 日志：

| 通道 | 用途 |
|---|---|
| `app` | 应用生命周期 |
| `ai` | AI 调用记录 |
| `export` | 导出操作 |
| `error` | 错误记录（所有通道的 error 级别也会写入此文件） |
| `search` | 搜索操作 |

日志路径：`{storageRoot}/logs/`

## 前端架构

- **设计系统**：`renderer/design-system/` — tokens、primitives、icons、components
- **页面**：`renderer/pages/` — 每个页面独立目录
- **状态管理**：React Context + useState（无全局状态库）
- **路由**：基于 `activeView` 状态的条件渲染（无 react-router）

## Electron → Swift 模块映射

> 完整映射表、优先级表和 Electron 保留清单见 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)

### 必须原生（✅）

| Electron 模块 | Swift 模块 | Swift 代码 |
|--------------|-----------|-----------|
| Capsule | CapsulePanel | `Features/Native/Capsule/CapsulePanel.swift` |
| Capture | CaptureService | `AcMindKit/Services/Input/Capture/` |
| Clipboard | ClipboardService | `AcMindKit/Services/Input/Clipboard/` |
| Inbox | InboxView | `Features/Native/Inbox/InboxView.swift` |
| Distill | DistillService | `AcMindKit/Services/Workflow/DistillService.swift` |
| Export | ExportService | `AcMindKit/Services/Workflow/ExportService.swift` |
| AI Runtime | AIRuntimeService | `AcMindKit/Services/AI/` |
| Settings | SettingsService | `AcMindKit/Services/Settings/` |
| Storage | Database + StorageService | `AcMindKit/Services/Storage/` |
| Agent Chat | AgentView | `Features/Native/Agent/` |
| Scheduler | 合并到 Schedule | `Features/Native/Schedule/` |
| Design System | AcMindTheme | `Design/AcMindTheme.swift` |
| Tray/Shortcut/Permission | AppDelegate | `App/AppDelegate.swift` |
| Pipeline + Strategy | 合并到 Workflow/AI | 内嵌到 DistillService/AIRuntimeService |

### 可过渡（🔄）

| Electron 模块 | 过渡方式 |
|--------------|---------|
| Knowledge Base | WebViewBridge → P3 迁移到 Swift |
| Voice | WebViewBridge → P3 迁移到 Swift |
| Search | WebViewBridge → P3 迁移到 Swift |
| Shelf | 合并到 Inbox 或保留 WebView |

### 最后再删（⏳）

| Electron 模块 | 保留原因 |
|--------------|---------|
| File Converter | 依赖 Python CLI，迁移成本高 |
| Import/Vault | Obsidian 导入逻辑复杂 |
| Projects/Datasets | 非核心功能 |
| VaultKeeper | 需评估产品方向 |
| Onboarding | UI 密集但非核心 |
| Error/Retry/Diagnostics | 辅助功能 |
