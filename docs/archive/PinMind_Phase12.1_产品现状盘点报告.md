> ⚠️ 历史文档，路径和内容可能已过时，仅供参考。

# AcMind Phase 12.1 产品现状盘点报告

> 生成日期：2026-05-01  
> 盘点范围：Phase 1-11 全部前端页面、入口、流程、组件、状态、mock 数据  
> 技术栈：Electron + React 18 + Vite + TailwindCSS + SQLite (better-sqlite3)

---

## 0. 摘要结论

当前 AcMind 已具备可运行的主链路：文本收集、文件解析、AI 蒸馏、Obsidian 导出、搜索、错误回看、设置与胶囊入口均已形成产品雏形。但产品体验仍处于“功能堆叠完成、信息架构尚未收敛”的阶段。

最需要先处理的不是继续加功能，而是清理不可用入口、统一导航命名、打通搜索和蒸馏链路，并把默认页改成用户能立即理解的工作台。

### 0.1 当前状态总览

| 维度 | 结论 | 风险等级 |
|---|---|---|
| 主链路 | 文本收集与 Obsidian 导出最完整，文件导入基本可用 | 中 |
| 语音输入 | 多条路径均为 stub，当前不可用 | 高 |
| AI 蒸馏 | 存在多套并行系统，输出和路由逻辑不统一 | 高 |
| 导航入口 | 命名混乱、入口重复、部分重要页面隐藏 | 高 |
| 搜索 | Search 页可用，但 TopBar 搜索框只读 | 中 |
| 组件系统 | 基础存在，但多数 UI 仍为页面内联实现 | 中 |
| 错误反馈 | 部分失败静默吞错，用户不可见 | 中 |

### 0.2 最关键的 5 个判断

1. **语音功能必须隐藏或灰态**：当前 whisper、音频转写、录屏保存均未实现，不能继续作为可用功能暴露。
2. **导航需要重新命名和分层**：“今日”“结果回看”“import”等名称与真实职责不匹配。
3. **AI 蒸馏需要统一为一条主链路**：`distillPipeline`、`strategyProcessor`、`ruleBasedDistiller` 并存会持续制造行为差异。
4. **默认页应承担“工作台”职责**：用户打开应用后应能看到下一步操作，而不是只看到统计卡片。
5. **组件库要先补基础件**：Button、Card、Input、Tabs、Modal、StatusBadge、Loading/Error State 是后续一致性的前置条件。

---

## 1. Phase 12.2 优先行动清单

### P0：必须先整理

| # | 问题 | 建议 | 影响范围 |
|---|---|---|---|
| P0-1 | 语音输入完全不可用 | 隐藏胶囊语音入口、设置页语音配置，或统一改为“即将推出”灰态 | 胶囊、设置页 |
| P0-2 | 侧边栏导航混乱 | 重命名“今日”“结果回看”，将 distill/export 纳入明确导航 | 全局导航 |
| P0-3 | TopBar 搜索框 readOnly | 接入 Search 页，或改为点击打开搜索面板 | TopBar、Search |
| P0-4 | 两套 AI 蒸馏系统并存 | 明确主链路，废弃或封存另一套 | distill 全链路 |
| P0-5 | 默认页缺少行动引导 | 将 daily-flow 改造为“工作台”，增加快速开始入口 | daily-flow |
| P0-6 | DashboardPage 已废弃但保留大量代码 | 删除死代码，移除路由或标记 deprecated | dashboard |

### P1：应该整理

| # | 问题 | 建议 | 影响范围 |
|---|---|---|---|
| P1-1 | 入口重复严重 | 截图保留快捷键 + CaptureLauncher；设置保留侧边栏 + TopBar | 全局 |
| P1-2 | 基础组件未统一 | 建立 Button、Card、Input、Select、Tabs、Modal、StatusBadge | 全局 |
| P1-3 | 错误处理不一致 | 所有用户触发流程的 catch 都应有 Toast 或错误区反馈 | 全局 |
| P1-4 | mockDistiller 自动 fallback 无提示 | 改为空状态提示“请先配置 AI 模型” | distill |
| P1-5 | SettingsPage 过大 | 拆分为多个设置子组件或 Tab 模块 | settings |
| P1-6 | InboxPage 遗留 | 合并到 CaptureInboxPage 或删除 | inbox |
| P1-7 | Tray 菜单英文 | 本地化为中文 | tray |
| P1-8 | 通知铃铛跳转日志 | 换图标，或改为真正通知入口 | TopBar |

