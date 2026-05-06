# AcMind 项目完整功能清单

> **项目名称**: AcMind (v0.10.0)
> **定位**: Local-first AI Memory Distiller — 将碎片化信息蒸馏为结构化知识，导出到 Obsidian Vault
> **技术栈**: Electron 35 + React 18 + TypeScript + Vite + Tailwind CSS + better-sqlite3

---

## 一、Capsule 悬浮胶囊

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 胶囊窗口创建与管理 | 透明、无边框、alwaysOnTop 的独立 BrowserWindow，支持 show/hide/toggle/expand/collapse/destroy | `src/main/capsuleController.ts` |
| 胶囊状态机 | 11 种状态: hidden_disabled, visible_idle, visible_has_content, edge_hidden, edge_peek, expanded, recording_voice, capturing_screen, saving, success, error | `src/shared/capsuleSettings.ts` |
| 折叠态 (Collapsed) | 灯泡图标 + "AcMind" 文字 + 待处理数量 badge + 状态颜色变化(录音/截图/成功/错误) | `src/renderer/pages/capsule/CapsuleCollapsed.tsx` |
| 展开态 (Expanded) | 360px 宽面板，包含 4 种采集模式(文字/链接/截图/语音)、输入区、操作按钮 | `src/renderer/pages/capsule/CapsuleExpanded.tsx` |
| 边缘隐藏态 (Edge Hidden) | 拖到屏幕边缘后自动隐藏，仅露出 6px 窄条，鼠标悬停 peek 显示图标和名称 | `src/renderer/pages/capsule/CapsuleEdgeHidden.tsx` |
| 胶囊拖拽 | 自定义拖拽实现(movable=false, 通过 IPC capsule:start-drag/drag-move/end-drag + setBounds)，支持记住最后位置 | `src/main/capsuleController.ts`, `src/renderer/pages/capsule/CapsuleCollapsed.tsx` |
| 自动吸附到边缘 | 拖拽释放时检测距屏幕边缘 < 20px 自动 dock(left/right/bottom)，设置 edgeVisibleWidth | `src/main/capsuleController.ts` |
| 点击/双击交互 | 单击展开面板，双击快速截图(200ms 判定)，可配置 clickAction/doubleClickAction | `src/renderer/pages/capsule/CapsuleCollapsed.tsx`, `src/shared/capsuleSettings.ts` |
| 失焦自动折叠 | 点击胶囊外部自动折叠回 collapsed 态(autoCollapseOnBlur 配置项) | `src/main/capsuleController.ts` |
| 胶囊外观设置 | 6 种主题色(orange/green/blue/gray/purple/rose)、4 种样式(capsule/circle/outline/glass)、3 种尺寸(small/medium/large)、透明度、暗色模式适配 | `src/shared/capsuleSettings.ts` |
| 胶囊位置设置 | 5 种默认位置(right-center/right-bottom/left-center/left-bottom/bottom-center) + remember-last | `src/shared/capsuleSettings.ts` |
| 胶囊快捷键 | toggleCapsule(Cmd+Shift+P), quickText, quickScreenshot, voiceInput, clipboardCapture | `src/shared/capsuleSettings.ts` |
| 胶囊专用 HTML | 独立的 capsule.html + capsule-main.tsx，不加载全局 styles.css，确保透明背景 | `src/renderer/capsule.html`, `src/renderer/capsule-main.tsx` |

---

