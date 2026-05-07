# AcMind Electron → Swift 迁移边界与目标架构

> 冻结日期：2026-05-07
> 状态：**已冻结** — 未经团队共识不得修改

---

## 一、Swift 架构唯一主线

### 1.1 目标架构

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

### 1.2 核心原则

1. **Swift 原生优先**：新功能只在 Swift 端开发，不新增 Electron 代码
2. **数据层先行**：Swift 端必须先完成 SQLite 存储层，再迁移业务逻辑
3. **协议驱动**：所有 Service 通过 Protocol 抽象，便于测试和替换
4. **Actor 并发**：Service 层统一使用 Swift actor 保证线程安全
5. **渐进替换**：通过 WebViewBridge 过渡，不搞大爆炸切换

---

## 二、目标导航收敛

### 2.1 新导航（Swift 目标）

| 序号 | 导航项 | Swift 视图 | 职责定义 |
|------|--------|-----------|---------|
| 1 | **Agent** | `AgentView.swift` | AI 对话入口、意图理解、任务调度、跨模块动作触发 |
| 2 | **Inbox** | `InboxView.swift` | 所有 SourceItem 统一入口，状态流转（inbox→distilling→distilled→exported） |
| 3 | **Schedule** | `ScheduleNativeView.swift` | 日程管理、定时任务（自动蒸馏/自动导出/清理）、时间线 |
| 4 | **Workbench** | 待创建 | 工作台总览：今日统计、快速入库、知识沉淀、Obsidian 入库 |
| 5 | **Tools** | 待创建 | 工具台：文件转换、OCR、ZTools、Agent 任务管理等工具集合 |
| 6 | **Settings** | `SettingsView.swift` | AI Provider、Vault 路径、外观、权限、快捷键、语音配置 |

### 2.2 旧导航（Electron，逐步废弃）

| 旧导航 | 对应新导航 | 处理方式 |
|--------|-----------|---------|
| 工作台 | Workbench | 合并到 Workbench |
| 暂存池 | Inbox | 合并到 Inbox |
| 整理 | Inbox | 合并到 Inbox（蒸馏操作在 Inbox 内触发） |
| 知识库 | Workbench | 合并到 Workbench |
| 工具台 | Tools | 重命名为 Tools |
| 设置 | Settings | 保持不变 |

---

## 三、模块映射表（Electron → Swift）

### 3.1 完整映射