### P2：后续精修

| # | 问题 | 建议 | 影响范围 |
|---|---|---|---|
| P2-1 | 信息密度不统一 | 制定页面密度标准，复杂操作渐进展示 | 全局 |
| P2-2 | Loading/Error/Empty 状态不统一 | 推广 EmptyState，新建 Loading/Error 组件 | 全局 |
| P2-3 | 胶囊硬编码标签 | 接入用户自定义标签 | 胶囊 |
| P2-4 | qualityFallback 降级无提示 | 在 UI 中显示降级提示 | distill |
| P2-5 | 导出进度不明确 | 增加导出进度或状态指示 | export |
| P2-6 | 视觉风格未完全统一 | 按 AcMind_UI设计规范收敛色彩、字体、间距 | 全局 |
| P2-7 | PersonalSpacePanel 与 Settings 重叠 | 精简个人空间面板 | 个人空间 |

---

## 2. 页面盘点

### 2.1 主视图

| # | 页面 / 视图 | 文件路径 | 当前入口 | 当前职责 | 可用性 | 主要问题 |
|---|---|---|---|---|---|---|
| 1 | `daily-flow` | `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` | 侧边栏“今日” | 今日知识流仪表盘：统计卡片、流动列表、需处理区、Obsidian 区、本周回顾 | 真实可用 | “今日”命名模糊，缺少下一步引导 |
| 2 | `capture-inbox` | `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx` | 侧边栏“收集箱” | 管线阶段分类、状态区、批量操作、队列暂停/恢复、tier 切换 | 真实可用 | 信息密度过高，新用户不知从何入手 |
| 3 | `dashboard` | `src/renderer/pages/dashboard/DashboardPage.tsx` | URL `?view=dashboard` | 已废弃，800ms 后重定向到 capture-inbox | 仅重定向 | 保留大量死代码，应清理 |
| 4 | `inbox` | `src/renderer/pages/inbox/InboxPage.tsx` | URL `?view=inbox` | SourceItemFilter + 列表 + SourceItemDetail | 真实可用 | 遗留页面，仍使用 `useSourceItems` |
| 5 | `capture` | `src/renderer/pages/capture/CapturePage.tsx` | URL `?view=capture` | 截图捕获、剪贴板、屏幕录制、存储、tier 状态 | 真实可用 | 与 CaptureInboxPage 没有统一入口 |
| 6 | `distill` | `src/renderer/pages/distill/DistillPage.tsx` | URL `?view=distill` | Tab 容器：workbench + batch | 真实可用 | 不在侧边栏，发现性差 |
| 7 | `DistillationWorkbench` | `src/renderer/pages/distill/DistillationWorkbench.tsx` | distill 页 Tab | 三栏工作台，规则模板蒸馏 | 部分可用 | 使用规则模板而非 AI，模拟延迟 |
| 8 | `export` | `src/renderer/pages/export/ExportPage.tsx` | URL `?view=export` | 导出记录、Vault 配置、历史 | 真实可用 | 不在侧边栏，部分加载错误静默 |
| 9 | `import` | `src/renderer/pages/import/ImportPage.tsx` | 侧边栏“结果回看” | 显示导出记录与血缘数据 | 真实可用 | 命名严重误导：view 为 import，实际是导出记录 |
| 10 | `edit` | `src/renderer/pages/edit/EditPage.tsx` | URL `?view=edit&id=xxx` | 编辑 SourceItem、CaptureItem、DistilledOutput | 真实可用 | 仅从 RightInspector 进入 |
| 11 | `settings` | `src/renderer/pages/settings/SettingsPage.tsx` | 侧边栏、TopBar、Tray | 19 个设置分类，含 AI、Obsidian、捕获设置 | 真实可用 | 页面过大，部分分类 disabled |
| 12 | `onboarding` | `src/renderer/pages/onboarding/OnboardingPage.tsx` | 首次启动门控 | 6 步向导 | 真实可用 | 无明显问题 |
| 13 | `search` | `src/renderer/pages/search/index.tsx` | 侧边栏“搜索” | FTS 搜索、防抖、索引状态与重建 | 真实可用 | 与 TopBar 搜索未连通 |
| 14 | `errors` | `src/renderer/pages/errors/ErrorReviewPage.tsx` | 侧边栏“错误回看” | 错误列表、过滤、重试/忽略/解决、详情 | 真实可用 | 无明显问题 |
| 15 | `history` | `src/renderer/pages/history/ProcessingHistoryPage.tsx` | 侧边栏“高级 > 处理历史” | 历史卡片、过滤、详情展开、内容预览 | 真实可用 | 隐藏较深 |