## 二、内容采集 (Capture)

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 文字采集 | 在胶囊展开面板中输入文字，保存到 Inbox | `src/renderer/pages/capsule/CapsuleExpanded.tsx` |
| 链接/网页采集 | 输入 URL 保存到 Inbox，后续通过 Readability 解析网页正文 | `src/renderer/pages/capsule/CapsuleExpanded.tsx`, `src/main/services/capture/webpageAdapter.ts` |
| 截图采集 | 全屏截图，支持选区截图和标注 | `src/renderer/pages/capture/CapturePage.tsx`, `src/renderer/CaptureOverlay.tsx`, `src/renderer/components/capture/AnnotationCanvas.tsx` |
| 语音采集 | 浏览器 MediaRecorder 录音 → 主进程转写(ASR) → 文本保存 | `src/renderer/pages/capsule/VoiceCapturePanel.tsx`, `src/main/services/capture/audioTranscriptionService.ts` |
| 剪贴板监控 | 轮询剪贴板(500ms)，自动捕获文本/图片变化，去重(hash)，记录来源应用 | `src/main/clipboardWatcher.ts`, `src/main/sourceApp.ts` |
| 文件导入 | PDF/DOCX/HTML/TXT/MD 等文件解析为 Markdown | `src/main/services/parser/documentImporter.ts`, `src/main/services/parser/pdfParser.ts`, `src/main/services/parser/docxParser.ts`, `src/main/services/parser/webParser.ts` |
| 采集适配器注册表 | 统一的 CaptureInput/CaptureOutput 接口，注册各类型适配器(text/image/audio/screenshot/video/webpage/file/clipboard/manual) | `src/main/services/capture/captureRegistry.ts`, `src/main/services/capture/index.ts` |
| CaptureService | 采集服务总入口，管理剪贴板监控启动、截图流程、语音监听 | `src/main/captureService.ts` |
| 手动文本输入 | 手动输入文字想法/笔记 | `src/main/services/capture/manualTextAdapter.ts` |
| 图片采集 | 单独的图片文件采集适配器 | `src/main/services/capture/imageAdapter.ts` |
| 音频采集 | 音频文件导入与采集 | `src/main/services/capture/audioAdapter.ts` |
| 视频采集 | 视频文件导入与采集 | `src/main/services/capture/videoAdapter.ts` |
| Capture Inbox (收集箱) | 采集内容的临时收件箱，支持查看/编辑/删除 | `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx` |
| 区域截图选择 | 支持自由/固定/区域/比例截图模式 | `src/renderer/captureSelection.ts` |
| Capture Launcher | 截图启动器（悬浮按钮） | `src/renderer/CaptureLauncher.tsx` |
| Capture Hub | 截图中心面板 | `src/renderer/CaptureHub.tsx` |
| 截图快照 | 截图后即时预览 | `src/renderer/captureSnap.ts` |
| 截图标注画布 | 对截图进行标注/绘制 | `src/renderer/components/capture/AnnotationCanvas.tsx` |

---

## 三、拖拽功能

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 胶囊拖拽移动 | 自定义拖拽实现，通过 IPC 通信控制窗口位置，支持位置记忆 | `src/main/capsuleController.ts`, `src/renderer/pages/capsule/CapsuleCollapsed.tsx` |
| 胶囊面板拖放收集 | 展开面板支持拖入文件(到 Shelf)、URL(到 Inbox)、文本(到 Inbox)，有拖放覆盖层视觉反馈 | `src/renderer/pages/capsule/CapsuleExpanded.tsx` |
| 文件转换器拖放 | FileConverterPage 支持拖放文件到页面进行格式转换 | `src/renderer/pages/file-converter/FileConverterPage.tsx` |
| 贴图浮窗拖拽 | PinnedImage 窗口可拖拽移动 | `src/main/pinnedImageController.ts` |

---

## 四、文件中转站 / Shelf

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| Shelf 文件暂存 | 文件暂存区，支持拖拽/剪贴板/采集/手动四种来源，文件列表展示 | `src/renderer/pages/shelf/ShelfPage.tsx` |
| Shelf 文件添加 | 通过拖放或 API 添加文件到 Shelf | `src/renderer/hooks/useShelfItems.ts` |

---

## 五、Pin Pool / Quick Desk

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| Pin Pool | 快速 Pin 住灵感/想法，支持创建、预筛选、提升到 Inbox、忽略、删除 | `src/renderer/pages/quick-desk/QuickDeskPage.tsx`, `src/renderer/hooks/usePinPool.ts` |
| 语音 Pin | 语音转写后直接创建 Pin | `src/renderer/pages/capsule/VoiceCapturePanel.tsx` |

---

