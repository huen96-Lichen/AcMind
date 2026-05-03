# AcMind 模块边界

## 概述

AcMind 由 11 个模块组成，每个模块有明确的职责边界。模块之间通过 IPC 和共享类型通信，避免直接耦合。

---

## Capsule

**职责**：
- 桌面横向胶囊（Desktop Muse Capsule）
- 菜单栏 / tray 入口
- 快速输入
- 快速拖拽
- 当前状态展示
- 进入 Capture / Inbox / AI Action 的轻入口

**不负责**：
- 复杂知识管理
- 具体 AI 整理逻辑
- 文件转换逻辑

**输入**：用户快速输入、拖拽文件/图片、快捷键触发
**输出**：SourceItem → Inbox，CaptureRecord → Capture 管线

**当前代码目录**：
- `src/main/capsuleController.ts`
- `src/renderer/pages/capsule/`
- `src/shared/capsuleSettings.ts`

**当前 IPC**：`capsule.*`（getStatus, toggle, quickCapture, quickInput, quickDrop）
**目标 IPC**：`capsule.*`（保持不变）
**允许依赖**：capture, inbox, ai-runtime
**禁止依赖**：distill, export, storage（不直接操作数据库）

---

## Capture

**职责**：
- 截图（全屏/区域/窗口）
- 贴图 / 钉图
- OCR 文字识别
- 标注
- 录音入口 / 语音采集入口
- 剪贴板文本采集
- 网页内容采集
- 文件导入采集

**不负责**：
- AI 总结逻辑
- Obsidian 导出逻辑
- 长期知识库逻辑

**输入**：用户截图操作、剪贴板变化、文件拖拽、URL 输入、语音录制
**输出**：CaptureRecord → 管线，SourceItem → Inbox，AssetFile → 存储

**当前代码目录**：
- `src/main/captureService.ts`
- `src/main/services/capture/`（12 种采集适配器）
- `src/main/services/strategy/`（内容策略处理）
- `src/renderer/pages/capture/`
- `src/renderer/pages/capture-inbox/`

**当前 IPC**：`capture.*`（start, stop, getStatus, quickCapture, quickText, quickWeb, quickFile, quickImage, quickAudio, quickVideo, quickScreenshot, quickClipboard, quickContext, quickVoice, quickPin, quickNote, quickImport, quickImportFiles, quickImportUrls, quickImportDirs）
**目标 IPC**：`capture.*`（保持不变）
**允许依赖**：storage, ai-runtime
**禁止依赖**：distill, export（不直接触发蒸馏或导出）

**Phase 2A 实现状态**：
- ✅ capture.startAreaCapture / capture.cancelCapture（触发截图）
- ✅ capture.pinImage（钉图到桌面，PinnedImageController 管理浮窗）
- ✅ capture.saveToInbox（贴图保存到收集箱）
- ✅ capture.listRecentCaptures（最近截图列表）
- ✅ capture.listPinnedImages（已钉图片列表）
- ✅ capture.closePinnedImage（关闭贴图）
- ✅ PinnedImageController：贴图浮窗管理器（alwaysOnTop + frameless + 可移动/可关闭）
- ✅ PinnedImageView：独立 BrowserWindow 贴图渲染
- ✅ CapturePage UI 重写：截图按钮、缩略图列表、已钉图片列表
- ✅ vite.config.ts 多页面构建（main/capsule/pinned-image）

**Phase 2B 实现状态**：
- ✅ capture.ocrExtract（macOS Vision Framework OCR，本地处理）
- ✅ capture.ocrSaveToInbox（OCR 文字保存到收集箱）
- ✅ ocrService.ts：Swift CLI 调用 Vision Framework
- ✅ scripts/vision_ocr.swift：OCR CLI 工具（中英文支持）
- ✅ AnnotationCanvas 组件：轻标注（矩形/箭头/文本，Canvas 2D）

---

## Clipboard

**职责**：
- 剪贴板监听（文本 / 图片 / 链接 / 文件）
- 剪贴板历史记录
- 智能卡片展示
- 重新复制
- 转纯文本 / 转 Markdown
- 发送到 Inbox
- **不直接做 AI 整理**