### 2.2 胶囊窗口

| # | 页面 / 视图 | 文件路径 | 当前职责 | 可用性 | 主要问题 |
|---|---|---|---|---|---|
| C1 | `CapsulePage` | `src/renderer/pages/capsule/CapsulePage.tsx` | 胶囊主状态机，驱动 11 种状态 | 真实可用 | 独立窗口不经过 App.tsx 路由 |
| C2 | `CapsuleCollapsed` | `src/renderer/pages/capsule/CapsuleCollapsed.tsx` | 56x88 折叠药丸，点击展开 | 真实可用 | 无 |
| C3 | `CapsuleExpanded` | `src/renderer/pages/capsule/CapsuleExpanded.tsx` | 网页转 Markdown、AI 润色、保存到收集箱 | 真实可用 | 快速标签与润色选项硬编码 |
| C4 | `CapsuleEdgeHidden` | `src/renderer/pages/capsule/CapsuleEdgeHidden.tsx` | 边缘停靠态、悬停 peek | 真实可用 | 无 |
| C5 | `VoiceCapturePanel` | `src/renderer/pages/capsule/VoiceCapturePanel.tsx` | 录音、Whisper 转写、编辑、润色 | 严重 stub | 转写返回空文本，功能不可用 |

---

## 3. 入口与导航盘点

### 3.1 一级导航建议

| 当前入口 | 当前指向 | 问题 | 建议 |
|---|---|---|---|
| 今日 | `daily-flow` | 命名模糊 | 改为“工作台”或“每日流程” |
| 收集箱 | `capture-inbox` | 清晰 | 保留 |
| 搜索 | `search` | 与 TopBar 搜索重复但未连通 | 保留，并接入 TopBar |
| 结果回看 | `import` | 名称与内容不匹配 | 改为“导出记录”，或合并到 export |
| 错误回看 | `errors` | 清晰但偏运维 | 可降级为二级 |
| 设置 | `settings` | 入口重复 | 保留侧边栏和 TopBar，Tray 作为系统入口 |
| 处理历史 | `history` | 隐藏在高级组 | 保留，视用户频率决定是否上移 |

### 3.2 重复入口

| 功能 | 当前入口数 | 位置 | 建议 |
|---|---:|---|---|
| 截图 | 4 | 快捷键、CaptureLauncher、CaptureHub、胶囊 | 保留快捷键 + CaptureLauncher，其他作为辅助入口 |
| 设置 | 4 | 侧边栏、TopBar、Tray、PersonalSpacePanel | 保留侧边栏 + TopBar，Tray 本地化 |
| 打开主窗口 | 3 | Tray、快捷键、胶囊 | 保留，统一中文文案 |
| 个人空间 | 2 | 侧边栏底部、TopBar 头像 | 保留一处，另一处降级 |
| 本地优先状态 | 2 | TopBar、BottomRuntimeBar | 合并状态展示 |

### 3.3 需要立即修正的入口