## 六、贴图浮窗 (Pinned Image)

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 截图贴图 | 将截图钉到桌面，独立 alwaysOnTop 窗口，可拖拽移动 | `src/main/pinnedImageController.ts`, `src/renderer/pages/pinned-image/PinnedImageView.tsx` |
| 贴图操作 | 关闭贴图、保存到 Inbox、复制到剪贴板 | `src/main/pinnedImageController.ts` |
| 贴图专用窗口 | 独立的 pinned-image-main.tsx 入口 | `src/renderer/pinned-image-main.tsx` |

---

## 七、OCR 文字识别

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| macOS Vision OCR | 使用 macOS Vision Framework (Swift CLI) 本地提取图片文字，不调用云端 API | `src/main/ocrService.ts`, `scripts/vision_ocr.swift` |
| OCR 保存到 Inbox | 截图 OCR 结果可直接保存到 Inbox | `src/renderer/pages/capture/CapturePage.tsx` |

---

## 八、AI 蒸馏系统

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| AI Provider 服务 | 统一 AI 调用层，支持 Ollama(本地) 和 OpenAI-compatible(云端) 两种 provider | `src/main/services/aiHub/aiProviderService.ts` |
| 蒸馏管线 (DistillPipeline) | 编排任务创建、队列、执行和结果存储，支持真实 AI + mock 两种模式 | `src/main/services/distiller/distillPipeline.ts` |
| 分层路由 (TierRouter) | 根据内容类型和复杂度自动选择本地/云端模型 | `src/main/services/distiller/tierRouter.ts` |
| 真实蒸馏器 (RealDistiller) | 调用 AI Provider 执行蒸馏，返回结构化结果 | `src/main/services/distiller/realDistiller.ts` |
| 批量蒸馏 (BatchProcessor) | 支持批量蒸馏多个 SourceItem | `src/main/services/distiller/batchProcessor.ts` |
| 蒸馏 Prompt 管理 | 各内容类型的蒸馏提示词模板 | `src/main/services/distiller/distillPrompts.ts` |
| 策略系统 (Strategy) | 按 source_type 选择处理策略(12 种: audio/clipboardText/docx/file/image/manualText/pdf/screenshot/unknownFile/video/webpage) | `src/main/services/strategy/strategyProcessor.ts`, `src/main/services/strategy/strategies/` |
| Prompt Profile | 按策略构建 Prompt | `src/main/services/strategy/promptProfile.ts` |
| Model Router | 模型路由选择(本地/云端/自定义) | `src/main/services/strategy/modelRouter.ts` |
| 输出校验 (OutputValidator) | 校验 AI 输出质量 | `src/main/services/strategy/outputValidator.ts` |
| 质量兜底 (QualityFallback) | 低质量结果自动降级处理 | `src/main/services/strategy/qualityFallback.ts` |
| AI 任务队列 | 异步任务队列管理 | `src/main/services/aiHub/taskQueue.ts` |
| AI Action Runner | AI 操作执行器 | `src/main/services/aiHub/aiActionRunner.ts` |
| 模型注册表 | 预定义模型信息 | `src/shared/ai/modelRegistry.ts` |
| 蒸馏工作台 | 批量蒸馏面板 UI，含蒸馏结果卡片和审核面板 | `src/renderer/pages/distill/DistillationWorkbench.tsx`, `src/renderer/components/distill/DistillBatchPanel.tsx`, `src/renderer/components/distill/DistillReviewPanel.tsx` |
| 蒸馏页面 | 单条蒸馏操作 UI | `src/renderer/pages/distill/DistillPage.tsx` |
| AI 密钥存储 | 安全存储 AI API 密钥 | `src/main/services/aiHub/secretStore.ts` |
| AI 页面 | AI 配置与任务管理界面 | `src/renderer/pages/ai/AIPage.tsx` |

---

## 九、内容管线 (Content Pipeline)

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 内容管线服务 | 端到端编排: 采集 → 策略处理 → AI 蒸馏 → Markdown 生成 → Obsidian 写入 | `src/main/services/pipeline/contentPipelineService.ts` |
| 内容状态机 | 追踪内容生命周期状态和去重 | `src/main/services/pipeline/contentStateMachine.ts` |

---

