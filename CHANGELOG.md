# Changelog

## 0.13.0 (2026-05-05) — Phase 2: 整理链路打通

### Changed
- **useSourceItems.updateItem**：从乐观更新占位改为调用真实 `sourceItems.update` IPC
- **DistillPage 整理页**：`handleDistill` / `handleRetry` 调用真实 `distill.run` IPC，新增整理进度 UI（spinner + 状态文案）
- **StagingPoolPage 暂存池**："标记待整理"替换为直接"送入整理"流程，新增单条和批量送入整理按钮
- **Sidebar 导航**："整理"导航从 `capture-inbox` 改为 `distill`（指向 DistillPage）
- **状态流**：inbox → distilling → distilled → exported 在 UI 层完整串联

### Added
- **批量整理**：DistillPage 新增"全部整理"按钮，一键整理所有待整理条目
- **整理进度追踪**：`distilling` 状态条目实时显示在待整理标签页，spinner + 状态文案
- **单条重试**：整理失败的条目显示错误状态和重试按钮
- **暂存池送入整理**：单条"送入整理"按钮 + 表头批量"送入整理"按钮，逐条追踪 distilling 状态
- Phase 2 技术文档已在 2026-05-07 文档清理中移除，当前状态见仓库源码与 README

## 0.12.0 (2026-05-05) — Phase 1: 核心收集主链路固定

### Changed
- **数据源统一**：废弃 pinPool，所有收集内容统一写入 sourceItems
- **SourceItem 类型扩展**：新增 `file`/`webpage`/`audio`/`video`/`screenshot` 类型，新增 `file_import`/`url_paste` 来源
- **SourceItem 字段扩展**：新增 `filePath`/`thumbnailPath`/`updatedAt`/`fileSize`/`mimeType` 字段
- **暂存池重构**：从 pinPool 数据源改为 sourceItems，支持类型筛选、搜索、详情面板、操作按钮
- **工作台重构**：移除 pinPool 依赖，"记录想法"直接写入 sourceItems，"今日暂存"展示 sourceItems 数据
- **剪贴板监听**：自动监听改为写入 sourceItems（不再写 pinPool）
- **数据库迁移**：v21 迁移新增 `file_path`/`thumbnail_path`/`updated_at`/`file_size`/`mime_type` 列

### Added
- **通用文件导入**：支持任意文件类型导入为 sourceItem（记录文件名/路径/大小/MIME）
- **URL 保存**：支持粘贴 URL 保存为 webpage 类型 sourceItem
- **IPC 通道**：新增 `sourceItems.importFile`/`sourceItems.saveUrl`/`sourceItems.update`
- **暂存池操作**：复制内容、删除、标记待整理、打开文件
- **暂存池筛选**：全部/文本/图片/截图/文件/网页/音频
- **暂存池空状态**：引导文案提示用户如何收集内容
- **Toast 反馈**：所有关键操作（收集/删除/复制/标记）均有成功/失败反馈
- Phase 1 技术文档已在 2026-05-07 文档清理中移除，当前状态见仓库源码与 README

### Removed
- 暂存池不再使用 pinPool 作为数据源
- 工作台不再使用 usePinPool hook

## 0.11.0 (2026-05-05) — Phase 0.5: Acore 产品线收束与产品边界统一

### Changed
- **品牌统一**：Acore 确立为母品牌，AcMind 为主应用名
- **导航收束**：一级导航从 8 项精简为 6 项（工作台、暂存池、整理、知识库、工具台、设置）
  - Agent 对话降级为工具台子页
  - 定时任务降级为工具台子页
- **首页重构**：标题改为"工作台"，副标题改为"个人桌面 AI 信息中枢 — 从碎片收集到知识沉淀"
- **CSS 类名统一**：`pinstack-*` 前缀全部替换为 `acmind-*`
- **localStorage key 统一**：`pinstack.quicknote` → `acmind.quicknote`
- **AI 助手中性化**：默认 systemPrompt 移除"小龙虾"人格，改为"你是 AcMind 的 AI 助手"
  - 用户可在设置中自定义 AI 助手名称和人设

### Added
- `docs/ACORE_PRODUCT_MAP.md` — Acore 产品体系地图
- `docs/ACMIND_PRODUCT_BOUNDARY.md` — AcMind 产品边界说明
- 项目交接文档已并入仓库源码说明，不再单独维护
- 工作日志已在 2026-05-07 文档清理中移除，当前状态见仓库源码与 README

## 0.10.0 (2026-05-03) — Phase 6: 语音能力深化