**不负责**：
- 全局知识库搜索
- 模型路由
- 文件转换处理
- AI 整理（交给 Distill）

**输入**：系统剪贴板变化事件、用户手动复制操作
**输出**：ClipboardItem（剪贴板历史），SourceItem → Inbox

**当前代码目录**：
- `src/main/clipboardWatcher.ts`
- `src/main/services/capture/clipboardTextAdapter.ts`
- `src/modules/clipboard/`（Phase 0 新建模块目录）

**当前 IPC**：
- `clipboard.getStatus` / `clipboard.toggle`（legacy，剪贴板监听开关）
- `clipboard.listItems` / `clipboard.getItem` / `clipboard.pinItem` / `clipboard.unpinItem` / `clipboard.deleteItem` / `clipboard.saveToInbox`（Phase 0 新增）
- `clipboard.searchItems` / `clipboard.copyItem` / `clipboard.clearHistory` / `clipboard.pause` / `clipboard.resume` / `clipboard.isPaused`（Phase 1A 新增）

**目标 IPC**：`clipboard.*`（Phase 1A 已补齐）
**允许依赖**：capture, storage, inbox
**禁止依赖**：distill, export, ai-runtime（不直接调用 AI）

**Phase 1A 实现状态**：
- ✅ 剪贴板监听（ClipboardWatcher 轮询 + 去重 + pause/resume）
- ✅ ClipboardItem 写入 clipboard_items 表
- ✅ Clipboard 页面 UI（列表、搜索、类型筛选、卡片操作）
- ✅ Clipboard → Inbox 保存链路（saveToInbox 创建 SourceItem）
- ✅ 重新复制（copyItem 写回系统剪贴板）
- ✅ 暂停/恢复监听
- ✅ 清空历史（保留固定项）
- ✅ URL 自动识别
- ✅ 图片占位记录
- ✅ 来源 App 记录
- ✅ 隐私：不上传、不调用 AI、空内容过滤、去重

---

## Shelf

**职责**：
- 文件临时架
- 拖拽暂存
- 文件 / 图片 / 链接批量暂存
- 发送到 Inbox
- 后续可接 MarkItDown 文件转换
- **不做完整 Finder 替代**

**不负责**：
- 完整文件管理器
- 云盘同步
- Finder 替代品

**输入**：用户拖拽文件/图片、从剪贴板粘贴、从 Capture 发送
**输出**：ShelfItem（临时架项目），SourceItem → Inbox

**当前代码目录**：
- `src/modules/shelf/`（Phase 0 新建模块目录）
- `src/main/services/pinPoolService.ts`（legacy，pin_pool_items）

**当前 IPC**：
- `pinPool.*`（legacy，Pin 池操作）
- `shelf.listItems` / `shelf.getItem` / `shelf.addFiles` / `shelf.addText` / `shelf.removeItem` / `shelf.saveToInbox`（Phase 0 新增）

**目标 IPC**：`shelf.*`（Phase 0 已补齐），`pinPool.*` 保留为 legacy
**允许依赖**：storage, inbox, capture
**禁止依赖**：distill, export, ai-runtime（不直接调用 AI）

**Phase 1B 实现状态**：
- ✅ Shelf storage 层方法（insert/get/list/updateStatus/delete/updateSourceItemId/updateLabel）
- ✅ Shelf IPC handlers（listItems/getItem/addFiles/addText/removeItem/saveToInbox）+ 事件推送
- ✅ Shelf preload 桥接（完整 shelf.* API + onItemsChanged 事件监听）
- ✅ Shelf UI 页面（拖拽文件区、手动添加文本、卡片列表、保存到收集箱、删除）
- ✅ Shelf → Inbox 保存链路（saveToInbox 创建 SourceItem + 关联 + 状态更新）
- ✅ 文件拖拽支持（通过 Electron file.path 获取真实路径）
- ✅ 来源标记（drag_drop / clipboard / capture / manual）
- ✅ Sidebar 新增「Shelf」导航入口
- ✅ App.tsx 注册 shelf view 路由

---

## File Converter

