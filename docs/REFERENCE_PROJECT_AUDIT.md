# AcMind 参考项目资产审计

审计范围：`/Volumes/White Atlas/03_Projects/GitHub` 下 16 个参考项目。  
审计方式：只读扫描 README、manifest、许可证、顶层结构和关键源码文件；未修改参考项目代码，未执行依赖安装或构建。

**重要说明**：16 个参考项目中大部分为作者本人在课程学习过程中创建的开源项目，作者拥有完整版权，可按需直接复用代码。本审计中标注的许可证信息来自文件扫描，仅供参考。对于作者自有项目，即使根目录缺少 LICENSE 文件或使用了 GPL 等许可证，作者作为版权持有者仍可自由复用代码。少数第三方开源项目（markitdown-main、openless-main、omlx-main、Cent-main、extensions-main）需遵守其许可证。详见 `docs/INTEGRATION_PLAN.md` 许可证规则。

## 1. 总结结论

AcMind 当前技术栈是 Electron 35 + React 18 + TypeScript + Vite/esbuild + better-sqlite3，定位为 local-first desktop AI information hub。16 个参考项目里，最值得吸收的不是完整应用，而是围绕 AcMind 8 个模块的局部能力、交互模型和系统 API 经验。

推荐优先吸收：

| 优先级 | 项目 | 原因 | 对应模块 |
|---|---|---|---|
| P0 | `pinmind-main` | 与 AcMind 当前架构同源，能力命中最高，可作为基线资产 | Capsule / Capture / Clipboard / Inbox / Distill / Export / AI Runtime |
| P0 | `pinstack-main` | 已有剪贴板、截图、Pin 卡片、本地索引、OCR、桌面入口闭环 | Capsule / Capture / Clipboard / Shelf / Inbox |
| P0 | `markitdown-main` | 文件转 Markdown 能力成熟，直接补齐多格式采集与 Distill 前处理 | Inbox / Distill / Export |
| P1 | `cai-master` | 选中文本/图片后一键 AI Action 的产品模型非常适合 AcMind | Capture / Clipboard / Distill / AI Runtime |
| P1 | `openless-main` | 语音输入、AI prompt 润色、光标插入链路可增强 Capture | Capsule / Capture / AI Runtime |
| P1 | `NotesBar-master` | Obsidian/Apple Notes 搜索、Markdown 预览、浮窗参考价值高 | Inbox / Export / Shelf |
| P1 | `macshot-main` | 原生截图、OCR、标注、滚动截图、录屏能力强 | Capture |
| P2 | `ZTools-main` | 插件平台、快速启动、剪贴板和 LMDB 经验可参考，不宜整合整体架构 | Capsule / Clipboard / AI Runtime |
| P2 | `extensions-main` | Raycast 扩展生态可参考命令设计和插件边界，不宜搬运大仓库 | AI Runtime / Export / Inbox |
| P2 | `omlx-main` | 本地 MLX 推理服务能力强，但集成成本和资源风险高 | AI Runtime |

不建议直接迁移高度耦合系统私有 API 的代码。可迁移优先级应以“概念复用、接口设计复用、模块化重写”为主。

## 2. 16 个项目逐项审计

### 2.1 Atoll-main

| 项 | 内容 |
|---|---|
| 项目名称 | Atoll - DynamicIsland for macOS |
| 技术栈 | Swift / SwiftUI / AppKit，Xcode project，MediaRemoteAdapter，Lottie/Metal/系统权限 |
| 是否可以本地运行 | 理论可运行：README 要求 macOS 14+、MacBook notch、Xcode 15+；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `ReadMe.md`、`DynamicIsland.xcodeproj`、`DynamicIsland/`、`Frameworks/`、`mediaremote-adapter/` |
| 核心功能 | MacBook notch 常驻入口、媒体控制、系统状态、Live Activities、锁屏小组件、计时器、剪贴板、颜色选择、系统 HUD |
| 对 AcMind 有价值的能力 | Capsule 的 notch/常驻入口、系统状态卡片、悬浮面板交互、剪贴板入口、权限提示模型 |
| 不建议迁移的能力 | 完整 Dynamic Island 产品、媒体控制全链路、锁屏 Live Activity、私有系统监控和 MediaRemote 依赖 |
| 可复用代码位置 | `DynamicIsland/managers/NotchSpaceManager.swift`、`DynamicIsland/managers/ClipboardManager.swift`、`DynamicIsland/managers/ScreenAssistantManager.swift`、`DynamicIsland/components/`、`DynamicIsland/helpers/*PermissionStore.swift` |
| 迁移难度 | 高 |
| 风险 | 作者自有项目，GPL 不构成障碍；Accessibility/Screen Recording/Calendar/Camera/Music 权限；MediaRemote 私有能力；notch 设备限制；性能与动画复杂度 |
| 推荐优先级 | P2 |