| 入口 | 当前问题 | 处理建议 |
|---|---|---|
| TopBar 搜索框 | `readOnly`，用户无法输入 | 接入真实搜索或打开搜索面板 |
| 通知铃铛 | 跳转日志，语义不匹配 | 更换图标或改为通知页 |
| RightInspector “去二级整理” / “整理后输出” | 两个按钮都进入 edit(id) | 合并或明确差异 |
| Tray 菜单 | Show AcMind / Settings / Quit 为英文 | 本地化为中文 |
| 胶囊“语音输入” | 当前不可用 | 隐藏或标记“即将推出” |

---

## 4. 核心流程盘点

### 4.1 文本收集流程

**端到端状态：基本连通，存在数据一致性风险。**

```text
用户输入/剪贴板
  -> captureRegistry
  -> CaptureRecord
  -> 桥接
  -> SourceItem + CaptureItem
  -> 存储
  -> UI 刷新
```

| 维度 | 状态 |
|---|---|
| 是否跑通 | 手动输入和剪贴板采集均可工作 |
| 需要手动操作 | 打开 AddCaptureItemDialog；点击“蒸馏”；选择 tier |
| 无反馈步骤 | 剪贴板自动采集去重；`captureRecordToSourceItem` 桥接 |
| 容易失败点 | 剪贴板权限停止无 UI 提示；桥接失败可能导致数据孤儿 |
| 用户不可见状态 | 监听器状态、去重命中、CaptureItem 与 SourceItem 关联 |

关键风险：`captureRecordToSourceItem()` 中 `storage.insertSourceItem()` 失败时，`CaptureItem` 已创建但 `SourceItem` 未创建，可能造成数据不一致。

### 4.2 文件导入流程

**端到端状态：基本连通，但命名和入口混乱。**

```text
用户拖拽文件
  -> DocumentImporter
  -> pdfParser/docxParser/webParser
  -> insertParsedDocument
  -> SourceItem

用户配置 Vault
  -> vaultScanner
  -> importQueue
  -> 去重
  -> SourceItem
```

| 维度 | 状态 |
|---|---|
| 是否真实解析 | PDF、DOCX、网页均为真实解析 |
| 是否存在占位 | markitdown Python CLI 不可用时有 fallback |
| 失败反馈 | 加密 PDF 仅 logger.warn；webParser 10 秒超时静默失败 |
| 能否回填统一结构 | 可以统一写入 SourceItem |

关键问题：

- `ImportPage.tsx` 实际是“结果回看”页面，不是真正的导入入口。
- `DocumentImporter` 与 `ImportPage` 没有直接关联。
- Vault 导入入口不明确。

### 4.3 语音输入流程

**端到端状态：严重断裂，当前不可用。**

```text
路径 A：VoiceCapturePanel -> useVoiceRecorder -> whisperService.transcribe() -> 返回空文本
路径 B：voiceWatchService -> audioTranscriptionService -> executeTranscription() 返回 null
路径 C：useRecording -> saveRecording() -> 未实现
```

| 维度 | 状态 |
|---|---|
| 是否真实可用 | 不可用，三条路径均断裂 |
| 外部依赖 | Whisper CLI / WASM，但当前均为 stub |
| 本地缓存 | 模型缓存逻辑存在但无法使用 |
| 失败重试 | 代码存在但无实际效果 |
| 与主链路统一 | 架构上可以统一，当前尚未实现 |

### 4.4 AI 蒸馏流程

**端到端状态：存在多套并行系统，架构复杂。**

```text
系统 A：DistillBatchPanel
  -> distillPipeline
  -> tierRouter
  -> taskQueue
  -> realDistiller/mockDistiller
  -> DistilledOutput

系统 B：contentPipelineService
  -> strategyProcessor
  -> strategyRegistry
  -> promptProfile
  -> modelRouter
  -> AI
  -> outputValidator
  -> qualityFallback

系统 C：DistillationWorkbench
  -> distillWithRules()
  -> 纯规则引擎
```

