# PinStack 合并评估资料包

> 扫描根目录：`/Volumes/White Atlas/03_Projects/Screen Pin`  
> 扫描方式：只读代码扫描 + `npm run typecheck`  
> typecheck：通过，`tsc --noEmit` 退出码 0  
> 结论标签：`真实存在` 表示代码中有主进程/IPC/存储/UI 链路；`半成品` 表示部分闭环但边界不足；`mock`/`占位` 表示不可作为真实合并基础。

## 一、项目基础信息

| 项 | 内容 |
|---|---|
| 项目名称 | PinStack |
| 当前版本号 | `2.7.1`，见 `package.json` |
| 技术栈 | Electron 35、React 18、TypeScript、Vite、TailwindCSS、Framer Motion、better-sqlite3、Tesseract.js、Swift Notch 子进程、Node JSONL/SQLite 混合存储 |
| 启动方式 | `npm run dev` 并行启动 Vite、esbuild main/preload、electronmon |
| 打包方式 | `npm run package:mac:arm64`：先 `scripts/build-notch.sh`，再 `electron-builder --mac dmg --arm64` |
| 主进程入口 | `src/main/index.ts`，构建到 `dist/main/index.cjs`；`main.js` 只是加载 dist |
| 渲染进程入口 | `src/renderer/main.tsx` + `src/renderer/App.tsx` |
| preload 入口 | `src/preload/index.ts`，暴露 `window.pinStack` |
| 路由 / 页面结构 | query 参数 `view` 路由：默认 Dashboard；`pin`、`capture-overlay`、`capture-hub`、`capture-launcher`、`ai-assistant`、`ai-console`、`model-center/settings`、`task-center`、`knowledge`、`obsidian`、`trash/temp-trash`、`vaultkeeper` |
| 主要目录结构 | `src/main` 主进程；`src/main/ipc` IPC 分组；`src/main/windows` 多窗口；`src/main/services` AI/DB/Obsidian/VaultKeeper/Knowledge；`src/renderer/features/dashboard` 主 UI；`src/shared` 类型；`native/PinStackNotch` Swift 胶囊；`server` Knowledge/VaultKeeper 相关服务；`design-system` 设计资产 |
| 文档 | 有 `README.md`、`CHANGELOG.md`、`WORKLOG.md`、`docs/PROJECT_HANDOVER.md`、`docs/audit/*`、`docs/releases/*` |

## 二、产品定位与当前主线

1. 当前主要解决的问题：macOS 上的剪贴板/截图快速捕获、悬浮固定、桌面快捷入口、素材整理，以及向 AI/Obsidian/VaultKeeper 扩展的生产力工具。
2. 默认主流程：启动后台监听剪贴板 → 捕获文本/图片 → 保存到 `~/PinStack` → 依据规则自动 pin 或进入 Dashboard → 用户搜索/分类/固定/复制/导出。
3. 核心页面 / 功能：Dashboard 素材台、截图 Capture Hub/Overlay、悬浮 Pin 卡片、桌面 Capsule/Notch、Model Center/AI Console、VaultKeeper/Obsidian 页面。
4. 已形成闭环：剪贴板文本/图片捕获、截图自由/固定/比例选择、保存/复制/Pin、悬浮卡片、Dashboard 管理、托盘/快捷键、JSONL 本地存储。
5. UI / mock / placeholder：AI 云端 `cloud:mock`；本地模型失败会降级 mock；部分 AI 整理按钮和历史审计提到的旧入口有占位风险；VaultKeeper/Wiki 能力依赖外部服务，不能视为 PinStack 内置闭环。
6. 当前最像的软件：桌面快捷工具 + 截图工具 + 剪贴板工具；AI 知识库前置处理是扩展方向，不是最稳主线。

## 三、功能清单与成熟度表