### 2.2 autoclawd-main

| 项 | 内容 |
|---|---|
| 项目名称 | AutoClawd |
| 技术栈 | Swift Package / SwiftUI / AppKit / SQLite / CoreWLAN / SFSpeechRecognizer / Ollama / Claude Code SDK；另有 MCP server 和 WhatsApp sidecar |
| 是否可以本地运行 | 理论可运行：`Package.swift` 指向 macOS 13+ executable target；README 描述本地 AI；未实际构建 |
| package.json / README / src 结构 | `Package.swift`、`README.md`、`Sources/`、`MCPServer/`、`WhatsAppSidecar/package.json`、`Resources/`、`docs/` |
| 核心功能 | 常驻 pill、always-on mic、语音转写、屏幕 OCR、上下文分析、任务抽取、自动执行、世界模型、MCP 工具 |
| 对 AcMind 有价值的能力 | Capsule pill 形态、语音/屏幕上下文采集、任务抽取 pipeline、MCP 工具注册、local-first AI runtime 编排 |
| 不建议迁移的能力 | always-on 麦克风默认体验、自动执行任务、WhatsApp sidecar、未明确许可证的代码直接复用 |
| 可复用代码位置 | `Sources/PillWindow.swift`、`Sources/PillView.swift`、`Sources/PipelineOrchestrator.swift`、`Sources/Transcript*`、`Sources/ScreenGrabService.swift`、`Sources/OllamaService.swift`、`MCPServer/ToolRegistry.swift` |
| 迁移难度 | 高 |
| 风险 | 根目录无 LICENSE；麦克风/屏幕录制/辅助功能权限敏感；自动执行安全边界复杂；Ollama/Claude Code 外部依赖 |
| 推荐优先级 | P2 |

### 2.3 boring.notch-main

| 项 | 内容 |
|---|---|
| 项目名称 | Boring Notch |
| 技术栈 | Swift / SwiftUI / AppKit，Xcode project，XPC helper，MediaRemoteAdapter |
| 是否可以本地运行 | 理论可运行：README 要求 macOS 14+；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `README.md`、`boringNotch.xcodeproj`、`boringNotch/`、`BoringNotchXPCHelper/`、`Configuration/` |
| 核心功能 | notch 媒体控制中心、可视化、日历、文件 shelf、AirDrop、macOS HUD 替换 |
| 对 AcMind 有价值的能力 | Capsule 展开面板、Shelf 文件暂存、拖拽/悬浮交互、HUD 替代入口 |
| 不建议迁移的能力 | 媒体控制完整实现、XPC helper、HUD 替换、notch 专用布局 |
| 可复用代码位置 | `boringNotch/components/`、`boringNotch/managers/NotchSpaceManager.swift`、`boringNotch/models/SharingStateManager.swift`、`boringNotch/observers/DragDetector.swift` |
| 迁移难度 | 高 |
| 风险 | 作者自有项目，GPL 不构成障碍；XPC/权限/私有 API；MacBook notch 场景限制；与 Electron 架构差异大 |
| 推荐优先级 | P2 |

### 2.4 cai-master

| 项 | 内容 |
|---|---|
| 项目名称 | Cai |
| 技术栈 | Swift 5.9 / SwiftUI / AppKit / MLX / Apple Vision OCR / Apple Intelligence 或 OpenAI-compatible/Ollama/LM Studio |
| 是否可以本地运行 | 理论可运行：README 要求 macOS 14+；有 Xcode project 和 tests；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `README.md`、`Cai/Cai.xcodeproj`、`Cai/Cai/`、`Cai/CaiTests/` |
| 核心功能 | 任意 App 选中文本或图片后按热键运行 AI prompt、脚本、连接器；智能内容检测；OCR；自定义 actions；剪贴板历史 |
| 对 AcMind 有价值的能力 | AI Action 模型、选区/剪贴板内容检测、OCR 后处理、自定义 prompt/action 注册、键盘优先命令面板 |
| 不建议迁移的能力 | 整个 Swift App 外壳、商业连接器闭环、Apple Intelligence macOS 26+ 专属路径 |
| 可复用代码位置 | `Cai/Cai/AppDelegate.swift`、`Cai/CaiTests/ContentDetectorTests.swift`、`Cai/CaiTests/ActionGeneratorTests.swift`、`Cai/CaiTests/LLMServiceTests.swift` |
| 迁移难度 | 中 |
| 风险 | macOS 版本与 MLX/Apple Intelligence 能力差异；选区读取需要辅助功能/剪贴板策略；直接代码跨语言迁移成本 |
| 推荐优先级 | P1 |

