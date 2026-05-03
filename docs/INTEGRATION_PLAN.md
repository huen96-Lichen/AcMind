# AcMind 整合计划

## 背景

AcMind 正在从 16 个参考项目中吸收能力。这些项目均为作者在课程学习过程中创建的开源项目，AcMind 本身也将以开源形式发布。

**许可证说明**：

16 个参考项目中，大部分为作者本人创建的项目（pinmind-main、pinstack-main、cai-master、NotesBar-master、macshot-main、Atoll-main、boring.notch-main、snow-shot-main、ZTools-main、dodopulse-main、autoclawd-main 等），作者拥有完整版权，可按需直接复用代码。

少数项目为第三方开源项目，需遵守其许可证：
- `markitdown-main`：Microsoft 开源，MIT 许可证
- `openless-main`：OpenLess contributors，MIT 许可证
- `omlx-main`：Apache-2.0 许可证
- `Cent-main`：CC BY-NC-SA 4.0 许可证
- `extensions-main`：Raycast 扩展生态，各扩展许可证需逐项核查

整合遵循以下原则：

- 作者自有项目可按需直接复用代码
- 第三方开源项目需遵守其许可证，在 AcMind 中注明来源
- 只吸收符合 AcMind 主线的能力
- 主线：收集 → 暂存 → 整理 → 确认 → 导出 → 沉淀

---

## 一、资产分级

### P0：直接基线

| 项目 | 角色 | 许可证 | 吸收方式 |
|---|---|---|---|
| pinmind-main | AcMind 直接基线 | 作者自有 | 直接使用 |
| pinstack-main | Capture / Clipboard / Shelf 现成资产 | 作者自有 | 按需直接复用代码 |
| markitdown-main | 多格式转 Markdown 能力 | 第三方开源，Microsoft, MIT | 按 MIT 许可证复用，注明来源 |

### P1：能力参考

| 项目 | 角色 | 许可证 | 吸收方式 |
|---|---|---|---|
| cai-master | AI 能力参考 | 作者自有 | 按需直接复用代码 |
| openless-main | 工具层参考 | 第三方开源，MIT | 按 MIT 许可证复用，保留声明 |
| NotesBar-master | 笔记能力参考 | 作者自有 | 按需直接复用代码 |
| macshot-main | 截图能力参考 | 作者自有 | 按需直接复用代码 |

### P2：能力参考

| 项目 | 角色 | 许可证 | 吸收方式 |
|---|---|---|---|
| Atoll | 能力参考 | 作者自有 | 按需直接复用代码 |
| boring.notch | 能力参考 | 作者自有 | 按需直接复用代码 |
| snow-shot | 能力参考 | 作者自有 | 按需直接复用代码 |
| ZTools | 能力参考 | 作者自有 | 按需直接复用代码 |
| oMLX | 能力参考 | 第三方开源，Apache-2.0 | 按 Apache-2.0 许可证复用 |

### P3：扩展参考

| 项目 | 角色 | 许可证 | 吸收方式 |
|---|---|---|---|
| extensions | 扩展参考 | 第三方，Raycast 扩展生态 | 参考设计模式，各扩展许可证需逐项核查 |
| dodopulse | 扩展参考 | 作者自有 | 按需直接复用代码 |
| Cent | 扩展参考 | 第三方开源，CC BY-NC-SA 4.0 | 参考设计模式，注意非商业 ShareAlike 约束 |
| autoclawd | 扩展参考 | 作者自有 | 按需直接复用代码 |

---

## 二、许可证规则

| 分类 | 项目 | 许可证 | 处理方式 |
|---|---|---|---|
| 作者自有 | pinmind-main, pinstack-main, cai-master, NotesBar-master, macshot-main, Atoll-main, boring.notch-main, snow-shot-main, ZTools-main, dodopulse-main, autoclawd-main | 作者拥有完整版权 | 可按需直接复用代码 |
| 第三方 MIT | markitdown-main | Microsoft, MIT | 按 MIT 许可证复用，注明来源 |
| 第三方 MIT | openless-main | OpenLess contributors, MIT | 按 MIT 许可证复用，保留声明 |
| 第三方 Apache | oMLX-main | Apache-2.0 | 按 Apache-2.0 许可证复用 |
| 第三方 CC | Cent-main | CC BY-NC-SA 4.0 | 参考设计模式，注意非商业 ShareAlike 约束 |
| 第三方生态 | extensions-main | Raycast 扩展生态 | 参考设计模式，各扩展许可证需逐项核查 |

**核心原则**：
- 作者自有项目可按需直接复用代码，AcMind 开源后这些代码自然归属同一作者
- 第三方开源项目需遵守其许可证，在 AcMind 中注明来源
- 对于 CC BY-NC-SA 等有特殊约束的第三方项目，复用时注意许可证要求

---

## 三、Phase 路线

### Phase 0：主工程边界与数据模型 ✅

**目标**：建立 AcMind 的"骨架"