| 功能 | 入口位置 | 涉及文件 | 当前状态 | 是否真实可用 | 是否适合合并进统一产品 | 备注 |
|---|---|---|---|---|---|---|
| 剪贴板监听 / 剪贴板历史 | 后台、Dashboard、Tray 模式 | `src/main/clipboardWatcher.ts`、`src/main/clipboardHandler.ts`、`src/main/storage.ts`、`src/renderer/features/dashboard/v2/DashboardV2.tsx` | 已闭环 | 是 | 是 | 轮询文本/图片，MD5 去重，写入 JSONL；Dashboard 有 clipboard 过滤 |
| 截图 | Capture Launcher/Hub、快捷键 | `src/main/captureController.ts`、`src/main/ipc/captureHandlers.ts`、`src/renderer/CaptureOverlay.tsx`、`src/renderer/CaptureHub.tsx` | 已闭环 | 是 | 是 | `desktopCapturer` + `screencapture` 兜底；权限诊断较完整 |
| 固定比例截图 | Capture Hub | `src/main/captureController.ts`、`src/renderer/CaptureHub.tsx`、`src/renderer/captureSelection.ts` | 已闭环 | 是 | 是 | 支持 fixed size 和 ratio session |
| 悬浮卡片 | 卡片 Pin 按钮、自动 Pin | `src/main/windows/pinWindowManager.ts`、`src/renderer/PinView.tsx`、`src/renderer/PinCardView.tsx` | 已闭环 | 是 | 是 | always-on-top transparent BrowserWindow |
| 桌面小胶囊 / 快捷入口 | Capsule/Notch | `native/PinStackNotch`、`src/main/windows/notchSubprocessController.ts`、`src/main/services/capsule/*` | 基本可用 | 是，依赖 Swift 子进程 | 是 | 最值得迁入 PinMind 的桌面入口能力 |
| 托盘菜单 | 系统托盘 | `src/main/tray.ts`、`src/main/index.ts` | 已闭环 | 是 | 是 | 支持 dashboard、模式切换、快捷动作 |
| 全局快捷键 | 系统快捷键 | `src/main/shortcutManager.ts`、`src/shared/shortcuts.ts`、`src/main/index.ts` | 已闭环 | 是 | 是 | screenshot/dashboard/captureHub/mode/tray 快捷键 |
| 音乐控制 / 当前播放状态 / 进度条 | Notch/Capsule | `native/PinStackNotch`、`NowPlayingManager.swift`、`MediaRemote*` | 半成品 | 部分 | 可迁概念，谨慎迁代码 | 有 native 文档和 Swift 文件，但 Electron 主链路耦合高 |
| 手动文本输入 | Dashboard / records IPC | `src/main/ipc/recordHandlers.ts`、`src/main/storage.ts` | 基本可用 | 是 | 是 | `records.createText` 写入 RecordItem |
| 网页链接保存 | 文本自动提取 URL、Knowledge/VK | `src/main/storage/normalizers.ts`、`server/src/knowledgeSourceOps.ts` | 半成品 | 部分 | 概念可迁 | 不是统一 SourceType 的网页采集 |
| 文件导入 | VaultKeeper / Knowledge | `src/main/vk/*`、`src/main/vaultkeeper/client.ts`、`src/shared/vaultkeeper.ts` | 半成品 | 依赖外部服务 | 谨慎 | 适合作为后期外部解析插件，不适合第一期 |
| 语音录入 | Capture recording | `src/main/ipc/captureHandlers.ts`、`src/renderer/hooks/useRecording.ts` | 半成品 | 部分录制状态/保存 | 后期 | 能保存 recording，但不是完整语音知识流 |
| 语音转文字 | VaultKeeper / WhisperX 设置 | `src/shared/vk/types.ts`、`src/shared/defaultSettings.ts` | 未接入/外部依赖 | 否/依赖外部 | 不建议一期迁 | 不是内置闭环 |
| Inbox / 信息队列 | Dashboard 素材列表 | `src/renderer/Dashboard.tsx`、`src/renderer/features/dashboard/v2/DashboardV2.tsx` | 基本可用 | 是 | 部分迁 | 更偏素材库，不是 PinMind 的知识流队列 |
| AI 蒸馏 / AI 整理 | AI Console、Model Center、debug IPC | `src/main/services/aiHub/*`、`src/main/services/localModel/*`、`src/main/ipc/recordHandlers.ts` | 半成品/mock 风险 | 部分 | 不建议作为主 AI 基础 | Ollama 可接，但 fallback mock 明显 |
| 编辑页 / 二级整理页 | 无统一二级整理主线 | `src/renderer/pages/aiConsole/*` | 半成品 | 部分 | 不迁 | PinMind 更完整 |
| Markdown 预览 | AI Console / Obsidian | `src/renderer/components/aiConsole/MarkdownPreview.tsx` | 基本可用 | 是 | 可参考 | 不是核心数据链路 |
| Obsidian 导出 | Obsidian 页面 / IPC | `src/main/services/obsidian/*`、`src/main/ipc/obsidianHandlers.ts` | 基本可用 | 是 | 可参考，不做主迁 | 简单写文件，规范不如 PinMind |
| VaultKeeper / 文件解析 | VaultKeeper 页面 / VK IPC | `src/main/vk/*`、`src/main/vaultkeeper/client.ts`、`src/shared/vk/*` | 半成品 | 依赖外部 | 后期整合 | 外部服务边界要重画 |
| AI Console / 模型管理 | AI Console、Model Center | `src/renderer/pages/aiConsole/*`、`src/renderer/pages/model-center/*` | 半成品 | 部分 | 概念参考 | UI 完整但 mock/降级风险 |
| 设置页 | Model Center / settings | `src/renderer/pages/model-center/*`、`src/renderer/features/dashboard/modern/SettingsPanel.tsx` | 基本可用 | 是 | 部分迁 | 与 PinMind 设置重叠 |
| 设计系统 / tokens / 组件库 | 全局样式和 primitives | `src/renderer/styles/pinstack-ui-v2.css`、`src/renderer/styles/tokens.ts`、`src/renderer/design-system/*`、`design-system/pinstack-system.css` | 基本可用 | 是 | 只迁组件概念 | 视觉偏深色/玻璃，与 PinMind Warm Focus 不完全一致 |
| 本地存储 | `~/PinStack` | `src/main/storage.ts`、`src/main/services/database/schema.ts` | 已闭环但分裂 | 是 | 不建议作为主存储 | JSONL RecordItem + SQLite services 并存 |
| 日志系统 | 控制台/telemetry/ai logs | `src/main/telemetry.ts`、`src/main/stabilityProbe.ts`、`src/main/services/aiLog/*` | 基本可用 | 是 | 可迁稳定性探针概念 | PinMind 已有 logger/errorService |
| 错误提示 / toast / 空状态 | Renderer Toast | `src/renderer/components/ToastViewport.tsx`、`src/main/failureFeedback.ts` | 基本可用 | 是 | 可迁体验细节 | failure feedback 较实用 |
| 版本展示与文档同步 | app version IPC | `src/main/ipc.ts`、`src/renderer/version.ts`、`CHANGELOG.md` | 基本可用 | 是 | 保留概念 | 版本文档较完整 |