| # | Electron 模块 | Electron 代码 | Swift 模块 | Swift 代码 | 迁移类别 | 当前状态 |
|---|--------------|--------------|-----------|-----------|---------|---------|
| 1 | **Capsule** | `capsuleController.ts` + `pages/capsule/` | CapsulePanel | `Features/Native/Capsule/CapsulePanel.swift` | ✅ 必须原生 | Swift 已实现 |
| 2 | **Capture** | `captureService.ts` + `services/capture/` | CaptureService | `AcMindKit/Services/Input/Capture/` | ✅ 必须原生 | Swift 已实现（OCR 除外） |
| 3 | **Clipboard** | `clipboardWatcher.ts` | ClipboardService | `AcMindKit/Services/Input/Clipboard/` | ✅ 必须原生 | Swift 已实现 |
| 4 | **Shelf** | `modules/shelf/` + `pages/shelf/` | 合并到 Inbox | — | 🔄 可过渡 | 先保留 Electron WebView |
| 5 | **Inbox** | `pages/capture-inbox/` + `components/inbox/` | InboxView | `Features/Native/Inbox/InboxView.swift` | ✅ 必须原生 | Swift 已实现（基础 CRUD） |
| 6 | **Distill** | `services/distiller/` + `pages/distill/` | DistillService | `AcMindKit/Services/Workflow/DistillService.swift` | ✅ 必须原生 | Swift Stub（Mock AI） |
| 7 | **Export** | `services/exporter/` + `pages/export/` | ExportService | `AcMindKit/Services/Workflow/ExportService.swift` | ✅ 必须原生 | Swift 部分实现 |
| 8 | **AI Runtime** | `services/aiHub/` + `services/strategy/` | AIRuntimeService | `AcMindKit/Services/AI/` | ✅ 必须原生 | Swift Provider 已有，调度层 Stub |
| 9 | **Knowledge Base** | `pages/knowledge-cards/` + `hooks/useDistilledNotes.ts` | KnowledgeService | `AcMindKit/Services/Knowledge/` | 🔄 可过渡 | Swift 纯 Stub |
| 10 | **Voice** | `voice/` + `pages/voice/` | VoiceService | `AcMindKit/Services/Voice/` | 🔄 可过渡 | Swift 仅录音框架 |
| 11 | **Settings** | `settings.ts` + `pages/settings/` | SettingsService | `AcMindKit/Services/Settings/` | ✅ 必须原生 | Swift 部分实现 |
| 12 | **Design System** | `renderer/design-system/` | AcMindTheme | `Design/AcMindTheme.swift` | ✅ 必须原生 | Swift 基础实现 |
| 13 | **Storage** | `storage.ts` (better-sqlite3) | Database + StorageService | `AcMindKit/Services/Storage/` | ✅ 必须原生 | Swift 仅 JSON 文件，**需重写为 SQLite** |
| 14 | **File Converter** | `services/parser/` + `pages/file-converter/` | 合并到 Tools | — | ⏳ 最后再删 | 先保留 Electron WebView |
| 15 | **Search** | `services/search/` + `pages/search/` | 合并到 Inbox/Workbench | — | 🔄 可过渡 | 先保留 Electron WebView |
| 16 | **Scheduler** | `services/scheduler/` + `pages/automation/` | 合并到 Schedule | — | ✅ 必须原生 | Swift 纯 Stub |
| 17 | **Agent Chat** | `services/chat/` + `pages/agent-chat/` + `components/agent-chat/` | AgentView + AgentViewModel | `Features/Native/Agent/` | ✅ 必须原生 | Swift 基础实现（Mock AI） |
| 18 | **Import/Vault** | `services/importer/` + `pages/import/` | 合并到 Workbench | — | ⏳ 最后再删 | 先保留 Electron WebView |
| 19 | **Pipeline** | `services/pipeline/` | 合并到 Workflow | — | ✅ 必须原生 | 逻辑内嵌到 DistillService |
| 20 | **Strategy** | `services/strategy/` | 合并到 AI Runtime | — | ✅ 必须原生 | 逻辑内嵌到 AIRuntimeService |
| 21 | **Projects/Datasets** | `pages/projects/` + `pages/datasets/` | 合并到 Workbench | — | ⏳ 最后再删 | 先保留 Electron WebView |
| 22 | **VaultKeeper** | `services/vaultkeeper/` | 待评估 | — | ⏳ 最后再删 | 先保留 Electron WebView |
| 23 | **Tray/Shortcut/Permission** | `tray.ts` + `shortcutManager.ts` + `permissionCoordinator.ts` | AppDelegate + SettingsService | `App/AppDelegate.swift` | ✅ 必须原生 | Swift 部分实现 |
| 24 | **Onboarding** | `pages/onboarding/` | 待创建 | — | ⏳ 最后再删 | 先保留 Electron WebView |
| 25 | **Error/Retry/Diagnostics** | `errorService.ts` + `retryService.ts` | 待创建 | — | ⏳ 最后再删 | 先保留 Electron WebView |

### 3.2 迁移类别定义

| 类别 | 标记 | 含义 | 迁移时机 |
|------|------|------|---------|
| **必须原生** | ✅ | 依赖 macOS 原生能力或为核心体验，必须用 Swift 重写 | P1/P2 阶段 |
| **可过渡** | 🔄 | 可通过 WebViewBridge 临时桥接，逐步替换 | P2/P3 阶段 |
| **最后再删** | ⏳ | 低优先级或复杂度高，保留 Electron WebView 到最后阶段 | P4 阶段 |

---

## 四、优先级表

### P1 — 存储层 + 核心链路（地基）

