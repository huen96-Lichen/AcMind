# PinMind 合并评估资料包

> 扫描根目录：`/Volumes/White Atlas/03_Projects/PinMindV2.0`  
> 扫描方式：只读代码扫描 + `npm run typecheck`  
> typecheck：通过，`tsc --noEmit` 退出码 0  
> 注意：当前 git 工作区已有大量既有变更，本报告未修改源码。

## 一、项目基础信息

| 项 | 内容 |
|---|---|
| 项目名称 | PinMind |
| 当前版本号 | `0.4.0`，见 `package.json` |
| 技术栈 | Electron 35、React 18、TypeScript、Vite、TailwindCSS、better-sqlite3、node-cron、pdf-parse、mammoth、jsdom/readability、electron-updater |
| 启动方式 | `npm run dev` 并行启动 Vite、esbuild main/preload、electronmon |
| 打包方式 | `npm run package:mac:arm64` 或 `npm run package:local`，electron-builder DMG |
| 主进程入口 | `src/main/index.ts`，构建到 `dist/main/index.cjs` |
| 渲染进程入口 | `src/renderer/main.tsx` + `src/renderer/App.tsx` |
| preload 入口 | `src/preload/index.ts`，暴露 `window.pinmind` |
| 路由 / 页面结构 | query 参数 `view`：`daily-flow` 默认首页，`capture-inbox`、`distill`、`export`、`import`、`settings`、`capture`、`capsule`、`edit`、`search`、`errors`、`history`、`ai`；`dashboard` 已重定向到 `DailyKnowledgeFlowPage` |
| 主要目录结构 | `src/main/services/capture` 统一采集适配器；`distiller` AI 蒸馏；`exporter` Obsidian/Markdown；`parser` PDF/DOCX/Web；`pipeline` 内容状态机；`strategy` source_type 策略；`vaultkeeper` 外部处理；`renderer/pages` 主页面；`renderer/design-system` tokens/组件；`shared/types.ts` 核心类型 |
| 文档 | 有 `README.md`、`CHANGELOG.md`、`docs/ARCHITECTURE.md`、`docs/DEVELOPMENT.md`、`docs/archive/WORKLOG.md`、`docs/archive/PROJECT_HANDOVER.md`、`docs/PinMind_规范准则_v1/*`、`docs/pinmind_output_spec_pack/*` |

## 二、产品定位与当前主线

1. 当前主要解决的问题：把剪贴板、手动输入、截图、网页、文件、音频等来源收集成统一 Capture/Source，再通过 AI 蒸馏生成可审阅、可导出的 Markdown/Obsidian 知识对象。
2. 默认主流程：启动 → 进入 `daily-flow` → Capture Inbox 收集 → Distill 整理 → Edit 审阅 → Export 入库 Obsidian/本地 vault → Search/History/Error 回看。
3. 核心页面 / 功能：DailyKnowledgeFlow、CaptureInbox、Distill、Edit、Export、Import、Settings、AIPage。
4. 已形成闭环：手动文本/剪贴板文本 CaptureItem、SourceItem、AI task/mock/real provider 管线、DistilledOutput、Markdown build、Obsidian ExportRecord、SQLite 存储、错误记录、搜索部分。
5. UI / mock / placeholder：截图固定区域相关 IPC 是 stub；PinStack 式悬浮 Pin/launcher 未真实接入；语音入口已有真实 CLI/API 转写代码但环境依赖强，历史文档仍标记过 stub；mockDistiller 会在无 provider 时 fallback；部分页面存在 UI 完整但真实执行依赖外部配置。
6. 当前最像的软件：AI 笔记工具 + 知识库前置处理工具；正在补齐桌面快捷采集能力。

## 三、功能清单与成熟度表

