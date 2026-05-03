# PinStack / PinMind 合并对比总报告

> PinStack 根目录：`/Volumes/White Atlas/03_Projects/Screen Pin`  
> PinMind 根目录：`/Volumes/White Atlas/03_Projects/PinMindV2.0`  
> 只读验证：两个项目均已执行 `npm run typecheck`，均通过。

## 一、总判断

1. 建议合并成一个软件。
2. 主仓库建议选择 PinMind。
3. 主数据模型建议选择 PinMind 的 `CaptureItem + SourceItem + DistilledOutput + ExportRecord`。
4. PinStack 应作为系统能力供应方迁入：截图、固定比例截图、剪贴板增强、悬浮卡片、桌面胶囊/快捷入口、托盘、全局快捷键。
5. PinMind 应作为产品主流程：Capture Inbox → Distill → Edit → Markdown Preview → Obsidian Export → History/Error/Search。
6. 不能作为合并基础的能力：PinStack `cloud:mock`、PinStack JSONL 主存储、PinMind screenshot fixed/region stub、两边未完整闭环的语音/音乐/VaultKeeper。

## 二、重叠能力对比

| 能力 | PinStack 实现情况 | PinMind 实现情况 | 建议保留哪边 | 合并方式 |
|---|---|---|---|---|
| 截图能力 | 成熟，`captureController.ts` 支持 overlay、region、fixed、ratio、copy/save/pin、权限诊断 | 全屏截图真实；fixed/region IPC stub | PinStack | 迁主进程控制器和前端 CaptureHub，输出改写 PinMind CaptureItem |
| 剪贴板能力 | 成熟，文本/图片轮询、hash 去重、ignoreNextCopy、scope/rule/pin | 基本可用，统一 adapter 入库，但系统体验较弱 | PinStack 采集 + PinMind 存储 | 用 PinStack watcher 行为，落到 PinMind `CaptureRecord/SourceItem` |
| 悬浮入口 | PinWindowManager 成熟，always-on-top transparent 多窗口 | 只有 Capsule，无 pin card | PinStack | 后期迁 PinWindowManager，数据源改 SourceItem/CaptureItem |
| 信息队列 | Dashboard 素材流，偏素材库 | CaptureInbox 是知识处理队列 | PinMind | PinStack 采集项进入 CaptureInbox |
| AI 整理 | AI Hub/LocalModel 有，但 mock 降级风险大，非统一蒸馏 | DistillPipeline、AiTask、DistilledOutput、source_type strategy 更完整 | PinMind | 保留 PinMind AI；参考 PinStack Ollama health UX |
| Markdown 导出 | Obsidian 导出简单，`ai_item_fields` 生成 Markdown | exporter 较完整，有 output spec、frontmatter、safe write、ExportRecord | PinMind | 保留 PinMind |
| 设置系统 | 多套设置面板，RuntimeSettings 丰富 | SettingsPage 覆盖 provider/vault/transcription/capsule | PinMind 主，迁 PinStack runtime 子集 | 合并为 Desktop Capture 设置分组 |
| 本地存储 | JSONL 主链路 + SQLite 新服务并存 | SQLite schema version 13，状态和 lineage 更完整 | PinMind | 不迁 JSONL，只写迁移器/adapter |
| 设计系统 | 桌面工具玻璃风，Capture/Pin 组件成熟 | Warm Focus 知识流，更适合主产品 | PinMind 主 UI，PinStack 组件重皮肤 | 按 PinMind tokens 重写 PinStack 组件 |
| 日志系统 | telemetry/stabilityProbe/failureFeedback 实用 | logger/errorService/error_records/retryService 更体系化 | PinMind 主，迁 stabilityProbe 概念 | 把 PinStack capture 事件写 PinMind logger |
| 快捷键 | 多快捷键成熟 | 基础快捷键存在 | PinStack | 迁注册逻辑，设置项纳入 PinMind |
| 托盘 | 成熟，支持模式切换 | 基本托盘 | PinStack | 迁菜单结构，视觉/文案按 PinMind |
| 小组件能力 | Swift Notch 子进程 + Capsule 状态队列 | Electron Capsule UI | 分期：一期 PinMind Electron Capsule，三期 PinStack Swift Notch | 先统一状态协议，再决定 native |
| 语音能力 | recording 保存/外部 VK，转写不闭环 | whisper/API/CLI 转写代码更接近闭环但需环境 | PinMind | 后期补权限和真实 smoke |
| 文件导入能力 | VaultKeeper/Knowledge 依赖外部服务 | PDF/DOCX/Web parser 已接入 SourceItem | PinMind | 保留 PinMind parser，VK 作为插件 |