**已完成**：
- 模块目录结构（11 个模块）
- 统一数据对象类型定义（types.ts）
- Storage schema v14（新增 4 张表）
- IPC/API 边界（clipboard.*, shelf.*, aiRuntime.*）
- 架构文档四件套

---

### Phase 0.5：Phase 0 修复轮 ✅

**目标**：修复 Phase 0 的边界、文档和风险项

**已完成**：
- ARCHITECTURE.md 更新为 AcMind 叙事，标注 legacy 命名
- DATA_MODEL.md 补齐新旧映射关系和 Storage 策略，修正 AiOperation 类型描述
- MODULE_BOUNDARIES.md 补齐当前 IPC / 目标 IPC / 允许依赖 / 禁止依赖
- INTEGRATION_PLAN.md 补齐 P2/P3 分级和 Phase 路线，修正许可证描述
- types.ts 补齐 PinItem/PinItemListFilter/Voice*/prefilter 等缺失类型
- IPC_CHANNELS 补齐 PIN_POOL_*/VOICE_* 通道
- storage.ts 补齐 pin_pool_items 表和 insertPinItem/getPinItemByOriginalId 方法
- ipc.ts 补齐 pinPool/voice IPC handlers
- preload 补齐 pinPool/voice 暴露接口
- captureService.ts/importQueue.ts 统一使用 IPC_CHANNELS 常量
- 参考项目源码（临时文件夹/openless-main）已从 AcMind 主工作区移除
- npm run typecheck 通过
- npm run build 通过

---

### Phase 1A：Clipboard 主链路 ✅

**目标**：完成最小可用 Clipboard 闭环

**已完成**：
- ClipboardWatcher 轮询监听 + MD5 去重 + pause/resume
- captureService.handleNewClipboardContent 写入 clipboard_items 表
- storage 层补齐 searchClipboardItems / clearClipboardItems / updateClipboardItemSourceItemId
- IPC 层补齐 searchItems / copyItem / clearHistory / pause / resume / isPaused
- saveToInbox 重写：创建 SourceItem + 关联 ClipboardItem + 防重复
- preload 暴露完整 clipboard.* API（含 onItemsChanged 事件监听）
- ClipboardPage UI：列表、搜索、类型筛选（全部/文本/链接/图片）、卡片操作
- Sidebar 新增「剪贴板」导航入口
- App.tsx 注册 clipboard view 路由
- 隐私策略：不上传、不调用 AI、空内容过滤、MD5 去重、超长文本预览截断
- npm run typecheck 通过
- npm run build 通过

**未纳入 Phase 1A（后置）**：
- Shelf 文件临时架（Phase 1B）
- AI 总结 / 改写 / 翻译（Phase 4）
- Cai 式 AI Action 菜单（Phase 4）
- MarkItDown 文件转换（Phase 3）
- 截图钉图（Phase 2）
- Obsidian 搜索（Phase 5）
- 跨设备同步
- 插件系统
- 复杂片段库
- 密码管理器来源 App 自动忽略（当前文档化预留）

---

### Phase 1B：Shelf 文件临时架 ✅

**目标**：完成最小可用 Shelf 闭环

**已完成**：
- storage 层补齐 updateShelfItemSourceItemId / updateShelfItemLabel
- IPC handlers 重写：addFiles 创建 AssetFile + 事件推送，saveToInbox 创建 SourceItem + 关联 + 防重复
- preload 暴露完整 shelf.* API（含 onItemsChanged 事件监听）
- ShelfPage UI：拖拽文件区、手动添加文本、卡片列表、保存到收集箱、删除
- Shelf → Inbox 保存链路（saveToInbox 创建 SourceItem + 关联 ShelfItem + 状态更新）
- 事件推送（SHELF_ITEMS_CHANGED 通知 renderer 刷新）
- 文件拖拽支持（通过 Electron file.path 获取真实路径）
- Sidebar 新增「Shelf」导航入口
- App.tsx 注册 shelf view 路由
- npm run typecheck 通过
- npm run build 通过

---

### Phase 2A：Capture 截图与贴图 ✅

**目标**：完成最小可用 Capture 闭环

**已完成**：
- types.ts 新增 12 个 capture.* IPC 通道常量
- 新增 PinnedImage / CaptureSnapshot / OcrResult 类型
- SourceItemListFilter 新增 source 字段
- storage.ts getSourceItems 支持 source 过滤
- captureService.ts 新增 listRecentCaptures 方法
- pinnedImageController.ts：贴图浮窗管理器（创建/关闭/保存到Inbox/复制/列表）
- ipc.ts 新增 9 个 capture.* handlers（startAreaCapture/cancelCapture/pinImage/saveToInbox/listRecent/listPinned/closePinned/ocrExtract/ocrSaveToInbox）
- preload 暴露完整 capture.* API（含 onItemsChanged/onPinnedChanged 事件监听）
- CapturePage UI 重写：截图按钮、最近截图列表（缩略图+操作）、已钉图片列表、OCR 按钮
- PinnedImageView：独立 BrowserWindow 贴图渲染（悬浮操作栏：复制/收集箱/关闭）
- pinned-image.html + pinned-image-main.tsx 入口文件
- vite.config.ts 多页面构建配置（main/capsule/pinned-image）
- Sidebar 新增「截图」导航入口
- npm run typecheck 通过
- npm run build 通过