## 四、数据模型与存储结构

核心数据对象：

| 对象 | 路径 | 简要结构 / 状态 |
|---|---|---|
| `RecordItem` | `src/shared/types.ts` | `id/type/category/path/displayName/previewText/ocrText/sourceApp/source/useCase/tags/originalUrl/createdAt/lastUsedAt/useCount/pinned/localModel/deletedAt` |
| `PinCardState` | `src/shared/types.ts` | pin window 的 `recordId/x/y/width/height/alwaysOnTop/visible` |
| `AppSettings` | `src/shared/types.ts`、`src/shared/defaultSettings.ts` | 剪贴板、快捷键、AI Hub、VaultKeeper、scope、storageRoot |
| `RuntimeSettings` | `src/shared/types.ts`、`src/shared/defaultSettings.ts` | mode、pinBehavior、dashboard、capture launcher、capsule |
| `AiHubSettings` | `src/shared/types.ts` | provider、model、persona、privacy、tierStrategy、tech 配置 |
| SQLite `items` | `src/main/services/database/schema.ts` | 新服务层对象：`items/folders/tags/ai_tasks/ai_call_logs/ai_versions/ai_item_fields/chunks` |
| JSONL index | `src/main/storage.ts` | `~/PinStack/index.jsonl`，主业务实际使用的 RecordItem 列表 |

内容类型表示：

| 类型 | 表示方式 |
|---|---|
| manual_text | `records.createText` 创建 `RecordItem.type='text'`，`source='clipboard'` 默认值不够准确 |
| clipboard_text | `RecordItem.type='text'`、`source='clipboard'`、`.txt` 文件 |
| screenshot | `RecordItem.type='image'`、`source='screenshot'`、`.png` 文件 |
| webpage | 主要通过 `originalUrl` 或 Knowledge/VK 外部链路；没有统一 `source_type='webpage'` |
| audio/video | `RecordItem.type='video'` 和 VK source type；主线不完整 |
| file/pdf/docx | VaultKeeper / Knowledge 外部链路；本地主存储没有统一 file item 模型 |

状态流转：`RecordItem` 没有统一 `status`，有 `deletedAt`、`cleanupStatus`、`explainStatus`；SQLite 新 schema 有 `processing_status` 和 AI 任务表，但与 JSONL 主链路并存。