**职责**：
- 本地文件转 Markdown（PDF、DOCX、PPTX、HTML、TXT、MD）
- 优先使用 Python markitdown CLI，自动回退到内置解析器（pdf-parse、mammoth、JSDOM+Readability）
- 转换任务管理（ProcessJob 生命周期：queued → running → succeeded/failed）
- 转换结果预览
- 保存到收集箱（SourceItem）
- **不做 URL 转换**（URL 转换由 markitdown.convert 负责）

**不负责**：
- URL 网页转换（由 markitdown.convert 处理）
- AI 整理（交给 Distill）
- 导出到 Obsidian（交给 Export）

**输入**：本地文件路径（用户选择或拖拽）
**输出**：Markdown 文本，SourceItem → Inbox，ProcessJob（任务记录）

**当前代码目录**：
- `src/main/services/parser/markitdownService.ts`（convertFileToMarkdown / convertFileViaFallback）
- `src/main/services/parser/pdfParser.ts`（PDF 解析）
- `src/main/services/parser/docxParser.ts`（DOCX 解析）
- `src/main/services/parser/webParser.ts`（HTML 解析）
- `src/renderer/pages/file-converter/`
- `src/renderer/hooks/useFileConverter.ts`

**当前 IPC**：
- `fileConverter.convert`（转换文件，创建 ProcessJob）
- `fileConverter.getStatus`（查询任务状态）
- `fileConverter.listJobs`（列出转换任务）
- `fileConverter.saveToInbox`（保存到收集箱）
- `fileConverter.preview`（预览转换结果，不创建任务）
- `fileConverter.jobsChanged`（任务变化事件推送）

**允许依赖**：storage, inbox
**禁止依赖**：ai-runtime, distill, export

**Phase 3 实现状态**：
- ✅ markitdownService.convertFileToMarkdown（本地文件 → Markdown，Python CLI + fallback）
- ✅ markitdownService.convertFileViaFallback（内置解析器回退：pdf-parse / mammoth / JSDOM）
- ✅ process_jobs 表（schema v15，ProcessJob CRUD）
- ✅ fileConverter.* IPC handlers（convert / getStatus / listJobs / saveToInbox / preview）
- ✅ preload 桥接（fileConverter.* API + onJobsChanged 事件）
- ✅ useFileConverter hook（任务列表、转换、预览、保存）
- ✅ FileConverterPage UI（拖拽区域、文件选择、预览、历史任务列表）
- ✅ Sidebar 导航入口（line-file-import 图标）
- ✅ App.tsx 路由注册（file-converter view）

---

## Inbox

**职责**：
- 所有 SourceItem 的统一入口
- 未整理 / 已整理 / 已导出状态管理
- SourceItem 列表展示
- 多源内容统一展示
- 发起 Distill / Export
- **不做具体截图逻辑**

**不负责**：
- 具体截图逻辑（交给 Capture）
- 具体模型调用细节（交给 AI Runtime）
- 具体 Markdown 转换实现（交给 Export）

**输入**：来自 Capture / Clipboard / Shelf / 手动输入的 SourceItem
**输出**：SourceItem（带状态流转），触发 Distill / Export 任务

**当前代码目录**：
- `src/renderer/pages/capture-inbox/`
- `src/renderer/components/inbox/`
- `src/main/services/pipeline/`（内容管线）

**当前 IPC**：
- `sourceItems.*`（legacy，SourceItem CRUD）
- `captureInbox.*`（legacy，采集收件箱）

**目标 IPC**：`inbox.*`（待 Phase 1 补齐），`sourceItems.*` / `captureInbox.*` 保留为 legacy
**允许依赖**：storage, distill, export
**禁止依赖**：capture（不直接截图）, ai-runtime（不直接调用模型）

---

## Distill

**职责**：
- AI 整理（标题生成、摘要、标签、分类）
- 结构化 Markdown 草稿生成
- quality_flags 质量评估
- 批量蒸馏处理
- 蒸馏结果审核
- **不负责采集**

**不负责**：
- 数据采集（交给 Capture / Clipboard / Shelf）
- 截图 / 剪贴板监听
- UI 常驻入口