| 序号 | 任务 | 依赖 | 验收标准 |
|------|------|------|---------|
| P1.1 | Swift Storage 层重写：JSON → SQLite | 无 | Database.swift 使用 SQLite，支持 Electron 版 22+ 张表的 schema |
| P1.2 | 数据迁移工具：Electron SQLite → Swift SQLite | P1.1 | 能读取现有 acmind.db，数据零丢失 |
| P1.3 | AIRuntimeService 接入真实 Provider | P1.1 | `chat()` 和 `runDistillation()` 调用 Ollama/OpenAI 返回真实结果 |
| P1.4 | DistillService 真实实现 | P1.3 | 单条蒸馏 + 批量蒸馏可用，结果写入 SQLite |
| P1.5 | ExportService 完善 | P1.1 | Markdown 生成 + 冲突处理 + 导出记录查询全部可用 |

### P2 — 导航六件套（骨架）

| 序号 | 任务 | 依赖 | 验收标准 |
|------|------|------|---------|
| P2.1 | Agent 页面完善 | P1.3 | 会话管理 + 流式输出 + 快捷指令 + 跨模块动作 |
| P2.2 | Inbox 页面完善 | P1.4 | 状态流转完整（inbox→distilling→distilled→exported） |
| P2.3 | Schedule 页面真实实现 | P1.1 | 接入 scheduler 数据，定时任务 CRUD + 执行历史 |
| P2.4 | Workbench 页面创建 | P1.5 | 今日统计 + 快速入库 + 知识沉淀入口 |
| P2.5 | Tools 页面创建 | P1.1 | 文件转换 + OCR + 工具集合入口 |
| P2.6 | Settings 页面完善 | P1.1 | Provider + Vault + 权限 + 快捷键 + 外观全部可用 |

### P3 — 过渡模块（填充）

| 序号 | 任务 | 依赖 | 验收标准 |
|------|------|------|---------|
| P3.1 | KnowledgeService 实现 | P1.1 | 知识卡片 CRUD + Vault 搜索 |
| P3.2 | VoiceService 完善 | P1.3 | ASR 转写 + 润色 + 词典管理 |
| P3.3 | WebViewBridge 补齐 7 通道 | P2.* | capture/inbox/distill/export/aiRuntime/clipboard/settings 全部可用 |
| P3.4 | Search 迁移到 Swift | P1.1 | FTS 关键词搜索可用 |

### P4 — 清理收尾（拆除）

| 序号 | 任务 | 依赖 | 验收标准 |
|------|------|------|---------|
| P4.1 | File Converter 迁移或保留 WebView | P3.3 | 文件转 Markdown 功能可用 |
| P4.2 | Import/Vault 迁移或保留 WebView | P3.3 | Obsidian Vault 导入可用 |
| P4.3 | Projects/Datasets 迁移或保留 WebView | P3.3 | 项目和数据集管理可用 |
| P4.4 | VaultKeeper 评估与处理 | P3.3 | 确定保留/迁移/废弃 |
| P4.5 | Onboarding 原生实现 | P2.* | 首次使用引导 |
| P4.6 | Error/Retry/Diagnostics 原生实现 | P2.* | 错误记录 + 重试 + 诊断导出 |
| P4.7 | 移除 Electron 依赖 | P4.1~P4.6 | 不再需要 Electron 运行时 |

---

## 五、Electron 保留到最后清单

以下模块/能力在 P1~P3 阶段**保留 Electron WebView**，仅在 P4 阶段处理：

| # | 模块 | 保留原因 | 计划处理阶段 |
|---|------|---------|------------|
| 1 | **File Converter** | 依赖 Python markitdown CLI + 多种解析器，迁移成本高 | P4.1 |
| 2 | **Import/Vault** | Obsidian Vault 扫描/导入逻辑复杂，优先级低 | P4.2 |
| 3 | **Projects/Datasets** | 非核心功能，使用频率低 | P4.3 |
| 4 | **VaultKeeper** | 外部服务集成，需评估是否保留 | P4.4 |
| 5 | **Onboarding** | UI 密集但非核心链路 | P4.5 |
| 6 | **Error/Retry/Diagnostics** | 辅助功能，优先级低 | P4.6 |
| 7 | **Shelf** | 功能可合并到 Inbox，暂不需要独立模块 | P4（评估合并） |
| 8 | **Training/Model Versions** | 实验性功能，非产品核心 | P4（评估废弃） |