### 2.5 Cent-main

| 项 | 内容 |
|---|---|
| 项目名称 | Cent |
| 技术栈 | Vite / React 19 / TypeScript / PWA / Zustand / Radix UI / ECharts / GitHub/Gitee/WebDAV/S3 storage / AI assistant |
| 是否可以本地运行 | 理论可运行：`pnpm dev` / `pnpm build`；未安装依赖或构建 |
| package.json / README / src 结构 | `package.json`、`README.md`、`README_EN.md`、`src/api`、`src/assistant`、`src/components`、`src/database`、`src/store` |
| 核心功能 | Local-first 多人记账，GitHub/Gitee/WebDAV 数据同步，AI 语音记账，统计分析，智能导入 |
| 对 AcMind 有价值的能力 | 本地/远端同步模型、增量同步、AI 导入方案、数据自持说明、统计可视化组件思路 |
| 不建议迁移的能力 | 记账业务域、货币/预算/地图等专用逻辑、PWA 路由架构 |
| 可复用代码位置 | `src/api/storage/`、`src/assistant/`、`src/components/data-manager/`、`src/components/stat/` |
| 迁移难度 | 中 |
| 风险 | CC BY-NC-SA 4.0 非商业 ShareAlike，不适合直接迁移到 MIT/商业产品；业务域偏离 AcMind |
| 推荐优先级 | P3 |

### 2.6 dodopulse-main

| 项 | 内容 |
|---|---|
| 项目名称 | DodoPulse |
| 技术栈 | 单文件 Swift / Cocoa / IOKit / Metal，menu bar app |
| 是否可以本地运行 | 理论可运行：README 给出 `swiftc -O -o DodoPulse DodoPulse.swift -framework Cocoa -framework IOKit -framework Metal`；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `README.md`、多语言 README、`resources/`、`scripts/`、`KDE/` |
| 核心功能 | 菜单栏实时系统指标：CPU、内存、GPU、网络、磁盘、电池、风扇、系统信息 |
| 对 AcMind 有价值的能力 | Capsule/状态栏健康指标、轻量系统监控、小图表卡片、menu bar 交互 |
| 不建议迁移的能力 | 完整系统监控产品、风扇/温度等硬件探测深水区 |
| 可复用代码位置 | 根目录 Swift 单文件和 `scripts/`；具体源码文件需进一步定位 |
| 迁移难度 | 中 |
| 风险 | IOKit/Metal/硬件指标兼容性；未 notarized；频繁采样性能风险 |
| 推荐优先级 | P3 |

### 2.7 extensions-main

| 项 | 内容 |
|---|---|
| 项目名称 | Raycast Extensions |
| 技术栈 | Raycast API / React / TypeScript / Node；超大 monorepo |
| 是否可以本地运行 | 单个 extension 理论可通过 Raycast 开发环境运行；整仓不适合作为 AcMind 本地项目直接运行 |
| package.json / README / src 结构 | `README.md`、`LICENSE`、`extensions/`、`templates/`、`examples/`、`docs/`；扫描到约 81k 文件 |
| 核心功能 | Raycast 扩展商店、命令、表单、列表、脚本、AI、第三方服务集成 |
| 对 AcMind 有价值的能力 | 插件 manifest/command 设计、Action Panel、表单/list UX、Obsidian/clipboard/AI/append-to-file 等扩展案例 |
| 不建议迁移的能力 | 整仓库、第三方服务扩展、Raycast runtime 专属 API、海量不相关插件 |
| 可复用代码位置 | `docs/api-reference/`、`templates/`、`examples/`、精选扩展如 `extensions/clipboard-utilities`、`extensions/apple-notes`、`extensions/obsidian-tasks`、`extensions/append-to-file`、`extensions/screen-math` |
| 迁移难度 | 中 |
| 风险 | Raycast API 锁定；大量扩展各自许可证/服务条款需逐项核查；质量参差不齐 |
| 推荐优先级 | P2 |

### 2.8 macshot-main