**输入**：SourceItem（来自 Inbox），AI 模型配置（来自 AI Runtime）
**输出**：DistilledNote（蒸馏结果），ProcessJob（处理任务记录）

**当前代码目录**：
- `src/main/services/distiller/`（蒸馏管线）
- `src/main/services/strategy/`（策略系统）
- `src/renderer/pages/distill/`

**当前 IPC**：`distill.*`（distill, getStatus, getOutput, listOutputs, batchDistill, review）
**目标 IPC**：`distill.*`（保持不变）
**允许依赖**：ai-runtime, storage, inbox
**禁止依赖**：capture, clipboard, shelf（不直接采集）

---

## Export

**职责**：
- Markdown 输出
- Obsidian / iCloud 目录写入
- frontmatter 生成
- 文件命名规则
- 导出记录管理
- Markdown 规范兼容
- **不负责 AI prompt**

**不负责**：
- AI prompt（交给 AI Runtime）
- 原始截图采集（交给 Capture）
- 剪贴板监听（交给 Clipboard）

**输入**：DistilledNote（来自 Distill），ExportConfig（导出配置）
**输出**：ExportRecord（导出记录），文件系统写入

**当前代码目录**：
- `src/main/services/exporter/`（导出服务）
- `src/renderer/pages/export/`

**当前 IPC**：`export.*`（export, exportBatch, getStatus, listRecords, preview, resolveConflict）
**目标 IPC**：`export.*`（保持不变）
**允许依赖**：storage, distill
**禁止依赖**：capture, clipboard, shelf, ai-runtime（不直接采集或调用 AI）

---

## AI Runtime

**职责**：
- 本地模型 / 云端模型 provider 管理
- OpenAI-compatible endpoint 支持
- Ollama 本地模型支持
- Action Registry（AI 动作注册）
- Prompt Profile 管理
- AI 任务队列
- 失败回退策略
- 模型路由（tierRouter）
- **不直接写业务 UI 状态**

**不负责**：
- UI 页面直接状态（交给各业务模块）
- 业务数据存储 schema 的主导权（交给 Storage）

**输入**：AIAction（动作定义），ProviderConfig（模型配置），处理请求
**输出**：AI 处理结果，任务状态变更事件

**当前代码目录**：
- `src/main/services/aiHub/`（AI 中心）
  - `aiProviderService.ts`（Ollama + OpenAI-compatible HTTP 调用）
  - `aiActionRunner.ts`（Action 执行管线：strategyProcessor → aiProviderService → outputValidator）
  - `taskQueue.ts`（FIFO 任务队列）
  - `secretStore.ts`（macOS Keychain 密钥管理）
- `src/main/services/strategy/`（策略系统）
  - `strategyProcessor.ts`（集成处理器）
  - `modelRouter.ts`（模型路由）
  - `promptProfile.ts`（Prompt Profile 体系）
  - `outputValidator.ts`（输出校验）
  - `qualityFallback.ts`（质量兜底）
  - `strategies/`（11 个具体策略）
- `src/shared/ai/modelRegistry.ts`
- `src/renderer/pages/ai/AIPage.tsx`（Action 管理 + Job 监控 UI）
- `src/renderer/hooks/useAI.ts`（AI Runtime 数据 Hook）

**当前 IPC**：
- `providers.*`（legacy，Provider CRUD）
- `aiTasks.*`（legacy，AI 任务 CRUD）
- `aiRuntime.listActions` / `aiRuntime.getAction` / `aiRuntime.createAction` / `aiRuntime.updateAction` / `aiRuntime.deleteAction`
- `aiRuntime.runAction`（真实 AI 调用，接入 strategyProcessor + aiProviderService）
- `aiRuntime.listJobs` / `aiRuntime.getJob` / `aiRuntime.cancelJob`
- `aiRuntime.jobChanged`（任务状态变化事件推送）
- `aiRuntime.healthCheck`（Provider 健康检查）