| 功能 | 入口位置 | 涉及文件 | 当前状态 | 是否真实可用 | 是否适合合并进统一产品 | 备注 |
|---|---|---|---|---|---|---|
| 剪贴板监听 / 剪贴板历史 | 后台、CaptureInbox、CapturePage | `src/main/clipboardWatcher.ts`、`src/main/captureService.ts`、`src/main/services/capture/clipboardTextAdapter.ts` | 基本可用 | 是 | 是，作为主模型 | 轮询+hash，写入 SourceItem/CaptureItem；功能不如 PinStack 丰富 |
| 截图 | CapturePage/CaptureInbox | `src/main/captureService.ts`、`src/main/ipc.ts` | 半成品 | 全屏截图可用，区域/固定多为 stub | 是，但需迁 PinStack 实现 | `capture.screenshot` 真实；`capture.takeFixedScreenshot` 返回 false |
| 固定比例截图 | preload 暴露 | `src/preload/index.ts`、`src/main/ipc.ts` | UI 占位/未接入 | 否 | 迁 PinStack | 主进程 stub |
| 悬浮卡片 | capsule UI 概念 | `src/main/capsuleController.ts`、`src/renderer/pages/capsule/*` | 半成品 | 胶囊可用，Pin 卡片无 | 迁 PinStack | 缺 PinWindowManager 等 |
| 桌面小胶囊 / 快捷入口 | Capsule 独立窗口 | `src/main/capsuleController.ts`、`src/renderer/capsule-main.tsx`、`src/renderer/pages/capsule/*` | 基本可用 | 是 | 是 | Electron 透明窗口实现；不如 PinStack Swift Notch 稳 |
| 托盘菜单 | 系统托盘 | `src/main/tray.ts` | 基本可用 | 是 | 是 | toggle/settings/quit 等 |
| 全局快捷键 | 系统快捷键 | `src/main/shortcutManager.ts`、`src/shared/shortcuts.ts` | 基本可用 | 是 | 是 | screenshot/dashboard 快捷键 |
| 音乐控制 / 当前播放状态 / 进度条 | Capsule 设置 | `src/shared/capsuleSettings.ts`、`src/renderer/pages/capsule/*` | UI 占位 | 否 | 迁 PinStack 概念 | 无 MediaRemote 真链路 |
| 手动文本输入 | CaptureInbox / Capsule | `manualTextAdapter.ts`、`CaptureInboxPage.tsx`、`CapsuleExpanded.tsx` | 已闭环 | 是 | 是 | CaptureRecord -> CaptureItem/SourceItem |
| 网页链接保存 | CaptureHub / parser | `webpageAdapter.ts`、`src/main/services/parser/webParser.ts`、`documentImporter.ts` | 基本可用 | 是 | 是 | Readability/jsdom，记录 originalUrl |
| 文件导入 | ImportPage / parser IPC | `src/main/services/parser/*`、`ImportPage.tsx` | 基本可用 | 是 | 是 | PDF/DOCX/Web；普通文件 adapter 也存在 |
| 语音录入 | Capsule VoicePanel | `VoiceCapturePanel.tsx`、`src/renderer/hooks/useRecording.ts` | 半成品 | 部分 | 后期 | UI 完整，录音状态/保存链路需实测 |
| 语音转文字 | Settings/Whisper IPC | `audioTranscriptionService.ts`、`src/main/ipc.ts` Whisper/voice handlers | 半成品 | 环境满足时可用 | 后期 | 支持 whisper-ctranslate2/whisper/API，但依赖本地环境 |
| Inbox / 信息队列 | CaptureInbox | `CaptureInboxPage.tsx`、`CaptureItemCard.tsx`、`CaptureItemDetail.tsx` | 基本可用 | 是 | 是 | 主流程核心 |
| AI 蒸馏 / AI 整理 | DistillPage/Edit/AIPage | `distillPipeline.ts`、`realDistiller.ts`、`mockDistiller.ts`、`tierRouter.ts` | 基本可用但 mock fallback | 是，配置 provider 后更真实 | 是 | 无 provider 会产生 `[Mock]` |
| 编辑页 / 二级整理页 | EditPage | `src/renderer/pages/edit/EditPage.tsx` | 基本可用 | 是 | 是 | 已从 mock 改 IPC 驱动，适合作主流程 |
| Markdown 预览 | Export/Edit | `MarkdownPreview.tsx`、`markdownBuilder.ts` | 基本可用 | 是 | 是 | 输出规范较完整 |
| Obsidian 导出 | ExportPage | `obsidianExporter.ts`、`safeWrite.ts`、`pathResolver.ts` | 已闭环 | 是 | 是 | atomic write、冲突处理、ExportRecord |
| VaultKeeper / 文件解析 | Settings/Advanced/IPC | `services/vaultkeeper/*`、`vaultKeeperAdapter.ts` | 半成品 | 依赖外部端点 | 后期 | HTTP adapter 真实，但默认 disabled |
| AI Console / 模型管理 | AIPage/Settings Providers | `src/renderer/pages/ai/AIPage.tsx`、`settings/components/*`、`modelRegistry.ts` | 半成品 | 部分 | 需要重构 | provider CRUD 有，模型运行依赖配置 |
| 设置页 | SettingsPage | `src/renderer/pages/settings/SettingsPage.tsx` | 基本可用 | 是 | 是 | 配置项多，需合并精简 |
| 设计系统 / tokens / 组件库 | 全局 | `src/renderer/design-system/tokens.ts`、`components/*`、`styles.css` | 基本可用 | 是 | 是，作为主 UI | Warm Focus 更适合统一产品 |
| 本地存储 | SQLite | `src/main/storage.ts` | 已闭环 | 是 | 是，作为主存储 | schema version 13，表较完整 |
| 日志系统 | 文件日志/错误服务 | `src/main/logger.ts`、`errorService.ts`、`retryService.ts` | 基本可用 | 是 | 是 | 有 error_records/diagnostics |
| 错误提示 / toast / 空状态 | Shared UI | `ToastViewport.tsx`、`ErrorBoundary.tsx`、`EmptyState.tsx`、`ErrorReviewPage.tsx` | 基本可用 | 是 | 是 | 比 PinStack 更贴近知识流 |
| 版本展示与文档同步 | app.version IPC/docs | `src/main/ipc.ts`、`CHANGELOG.md`、`docs/*` | 基本可用 | 是 | 是 | 文档体系完整 |