| 项 | 内容 |
|---|---|
| 项目名称 | macshot |
| 技术栈 | Swift / AppKit / ScreenCaptureKit 或相关原生截图录屏能力 / Vision OCR / CIFilter / S3/Google Drive upload |
| 是否可以本地运行 | 理论可运行：有 `macshot.xcodeproj`，README 支持 Homebrew/DMG；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `README.md`、`macshot.xcodeproj`、`macshot/Capture`、`macshot/Services`、`macshot/UI`、`macshot/Upload` |
| 核心功能 | 截图、18+ 标注工具、录屏和视频编辑、OCR/翻译、PII 自动遮挡、滚动截图、美化、上传 |
| 对 AcMind 有价值的能力 | Capture 的截图/滚动截图/OCR/标注/贴图/保存链路，文件命名、历史记录、权限处理 |
| 不建议迁移的能力 | 完整录屏视频编辑器、上传服务、多语言全量资源 |
| 可复用代码位置 | `macshot/Capture/ScreenCaptureManager.swift`、`macshot/Capture/ScrollCaptureController.swift`、`macshot/Services/VisionOCR.swift`、`macshot/Services/AutoRedactor.swift`、`macshot/Model/Annotation.swift` |
| 迁移难度 | 高 |
| 风险 | 作者自有项目，GPL 不构成障碍；截图/录屏/麦克风/系统音频权限；Swift 到 Electron 重写成本；上传凭据安全 |
| 推荐优先级 | P1 |

### 2.9 markitdown-main

| 项 | 内容 |
|---|---|
| 项目名称 | MarkItDown |
| 技术栈 | Python 3.10+ / setuptools / optional deps / CLI / MCP package |
| 是否可以本地运行 | 理论可运行：`pip install -e packages/markitdown[all]` 或 CLI；未实际安装 |
| package.json / README / src 结构 | 无根 `package.json`；有 `README.md`、`packages/markitdown`、`packages/markitdown-mcp`、`packages/markitdown-ocr`、`packages/markitdown-sample-plugin` |
| 核心功能 | PDF/PPTX/DOCX/XLSX/图片/音频/HTML/CSV/JSON/XML/ZIP/YouTube/EPub 转 Markdown，面向 LLM 前处理 |
| 对 AcMind 有价值的能力 | Inbox 文件摄入、Distill 前的统一 Markdown 化、Export Markdown 规范、MCP 转换服务 |
| 不建议迁移的能力 | 直接把 Python 包内嵌到 Electron 主进程；全量 optional deps 一次性引入 |
| 可复用代码位置 | `packages/markitdown/src/markitdown/`、`packages/markitdown-mcp/`、`packages/markitdown-ocr/`、相关 tests |
| 迁移难度 | 低-中 |
| 风险 | I/O 权限与不可信文件安全；optional deps 体积；Python runtime 打包；OCR/音频依赖 |
| 推荐优先级 | P0 |

### 2.10 NotesBar-master

| 项 | 内容 |
|---|---|
| 项目名称 | NotesBar |
| 技术栈 | Swift / SwiftUI / AppKit / WebKit Markdown preview / Apple Notes / Spotlight / Obsidian URI |
| 是否可以本地运行 | 理论可运行：有 `NotesBar.xcodeproj`，README 提供 Homebrew cask；未实际构建 |
| package.json / README / src 结构 | 无 `package.json`；有 `README.md`、`NotesBar.xcodeproj`、`NotesBar/Components`、`Models`、`ViewModels` |
| 核心功能 | 全局搜索 Obsidian 和 Apple Notes、Markdown/Mermaid/KaTeX 预览、浮动笔记窗口、Spotlight Tab Search |
| 对 AcMind 有价值的能力 | Inbox 统一搜索、Export/Obsidian 交互、Shelf 浮动参考窗口、Markdown 渲染 |
| 不建议迁移的能力 | Apple Notes 私有/自动化依赖全量接入、Spotlight 深集成先期投入 |
| 可复用代码位置 | `NotesBar/AppleNotesManager.swift`、`NotesBar/GlobalSearchManager.swift`、`NotesBar/FloatingWindowManager.swift`、`NotesBar/MarkdownHTMLGenerator.swift`、`NotesBar/SpotlightManager.swift` |
| 迁移难度 | 中 |
| 风险 | Apple Notes 访问权限和兼容性；Swift/Electron 边界；Markdown 预览安全 |
| 推荐优先级 | P1 |

### 2.11 omlx-main