存储位置：

| 存储 | 状态 |
|---|---|
| JSON 文件 / JSONL | 真实主链路，`~/PinStack/index.jsonl` + 日期文件夹 |
| SQLite | 新服务层存在，`src/main/services/database/schema.ts`，但不是所有主功能统一走它 |
| localStorage | Dashboard 视图模式 `pinstack-view-mode` |
| Obsidian vault | 可导出 Markdown |
| iCloud | 无直接强绑定 |

存储层判断：对 PinStack 自身可用，但不适合作为合并后的主存储。原因是 JSONL RecordItem 与 SQLite items/ai_item_fields 两套模型并存，source type、status、AI 输出、导出记录都不如 PinMind 统一。

## 五、AI 能力与模型接入

| 项 | 判断 |
|---|---|
| AI Provider 抽象 | 有，`src/main/services/aiHub/aiHubService.ts`、`src/shared/types.ts` |
| 本地模型 | 有，Ollama：`src/main/services/localModel/ollamaClient.ts`、`gemmaLocalProvider.ts` |
| 云端模型 | 有配置与 Keychain secret：`secretStore.ts`，但 `cloud:mock` 明确存在 |
| mock provider | 有，`MockLocalProvider` 和 `cloud:mock` |
| 模型注册表 | 有，`src/shared/ai/modelRegistry.ts` |
| prompt profile/persona | 有 persona slots；prompt profile 偏 AI Hub，不是 PinMind 输出规范 |
| AI 蒸馏 pipeline | 不是标准蒸馏 pipeline，偏 rename/summary/orchestrator |
| 错误回退 | 有，preflight 失败降级 mock |
| 任务队列 | 有 AI task services 与 AI Console，但主 RecordItem 闭环不如 PinMind |
| 日志 | 有 telemetry、aiLog、diagnostics |
| source_type 策略 | 弱，基于 RecordItem type/source/useCase，不是统一 SourceType 策略 |
| UI 消费 AI 结果 | 部分消费，写入 `localModel` 或 `ai_item_fields` |
| Markdown 导出 | 有 Obsidian 导出，但规范简单 |

迁移判断：不要迁 AI 核心代码作为统一产品基础。可保留模型中心的 UX、Ollama 健康检查、Keychain secret、persona 概念；蒸馏/输出/数据结构应以 PinMind 为主。

## 六、UI / 设计系统扫描

1. 设计 tokens：有 `src/renderer/styles/tokens.ts`、`src/renderer/styles/pinstack-ui-v2.css`、`design-system/pinstack-system.css`。
2. 组件库：有 `src/renderer/design-system/*`、dashboard modern/v2 组件、Toast、PageShell。
3. Tailwind / CSS variables：两者都有，CSS variables 较多。
4. 主界面风格：玻璃、深色/中性色、桌面工具感、卡片素材台。
5. 较成熟页面：DashboardV2、CaptureHub、PinView、ModelCenter 基础布局、Capsule/Notch。
6. 风格割裂：旧 Dashboard、modern/v2、AI Console、VaultKeeper 页面并存。
7. 浅色/深色：有多套样式，但不是统一主题系统。
8. 重复组件：`EmptyState`、MarkdownPreview、设置组件、Dashboard 卡片多套。
9. 老样式 / 临时样式：`Dashboard.tsx`、`features/dashboard/modern`、`features/dashboard/v2` 并存。
10. 是否适合 Acore/PinMind：适合迁入桌面工具控件，不适合作为合并主 UI。主 UI 应以 PinMind Warm Focus 为基底。

值得保留：CaptureHub、CaptureOverlay、CaptureLauncher、PinWindow 卡片、Notch/Capsule 交互、Toast/failure feedback。  
建议废弃/重写：旧 Dashboard 多套、AI Console 的 mock 导向、VaultKeeper 页面壳、重复设置面板。

## 七、进程能力与系统权限