| 维度 | 状态 |
|---|---|
| 调用模块 | A 使用 distillPipeline；B 使用 strategyProcessor；C 使用 ruleBasedDistiller |
| 模型策略 | A 使用 tierRouter；B 使用 modelRouter |
| 输出结构 | 三套系统输出结构不完全统一 |
| 重新生成 | A/B 支持重试或 regenerate |
| 人工编辑 | EditPage 支持编辑全部字段 |
| 确认导出 | DistillReviewPanel 支持“接受并导出” |

关键问题：

- 系统 A 和系统 B 是两套独立蒸馏管线，共享 storage 但路由逻辑不同。
- `batchProcessor` 在 mock fallback 时直接 throw，没有使用 `mockDistiller`。
- `DistillationWorkbench` 使用纯规则引擎，仅标注“基于规则模板生成，暂未接入 AI 模型”。
- `qualityFallback` critical 时自动使用 fallback 内容，用户不知道原始 AI 输出被丢弃。

### 4.5 Obsidian 导出流程

**端到端状态：链路完整，是当前质量最高的流程。**

```text
用户确认导出
  -> obsidianExporter.exportSingle()
  -> assertExportable()
  -> markdownBuilder.buildMarkdown()
  -> frontmatter.generateFrontmatter()
  -> pathResolver.resolvePath()
  -> conflictHandler.handleConflict()
  -> safeWrite.atomicWrite()
  -> storage.insertExportRecord()
```

| 维度 | 状态 |
|---|---|
| 路径配置 | VaultConfigPanel 配置 Vault 路径、默认文件夹、路径规则 |
| 文件名生成 | `YYYY-MM-DD_HHmm_标题.md` |
| frontmatter | 通过 `frontmatter.ts` 统一生成 |
| tags | 通过 `standardFields.ts` 统一处理 |
| 成功反馈 | ExportPage 表格 + 详情面板 |
| 失败反馈 | ExportHistory `loadRecords()` catch 为空，存在静默吞错 |

关键问题：

- `ExportHistory.tsx` 中 `loadRecords()` 的 catch 块为空。
- `safeWrite.atomicWrite()` 在 temp 文件写入成功但 rename 失败时可能留下残留文件。

---

## 5. 组件与视觉系统盘点

| 组件 | 是否统一封装 | 文件路径 | 当前问题 | 建议 |
|---|---|---|---|---|
| Button | 否 | 无 | 各页面内联，层级混乱 | 新建基础组件 |
| Card | 否 | 无 | 卡片风格不一致 | 新建基础组件 |
| Sidebar | 是 | `src/renderer/components/layout/Sidebar.tsx` | 导航项多，“高级”不直观 | 优化结构 |
| TopBar | 是 | `src/renderer/components/layout/TopBar.tsx` | 搜索只读，状态 Chip 信息密度不均 | 接入搜索，精简状态 |
| Modal / Dialog | 否 | 无 | 样式不一致 | 新建基础组件 |
| Toast | 部分 | `src/renderer/components/shared/ToastViewport.tsx` | 覆盖范围不足 | 扩展使用 |
| Empty State | 是 | `src/renderer/components/shared/EmptyState.tsx` | 资产使用不统一 | 推广 |
| Loading State | 否 | 无 | 加载展示不一致 | 新建基础组件 |
| Error State | 否 | 无 | 错误展示不一致 | 新建基础组件 |
| Status Badge | 否 | 无 | 状态标记样式不统一 | 新建基础组件 |
| Input / Textarea | 否 | 无 | 表单样式不一致 | 新建基础组件 |
| Select / Dropdown | 否 | 无 | 下拉样式不一致 | 新建基础组件 |
| Tabs | 否 | 无 | Distill、Export、Settings 样式不一致 | 新建基础组件 |
| List Item | 否 | 无 | 列表项样式不一致 | 新建基础组件 |
| ScrollContainer | 是 | `src/renderer/components/shared/ScrollContainer.tsx` | 使用范围有限 | 推广 |
| 设计系统基础 | 部分 | `src/renderer/design-system/primitives.tsx` | 有基础但未广泛使用 | 作为组件库入口 |