**Phase 4 实现状态**：
- ✅ aiProviderService（Ollama /api/generate + OpenAI-compatible /chat/completions）
- ✅ aiActionRunner（完整管线：mockRecord → strategyProcessor.prepareProcessing → aiProviderService.call → processAiOutput）
- ✅ preload 桥接（aiRuntime.* 完整 API + onJobChanged 事件）
- ✅ useAI Hook（Action CRUD、执行、Job 监控、健康检查）
- ✅ AIPage 增强（Action 创建/删除/运行、Job 列表/取消、运行结果预览）
- ✅ ProcessedContent 提升到 shared/types.ts
- ✅ AI_RUNTIME_JOB_CHANGED + AI_RUNTIME_HEALTH_CHECK IPC 通道

**目标 IPC**：`aiRuntime.*`（Phase 4 已补齐真实调用），`providers.*` / `aiTasks.*` 保留为 legacy
**允许依赖**：storage
**禁止依赖**：capture, clipboard, shelf, inbox, distill, export（不直接操作业务模块）

---

## Settings

**职责**：
- 应用权限管理
- 快捷键配置
- 外观设置（主题、密度）
- 存储路径配置
- AI Provider 配置
- Vault 配置
- 用户配置文件

**不负责**：具体业务逻辑、数据采集

**当前代码目录**：
- `src/main/settings.ts`
- `src/main/permissions.ts`
- `src/main/permissionCoordinator.ts`
- `src/main/shortcutManager.ts`
- `src/shared/defaultSettings.ts`
- `src/renderer/pages/settings/`

**当前 IPC**：`settings.*`（get, update, resetSection, getStats, getVaultConfig, updateVaultConfig, getPermissionStatus, checkPermission, openSystemSettings, resetPermissions, getShortcutSettings, updateShortcut, resetShortcut, getShortcutConflicts）
**目标 IPC**：`settings.*`（保持不变）
**允许依赖**：storage
**禁止依赖**：所有业务模块

---

## Design System

**职责**：
- 视觉 Token（颜色、字体、间距）
- 基础组件（Button、Input、Card 等）
- 图标系统
- 布局组件
- 主题切换

**当前代码目录**：
- `src/renderer/design-system/`（tokens, primitives, icons, components）
- `src/assets/icon/`（SVG 图标资源）

**当前 IPC**：无（纯渲染层）
**目标 IPC**：无
**允许依赖**：无
**禁止依赖**：所有主进程模块

---

## Knowledge Base

**职责**：
- Knowledge Card 浏览与管理
- Knowledge Edge 关系图谱
- DistilledNote（蒸馏笔记）CRUD
- Obsidian Vault 关键词搜索
- 知识卡片与蒸馏笔记的关联展示

**不负责**：
- AI 蒸馏逻辑（交给 AI Runtime）
- Obsidian 导出逻辑（交给 Export）
- 数据存储 schema（交给 Storage）

**输入**：用户搜索关键词、Knowledge Card 查询
**输出**：搜索结果、卡片详情、蒸馏笔记列表

**当前代码目录**：
- `src/renderer/pages/knowledge-cards/KnowledgeCardsPage.tsx`（知识卡片 + Vault 搜索 + 蒸馏笔记 UI）
- `src/renderer/hooks/useDistilledNotes.ts`（蒸馏笔记 CRUD Hook）
- `src/renderer/hooks/useVaultSearch.ts`（Vault 搜索 Hook）
- `src/main/services/importer/vaultScanner.ts`（Vault 文件扫描 + 关键词搜索）

**当前 IPC**：
- `knowledgeCards.*`（list, get, getBySourceItemId, upsertFromReview）
- `knowledgeEdges.*`（list, create, delete）
- `graph.get`（知识图谱查询）
- `distilledNotes.*`（list, get, create, update, delete）
- `vaultSearch.search`（Vault 关键词搜索）

**Phase 5 实现状态**：
- ✅ distilled_notes 表（schema v16）+ 完整 CRUD
- ✅ VaultSearchResult 类型 + VaultScanner.search()
- ✅ distilledNotes.* IPC + preload 桥接
- ✅ vaultSearch.* IPC + preload 桥接
- ✅ KnowledgeCardsPage UI（三 Tab：知识卡片 / Vault 搜索 / 蒸馏笔记）
- ✅ useDistilledNotes / useVaultSearch hooks
- ✅ Sidebar 新增"知识库"导航入口