| 能力 | 文件 / 状态 |
|---|---|
| 主进程能力 | 剪贴板、截图、窗口管理、托盘、全局快捷键、文件读写、外部链接、Swift 子进程、VaultKeeper HTTP |
| IPC 通道 | `src/main/ipc.ts` 统一注册，另有 `src/main/ipc/*.ts` 分组 |
| 渲染调用方式 | `window.pinStack`，`src/preload/index.ts` 使用 `contextBridge` |
| 截图权限 | `systemPreferences.getMediaAccessStatus('screen')`、`desktopCapturer`、`screencapture`，见 `captureController.ts` |
| 麦克风权限 | 语音主线弱，未形成完整权限闭环 |
| 文件系统权限 | 写 `~/PinStack`、打开/导出 vault、任意用户选择路径 |
| 剪贴板权限 | Electron `clipboard` 轮询 |
| 托盘能力 | `src/main/tray.ts` |
| 全局快捷键 | `src/main/shortcutManager.ts` |
| 悬浮窗 | `PinWindowManager` 使用 `transparent/alwaysOnTop/skipTaskbar` |
| 多窗口 | Dashboard、Pin、CaptureOverlay、CaptureHub、CaptureLauncher、AI Assistant、Notch 子进程 |
| 安全风险 | `contextIsolation:true`、`nodeIntegration:false` 较好；但 preload 暴露面很大，`settings.openExternalUrl`、`records.open`、VaultKeeper 任意路径/HTTP、外部文件打开需要合并时收窄 |

## 八、重叠能力对比占位

详见第三份 `PinStack_PinMind_合并对比总报告.md`。

## 九、合并风险清单

| 风险 | 严重程度 | 触发原因 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| 数据结构冲突 | 高 | PinStack `RecordItem`/JSONL 与 PinMind `SourceItem/CaptureItem`/SQLite 不同 | `src/shared/types.ts`、`src/main/storage.ts` | 只迁能力，不迁主存储 |
| UI 风格冲突 | 中 | PinStack 桌面工具玻璃风，PinMind Warm Focus 知识流 | `styles/pinstack-ui-v2.css` | 迁交互，重写视觉 |
| IPC 命名冲突 | 高 | `capture.*`、`settings.*`、`records.*` 与 PinMind 重叠 | `src/main/ipc.ts`、`src/main/ipc/*` | 合并前设计 namespace |
| 截图主进程重复 | 中 | 两边都有截图入口，但 PinMind 多为 stub | `captureController.ts` | 以 PinStack 实现替换 PinMind stub |
| mock 被误当真实功能 | 高 | `cloud:mock`、MockLocalProvider 降级 | `modelRegistry.ts`、`mockLocalProvider.ts` | 合并文案明确禁用 mock 基础 |
| 打包配置冲突 | 中 | PinStack 有 native Notch extraResources | `package.json`、`native/PinStackNotch` | 第一期先不打包 Notch，或单独 feature flag |
| 权限声明缺失 | 中 | 截图/录音/辅助功能需要 macOS 权限 | `build/entitlements.*` | 合并打包时统一 entitlements |
| 性能问题 | 中 | 剪贴板轮询、多个 always-on-top 窗口、Swift 子进程 | `clipboardWatcher.ts`、`pinWindowManager.ts` | 保留 stabilityProbe，加入开关和节流 |

## 十、Codex 初步合并建议

1. 建议合并成一个软件，但 PinStack 不适合作为主仓库。
2. 主仓库建议：PinMind。
3. 应迁入 PinMind 的 PinStack 模块：截图控制器、Capture Overlay/Hub/Launcher、PinWindowManager、clipboard watcher 的去重/ignoreNextCopy、tray/shortcut 管理、Notch/Capsule 概念与后续 native 实现。
4. 只保留概念不迁代码：AI Hub、Obsidian exporter、VaultKeeper 页面、Knowledge server、Dashboard 素材台。
5. 应废弃：PinStack JSONL 主存储作为合并主线、cloud mock 作为能力基础、多套 Dashboard 老 UI。
6. 合并后推荐结构：PinMind 负责 Source/Capture/Distill/Export 主线；PinStack 提供系统采集层和桌面入口层。
7. 推荐分期：一期截图+剪贴板+悬浮入口；二期 Pin 卡片；三期 Notch/Capsule；四期语音/文件外部解析；五期 AI Console 整理。
8. 第一期最小可行范围：PinMind `CaptureItem` 接入 PinStack 截图和剪贴板，保留 PinMind SQLite；不用迁 Dashboard/AI/VaultKeeper。
9. 需要 ChatGPT 决策：统一产品定位是否保留“桌面小工具感”；Pin 卡片是否是主流程；Notch 是否默认开启。
10. 需要 Trae 执行：按 Codex 拆分 IPC namespace、迁移 CaptureController、迁移快捷键/托盘、写 UI 适配。
11. 需要 Codex 继续核验：PinStack 截图模块迁入 PinMind 后权限、打包、窗口生命周期、typecheck/build、真实截图 smoke test。