结论：16 类核心组件中，已统一封装或部分封装的只有 5 类左右。后续产品体验收敛需要先补齐基础组件，而不是继续在页面内堆 Tailwind class。

---

## 6. 状态系统盘点

### 6.1 内容状态

| 状态 | 当前已有 | UI 是否可见 | 问题 |
|---|---|---|---|
| `new` | 是 | 可见 | 无 |
| `collected` | 是 | 可见 | 无 |
| `processing` | 是 | 可见 | 无 |
| `distilled` | 是 | 可见 | 无 |
| `review_required` | 是 | 可见 | 无 |
| `exported` | 是 | 可见 | 无 |
| `failed` | 是 | 可见 | 无 |

### 6.2 AI 任务状态

| 状态 | 当前已有 | UI 是否可见 | 问题 |
|---|---|---|---|
| `idle` | 是 | 不直接可见 | 可接受 |
| `queued` | 是 | 可见 | 无 |
| `running` | 是 | 可见 | 无 |
| `success` | 是 | 可见 | 无 |
| `failed` | 是 | 可见 | 无 |
| `fallback` | 部分 | 不可见 | 降级发生时用户无感知 |

### 6.3 导出状态

| 状态 | 当前已有 | UI 是否可见 | 问题 |
|---|---|---|---|
| `not_exported` | 是 | 可见 | 无 |
| `exporting` | 部分 | 不明确 | 缺少进度指示 |
| `exported` | 是 | 可见 | 无 |
| `export_failed` | 是 | 可见 | 部分加载错误静默吞错 |

### 6.4 管线状态

| 状态 | 当前已有 | UI 是否可见 | 问题 |
|---|---|---|---|
| `captured` | 是 | 可见 | 无 |
| `queued` | 是 | 可见 | 无 |
| `processing` | 是 | 可见 | 无 |
| `distilled` | 是 | 可见 | 无 |
| `review_required` | 是 | 可见 | 无 |
| `approved` | 是 | 可见 | 无 |
| `exporting` | 部分 | 不明确 | 缺少进度 |
| `exported` | 是 | 可见 | 无 |
| `failed` | 是 | 可见 | 无 |

---

## 7. Mock / Placeholder / 假数据清单

| # | 位置 | 文件路径 | 内容 | 用户影响 | 建议 |
|---|---|---|---|---|---|
| 1 | whisperService WASM stub | `src/renderer/services/whisperService.ts` | `loadWasmModule()` 返回 mock，`transcribe()` 返回空文本 | 高：语音转写不可用 | 隐藏语音入口或灰态 |
| 2 | audioTranscriptionService stub | `src/main/services/capture/audioTranscriptionService.ts` | `executeTranscription()` 返回 null | 高：音频任务无实际结果 | 隐藏或标记 |
| 3 | useRecording stub | `src/renderer/hooks/useRecording.ts` | `saveRecording()` 未实现，状态始终 inactive | 高：录屏不可用 | 隐藏录屏按钮或灰态 |
| 4 | mockDistiller | `src/main/services/distiller/mockDistiller.ts` | 固定格式结果、500ms 延迟、`[Mock]` 前缀 | 中：用户可能不知道结果是 mock | 改为配置 AI 模型提示 |
| 5 | DistillationWorkbench 规则引擎 | `src/renderer/pages/distill/DistillationWorkbench.tsx` | 纯前端规则引擎，模拟延迟 | 中：容易被误认为 AI | 标记为“规则模板模式”或接入 AI |
| 6 | DashboardPage 死代码 | `src/renderer/pages/dashboard/DashboardPage.tsx` | 未使用的 display、detail、metric 代码 | 低：增加维护负担 | 删除 |
| 7 | SettingsPage disabled 分类 | `src/renderer/pages/settings/SettingsPage.tsx` | 数据维护、开发者选项、写入规则 disabled | 低：用户看到但不可用 | 隐藏或改为即将推出 |
| 8 | CapsuleExpanded 硬编码标签 | `src/renderer/pages/capsule/CapsuleExpanded.tsx` | 快速标签和润色选项硬编码 | 低：不可自定义 | 接入用户标签 |
| 9 | qualityFallback 占位内容 | `src/main/services/strategy/qualityFallback.ts` | critical 时生成占位 ProcessedContent | 中：用户不知道降级 | UI 显示降级提示 |
| 10 | 非文本结构占位 | `src/main/services/pipeline/contentPipelineService.ts` | `buildNonTextStructured()` confidence 仅 0.3 | 低：非文本处理质量低 | 显示低置信度 |
| 11 | TopBar 搜索框 | `src/renderer/components/layout/TopBar.tsx` | `readOnly`，未接入搜索 | 中：点击无反应 | 接入 Search |
| 12 | Tray 菜单英文 | `src/main/tray.ts` | Show AcMind / Settings / Quit | 低：中文体验不佳 | 本地化 |
| 13 | ExportHistory 静默吞错 | `src/renderer/components/export/ExportHistory.tsx` | `loadRecords()` catch 为空 | 中：失败不可见 | 加 Toast 或错误状态 |