### Added
- ASR Provider 真实实现（OpenAI-compatible Whisper API + 本地 whisper CLI fallback）
  - `asrProvider.getStatus()` — 检查 ASR 配置状态
  - `asrProvider.transcribe(filePath, options)` — 调用 API 或本地 CLI 转写音频
  - 支持 multipart/form-data 上传、language/prompt/translate 参数
- 全局语音快捷键 `Cmd+Shift+V`（shortcutManager 注册）
- 语音词典管理增强
  - `VoiceDictionaryStore.remove(id)` — 删除词典条目
  - `VoiceDictionaryStore.toggle(id, enabled)` — 启用/禁用词典条目
- 6 个新 IPC 通道 + preload 桥接：
  - `voiceDictionary.list/add/delete/toggle` — 词典 CRUD
  - `asr.getStatus/transcribe` — ASR 状态查询和转写
- VoiceDictionaryPage UI（词典管理 + ASR 状态 + AI 润色测试）
- useVoiceDictionary hook
- Sidebar 新增"语音"导航入口

### Verified
- `npx tsc --noEmit` 编译通过
- `npm run build` 构建通过

## 0.9.0 (2026-05-03) — 区域截图完整接入 Pin Pool

### Added
- `captureService.captureRegionScreenshot(bounds)` — 全屏截图 → nativeImage 裁剪 → SourceItem + PinItem
- `captureService.copyImageToClipboard(imagePath)` — 图片复制到剪贴板
- 6 个区域截图 IPC handler 从空 stub 替换为真实实现：
  - `capture.takeRegionScreenshot` — 截图 + Pin
  - `capture.takeRegionScreenshotCopy` — 截图 + 复制到剪贴板 + Pin
  - `capture.takeRegionScreenshotSave` — 截图 + Pin
  - `capture.takeRegionScreenshotSaveAs` — 截图 + 另存为对话框 + Pin
  - `capture.takeRegionScreenshotPin` — 截图 + Pin
  - `capture.cancelRegionScreenshot` — 取消（保留 stub）

### Verified
- `npx tsc --noEmit` 编译通过

## 0.8.0 (2026-05-03) — Phase 4-8: 全捕获入口拼接到 Pin Pool

### Changed
- **Phase 4: 截图→Pin Pool**：`captureService.captureScreenshot()` 在创建 SourceItem 的同时创建 PinItem（sourceType='screenshot'），截图自动进入 Pin Pool
  - 新增 `captureService.emitPinPoolChanged()` 私有方法
- **Phase 5: AI 预筛**：`prefilterPinItem` 从规则 mock 升级为调用 `realDistiller`（Ollama / OpenAI-compatible）
  - 新增 `'prefilter'` AiOperation 类型 + prompt 模板 + tier 路由 + mock fallback
  - 无可用 provider 或 AI 调用失败时自动降级到规则引擎
- **Phase 6: 语音→Pin Pool**：`CapsuleExpanded.handleVoiceComplete` 改为调用 `voice.createPinFromTranscript`（已有 IPC），语音内容直接进入 Pin Pool
- **Phase 7: 胶囊→Pin Pool**：`CapsuleExpanded` 的文字/链接收集改为调用 `pinPool.createFromText`，截图收集通过 Phase 4 的修复自动生效
- **Phase 8: 文件导入→Pin Pool**：`importQueue.executeImport` 在创建 SourceItem 的同时创建 PinItem（sourceType='file'/'pdf'/'docx'），导入文件自动进入 Pin Pool

### Verified
- `npx tsc --noEmit` 编译通过
- 所有捕获入口（手动文本、剪贴板、截图、语音、胶囊文字/链接/截图、文件导入）均通过 Pin Pool 管线

## 0.7.0 (2026-05-03) — Phase 3: Promote to Inbox + Markdown Export 闭环

### Added
- **`createSourceItemFromPinItem`**：storage 新增方法，支持从无 `captureItemId` 的 PinItem 直接创建 SourceItem
  - 内容写入 `sources/YYYY-MM-DD/pin-bridge/` 目录
  - 自动生成 contentHash，支持去重
  - 保留 PinItem 的 title、tags、previewText

### Fixed
- **`promoteToInbox` 修复**：Phase 1/2 创建的 PinItem（`captureItemId=''`）现在可以正确 promote 到 Inbox
  - 有 `captureItemId` 时走原有 `createSourceItemFromCaptureItem` 路径
  - 无 `captureItemId` 时走新的 `createSourceItemFromPinItem` 路径
- 版本号 0.6.0 → 0.7.0

### Verified
- Distill → Review → Export 全链路已存在且可复用（来自 AcMind 底座）
- `distill.run` / `distill.runSingle` / `distilledOutputs.review` / `export.single` IPC 均完整

## 0.6.0 (2026-05-03) — Phase 2: 剪贴板文本自动进入 Pin Pool