## 四、数据模型与存储结构

核心数据对象：

| 对象 | 路径 | 简要结构 / 状态 |
|---|---|---|
| `SourceItem` | `src/shared/types.ts` | `id/captureItemId/type/source/contentPath/contentHash/previewText/ocrText/sourceApp/originalUrl/createdAt/status/title/tags/vaultImportPath/originalId/metadata` |
| `CaptureRecord` | `src/shared/types.ts` | `original_id/source_type/raw_content/raw_file_path/source_url/preview_text/metadata/status/created_at` |
| `CaptureItem` | `src/shared/types.ts` | `id/title/sourceType/status/previewText/rawText/rawFilePath/sourceUrl/tags/createdAt/updatedAt/metadata` |
| `AiTask` | `src/shared/types.ts` | `sourceItemId/tier/operation/status/provider/model/input/output/error/timestamps` |
| `DistilledOutput` | `src/shared/types.ts` | `suggestedTitle/summary/category/tags/documentType/contentMarkdown/valueScore/cleanSuggestion/reviewStatus` |
| `ExportRecord` | `src/shared/types.ts` | `sourceItemId/distilledOutputId/knowledgeCardId/vaultPath/relativeFilePath/frontmatter/exportedAt/status/conflictResolution/error` |
| `KnowledgeCard/KnowledgeEdge` | `src/shared/types.ts` | 已有卡片和关系结构 |
| `ProviderConfig/VaultConfig/AppSettings` | `src/shared/types.ts` | AI provider、Obsidian vault、全局偏好 |

内容类型表示：

| 内容类型 | 表示方式 |
|---|---|
| manual_text | `source_type='manual_text'`，adapter：`manualTextAdapter.ts` |
| clipboard_text | `source_type='clipboard_text'`，adapter：`clipboardTextAdapter.ts` |
| screenshot | `source_type='screenshot'`，adapter：`screenshotAdapter.ts`；全屏真实，区域能力缺 |
| webpage | `source_type='webpage'`，`source_url/originalUrl`，Readability parser |
| audio | `source_type='audio'`，`raw_file_path`，transcription status |
| video | `source_type='video'`，adapter 存在，处理策略存在 |
| file | `source_type='file' / unknown_file`，fileAdapter/strategy |
| pdf | parser 和 pdfStrategy |
| docx | parser 和 docxStrategy |

状态流转：

| 层 | 状态 |
|---|---|
| `SourceItem.status` | `inbox -> distilling -> distilled -> exported -> archived` |
| `CaptureItemStatus` | `pending/distilling/archived/ignored/failed/transcribing/transcribed` |
| `AiTaskStatus` | `queued/running/done/failed/cancelled` |
| `DistilledOutput.reviewStatus` | `pending/accepted/edited/rejected` |
| `ExportRecord.status` | `success/conflict/failed` |
| `content_state_history` | 记录状态流转历史 |

存储位置：