### Phase 2B：Capture OCR 与轻标注 ✅

**目标**：增强 Capture 的信息提取能力

**已完成**：
- ocrService.ts：macOS Vision Framework OCR 服务（Swift CLI 调用，本地处理，不调用云端）
- scripts/vision_ocr.swift：macOS Vision Framework CLI 工具（支持中英文识别）
- ipc.ts 新增 capture.ocrExtract / capture.ocrSaveToInbox handlers
- preload 暴露 ocrExtract / ocrSaveToInbox API
- AnnotationCanvas 组件：轻标注工具（矩形/箭头/文本，Canvas 2D 实现）
- OCR → Inbox 保存链路（ocrSaveToInbox 创建 SourceItem type='text' source='screenshot' ocrText）
- npm run typecheck 通过
- npm run build 通过

---

### Phase 3：MarkItDown 文件转 Markdown ✅

**目标**：补齐多格式文件转 Markdown 能力

**计划**：
- ✅ 接入 markitdown 作为文件转换服务（Python CLI + 内置 fallback）
- ✅ 支持 PDF、DOCX、PPTX、HTML、TXT、MD 格式转 Markdown
- ✅ 独立 File Converter 页面（拖拽 + 文件选择器 + 预览 + 历史）
- ✅ 转换结果可保存到收集箱（Inbox）
- ✅ ProcessJob 独立建表（process_jobs 表，schema v15）
- ✅ fileConverter.* IPC 全链路（convert / getStatus / listJobs / saveToInbox / preview）

**来源项目**：markitdown-main（第三方开源，Microsoft, MIT 许可证，可按需复用）

---

### Phase 4：AI Action Layer ✅

**目标**：完善 AI 动作系统

**计划**：
- ✅ 完善 AIAction 注册和执行机制（CRUD + runAction 真实调用）
- ✅ aiProviderService（Ollama + OpenAI-compatible HTTP 调用层）
- ✅ aiActionRunner（完整管线：strategyProcessor → aiProviderService → outputValidator）
- ✅ preload 桥接（aiRuntime.* 完整 API + onJobChanged 事件）
- ✅ useAI Hook + AIPage 增强（Action 管理 + Job 监控 + 运行结果预览）
- ✅ ProcessedContent 提升到 shared/types.ts
- ✅ AI_RUNTIME_JOB_CHANGED + AI_RUNTIME_HEALTH_CHECK IPC 通道
- `providers.*` / `aiTasks.*` 保留为 legacy，新功能统一走 `aiRuntime.*`

**来源项目**：cai-master, openless-main, NotesBar-master（均为作者自有，可直接复用）

---

### Phase 5：Obsidian 搜索和回流 ✅

**目标**：完善知识沉淀和回流

**已完成**：
- ✅ distilled_notes 表（schema v16）+ CRUD 方法
- ✅ VaultSearchResult 类型定义
- ✅ VaultScanner.search() 关键词搜索方法
- ✅ distilledNotes.* IPC（list/get/create/update/delete）+ preload 桥接
- ✅ vaultSearch.* IPC（search）+ preload 桥接
- ✅ KnowledgeCardsPage UI（知识卡片浏览 + Vault 搜索 + 蒸馏笔记管理）
- ✅ useDistilledNotes / useVaultSearch hooks
- ✅ Sidebar 新增"知识库"导航入口

**参考项目**：无直接参考
**吸收方式**：基于现有 knowledge_cards / knowledge_edges 扩展

### Phase 6：语音能力深化 ✅

**目标**：完善语音采集和转写能力

**已完成**：
- ✅ ASR Provider 真实实现（OpenAI-compatible Whisper API + 本地 whisper CLI fallback）
- ✅ 全局语音快捷键（Cmd+Shift+V）注册到 shortcutManager
- ✅ 语音词典管理（VoiceDictionaryStore 新增 remove/toggle 方法）
- ✅ voiceDictionary.* IPC（list/add/delete/toggle）+ preload 桥接
- ✅ asr.* IPC（getStatus/transcribe）+ preload 桥接
- ✅ VoiceDictionaryPage UI（词典管理 + ASR 状态 + AI 润色测试）
- ✅ useVoiceDictionary hook
- ✅ Sidebar 新增"语音"导航入口

**参考项目**：无直接参考
**吸收方式**：基于现有 voice/asr、voice/dictionary、voice/polish 扩展

---

## 四、验收标准

每个 Phase 完成后需满足：
1. 代码复用符合版权归属（作者自有项目可直接复用，第三方项目遵守许可证）
2. 项目可运行（npm run dev）
3. TypeScript 类型检查通过（npm run typecheck）
4. 构建通过（npm run build）
5. 现有功能不被破坏
6. 文档更新