## 三、哪个仓库适合作为主仓库

建议以 PinMind 为主仓库。

理由：

| 判断点 | PinStack | PinMind | 结论 |
|---|---|---|---|
| 最终产品数据模型 | `RecordItem` 偏素材和悬浮卡片 | `CaptureItem/SourceItem/DistilledOutput/ExportRecord` 贴近 AI 知识库 | PinMind |
| AI 蒸馏闭环 | rename/summary/orchestrator，mock 风险 | taskQueue + distillPipeline + review + export | PinMind |
| Markdown/Obsidian | 简单生成 | output spec + frontmatter + safe write + conflict | PinMind |
| 系统能力 | 截图/悬浮/托盘/快捷键强 | 截图和悬浮弱 | PinStack 模块迁入 |
| UI 主流程 | 素材 Dashboard | 收集、整理、入库、回看 | PinMind |
| 合并成本 | 如果反向迁 PinMind，要重写存储/AI/导出 | 迁 PinStack 系统能力较清晰 | PinMind |

## 四、数据模型合并建议

目标模型：

```text
PinStack Capture Event
  -> PinMind CaptureRecord(source_type, raw_content/raw_file_path/source_url)
  -> CaptureItem(status=pending/transcribing/distilling/failed)
  -> SourceItem(status=inbox/distilling/distilled/exported)
  -> AiTask / DistilledOutput
  -> KnowledgeCard
  -> ExportRecord
```

字段映射建议：

| PinStack `RecordItem` | PinMind 目标 |
|---|---|
| `id` | `original_id` 或迁移 metadata |
| `type='text'` + `source='clipboard'` | `source_type='clipboard_text'` |
| `type='image'` + `source='screenshot'` | `source_type='screenshot'` |
| `path` | `raw_file_path` / `contentPath` |
| `previewText` | `preview_text` / `previewText` |
| `ocrText` | `extracted_text` 或 `ocrText` |
| `originalUrl` | `source_url` / `originalUrl` |
| `tags/useCase/category` | `metadata` 初始字段，AI 后再规范化 |
| `pinned` | UI 状态，不进入 SourceItem 主状态 |

不建议迁移 PinStack JSONL 为主存储；只在需要保留旧用户数据时写一次性 import/migration。

## 五、PinStack 应迁入 PinMind 的能力

| 优先级 | 模块 | 路径依据 | 迁移理由 |
|---|---|---|---|
| P0 | 截图 region/fixed/ratio/copy/save/pin | `src/main/captureController.ts`、`src/main/ipc/captureHandlers.ts`、`src/renderer/CaptureOverlay.tsx`、`CaptureHub.tsx` | PinMind 当前最大缺口 |
| P0 | 剪贴板去重和 ignoreNextCopy | `src/main/clipboardWatcher.ts`、`src/main/clipboardHandler.ts` | 防止复制导出结果又被捕获 |
| P0 | 全局快捷键 | `src/main/shortcutManager.ts` | 桌面采集产品必需 |
| P1 | 托盘菜单和运行模式 | `src/main/tray.ts`、`runtimeSettingsUpdater.ts` | 提升后台工具体验 |
| P1 | Capture Launcher | `src/main/captureController.ts`、`src/renderer/CaptureLauncher.tsx` | 快捷入口 |
| P1 | PinWindowManager | `src/main/windows/pinWindowManager.ts` | 支持临时悬浮卡片 |
| P2 | Swift Notch/Capsule | `native/PinStackNotch`、`notchSubprocessController.ts` | 作为高级桌面入口 |
| P2 | stabilityProbe/failure feedback | `src/main/stabilityProbe.ts`、`failureFeedback.ts` | 提升系统能力可观测性 |