### Added
- **剪贴板→Pin Pool 自动入池**：后台剪贴板监听的文本/图片内容自动创建 PinItem（status=pinned）
  - 不再经过 Capture Inbox / SourceItem，直接进入 Pin Pool
  - 图片类型标记为 `clipboard_image`，文本标记为 `clipboard_text`
- **内容级去重**：通过 `original_id`（SHA-256 哈希）检测重复内容，已存在的 PinItem 不会重复创建
  - 新增 `storage.getPinItemByOriginalId()` 方法
- **`ignoreNextCopy` 真实实现**：`ClipboardWatcher.ignoreNextCopy(count)` 跳过下 N 次剪贴板变化
  - 用于截图取色器等场景，避免应用自身写入剪贴板时触发捕获
- **暂停/恢复收集**：`clipboard.pause()` / `clipboard.resume()` 临时暂停剪贴板捕获
  - 暂停期间仍更新哈希状态，恢复后不会重新捕获旧内容
  - 新增 IPC 通道：`clipboard.pause`、`clipboard.resume`、`clipboard.isPaused`
- **Preload API 增强**：`window.acmind.clipboard` 新增 `pause()`、`resume()`、`isPaused()` 方法

### Changed
- `captureService.init()` 现在同时检查 `autoCapture` 和 `backgroundClipboard` 设置
- 版本号 0.5.0 → 0.6.0

## 0.5.0 (2026-05-03) — Phase 1: Pin Pool 单条闭环

### Added
- **手动输入→Pin Pool 直接入口**：Quick Desk 左侧面板新增文本输入框 + "Pin 住"按钮
  - 支持 Cmd/Ctrl+Enter 快捷键提交
  - 输入内容直接创建 PinItem（status=pinned），无需经过 Capture Inbox
- **Pin Pool 删除功能**：右侧面板新增"删除"按钮，支持软删除（status→deleted）
- **`createFromText` IPC 通道**：新增 `pinPool.createFromText` 通道，支持纯文本直接创建 PinItem
- **`excludeStatuses` 过滤**：`PinItemListFilter` 新增 `excludeStatuses` 字段
- **`usePinPool` hook 增强**：新增 `createFromText` 和 `deletePin` 方法

### Changed
- `getPinItems` 默认排除 `deleted` 和 `ignored` 状态的 PinItem（除非显式指定 status）
- Quick Desk 左侧面板从"Voice Pin"改为通用"手动输入"入口
- 版本号 0.4.0 → 0.5.0

## 0.4.0 (2026-05-01) — Phase 11

### Added
- **今日知识流首页** (`/daily-flow`)：用户每天打开 AcMind 的第一个页面
  - 顶部 4 统计卡：今日收集 / 已整理 / 已进入 Obsidian / 需要处理
  - 今日知识流列表：每条显示标题、来源类型、用户可读状态、摘要、时间、主操作
  - 筛选标签：全部 / 已进入 Obsidian / 需要处理 / 等待处理 / 语音 / 网页 / 文件
  - 关键词搜索：标题、摘要、标签、来源类型、输出路径
  - 需要处理区：聚合失败和等待内容，用户可读错误文案
  - 最近进入 Obsidian 区：最近 10 条成功输出，支持打开文件和在 Finder 中显示
  - 本周回顾区：本周收集/写入统计、来源类型分布、高频标签、高价值内容推荐
  - 完整空状态设计（无收集/无失败/无输出/无本周数据）
- **状态映射**：内部状态 → 用户可读中文文案，不暴露工程概念
- **来源类型映射**：text/clipboard/url/screenshot/file/pdf/audio/voice/video → 中文标签
- **高价值内容规则**：基于 quality_flags / tags / 标题长度判断，不做模型推荐
  - UI 明确标注"规则推荐"标签，避免被误认为模型结果
- **主操作接入真实业务逻辑**：打开 Obsidian 文件 / 重试整理 / 查看详情 / 查看录音 / 忽略错误
- **数据口径映射文档**：CaptureRecord→CaptureItem / OutputHistory→ExportRecord / ErrorLog→ErrorRecord
- Sidebar 新增"今日"导航项（置顶）

### Changed
- 默认首页从 `capture-inbox` 改为 `daily-flow`
- onboarding 完成后导航到 `daily-flow`
- 版本号 0.3.0 → 0.4.0

## 0.3.0 (2026-05-01) — Phase 10

### Added
- 语音输入与录音工作流产品化
- VoiceWatchService / AudioTranscriptionService
- 语音设置面板

## 0.2.2 (2026-04-29)

### Added
- EditPage 审阅页产品化
- 导出 false-success 修复
- 真闭环修复（三轮）