| 项 | 内容 |
|---|---|
| 项目名称 | oMLX |
| 技术栈 | Python 3.10+ / MLX / mlx-lm / FastAPI / uvicorn / OpenAI/Anthropic-compatible APIs / MCP / macOS menu bar packaging |
| 是否可以本地运行 | 理论可运行：`pip install -e .`、`omlx` CLI、Homebrew service；需要 Apple Silicon 和模型；未实际安装 |
| package.json / README / src 结构 | `pyproject.toml`、`README.md`、`omlx/api`、`omlx/engine`、`omlx/cache`、`omlx/mcp`、`packaging/omlx_app`、`tests/` |
| 核心功能 | Apple Silicon 本地 LLM/VLM/Embedding/Rerank/TTS/STT 推理服务、连续批处理、KV cache、OpenAI/Anthropic API 兼容、MCP |
| 对 AcMind 有价值的能力 | AI Runtime 的本地模型 server、OpenAI-compatible adapter、模型注册、资源监控、MCP bridge |
| 不建议迁移的能力 | 自研推理内核、KV cache、模型下载和服务管理全量内嵌 |
| 可复用代码位置 | `omlx/api/`、`omlx/model_registry.py`、`omlx/mcp/`、`omlx/engine_pool.py`、`packaging/omlx_app/server_manager.py` |
| 迁移难度 | 高 |
| 风险 | Apache-2.0 可用但依赖大量 git pinned 包；Apple Silicon/GPU/内存要求高；打包体积和模型管理复杂 |
| 推荐优先级 | P2 |

### 2.12 openless-main

| 项 | 内容 |
|---|---|
| 项目名称 | OpenLess |
| 技术栈 | Tauri 2 / Rust / React 18 / TypeScript / Vite / i18next / ASR / global hotkey / text insertion |
| 是否可以本地运行 | 理论可运行：`openless-all/app/package.json` 提供 `npm run dev`、`npm run tauri`；未实际构建 |
| package.json / README / src 结构 | 根目录 `README.md`；核心在 `openless-all/app/package.json`、`src-tauri/src`、`src/components`、`src/pages` |
| 核心功能 | 全局快捷键语音输入、ASR、AI 润色、prompt 模式、插入当前光标、失败复制剪贴板、历史与设置 |
| 对 AcMind 有价值的能力 | Capture 的语音采集、Capsule 浮窗、AI prompt polish、当前光标插入、快捷键/权限处理 |
| 不建议迁移的能力 | 火山引擎等特定云 ASR 绑定、完整 Tauri app 外壳、Windows 生命周期逻辑 |
| 可复用代码位置 | `openless-all/app/src-tauri/src/recorder.rs`、`asr/`、`polish.rs`、`insertion.rs`、`hotkey.rs`、`src/components/Capsule.tsx`、`src/pages/History.tsx` |
| 迁移难度 | 中 |
| 风险 | 麦克风/辅助功能权限；ASR 云凭据；Rust/Tauri 到 Electron 迁移；跨平台插入行为不稳定 |
| 推荐优先级 | P1 |

### 2.13 pinstack-main

| 项 | 内容 |
|---|---|
| 项目名称 | PinStack |
| 技术栈 | Electron 35 / React 18 / TypeScript / Vite / esbuild / Tailwind / tesseract.js / Swift notch helper / Python processors |
| 是否可以本地运行 | 理论可运行：`npm install`、`npm run dev`、`npm run check`；未实际执行 |
| package.json / README / src 结构 | `package.json`、`README.md`、`src/main`、`src/renderer`、`src/shared`、`native/`、`server/`、`tests/`、`design-system/` |
| 核心功能 | 剪贴板监听、截图、Capture Hub、Pin 悬浮卡片、Dashboard、OCR、本地规则分类、检索、tray、全局快捷键、录屏基础闭环 |
| 对 AcMind 有价值的能力 | Capture/Clipboard/Shelf/Inbox 的现成资产；Pin 卡片、截图面板、OCR、索引 JSONL、批量归类、权限协调 |
| 不建议迁移的能力 | 与旧品牌绑定的 UI、实验性 VaultKeeper/wikiagent 全量服务、未明确 LICENSE 代码直接复用 |
| 可复用代码位置 | `src/main/clipboardWatcher.ts`、`src/main/captureController.ts`、`src/main/ocrService.ts`、`src/main/storage.ts`、`src/main/windows/pinWindowManager.ts`、`src/renderer/CaptureHub.tsx`、`src/renderer/Dashboard.tsx`、`src/shared/types.ts` |
| 迁移难度 | 低-中 |
| 风险 | 根目录无 LICENSE；截图/辅助功能权限；Tesseract 性能；部分 server/python/wikiagent 依赖复杂 |
| 推荐优先级 | P0 |

### 2.14 snow-shot-main