## 六、PinMind 应成为主流程的页面

| 页面 | 路径 | 建议 |
|---|---|---|
| DailyKnowledgeFlow | `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` | 合并后首页 |
| CaptureInbox | `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx` | 统一信息队列 |
| Distill | `src/renderer/pages/distill/DistillPage.tsx` | AI 整理主入口 |
| Edit | `src/renderer/pages/edit/EditPage.tsx` | 二级审阅/整理页 |
| Export | `src/renderer/pages/export/ExportPage.tsx` | Markdown/Obsidian 出口 |
| Settings | `src/renderer/pages/settings/SettingsPage.tsx` | 统一设置 |
| Search/History/Errors | `src/renderer/pages/search`、`history`、`errors` | 作为回看与质量保障 |

## 七、不能被当作合并基础的 mock / placeholder

| 项 | 项目 | 路径 | 原因 |
|---|---|---|---|
| `cloud:mock` | PinStack/PinMind | `src/shared/ai/modelRegistry.ts` | 明确是云端占位 |
| `MockLocalProvider` | PinStack | `src/main/services/localModel/mockLocalProvider.ts` | Ollama 不可用时降级，不能代表真实 AI |
| `mockDistiller` | PinMind | `src/main/services/distiller/mockDistiller.ts` | 会输出 `[Mock]`，只能测试链路 |
| fixed/region screenshot stub | PinMind | `src/main/ipc.ts` | `capture.takeFixedScreenshot` 返回 false，多个 region handler 空实现 |
| PinMind 音乐状态 | PinMind | `src/shared/capsuleSettings.ts`、Capsule UI | 无 MediaRemote 主链路 |
| PinStack VaultKeeper/Wiki | PinStack | `src/main/vk/*`、`src/main/vaultkeeper/client.ts` | 依赖外部服务，非内置闭环 |
| PinStack AI 整理按钮历史风险 | PinStack | `docs/audit/PINSTACK_DEAD_ENTRY_AUDIT_v2.7.0.md` | 审计曾指出 placeholder 按钮，迁移前需重扫具体页面 |

## 八、合并风险清单

| 风险 | 严重程度 | 触发原因 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| 数据结构冲突 | 高 | PinStack `RecordItem` vs PinMind `CaptureItem/SourceItem` | 两边 `src/shared/types.ts` | PinMind 模型为准，写 adapter |
| UI 风格冲突 | 中 | PinStack 玻璃工具风 vs PinMind Warm Focus | `pinstack-ui-v2.css`、`styles.css` | 重皮肤，不直接搬 CSS |
| 存储方式冲突 | 高 | JSONL + SQLite vs SQLite 主 schema | `PinStack/src/main/storage.ts`、`PinMind/src/main/storage.ts` | 不迁 JSONL 主链路 |
| IPC 命名冲突 | 高 | 两边都有 `capture.*`、`settings.*`、`clipboard.*` | `src/main/ipc.ts` | 设计 `desktopCapture.*` 或统一 `capture.*` 显式替换 |
| 截图/悬浮窗重复 | 中 | PinMind capsule 与 PinStack launcher/pin 都用 alwaysOnTop | `capsuleController.ts`、`captureController.ts`、`pinWindowManager.ts` | 窗口管理统一 registry |
| 设置项重复 | 中 | 快捷键、capsule、AI、vault 多套 | `defaultSettings.ts` | 合并设置 schema，保留迁移函数 |
| 版本系统混乱 | 中 | PinStack 2.7.1、PinMind 0.4.0 | `package.json`、`CHANGELOG.md` | 合并后从 PinMind 版本继续，记录迁入模块 |
| mock 被误当真实功能 | 高 | AI fallback 静默或展示不清 | AI provider/mock 文件 | mock 输出禁止导出或加水印提示 |
| 旧功能迁移后不可用 | 高 | PinStack native Notch、权限、路径依赖 | `native/PinStackNotch`、`package.json extraResources` | Notch 放 P2，不进一期 |
| 打包配置冲突 | 中 | entitlements、extraResources、native binary | 两边 `package.json`、`build/entitlements*` | 单独验证打包 |
| 权限声明缺失 | 中 | 截图/录音/辅助功能 | `permissions.ts`、`entitlements` | 合并权限中心 |
| 性能问题 | 中 | 剪贴板轮询、多窗口、AI 队列 | watcher、window manager、taskQueue | 节流、开关、日志 |