## 十、Obsidian 导出

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| Obsidian 导出器 | 生成带 Frontmatter 的 Markdown，原子写入(temp+rename)，original_id 去重，Vault 路径校验 | `src/main/services/exporter/obsidianExporter.ts` |
| Markdown 构建 | 从蒸馏结果构建标准 Markdown 文档 | `src/main/services/exporter/markdownBuilder.ts` |
| Frontmatter 生成 | 构建 YAML Frontmatter (AcMind 标准字段) | `src/main/services/exporter/frontmatter.ts`, `src/main/services/exporter/standardFields.ts` |
| 路径解析 | 根据 Vault 配置解析输出文件路径 | `src/main/services/exporter/pathResolver.ts` |
| 冲突处理 | 文件名冲突策略(跳过/覆盖/重命名) | `src/main/services/exporter/conflictHandler.ts` |
| 安全写入 | 原子写入 + Vault 路径验证 | `src/main/services/exporter/safeWrite.ts` |
| 导出规范 (OutputSpec) | AcMind 标准 Frontmatter 字段规范和校验 | `src/main/services/outputSpec/outputSpecService.ts`, `src/shared/outputSpec.ts` |
| 导出页面 UI | Vault 配置、导出操作、导出历史、Markdown 预览 | `src/renderer/pages/export/ExportPage.tsx`, `src/renderer/components/export/VaultConfigPanel.tsx`, `src/renderer/components/export/ExportHistory.tsx`, `src/renderer/components/export/MarkdownPreview.tsx` |

---

## 十一、Vault 导入

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| Vault 扫描 | 扫描 Obsidian Vault 中的 Markdown 文件 | `src/main/services/importer/vaultScanner.ts` |
| Vault 导入队列 | 异步批量导入，支持取消 | `src/main/services/importer/importQueue.ts` |
| Frontmatter 解析 | 解析已有 Markdown 文件的 Frontmatter | `src/main/services/importer/frontmatterParser.ts` |
| 导入页面 UI | 导入历史记录列表，支持筛选和搜索 | `src/renderer/pages/import/ImportPage.tsx` |

---

## 十二、搜索

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 关键词搜索 | SQLite FTS 全文搜索 | `src/main/services/search/keywordSearch.ts` |
| 搜索页面 UI | 搜索输入、结果列表、索引重建 | `src/renderer/pages/search/index.tsx`, `src/renderer/components/search/SearchResultCard.tsx` |
| Vault 搜索 | 在 Obsidian Vault 中搜索关键词 | `src/renderer/hooks/useVaultSearch.ts` |

---

## 十三、语音系统

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 语音录制 | 浏览器 MediaRecorder API 录音 | `src/renderer/pages/capsule/VoiceCapturePanel.tsx`, `src/main/voice/recorder/index.ts` |
| ASR 转写 | 语音转文字(ASR Provider) | `src/main/voice/asr/index.ts` |
| 语音监听服务 | 后台持续监听语音输入 | `src/main/services/capture/voiceWatchService.ts` |
| 语音词典 | 自定义语音转写词典(CRUD) | `src/main/voice/dictionary/index.ts`, `src/renderer/pages/voice/VoiceDictionaryPage.tsx` |
| AI 文本润色 | 本地 Polish 模式优化转写文本 | `src/main/voice/polish/index.ts` |
| Whisper 集成 | 本地 Whisper 模型转写 | `src/renderer/services/whisperService.ts` |
| 音频转写服务 | 音频文件转写处理 | `src/main/services/capture/audioTranscriptionService.ts` |

---

## 十四、剪贴板管理

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 剪贴板历史 | 浏览剪贴板历史记录(文本/URL/图片)，支持筛选 | `src/renderer/pages/clipboard/ClipboardPage.tsx`, `src/renderer/hooks/useClipboardItems.ts` |
| 剪贴板监控 | 后台轮询剪贴板变化，自动捕获新内容 | `src/main/clipboardWatcher.ts` |
| 剪贴板暂停/恢复 | 可暂停剪贴板监听 | IPC: `CLIPBOARD_PAUSE` / `CLIPBOARD_RESUME` |
| 剪贴板搜索 | 搜索剪贴板历史记录 | IPC: `CLIPBOARD_SEARCH_ITEMS` |
| 剪贴板置顶 | Pin 住重要剪贴板条目 | IPC: `CLIPBOARD_PIN_ITEM` / `CLIPBOARD_UNPIN_ITEM` |
| 剪贴板复制 | 从历史中重新复制到剪贴板 | IPC: `CLIPBOARD_COPY_ITEM` |
| 剪贴板清空 | 清空剪贴板历史 | IPC: `CLIPBOARD_CLEAR_HISTORY` |
| 剪贴板保存到 Inbox | 将剪贴板内容送入收集箱 | IPC: `CLIPBOARD_SAVE_TO_INBOX` |
| 来源应用识别 | 识别剪贴板内容来源应用 | `src/main/sourceApp.ts`, `src/main/sourceClassifier.ts` |