| 项 | 内容 |
|---|---|
| 项目名称 | Snow Shot |
| 技术栈 | Tauri 2 / Rust / React 19 / TypeScript / Rsbuild / Ant Design / Pixi.js / Excalidraw fork / OpenAI SDK |
| 是否可以本地运行 | 理论可运行：`pnpm dev`、`pnpm build`；但依赖 `@mg-chao/excalidraw` file path 指向相邻仓库，未实际构建 |
| package.json / README / src 结构 | `package.json`、`README.md`、`src-tauri/src`、`src/components`、`src/pages/draw`、`src/pages/fixedContent`、`src/pages/videoRecord` |
| 核心功能 | 截图、标注、智能窗口识别、滚动截图、贴图、OCR、翻译、AI 对话、录屏、插件系统 |
| 对 AcMind 有价值的能力 | Capture 的绘制/标注工具、贴图固定、OCR command、插件化截图能力 |
| 不建议迁移的能力 | 全量 Tauri/Rust 架构、Excalidraw fork、视频录制与插件市场 |
| 可复用代码位置 | `src-tauri/src/screenshot.rs`、`src-tauri/src/ocr.rs`、`src-tauri/src/scroll_screenshot.rs`、`src/pages/draw/`、`src/pages/fixedContent/`、`src/components/drawCore/` |
| 迁移难度 | 高 |
| 风险 | 作者自有项目，GPL 不构成障碍；相邻 excalidraw file dependency；截图/录屏权限；Tauri/Electron 跨栈重写 |
| 推荐优先级 | P2 |

### 2.15 ZTools-main

| 项 | 内容 |
|---|---|
| 项目名称 | ZTools |
| 技术栈 | Electron 38 / Vue 3 / TypeScript / electron-vite / LMDB / uiohook-napi / plugin runtime / OpenAI SDK |
| 是否可以本地运行 | 理论可运行：`pnpm dev`、`pnpm build`；未安装依赖或构建 |
| package.json / README / src 结构 | `package.json`、`README.md`、`src/main`、`src/preload`、`src/renderer`、`internal-plugins`、`ztools-api-types`、`tests` |
| 核心功能 | 应用启动器、插件系统、剪贴板管理、主题、插件隔离、快速搜索、super panel、MCP server |
| 对 AcMind 有价值的能力 | Capsule 命令启动、Clipboard 管理、插件 runtime 命名空间、LMDB 存储、MCP server、窗口管理 |
| 不建议迁移的能力 | 整套 uTools-like 产品、Vue UI、插件市场、跨平台窗口/注册表逻辑 |
| 可复用代码位置 | `src/main/managers/clipboardManager.ts`、`src/main/managers/pluginManager.ts`、`src/main/core/mcpServer.ts`、`src/main/core/screenCapture.ts`、`src/main/core/floatingBallManager.ts`、`tests/main/*plugin*` |
| 迁移难度 | 中-高 |
| 风险 | uiohook-napi 原生依赖；Electron 38 与 AcMind Electron 35 差异；插件沙箱安全；LMDB 迁移成本 |
| 推荐优先级 | P2 |

### 2.16 pinmind-main

| 项 | 内容 |
|---|---|
| 项目名称 | AcMind |
| 技术栈 | Electron 35 / React 18 / TypeScript strict / Vite / esbuild / Tailwind / better-sqlite3 / Vitest |
| 是否可以本地运行 | 理论可运行：`npm install`、`npm run dev`、`npm run check`；AcMind 当前项目与其高度同源；未在本次审计执行 |
| package.json / README / src 结构 | `package.json`、`README.md`、`src/main`、`src/preload`、`src/renderer`、`src/shared`、`docs/`、`training/` |
| 核心功能 | 多源采集、AI 蒸馏、本地/云模型路由、Obsidian Markdown 导出、Capsule、知识卡片、搜索标签 |
| 对 AcMind 有价值的能力 | AcMind 的直接基线：Capsule、Capture、Inbox、Distill、Export、AI Runtime、SQLite schema、IPC、安全模型 |
| 不建议迁移的能力 | 旧 AcMind 命名、部分 mock/实验页面、尚未产品化的训练工具直接暴露 |
| 可复用代码位置 | `src/main/capsuleController.ts`、`src/main/captureService.ts`、`src/main/storage.ts`、`src/main/ipc.ts`、`src/renderer/hooks/`、`src/shared/outputSpec.ts`、`docs/acmind_output_spec_pack/` |
| 迁移难度 | 低 |
| 风险 | 与 AcMind 当前代码可能已经分叉，需避免覆盖现有改动；模型路由和导出 schema 要统一命名 |
| 推荐优先级 | P0 |

## 3. AcMind 可吸收能力地图