---

## 8. 当前最大体验问题 Top 10

1. **用户打开应用后不知道下一步做什么**  
   默认进入“今日”页，但页面没有明确行动引导。建议改为工作台，提供收集文本、导入文件、查看结果、配置模型等入口。

2. **语音输入功能完全不可用**  
   胶囊和设置页存在语音入口，但转写链路均为 stub。建议隐藏或灰态。

3. **侧边栏导航项与实际功能不匹配**  
   “结果回看”实际展示导出记录，“今日”含义模糊，distill/export 不在侧边栏。建议重做导航命名和层级。

4. **存在多套并行 AI 蒸馏系统**  
   主链路、Phase 8 管线、规则工作台并存，导致路由、输出和降级策略不一致。建议统一。

5. **TopBar 搜索框是只读的**  
   用户看到搜索框和快捷键提示，但无法输入。建议接入真实搜索。

6. **信息密度不统一**  
   CaptureInboxPage 极密，DailyKnowledgeFlowPage 较松，体验割裂。建议统一密度标准。

7. **入口重复严重**  
   截图、设置、打开主窗口均有多处入口。建议保留主入口，其他入口降级。

8. **按钮层级和反馈不统一**  
   各页面按钮、Toast、错误反馈不一致。建议建立基础组件和反馈规范。

9. **DistillationWorkbench 使用规则引擎而非 AI**  
   用户可能预期 AI 处理，但得到规则模板结果。建议明确标记或接入真实 AI。

10. **错误处理不一致**  
    ExportHistory 静默吞错，剪贴板监听停止无提示，部分失败仅 logger.warn。建议统一用户可见反馈。

---

## 9. 关键数据附录

### 9.1 页面统计

- 总页面数：15 个主视图 + 5 个胶囊子页面 = 20 个
- 真实可用：17 个
- 已废弃：1 个，`dashboard`
- 严重 stub：2 个，`VoiceCapturePanel`、`DistillationWorkbench` 部分能力

### 9.2 入口统计

- 总入口数：36 个
- 重复入口：截图 4 处、设置 4 处、打开主窗口 3 处、个人空间 2 处
- 命名问题：4 处，“今日”模糊、“结果回看”误导、Tray 英文、通知铃铛语义不匹配

### 9.3 组件统计

- 核心组件：16 类
- 已统一或部分统一：约 5 类
- 需要重构或补齐：约 11 类

### 9.4 Mock 统计

- 严重 mock：3 个，`whisperService`、`audioTranscriptionService`、`useRecording`
- 中等 mock：4 个，`mockDistiller`、`DistillationWorkbench`、`qualityFallback`、TopBar 搜索
- 轻微 mock：6 个

### 9.5 流程统计

- 完整可用：文本收集、Obsidian 导出
- 基本可用但有问题：文件导入、AI 蒸馏
- 当前不可用：语音输入