## 九、推荐合并路线

### 第一期：最小可行合并

目标：PinMind 继续作为 AI 知识流产品，但获得 PinStack 的真实桌面采集能力。

范围：

| 任务 | 说明 |
|---|---|
| 迁截图控制器 | PinStack region/fixed/ratio/copy/save 能力接入 PinMind |
| 迁剪贴板增强 | 去重、ignoreNextCopy、sourceApp/scope 可选 |
| 迁快捷键/托盘基础 | `dashboard`、`screenshot`、`capture hub` |
| 统一写入 CaptureItem | 所有采集都生成 PinMind `CaptureRecord/CaptureItem/SourceItem` |
| 移除/替换 PinMind screenshot stub | 禁止 UI 调到空 handler |
| typecheck/build/smoke | 截图、剪贴板、导出三条 smoke |

不做：

| 不纳入一期 | 原因 |
|---|---|
| PinWindowManager 多悬浮卡片 | 需要 UI/状态策略 |
| Swift Notch | 打包和 native 风险高 |
| VaultKeeper 合并 | 外部服务边界未定 |
| AI Hub 合并 | PinMind 已有主线，合并会增加混乱 |
| 音乐控制 | 与知识流主线弱相关 |

### 第二期：桌面工作台体验

迁 PinWindowManager、CaptureLauncher 视觉重皮肤、托盘模式、窗口管理 registry。

### 第三期：Native Capsule / Notch

统一状态协议，决定 Electron Capsule 与 Swift Notch 二选一或分层。

### 第四期：文件/语音/外部解析

整理 PinMind parser、Whisper、VaultKeeper 插件边界。

## 十、给不同角色的问题

### 需要 ChatGPT 做产品决策

1. 合并后软件主定位是“AI 第二大脑入口”还是“桌面快捷采集工具 + AI 整理”？
2. 截图后的默认行为：入 Inbox、直接 Pin、还是弹出动作菜单？
3. Pin 卡片是否进入主流程，还是作为临时工具？
4. Notch/Capsule 是否作为默认入口，还是高级开关？
5. mock AI 结果是否允许继续流转到导出？

### 需要 Trae 执行

1. 在 PinMind 新增 desktop capture adapter 层。
2. 迁 PinStack `CaptureController` 到 PinMind，并改写存储落点。
3. 替换 PinMind screenshot stub IPC。
4. 合并快捷键和托盘设置。
5. 按 PinMind tokens 重写 CaptureHub/Launcher 样式。
6. 增加 smoke tests：clipboard text、screenshot region、export markdown。

### 需要 Codex 继续核验

1. 迁移 patch 的主进程窗口生命周期。
2. macOS 权限和 entitlements。
3. preload 暴露面安全审计。
4. `CaptureItem -> SourceItem -> DistilledOutput -> ExportRecord` lineage 是否完整。
5. mock 防误用策略是否落实到 UI 和 export guard。

## 十一、最终建议

合并方向成立，但不要做“大仓库互相拷贝”。正确方式是：

```text
PinMind = 主产品、主仓库、主数据模型、主 AI/导出链路
PinStack = 系统采集能力库、桌面入口能力库、窗口/快捷键/托盘经验来源
```

第一期只做采集能力合并，确保真实可用后，再讨论 Pin 卡片、Notch、音乐、VaultKeeper、AI Console 的二期以后整合。