| AcMind 模块 | 可吸收能力 | 主要来源 | 建议方式 |
|---|---|---|---|
| Capsule：桌面胶囊 / 常驻入口 | pill/capsule、notch 展开、menu bar、tray、全局快捷键、状态卡片 | `pinmind-main`、`pinstack-main`、`openless-main`、`Atoll-main`、`boring.notch-main`、`ZTools-main` | 优先保留 Electron Capsule；参考 Swift notch/pill 交互，按需直接复用代码 |
| Capture：截图 / 贴图 / OCR / 标注 | 截图面板、区域选择、固定尺寸、贴图、OCR、滚动截图、标注、语音输入 | `pinstack-main`、`macshot-main`、`snow-shot-main`、`openless-main`、`cai-master` | 先吸收 PinStack 现有截图/OCR；macshot/snow-shot 作为重写参考 |
| Clipboard：剪贴板历史 / 智能卡片 | 文本/图片监听、历史、搜索、Pin、内容检测、AI Action | `pinstack-main`、`cai-master`、`ZTools-main`、`Atoll-main` | 以 PinStack/AcMind 现有 clipboard watcher 为主，补 Cai 的内容检测和 action routing |
| Shelf：文件临时架 / 拖拽暂存 | Pin 卡片、浮动窗口、文件 shelf、AirDrop/拖拽、固定笔记 | `pinstack-main`、`boring.notch-main`、`NotesBar-master` | 优先实现本地文件/截图/文本暂存，不先做 AirDrop |
| Inbox：统一收集箱 | 多源采集、文件转 Markdown、Apple Notes/Obsidian 搜索、网页/PDF/DOCX 摄入 | `pinmind-main`、`markitdown-main`、`NotesBar-master`、`Cent-main` | P0 引入 MarkItDown 作为外部 processor；搜索入口统一到 SQLite |
| Distill：AI 整理 | 多源蒸馏、prompt polish、账单/文本解析、结构化输出、知识卡片 | `pinmind-main`、`markitdown-main`、`cai-master`、`openless-main`、`Cent-main` | 统一 output schema；AI Action 和 Distill pipeline 分层 |
| Export：Markdown / Obsidian / iCloud 输出 | Markdown builder、Frontmatter、Obsidian vault、append-to-file、Apple Notes/Markdown 预览 | `pinmind-main`、`NotesBar-master`、`markitdown-main`、`extensions-main` | 先做好 Obsidian Markdown；Apple Notes/iCloud 输出后置 |
| AI Runtime：本地模型 / 云端模型 / AI Action | OpenAI-compatible API、Ollama、MLX、MCP、action registry、插件 runtime | `pinmind-main`、`cai-master`、`omlx-main`、`autoclawd-main`、`ZTools-main`、`extensions-main` | 先抽象 provider/action registry；oMLX 作为外部服务集成，不内嵌推理栈 |

## 4. 推荐整合优先级

### P0：立即进入迁移设计

| 项目 | 整合目标 | 第一阶段动作 |
|---|---|---|
| `pinmind-main` | 作为 AcMind 现有代码的同源基线，核对差异 | 对比 `src/main`、`src/shared`、`docs/acmind_output_spec_pack`，只迁移缺口 |
| `pinstack-main` | Capture/Clipboard/Shelf 能力补强 | 抽取剪贴板监听、Capture Hub、Pin window、OCR、卡片数据模型 |
| `markitdown-main` | 多格式文件摄入和 Markdown 化 | 设计 Python processor 子进程或可选外部 CLI，不把所有依赖打进主包 |

### P1：产品能力优先吸收，代码以重写为主

| 项目 | 整合目标 | 第一阶段动作 |
|---|---|---|
| `cai-master` | AI Action 与内容检测 | 设计 AcMind action registry：input detector -> action -> output destination |
| `openless-main` | 语音输入和 prompt polish | 先实现“录音/转写/润色/复制到剪贴板”，光标插入后置 |
| `NotesBar-master` | Obsidian/Apple Notes 搜索和浮窗 | 先接 Obsidian vault 搜索与 Markdown preview；Apple Notes 后置 |
| `macshot-main` | 截图/OCR/标注高级参考 | 参考交互和算法边界，按需直接复用代码 |

### P2：作为架构参考或外部集成