| 存储 | 状态 |
|---|---|
| SQLite | 主存储，`better-sqlite3`，`src/main/storage.ts` schema version 13 |
| 文件系统 | source 内容文件、导出 Markdown、日志、诊断包 |
| localStorage | 很少，主要 UI 局部行为 |
| Obsidian vault | 真实导出目标 |
| iCloud | 默认文档根与 Obsidian 兼容路径可指向 iCloud，但不是强依赖 |

关键 SQLite 表：`source_items`、`ai_tasks`、`distilled_outputs`、`knowledge_cards`、`knowledge_edges`、`review_events`、`training_examples`、`dataset_snapshots`、`training_runs`、`eval_runs`、`model_versions`、`export_records`、`import_tasks`、`capture_items`、`provider_configs`、`vault_config`、`content_state_history`、`error_records`。

存储层判断：适合作为合并后的主存储。需要做的是把 PinStack `RecordItem` 迁移/映射成 PinMind `CaptureItem + SourceItem`，而不是反向迁 PinMind 到 JSONL。

## 五、AI 能力与模型接入

| 项 | 判断 |
|---|---|
| AI Provider 抽象 | 有，`ProviderConfig` + `tierRouter` + `realDistiller` |
| 本地模型 | 有，Ollama provider，`realDistiller.callOllama` |
| 云端模型 | 有，OpenAI-compatible provider |
| mock provider | 有，`mockDistiller.ts`，无 provider 时 fallback |
| 模型注册表 | 有，`src/shared/ai/modelRegistry.ts` |
| prompt profile | 有，`services/strategy/promptProfile.ts`、OutputSpec distill template |
| AI 蒸馏 pipeline | 有，`distillPipeline.ts` + `taskQueue.ts` + `batchProcessor.ts` |
| 错误回退 | 有 retry、errorService、mock fallback；但 mock 需要 UI 明确标注 |
| 任务队列 | 有，`src/main/services/aiHub/taskQueue.ts` |
| 日志 | 有 `logger.ts`、`error_records`、diagnostics export |
| source_type 策略 | 有，`services/strategy/strategies/*` 覆盖 manual/clipboard/screenshot/webpage/audio/video/file/pdf/docx |
| UI 消费 AI 结果 | 是，Distill/Edit/Export 消费 `DistilledOutput` |
| Markdown 导出 | 是，`markdownBuilder.ts`、`obsidianExporter.ts` |

迁移判断：AI/输出/存储主线应直接保留 PinMind。需要重构的是 provider 配置 UX、mock 提示、截图/语音 source 的真实采集接入。

## 六、UI / 设计系统扫描

1. 设计 tokens：有 `src/renderer/design-system/tokens.ts` 和 CSS variables。
2. 统一组件库：有 `design-system/components`、shared `EmptyState/ErrorBoundary/ToastViewport/ScrollContainer`。
3. Tailwind / CSS variables：两者都有，Warm Focus 变量较系统。
4. 主界面风格：Warm Focus、知识流、浅色生产力工作台。
5. 已成熟页面：DailyKnowledgeFlow、CaptureInbox、Distill、Edit、Export、Settings。
6. 风格割裂：Capsule 的桌面工具风、旧 CapturePage、部分 Advanced settings 与主线不完全一致。
7. 浅色 / 深色：`themeMode` 有设置，实际深色完整性需继续核验。
8. 重复组件：MarkdownPreview、状态 Badge、provider card、empty/error 状态有重复风险。
9. 老样式 / 临时样式：DashboardPage 已废弃，distillation-workbench 旧目录被删除但历史残留文档存在。
10. 是否适合统一 Acore/PinMind 风格：适合，建议作为合并后主 UI。

值得保留：AppShell、Sidebar、DailyKnowledgeFlow、CaptureInbox、DistillReviewPanel、EditPage、Export/VaultConfig、ErrorReview/ProcessingHistory、tokens。  
建议重写：Capsule 外观与 PinStack Notch 融合、截图 Hub、快捷入口、音乐状态模块。  
建议废弃：Dashboard 旧概念、未接入 screenshot fixed/region stub、语音 UI 的不可用状态暴露。

## 七、进程能力与系统权限