---

## 十五、知识管理

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 知识卡片 | 知识卡片列表浏览，支持 KnowledgeEdge 关系 | `src/renderer/pages/knowledge-cards/KnowledgeCardsPage.tsx` |
| 蒸馏笔记 | DistilledNote 列表/详情浏览 | `src/renderer/hooks/useDistilledNotes.ts` |
| 项目空间 | 项目管理(创建/归档/删除)，网格卡片展示 | `src/renderer/pages/projects/ProjectsPage.tsx` |
| 数据集管理 | 数据集 CRUD，支持 fine_tune/rag/evaluation/archive 用途，导出 JSONL/Markdown | `src/renderer/pages/datasets/DatasetsPage.tsx` |
| 审核页面 | 蒸馏结果审核(pending/accepted/rejected) | `src/renderer/pages/review/ReviewPage.tsx` |
| 标签管理 | 标签的合并/重命名/删除 | IPC: `TAGS_MERGE` / `TAGS_RENAME` / `TAGS_DELETE` |
| 标签规范化 | 标签自动规范化处理 | `src/shared/tagNormalizer.ts` |
| 知识图谱 | 知识卡片之间的关系图谱 | IPC: `GRAPH_GET` |

---

## 十六、文件转换器

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 文件转 Markdown | PDF/DOCX/PPTX/HTML/TXT/MD → Markdown 转换，支持拖放和文件选择器 | `src/renderer/pages/file-converter/FileConverterPage.tsx`, `src/renderer/hooks/useFileConverter.ts` |
| MarkItDown 集成 | 调用 markitdown CLI 转换文件 | `src/main/services/parser/markitdownService.ts` |
| 转换预览 | 预览转换后的 Markdown 内容 | `src/renderer/pages/file-converter/FileConverterPage.tsx` |
| 保存到 Inbox | 转换结果直接保存到收集箱 | `src/renderer/pages/file-converter/FileConverterPage.tsx` |

---

## 十七、自动化 / 定时任务

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 定时任务调度 | 基于 node-cron 的定时任务(auto_distill/auto_export/cleanup) | `src/main/services/scheduler/schedulerService.ts` |
| 自动蒸馏 | 定时自动蒸馏收集箱中的内容 | `src/main/services/scheduler/schedulerService.ts` |
| 自动导出 | 定时自动导出到 Obsidian | `src/main/services/scheduler/schedulerService.ts` |
| 自动清理 | 定时清理过期/归档内容 | `src/main/services/scheduler/schedulerService.ts` |
| 自动化页面 UI | 创建/管理定时任务，查看执行历史 | `src/renderer/pages/automation/AutomationPage.tsx` |

---

## 十八、外部处理服务 (VaultKeeper)

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| VaultKeeper 适配器 | 与外部处理服务的 HTTP 通信层，提交任务/查询状态/获取结果/取消任务 | `src/main/services/vaultkeeper/vaultKeeperAdapter.ts` |
| 外部结果回填 | 将外部处理结果导入回 AcMind | `src/main/services/vaultkeeper/externalResultIngestionService.ts` |
| Processing Job 服务 | 管理外部处理任务生命周期 | `src/main/services/vaultkeeper/processingJobService.ts` |
| 健康检查 | 检查外部服务可用性 | IPC: `VK_CHECK_HEALTH` |

---

## 十九、系统功能