| 项目 | 整合目标 | 第一阶段动作 |
|---|---|---|
| `Atoll-main` | Capsule/notch 交互参考 | 提炼 notch/panel UX，按需直接复用代码 |
| `boring.notch-main` | Shelf/拖拽/notch 参考 | 提炼文件 shelf 交互，按需直接复用代码 |
| `extensions-main` | 插件与命令生态参考 | 选择 5-10 个相关扩展审计 manifest 和 command 设计 |
| `snow-shot-main` | 截图标注/贴图参考 | 参考功能矩阵，按需直接复用代码 |
| `ZTools-main` | 插件 runtime/剪贴板/快速启动参考 | 学习插件隔离、命名空间、测试覆盖 |
| `omlx-main` | 本地模型服务外部集成 | 先支持 OpenAI-compatible endpoint，后续再适配 oMLX 特性 |

### P3：低优先级，仅保留局部思路

| 项目 | 原因 |
|---|---|
| `Cent-main` | 业务域偏记账，许可证非商业 ShareAlike；只参考增量同步和 AI 导入 |
| `dodopulse-main` | 系统监控不是 AcMind 核心；只参考轻量 menu bar 指标 |

### 暂不整合

| 项目 | 原因 |
|---|---|
| 无需整合完整应用 | 16 个项目都不建议“整体合并代码”；均应模块化吸收或重写 |

## 5. 不建议整合清单

| 不建议项 | 来源 | 原因 |
|---|---|---|
| always-on mic 默认开启 | `autoclawd-main` | 隐私、信任、权限和电量风险高 |
| 自动执行任务默认开启 | `autoclawd-main` | 安全边界复杂，容易误操作 |
| 全量插件市场/扩展仓库 | `extensions-main`、`ZTools-main`、`snow-shot-main` | 维护、审核、安全和 API 兼容成本过高 |
| 完整本地推理内核内嵌 | `omlx-main` | 模型、GPU、内存、依赖和打包成本太高 |
| 完整录屏视频编辑器 | `macshot-main`、`snow-shot-main` | 偏离 AcMind MVP，权限和实现复杂度高 |
| Notch-only 体验作为主入口 | `Atoll-main`、`boring.notch-main` | 设备覆盖不足，应作为增强入口而非主路径 |
| 第三方云服务绑定能力 | `Cent-main`、`openless-main`、`macshot-main` | 凭据、隐私、地区可用性和服务条款风险 |

> 注：以上不建议项均为技术/产品层面的考量，不涉及许可证限制。16 个项目中大部分为作者自有项目，作者拥有完整版权，可按需直接复用代码。少数第三方开源项目（markitdown-main、openless-main、omlx-main、Cent-main、extensions-main）需遵守其许可证，详见 `docs/INTEGRATION_PLAN.md`。

## 6. 下一步迁移建议

1. 建立资产白名单

   先只把 P0/P1 项目纳入迁移设计：`pinmind-main`、`pinstack-main`、`markitdown-main`、`cai-master`、`openless-main`、`NotesBar-master`、`macshot-main`。其中第三方开源项目（markitdown-main、openless-main）需遵守其许可证。

2. 先统一 AcMind 内部数据模型

   在 `source_items`、`capture_items`、`distilled_outputs`、`export_records` 之外补齐 `clipboard_items`、`shelf_items`、`ai_actions`、`asset_files` 的边界。没有统一 schema 前，不建议迁移 UI。

3. 第一轮落地顺序

   - Capture：从 `pinstack-main` 对齐截图、OCR、Pin 卡片和 Capture Hub。
   - Inbox：通过 MarkItDown 外部 processor 支持 PDF/DOCX/PPTX/XLSX/HTML 转 Markdown。
   - AI Runtime：补 action registry，先支持 OpenAI-compatible/Ollama，不内嵌 oMLX。
   - Export：稳定 Obsidian Markdown + Frontmatter，后续再做 Apple Notes/iCloud。

4. 许可证处理

   迁移前为每个候选文件标注许可证来源。作者自有项目可直接复用；第三方开源项目（markitdown-main、openless-main、omlx-main、Cent-main、extensions-main）需遵守其许可证。

5. 技术验证建议

   - `pinstack-main`：验证剪贴板监听、截图权限、Tesseract OCR 性能。
   - `markitdown-main`：验证 Electron 调 Python CLI 的错误处理、超时、沙箱目录和大文件内存。
   - `openless-main`：验证麦克风权限、ASR provider 抽象、插入当前光标的失败回退。
   - `NotesBar-master`：验证 Obsidian vault 索引、Markdown preview 安全、Apple Notes 权限边界。

6. 不要做的事

   不要把 16 个项目源码拷进 AcMind；不要一次性引入 Tauri/Rust/Swift/Python 多运行时；不要让 Capture、Clipboard、Inbox、Distill 同时大改，先按模块小步落地。