| 能力 | 文件 / 状态 |
|---|---|
| 主进程能力 | SQLite、剪贴板监听、全屏截图、托盘、快捷键、胶囊窗口、文件导入/解析、AI provider、导出、调度、错误诊断 |
| IPC 通道 | `src/shared/types.ts` 的 `IPC_CHANNELS` + `src/main/ipc.ts` 大量 `safeHandle` |
| 渲染调用方式 | `window.pinmind`，`src/preload/index.ts` 使用 `contextBridge` |
| 截图权限 | `captureService.ts` 使用 `systemPreferences.getMediaAccessStatus('screen')` + `/usr/sbin/screencapture` |
| 麦克风权限 | 没看到完整 macOS 麦克风权限协调；语音主要走浏览器/文件/API/CLI |
| 文件系统权限 | 选择目录、打开路径、读图片、导出 Markdown、解析文件；暴露面较大 |
| 剪贴板权限 | Electron `clipboard` 轮询 |
| 托盘能力 | `src/main/tray.ts` |
| 全局快捷键 | `src/main/shortcutManager.ts` |
| 悬浮窗 | `capsuleController.ts` 透明 always-on-top；无 PinStack 式多 Pin 卡片 |
| 多窗口管理 | Dashboard 主窗口 + capsule 独立窗口；截图/Pin 多窗口能力弱 |
| 安全风险 | 主窗口 `contextIsolation:true/nodeIntegration:false` 较好；`sandbox:false`；preload API 面很大；`app.openPath(filePath)`、`sourceItems.readImage(filePath)`、workspace open/test、parser import arbitrary path 需要权限约束 |

## 八、重叠能力对比占位

详见第三份 `PinStack_PinMind_合并对比总报告.md`。

## 九、合并风险清单

| 风险 | 严重程度 | 触发原因 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| 截图 stub 被误当真实 | 高 | region/fixed screenshot IPC stub | `src/main/ipc.ts` | 第一期用 PinStack CaptureController 替换 |
| mock AI 被误用 | 高 | 无 provider 时 `mockDistiller` fallback | `mockDistiller.ts`、`tierRouter.ts` | UI 强提示或禁用导出 mock |
| source_type 与 legacy SourceItem 双轨 | 中 | `SourceItem.source` 与 `CaptureRecord.source_type` 并存 | `shared/types.ts` | 统一以 `source_type` 为新主键 |
| 语音能力可用性不稳定 | 中 | 依赖 whisper CLI/API/本地模型 | `audioTranscriptionService.ts` | 后期灰度，先隐藏高级入口 |
| IPC 暴露过多 | 中 | preload 集中暴露大量任意路径相关 API | `preload/index.ts` | 合并时按功能收窄 |
| UI 入口过多 | 中 | daily-flow/capture/distill/edit/export/import/settings/ai/history/errors | `App.tsx` | 合并后第一期收敛到 4 个主入口 |
| 外部服务边界不清 | 中 | VaultKeeper adapter 与本地 parser 并存 | `services/vaultkeeper/*`、`parser/*` | 标为可选插件，不进入一期主线 |

## 十、Codex 初步合并建议

1. 建议合并成一个软件。
2. 如果合并，建议以 PinMind 为主仓库。
3. 应从 PinStack 迁入：截图/固定比例/区域截图完整链路、CaptureHub/Launcher、PinWindowManager、剪贴板去重和 ignoreNextCopy、托盘快捷模式、Swift Notch/Capsule 后期方案。
4. 只保留概念不迁代码：PinStack AI Hub、Obsidian 简单导出、JSONL Dashboard 素材库、VaultKeeper 页面。
5. 应废弃：PinMind 截图 stub、未接入的音乐 UI、旧 Dashboard 概念、隐藏但不可用的语音入口。
6. 合并后的推荐产品结构：`Capture Layer` 采集系统能力；`Inbox Layer` 统一 CaptureItem/SourceItem；`Distill Layer` AI/策略；`Review Layer` Edit；`Export Layer` Markdown/Obsidian；`Desktop Layer` tray/shortcut/capsule/pin。
7. 推荐分四期：一期采集能力；二期桌面入口/Pin；三期语音/文件增强；四期 AI Console/模型治理。
8. 第一期最小可行合并范围：保持 PinMind UI/SQLite/AI/Export，迁 PinStack 截图、剪贴板增强、托盘快捷键；所有新输入写入 CaptureItem/SourceItem。
9. 需要 ChatGPT 决策：产品主流程是否默认展示桌面入口；截图后默认入 Inbox 还是直接 Pin；mock 结果是否允许导出。
10. 需要 Trae 执行：具体迁移实现、IPC namespace、样式适配、权限打包。
11. 需要 Codex 继续核验：迁移后 typecheck/build、截图真实 smoke test、剪贴板重复捕获、导出 lineage、mock 防误用。