### 保留策略

- 上述模块通过 `WebViewBridge` + `WKWebView` 在 Swift 壳内渲染
- 不再为这些模块新增 Electron 端功能
- P4 阶段逐个评估：迁移到 Swift 原生 / 合并到其他模块 / 直接废弃

---

## 六、Swift 端当前实现状态快照

> 以下为 2026-05-07 冻结时的状态，后续进展在 WORKLOG.md 追踪

### 已完成（可运行）

| 模块 | 文件 | 说明 |
|------|------|------|
| Models | 6 个文件 | SourceItem, DistilledNote, AppSettings, KnowledgeCard, VaultConfig, RecordingStatus |
| Protocols | 3 个文件 | 9 个业务协议全部定义 |
| StorageService | 3 个文件 | JSON 文件 CRUD + AssetStore（**需重写为 SQLite**） |
| CaptureService | 1 个文件 | 截图/剪贴板/文件/网页/手动文本（OCR 为空壳） |
| ClipboardService | 1 个文件 | 实时监听 + CRUD + 保存到 Inbox |
| OllamaProvider | 1 个文件 | 真实 HTTP 调用 |
| OpenAICompatibleProvider | 1 个文件 | 真实 HTTP 调用 |
| SecretStore | 1 个文件 | macOS Keychain |
| ExportService | 1 个文件 | Markdown 生成 + 文件写入（冲突处理为空壳） |
| DI Container | 1 个文件 | ServiceContainer 全服务注册 |
| App Shell | 4 个文件 | 入口 + 状态栏 + 导航 + 初始化 |
| AgentView | 2 个文件 | View + ViewModel（Mock AI） |
| InboxView | 2 个文件 | View + ViewModel（完整 CRUD） |
| SettingsView | 2 个文件 | View + ViewModel |
| CapsulePanel | 1 个文件 | NSPanel 浮动胶囊 |
| WebViewBridge | 2 个文件 | JS↔Swift 双向通信（3/7 通道） |
| AcMindTheme | 1 个文件 | 设计 Token + 卡片样式 |

### 未完成（Stub/Placeholder）

| 模块 | 缺失内容 |
|------|---------|
| Database.swift | JSON 文件 → 需重写为 SQLite |
| AIRuntimeService | chat() 返回 Mock，runDistillation() 返回空壳 |
| TaskQueue | 仅内存数组，无执行逻辑 |
| KnowledgeService | 全部方法返回空数组 |
| VoiceService | transcribe()/polishTranscript() 为空壳 |
| DistillService | 代理到 Mock AI，review() 为空壳 |
| ScheduleNativeView | 硬编码数据，不持久化 |
| SettingsService | 权限/快捷键/Voice 配置为空壳 |
| Workbench 页面 | 不存在 |
| Tools 页面 | 不存在（ContentView 中仅占位文字） |
| WebViewBridge | distill/export/aiRuntime/clipboard 通道未实现 |

---

## 七、决策记录

| 决策 | 结论 | 理由 |
|------|------|------|
| Swift UI 框架 | SwiftUI + AppKit | 已有代码全部基于 SwiftUI，系统级功能用 AppKit |
| 存储方案 | SQLite（与 Electron 对齐） | JSON 文件无法支撑 22+ 张表和复杂查询 |
| 并发模型 | Swift actor | 已有代码全部使用 actor，保持一致 |
| 过渡策略 | WebView 桥接 | 已有 WebViewBridge 框架，渐进替换风险低 |
| Shelf 模块 | 合并到 Inbox | 功能重叠度高，独立模块价值不大 |
| VaultKeeper | P4 评估 | 外部服务依赖，需确认产品方向 |
| Hermes Agent | 暂不集成 | Agent v1 先用自有实现，Hermes 作为 P4+ 选项 |