| 功能名称 | 描述 | 对应文件路径 |
|---------|------|------------|
| 系统托盘 | macOS 菜单栏图标，右键菜单(打开面板/切换模式/退出) | `src/main/tray.ts` |
| 全局快捷键 | 截图/打开面板/语音输入/采集中心/模式切换等快捷键注册 | `src/main/shortcutManager.ts` |
| 自定义快捷键 | 用户可配置 dashboard 和 screenshot 快捷键，有冲突检测和自动交换机制 | `src/shared/shortcuts.ts` |
| IPC 通信 | 主进程与渲染进程的完整 IPC 通道注册 | `src/main/ipc.ts` |
| Preload 安全桥接 | contextIsolation 安全桥接，暴露 window.acmind API | `src/preload/index.ts` |
| SQLite 存储 | better-sqlite3 WAL 模式本地数据库 | `src/main/storage.ts` |
| 设置管理 | 应用设置加载/保存(Provider/Vault/通用配置) | `src/main/settings.ts`, `src/shared/defaultSettings.ts` |
| 日志系统 | 结构化日志记录 | `src/main/logger.ts` |
| 错误服务 | 错误记录和追踪 | `src/main/errorService.ts` |
| 错误审核页面 | 查看/处理各类错误记录 | `src/renderer/pages/errors/ErrorReviewPage.tsx` |
| 失败反馈 | 处理失败后的用户反馈机制 | `src/main/failureFeedback.ts` |
| 重试服务 | 失败任务自动重试 | `src/main/retryService.ts` |
| 权限管理 | macOS 权限协调(屏幕录制/辅助功能/文件访问等) | `src/main/permissionCoordinator.ts`, `src/main/permissions.ts` |
| 自动更新 | electron-updater 自动更新 | `src/main/autoUpdater.ts` |
| 布置向导 | 首次使用引导(欢迎/权限/模型/知识库/试运行/完成) | `src/renderer/pages/onboarding/OnboardingPage.tsx` |
| 设置页面 | AI Provider 管理、高级控制面板 | `src/renderer/pages/settings/SettingsPage.tsx` |
| 工具集页面 | 各功能模块入口和状态展示 | `src/renderer/pages/utilities/UtilitiesPage.tsx` |
| 每日知识流 | 仪表盘：待处理/已蒸馏/已导出统计 + 最近项目 | `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` |
| Dashboard 工作台 | 今日工作台统计面板 | `src/renderer/pages/dashboard/DashboardPage.tsx` |
| 处理历史 | 查看内容处理历史记录 | `src/renderer/pages/history/ProcessingHistoryPage.tsx` |
| 任务队列页面 | 查看和管理 AI 任务队列 | `src/renderer/pages/task-queue/TaskQueuePage.tsx` |
| 编辑页面 | 内容编辑 | `src/renderer/pages/edit/EditPage.tsx` |
| 仪表盘窗口控制器 | 主窗口管理 | `src/main/dashboardWindowController.ts` |
| 窗口工厂 | 统一创建 BrowserWindow | `src/main/windowFactory.ts` |
| 应用作用域 | 应用生命周期管理 | `src/main/appScope.ts` |
| 遗留内容迁移 | 旧版数据迁移 | `src/main/migrateLegacyContent.ts` |
| 单实例锁 | 防止多实例运行 | `src/main/index.ts` |
| 最小化到托盘 | 关闭窗口时最小化到系统托盘 | `src/main/index.ts` |
| 登录时启动 | 开机自动启动 | `src/shared/types.ts` (launchAtLogin) |
| 文件工具 | 文件类型推断等工具函数 | `src/shared/fileUtils.ts` |
| 设计系统 | UI 基础组件库(primitives) | `src/renderer/design-system/primitives.tsx` |
| Toast 通知 | 全局 Toast 通知系统 | `src/renderer/components/shared/ToastViewport.tsx` |
| 错误边界 | React 错误边界组件 | `src/renderer/components/shared/ErrorBoundary.tsx` |
| 健康检查 | 应用各子系统健康状态检测 | IPC: `HEALTH_CHECK` |
| 诊断导出 | 导出本地诊断信息 | IPC: `DIAGNOSTICS_EXPORT` |
| 训练工具 | AI 蒸馏训练器 CLI | `training/` |