**允许依赖**：storage, ai-runtime
**禁止依赖**：capture, clipboard, shelf, inbox（不直接操作采集模块）

---

## Voice

**职责**：
- ASR 语音转写（OpenAI-compatible Whisper API + 本地 whisper CLI）
- 语音词典管理（专有名词热词）
- AI 文本润色（raw/light/structured/formal 四种模式）
- 全局语音快捷键（Cmd+Shift+V）
- 语音录音面板（MediaRecorder → importAudioBuffer → 转写）

**不负责**：
- 音频文件导入和监听（交给 Capture 的 voiceWatchService）
- 转写任务队列管理（交给 Capture 的 audioTranscriptionService）
- 语音笔记蒸馏策略（交给 AI Runtime 的 audioStrategy）

**输入**：用户语音录音、音频文件路径、词典短语
**输出**：转写文本、润色结果、ASR 状态

**当前代码目录**：
- `src/main/voice/asr/index.ts`（ASR Provider — OpenAI-compatible API + 本地 CLI）
- `src/main/voice/dictionary/index.ts`（语音词典 JSON 存储）
- `src/main/voice/polish/index.ts`（本地确定性文本润色）
- `src/main/voice/recorder/index.ts`（录音状态机）
- `src/renderer/pages/voice/VoiceDictionaryPage.tsx`（词典管理 + ASR 状态 + 润色测试 UI）
- `src/renderer/hooks/useVoiceDictionary.ts`（词典 CRUD Hook）
- `src/renderer/pages/capsule/VoiceCapturePanel.tsx`（录音面板 UI）
- `src/main/shortcutManager.ts`（全局快捷键注册）

**当前 IPC**：
- `voice.*`（importAudio, importAudioBuffer, startWatch, stopWatch, getWatchState, retryTranscription, getTranscriptionStatus, getDictationGuide, polishTranscript, createPinFromTranscript）
- `whisper.*`（getStatus, getModels, downloadModel, deleteModel, initialize, transcribe）
- `voiceDictionary.*`（list, add, delete, toggle）
- `asr.*`（getStatus, transcribe）

**Phase 6 实现状态**：
- ✅ ASR Provider 真实实现（OpenAI-compatible Whisper API + 本地 whisper CLI fallback）
- ✅ 全局语音快捷键（Cmd+Shift+V）
- ✅ 语音词典 remove/toggle 方法
- ✅ voiceDictionary.* IPC + preload 桥接
- ✅ asr.* IPC + preload 桥接
- ✅ VoiceDictionaryPage UI（词典管理 + ASR 状态 + AI 润色测试）
- ✅ useVoiceDictionary hook

**允许依赖**：settings, storage, logger
**禁止依赖**：capture, clipboard, shelf, inbox（不直接操作采集模块）

---

## Storage

**职责**：
- SQLite 数据库管理（better-sqlite3）
- Schema 定义与迁移
- 文件资产存储
- 全文搜索索引
- 数据备份
- **不承担业务决策**

**不负责**：
- 业务决策（交给各业务模块）
- AI 模型调用（交给 AI Runtime）

**当前代码目录**：
- `src/main/storage.ts`（Schema v16，24 张表，含 distilled_notes）
- `src/main/services/search/`（搜索服务）
- `src/main/services/importer/`（Vault 导入）

**当前 IPC**：无直接 IPC（通过各业务模块间接调用）
**目标 IPC**：无
**允许依赖**：无（底层模块）
**禁止依赖**：所有业务模块

---

## 模块依赖关系

```
Capsule ──→ Capture, Inbox, AI Runtime
Capture ──→ Storage, AI Runtime
Clipboard ──→ Capture, Storage, Inbox
Shelf ──→ Storage, Inbox, Capture
Inbox ──→ Storage, Distill, Export
Distill ──→ AI Runtime, Storage, Inbox
Export ──→ Storage, Distill
AI Runtime ──→ Storage
Knowledge Base ──→ Storage, AI Runtime
Voice ──→ Settings, Storage, Logger
Settings ──→ Storage
Design System ──→ (无依赖)
Storage ──→ (无依赖，底层模块)
```
