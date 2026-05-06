# AcMind 当前进度交接文档

## 文档元信息
- 文档日期：2026-05-06
- 文档性质：当前项目状态扫描 / 明天继续开发交接
- 适用范围：AcMind 当前仓库
- 版本说明：详细版，不压缩内容，侧重结构梳理、功能归类、模块边界与下一步开发建议
- 维护原则：只记录当前状态，不替代需求文档，不重构产品定义

本文档用于 2026-05-06 的项目状态交接，目标是让明天接手的人可以直接基于当前仓库继续推进，而不用再重新梳理一遍结构、路由、页面、数据流与能力边界。

结论先说：
- 当前项目已经不是“空壳原型”，而是一个有真实 SQLite 持久化、真实主进程服务、真实 IPC、真实 Agent 会话、真实蒸馏/导出/知识库链路的桌面应用。
- 但产品结构已经开始转向新的 5 一级架构，旧页面、旧路由、旧入口、设置页里的配置面板、主进程服务之间仍然并存。
- 目前最大的工作不是补新功能本身，而是“把已经存在的能力，按新的一级架构重新收拢、归位、定责”。

## 阅读导航

如果你明天要接着做开发，建议按下面顺序看：

1. 先看第 1 章，确认项目现在是怎么跑起来的。
2. 再看第 2 章，确认“新一级架构”到底怎么定义。
3. 再看第 3 章，快速判断哪些功能是真完成，哪些只是占位。
4. 再看第 4 到第 8 章，逐个模块理解当前职责和边界。
5. 最后看第 9、10 章，直接定位问题和下一步任务。

如果你只想先做最优先的事情，可以直接跳到第 10 章。

## 目录
- [1. 项目当前状态总览](#1-项目当前状态总览)
- [2. 最新目标架构](#2-最新目标架构)
- [3. 当前功能完成度表](#3-当前功能完成度表)
- [4. Agent 模块现状](#4-agent-模块现状)
- [5. 日程表模块现状](#5-日程表模块现状)
- [6. 工作台模块现状](#6-工作台模块现状)
- [7. 自动工具模块现状](#7-自动工具模块现状)
- [8. 设置模块现状](#8-设置模块现状)
- [9. 当前主要问题](#9-当前主要问题)
- [10. 明天继续开发建议](#10-明天继续开发建议)

## 术语说明
- `已完成`：该能力已经有真实代码、真实数据链路、真实持久化或可稳定交互。
- `部分完成`：真实能力存在，但入口、职责、体验或闭环还不完整。
- `仅 UI / Mock`：当前主要是壳子、说明页、占位页或显式 Mock。
- `未开始`：仓库内尚未形成可用链路，或者只有概念没有实现。
- `真实能力`：指最终会落到主进程服务、IPC、持久化层或外部执行器的能力，不等于页面上能点的按钮。
- `占位`：指视觉上先占着位置，但还没有真正接功能。
- `Mock`：指有意模拟真实流程或返回结果，通常用于开发态、降级或未接 Provider 的情况。

---

## 1. 项目当前状态总览

### 1.1 当前运行方式

AcMind 是一个 Electron 桌面应用，开发和构建方式如下：

- 开发态通过 `npm run dev` 并行启动渲染进程、主进程、preload 和 Electron。
- 渲染层使用 Vite 热更新。
- 主进程和 preload 使用 esbuild bundle。
- Electron 通过 `electronmon` 跑开发实例。

对应脚本见 [`package.json`](/Volumes/White%20Atlas/03_Projects/AcMind/package.json)。

从代码入口上看：
- 渲染入口是 [`src/renderer/main.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/main.tsx)。
- 渲染总入口是 [`src/renderer/App.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/App.tsx)。
- 主进程入口是 [`src/main/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/index.ts)。
- preload 桥接入口是 [`src/preload/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/preload/index.ts)。

### 1.2 当前技术栈

当前技术栈已经比较完整，关键点如下：

- 框架：Electron 35 + React 18。
- 语言：TypeScript，且项目明确采用 strict 模式。
- 构建：Vite（渲染）+ esbuild（主进程 / preload）。
- 样式：Tailwind CSS 3 + 项目自定义 design system。
- 数据库：better-sqlite3。
- 测试：Vitest。
- 质量工具：ESLint 9、Prettier、Husky、lint-staged。

这部分同样见 [`package.json`](/Volumes/White%20Atlas/03_Projects/AcMind/package.json)。

### 1.3 当前主要入口

从用户视角：
- 默认启动后进入的是 Agent 首页，而不是传统工作台首页。
- `view` 查询参数会影响初始页面。
- `tab` 查询参数会影响二级 tab。
- `id` 查询参数会影响某些详情页。

从代码视角：
- `App` 负责一级导航与页面分发，见 [`src/renderer/App.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/App.tsx)。
- `AppShell` 负责壳层布局、顶部栏、侧边栏、右侧 Inspector、个人空间面板，见 [`src/renderer/components/layout/AppShell.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/AppShell.tsx)。
- `Sidebar` 已经写成新的 5 一级模块，见 [`src/renderer/components/layout/Sidebar.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/Sidebar.tsx)。

### 1.4 当前一级导航

当前主导航已经明确写成新架构：

1. Agent
2. 日程表
3. 工作台
4. 自动工具
5. 设置

相关证据：
- [`src/renderer/App.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/App.tsx)
- [`src/renderer/components/layout/Sidebar.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/Sidebar.tsx)

但注意：
- 一级导航已经更新。
- 二级页面和旧路由仍然保留很多。
- 一些旧页面现在仍然承担真实能力，而不是纯历史残留。

### 1.5 当前数据是否真实持久化

是，且持久化范围不小。

当前已经确认的真实持久化包括：
- 应用设置写入 SQLite。
- source items 写入 SQLite。
- AI tasks 写入 SQLite。
- distilled outputs 写入 SQLite。
- knowledge cards 写入 SQLite。
- export records 写入 SQLite。
- scheduler / scheduled tasks 写入 SQLite。
- Agent 会话、消息、任务，也都通过主进程和存储服务形成了真实链路。

主要证据：
- [`src/main/storage.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/storage.ts)
- [`src/main/settings.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/settings.ts)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts)

### 1.6 当前是否存在 Mock 模式

是，而且 Mock 不是单点开关，而是多层存在。

当前 Mock / fallback 的主要类型：

- Agent 设置中有 `mockMode`，属于 UI 可见的显式 Mock 标识。
- 蒸馏管线存在真实 provider 与 `mockDistiller` fallback。
- 某些页面中的 “EmptyState / 即将支持 / 暂未开放” 不是 Mock，而是功能未接入。
- Preload 里还有一些 stub 风格接口，属于桥接层尚未完全实现的标记。

关键证据：
- [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx)
- [`src/renderer/pages/settings/components/AgentChatSettings.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/components/AgentChatSettings.tsx)
- [`src/main/services/distiller/distillPipeline.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/distiller/distillPipeline.ts)
- [`src/main/services/distiller/mockDistiller.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/distiller/mockDistiller.ts)
- [`src/preload/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/preload/index.ts)

---

## 2. 最新目标架构

一级菜单应调整为：

1. Agent
2. 日程表
3. 工作台
4. 自动工具
5. 设置

下面按模块定义职责边界。

### 2.1 Agent

职责：
- 作为所有意图表达的第一入口。
- 让用户直接用自然语言告诉 AcMind 要做什么。
- 支持文字输入、未来支持语音输入。
- 支持快捷指令。
- 支持跨模块调度。
- 支持对工作台、日程表、自动工具、知识库的发起动作。

合理边界：
- 不应该再混入大量工具总览。
- 不应该承担 Obsidian 细节配置。
- 不应该把所有旧页面都堆到主页上。

### 2.2 日程表

职责：
- 管理个人时间与计划。
- 提供今日视图、时间轴、日历、任务清单、提醒、复盘、历史。
- 承接 Agent 生成的提醒、周期任务、定时执行。
- 显示调度结果，而不是只展示说明文案。

合理边界：
- 日程表是“时间管理主面板”。
- 它不应该成为工作台或工具台的替代品。

### 2.3 工作台

职责：
- 只负责 Obsidian 相关和知识沉淀相关流程。
- 统一管理收集、暂存、整理、确认、入库。
- 提供处理日志、知识库、导出历史。
- 承接 `source_items -> distilled_outputs -> knowledge_cards -> export_records` 这条主线。

合理边界：
- 不应该塞入日程、工具总览、Agent 会话等杂项。
- 不应该再把“快速录音 / 工具调用 / 旧导航”混在工作台里。

### 2.4 自动工具

职责：
- 作为 AcMind 的工具能力控制台。
- 收纳所有可调用的处理能力。
- 展示文件转换、OCR、语音转写、网页正文提取、监听、自动化、本地模型、运行状态。
- 为 Agent 提供可调用工具清单和状态展示。

合理边界：
- 只展示“工具能力”和“工具运行状态”。
- 不应再承担知识库、Agent 会话、工作台主流程。

### 2.5 设置

职责：
- 统一管理全局配置、模块配置、AI 配置、语音配置、知识库配置、桌面组件配置、高级配置。
- 作为能力的参数管理中心，而不是功能操作中心。

合理边界：
- 设置页可以解释能力、配置能力，但不应该变成业务操作主入口。
- 真正的执行动作应回到对应模块完成。

---

## 3. 当前功能完成度表

说明：
- `已完成`：已有真实数据、真实 IPC、真实持久化或完整可用交互。
- `部分完成`：真实能力存在，但入口、归属或交互未完全闭环。
- `仅 UI / Mock`：当前主要是说明页、占位页、静态壳子或显式 Mock。
- `未开始`：仓库内没有形成可用功能链路。

| 模块 | 功能 | 当前状态 | 完成度 | 证据文件 / 组件 | 备注 |
|---|---|---|---|---|---|
| Agent | 文字对话 | 真实可用 | 已完成 | [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx), [`src/renderer/hooks/useChat.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useChat.ts), [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L5348) | 有 session、消息、流式回传、停止生成。 |
| Agent | 会话管理 | 真实可用 | 已完成 | [`useChat.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useChat.ts), [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L5357) | 创建、切换、删除、更新会话都可用。 |
| Agent | 流式输出反馈 | 真实可用 | 已完成 | [`useChat.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useChat.ts#L227), [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L5408) | chunk / done / error 三类事件都接了。 |
| Agent | 语音入口 | 仅本地状态切换 | 仅 UI / Mock | [`AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx#L122) | 当前只是 toggle，不是实际录音。 |
| Agent | 快捷指令 | 部分真实、部分导航降级 | 部分完成 | [`AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx#L93), [`actionHandlers.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/agent-chat/actionHandlers.ts#L45) | 有真导航，但真正执行动作仍有限。 |
| Agent | 跨模块调度 | 已有雏形 | 部分完成 | [`actionHandlers.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/agent-chat/actionHandlers.ts) | 以 navigation / fallback 为主，还不是统一调度层。 |
| Agent | 最近任务 / 工作统计 | 有展示但不是真任务面板 | 部分完成 | [`AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx#L61) | 统计的是工作台状态，不是任务列表。 |
| 日程表 | 今日视图 | 仅占位 | 仅 UI / Mock | [`src/renderer/pages/schedule/SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L105) | 只有 EmptyState。 |
| 日程表 | 时间轴 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L135) | 未接真实时间数据。 |
| 日程表 | 日历视图 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L149) | 未接事件源。 |
| 日程表 | 任务清单 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L163) | 未接任务数据。 |
| 日程表 | 快速提醒 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L177) | 只有示例文案。 |
| 日程表 | 快速复盘 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L212) | 没有输入、保存、回顾闭环。 |
| 日程表 | 历史记录 | 仅占位 | 仅 UI / Mock | [`SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx#L226) | 没有真实历史数据。 |
| 日程表 | 调度后台 | 真实可用 | 已完成 | [`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/scheduler/schedulerService.ts), [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L2632) | 真正的定时任务服务已存在。 |
| 工作台 | 总览 | 真实可用 | 已完成 | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L131) | 统计、最近收集、最近入库都是真数据。 |
| 工作台 | 快速入库 | 占位 | 仅 UI / Mock | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L241) | 现在只是说明块。 |
| 工作台 | 暂存区 | 真实可用 | 已完成 | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L257), [`useSourceItems.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useSourceItems.ts) | 能看列表、详情、送入整理、删除。 |
| 工作台 | 整理中 | 真实可用 | 已完成 | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L313) | 基于 sourceItem 状态展示。 |
| 工作台 | 待确认 | 真实可用 | 已完成 | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L336) | 可确认入库。 |
| 工作台 | 知识库 | 真实可用 | 已完成 | [`WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx#L490), [`useKnowledgeCards.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useKnowledgeCards.ts) | 可搜索已入库知识卡。 |
| 工作台 | 处理日志 | 真实可用 | 已完成 | [`useProcessingHistory.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useProcessingHistory.ts) | 合并 source item、export history、errors。 |
| 工作台 | Markdown 导出 | 真实可用但分散 | 部分完成 | [`ExportPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/export/ExportPage.tsx), [`obsidianExporter.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/exporter/obsidianExporter.ts) | 能导出，但不是工作台里唯一入口。 |
| 工作台 | Obsidian Vault 路径配置 | 真实可用 | 已完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1478), [`settings.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/settings.ts#L34) | 路径、规则、frontmatter 已配置。 |
| 自动工具 | 工具总览 | 仅展示骨架 | 仅 UI / Mock | [`ToolBenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/tool-bench/ToolBenchPage.tsx#L193) | 主要是卡片列举。 |
| 自动工具 | 文件转 Markdown | 真实能力存在 | 部分完成 | [`FileConverterPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/file-converter/FileConverterPage.tsx), [`src/main/services/parser/*`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/parser) | 能力在，但 hub 未统一收束。 |
| 自动工具 | OCR 图像识别 | 真实能力存在 | 部分完成 | [`ocrService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ocrService.ts) | 后台有服务，UI 未整合成运行台。 |
| 自动工具 | 语音转文字 | 真实能力存在 | 部分完成 | [`audioTranscriptionService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/audioTranscriptionService.ts), [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L841) | Whisper 下载/修复/状态都存在。 |
| 自动工具 | 网页正文提取 | 真实能力存在 | 部分完成 | [`webpageStrategy.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/strategy/strategies/webpageStrategy.ts) | 页面总览没变成真正工作台。 |
| 自动工具 | 剪贴板监听 | 真实后台存在 | 部分完成 | [`clipboardWatcher.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/clipboardWatcher.ts), [`ClipboardPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/clipboard/ClipboardPage.tsx) | 监听是真，hub 整合不完整。 |
| 自动工具 | 截图捕获 | 真实后台存在 | 部分完成 | [`captureService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/captureService.ts), [`CapturePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/capture/CapturePage.tsx) | 页面与服务都存在，但 hub 未统一。 |
| 自动工具 | 文件夹监听 | 真实后台存在 | 部分完成 | [`voiceWatchService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/voiceWatchService.ts) | 仍需统一到自动工具模块。 |
| 自动工具 | 自动化任务 | 真实后台存在 | 已完成 | [`schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/scheduler/schedulerService.ts), [`AutomationPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/automation/AutomationPage.tsx) | 真服务存在，但界面分散。 |
| 自动工具 | 本地模型 | 真实能力存在 | 已完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L841) | Whisper 模型下载、删除、修复、状态均可用。 |
| 自动工具 | 运行状态 | 占位说明 | 仅 UI / Mock | [`ToolBenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/tool-bench/ToolBenchPage.tsx#L428) | 现在还是说明性页面。 |
| 设置 | 基础设置 | 真实可用 | 已完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L779), [`settings.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/settings.ts#L68) | 自动保存到 SQLite。 |
| 设置 | Agent 设置 | 真实可用 | 已完成 | [`AgentChatSettings.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/components/AgentChatSettings.tsx) | 支持 mock / provider / prompt / stream / timeout。 |
| 设置 | 日程表设置 | 真实配置存在 | 部分完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1299) | 配置已存在，日程表视图本体未接。 |
| 设置 | 工作台设置 | 真实配置存在 | 部分完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1625) | 规则与 Capsule 配置较多。 |
| 设置 | 自动工具设置 | 说明性为主 | 仅 UI / Mock | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1628) | 有区块，但没形成完整配置控制台。 |
| 设置 | 桌面组件设置 | 真实配置与说明混合 | 部分完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1681) | 更像入口汇总。 |
| 设置 | 语音设置 | 真实可用 | 已完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1777) | 自检、Whisper、快捷键、语言配置都在。 |
| 设置 | 知识库设置 | 真实可用 | 已完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1478) | Vault 路径与导出规则均可配。 |
| 设置 | 高级设置 | 真实配置与说明混合 | 部分完成 | [`SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L2055) | 日志与数据维护有真实动作，开发者选项仍偏说明。 |

---

## 4. Agent 模块现状

### 4.1 文字输入

状态：已完成。

当前链路：
- 页面输入区位于 [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx)。
- 输入内容通过 [`useChat.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useChat.ts) 发送。
- 最终调用 preload 暴露的 `window.acmind.agentChat.sendMessage`。
- 主进程的 `agentChat.send` 再转到 `chatService`。

这条链路不是 mock。它包括：
- 会话创建
- 会话切换
- 会话删除
- 发送消息
- 流式 chunk
- 流式 done
- 流式 error

### 4.2 语音入口

状态：未完成，当前只是 UI 占位。

具体表现：
- Agent 首页有一个录音按钮。
- 点击后只是切换 `isRecording`。
- 代码里明确写了 `TODO: Implement actual voice recording`。
- 现在不会真正采集麦克风、也不会走 ASR。

证据：
- [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx#L122)

### 4.3 快捷指令

状态：部分完成。

当前已有的快捷指令：
- 整理今天收集的内容
- 查看待确认内容
- 把最近截图整理成 Markdown
- 搜索我的知识库
- 导入文件并整理
- 打开工具台

行为分两类：
- 一类直接发送给 Agent。
- 一类直接发导航事件跳转到对应模块。

这说明快捷指令已经具备“调度入口”的雏形，但还没有统一动作编排层。

证据：
- [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx#L21)
- [`src/renderer/components/agent-chat/actionHandlers.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/agent-chat/actionHandlers.ts)

### 4.4 最近任务

状态：部分完成。

当前 Agent 首页展示的是：
- 左侧会话列表。
- 右上方工作台统计。

但是：
- 它不是一个真正的“任务看板”。
- 没有显式列出 agent tasks。
- 没有展示 scheduled agent tasks。
- 没有把任务历史、技能执行记录、失败重试归在同一个区域里。

因此，严格来说这块只是“会话 + 概览反馈”，不算完整的最近任务中心。

### 4.5 执行反馈

状态：已完成。

已经具备的反馈包括：
- 连接状态显示。
- 错误 banner。
- Assistant 流式显示。
- 发送中状态。
- 停止生成按钮。
- Mock 标识。
- 空状态下的快捷指令卡片。

证据：
- [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx)
- [`src/renderer/hooks/useChat.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useChat.ts)

### 4.6 是否能跨模块调度

状态：有雏形，但未完全统一。

当前能跨模块做的事：
- 通过 `acmind:navigate` 跳到工作台、工具台、知识库等。
- 通过 `actionHandlers` 触发蒸馏、导出、扫描、运行技能、创建任务等动作。

当前的问题：
- 很多 action 在 API 不可用时会退化成导航。
- `handleRunSkill`、`handleCreateTask` 等接口在前端可调用，但缺少完整统一调度语义。
- Agent 还没有成为真正的“全局操作编排器”。

### 4.7 是否只是 Mock

结论：
- 文字聊天不是 Mock。
- 会话管理不是 Mock。
- 流式反馈不是 Mock。
- 语音入口是占位。
- 一部分跨模块动作是降级导航，而不是实动作。

因此 Agent 模块应被标注为：
- 主聊天链路：已完成
- 语音能力：仅 UI / Mock
- 跨模块调度：部分完成

---

## 5. 日程表模块现状

当前日程表页明确写出了 7 个 tab：
- 今日
- 时间轴
- 日历
- 任务清单
- 快速提醒
- 快速复盘
- 历史记录

但从页面代码看，当前全部都是占位式 EmptyState，见 [`src/renderer/pages/schedule/SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx)。

### 5.1 今日视图

状态：未开始。

当前内容：
- 一个占位标题。
- 一段说明文字。
- 一组“试试对 Agent 说”的示例。

缺少内容：
- 今日日程列表。
- 今日提醒列表。
- 今日待办列表。
- 今日执行状态。

### 5.2 时间轴

状态：未开始。

缺少内容：
- 按小时展示的真实事件。
- 时间块。
- 时间冲突标记。
- 今日时间预算。

### 5.3 日历视图

状态：未开始。

缺少内容：
- 月视图 / 周视图 / 日视图真实渲染。
- 事件聚合。
- 任务与提醒的日期分布。

### 5.4 任务清单

状态：未开始。

缺少内容：
- 待办列表。
- 完成状态。
- 周期任务。
- 和 Agent task / scheduler 的真实映射。

### 5.5 快速提醒

状态：未开始。

当前只有：
- 提示文案。
- 示例语句。

缺少内容：
- 创建提醒的输入。
- 定时规则。
- 提醒确认。
- 取消提醒。

### 5.6 快速复盘

状态：未开始。

缺少内容：
- 今日复盘输入。
- 模板。
- 自动回顾。
- 与任务完成情况的关联。

### 5.7 历史记录

状态：未开始。

缺少内容：
- 历史日程列表。
- 历史提醒记录。
- 历史复盘记录。

### 5.8 未来接入建议

建议优先接入的后端来源：
- `schedulerService` 的普通定时任务。
- `scheduledAgentTasks` 的 Agent 定时任务。
- 如果未来真的做日程事件模型，再追加专门的日程事件表或聚合层。

建议接入顺序：
- 先做今日视图和任务清单。
- 再做提醒和历史。
- 最后做更复杂的时间轴与日历。

当前模块完成度建议标注：
- 日程表主页面：仅 UI / Mock
- 日程后台能力：已完成

---

## 6. 工作台模块现状

工作台的角色定义已经很清楚：
- 只负责 Obsidian 相关和知识沉淀相关流程。
- 核心是收集、暂存、整理、确认、入库。

当前工作台是五个新一级模块里最接近目标形态的一个。

### 6.1 总览

状态：已完成。

已完成内容：
- 统计卡片。
- 最近收集。
- 最近入库。
- 导航到 Agent / staging / knowledge。

数据来源：
- [`useSourceItems.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useSourceItems.ts)
- [`useKnowledgeCards.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useKnowledgeCards.ts)

### 6.2 快速入库

状态：仅 UI / Mock。

现在这个 tab 只有占位说明，没有真正完成“快速入库”动作。

缺少内容：
- 一键快速收集入口。
- 快速录入表单。
- 自动进入整理链路的触发。
- 与 `sourceItems.createText` 或文件导入的联动。

### 6.3 暂存区

状态：已完成。

已具备能力：
- 列出所有 inbox 条目。
- 查看 item 详情。
- 读取内容。
- 送入整理。
- 删除条目。

关键链路：
- `useSourceItems` 负责取数据。
- `sourceItems.getContent` 负责取详情。
- `sourceItems.update` 负责状态推进。
- `distill.run` 或相关蒸馏入口负责进入整理流。

### 6.4 整理中

状态：已完成。

当前基于 `status === 'distilling'` 的 source items 展示。

这说明：
- 不是假数据。
- 不是本地 mock。
- 是真实状态机的一部分。

### 6.5 待确认

状态：已完成。

当前能：
- 列出 `distilled` 条目。
- 查看摘要预览。
- 执行确认入库。
- 删除条目。

### 6.6 知识库

状态：已完成。

当前能：
- 列出 `knowledgeCards`。
- 搜索标题、摘要、标签。
- 显示已入库内容。

### 6.7 处理日志

状态：已完成。

`useProcessingHistory` 做了一个很重要的事情：
- 把 source item 生命周期、导出记录、错误记录、处理时间统一聚合。

这对交接非常有价值，因为它证明工作台不是单页展示，而是有历史纵深的。

### 6.8 Markdown 导出

状态：部分完成。

原因不是“没做”，而是“做了但不在工作台主流程里统一归位”。

真实能力来源：
- [`obsidianExporter.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/exporter/obsidianExporter.ts)
- [`ExportPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/export/ExportPage.tsx)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L1119)

### 6.9 Obsidian 路径 / Vault 相关能力

状态：已完成。

当前已经可以：
- 选择 Vault 路径。
- 校验路径。
- 配默认文件夹。
- 配路径规则。
- 配冲突策略。
- 配自动 frontmatter。

证据：
- [`src/renderer/pages/settings/SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L1478)
- [`src/main/settings.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/settings.ts#L34)

### 6.10 工作台当前最大缺口

- `QuickImportTab` 还是空的。
- 工作台与旧页面仍然重叠。
- “快速入库”没有成为真正的首要操作入口。

因此工作台现在的建议完成度是：
- 总览、暂存、整理中、待确认、知识库、日志：已完成
- 快速入库：仅 UI / Mock
- Markdown 导出：部分完成

---

## 7. 自动工具模块现状

自动工具模块目前是“能力很多，入口很多，但 hub 没收束”的状态。

### 7.1 文件转 Markdown

状态：部分完成。

证据：
- [`src/renderer/pages/file-converter/FileConverterPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/file-converter/FileConverterPage.tsx)
- [`src/main/services/parser/*`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/parser)

判断：
- 真实文件转换能力存在。
- 但自动工具页里的入口更多是目录式展示，而不是统一操作控制台。

### 7.2 OCR 图像识别

状态：部分完成。

证据：
- [`src/main/ocrService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ocrService.ts)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts#L4156)

判断：
- 后台服务真实存在。
- 顶层自动工具页没有把它做成完整面板。

### 7.3 语音转文字

状态：部分完成。

证据：
- [`src/main/services/capture/audioTranscriptionService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/audioTranscriptionService.ts)
- [`src/renderer/pages/settings/SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L841)

判断：
- Whisper 下载、删除、修复、状态检查已经有。
- 但 `ToolBenchPage` 里没有统一的运行态控制。

### 7.4 网页正文提取

状态：部分完成。

证据：
- [`src/main/services/strategy/strategies/webpageStrategy.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/strategy/strategies/webpageStrategy.ts)

判断：
- 真实能力存在。
- 但 hub 没收束。

### 7.5 剪贴板监听

状态：部分完成。

证据：
- [`src/main/clipboardWatcher.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/clipboardWatcher.ts)
- [`src/renderer/pages/clipboard/ClipboardPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/clipboard/ClipboardPage.tsx)

判断：
- 后台监听是真实能力。
- UI 页面是真实能力。
- 但自动工具模块还没有把它变成自己的统一子模块。

### 7.6 截图捕获

状态：部分完成。

证据：
- [`src/main/captureService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/captureService.ts)
- [`src/renderer/pages/capture/CapturePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/capture/CapturePage.tsx)

判断：
- 真能力存在。
- 仍散落在旧页面和工具入口中。

### 7.7 文件夹监听

状态：部分完成。

证据：
- [`src/main/services/capture/voiceWatchService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/voiceWatchService.ts)

判断：
- 说明里已经出现。
- 真能力存在。
- 但不是自动工具顶层页的主控内容。

### 7.8 自动化任务

状态：已完成后台能力，前端分散。

证据：
- [`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/scheduler/schedulerService.ts)
- [`src/renderer/pages/automation/AutomationPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/automation/AutomationPage.tsx)

判断：
- 真实可创建 / 更新 / 删除 / 运行。
- 但入口还没统一到自动工具模块。

### 7.9 本地模型

状态：已完成。

证据：
- [`src/renderer/pages/settings/SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L841)
- [`src/main/services/capture/audioTranscriptionService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/audioTranscriptionService.ts)

判断：
- 模型管理已经是真能力。
- 但它现在更像设置中心里的一个配置项，而不是自动工具中心里的运行控制项。

### 7.10 运行状态

状态：仅 UI / Mock。

证据：
- [`src/renderer/pages/tool-bench/ToolBenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/tool-bench/ToolBenchPage.tsx#L428)

判断：
- 当前只有描述，没有实时状态总览。
- 没有真正的工具健康检查聚合层。

### 7.11 自动工具模块总结

当前自动工具模块最准确的定位应该是：
- 后台真实能力很多。
- 前端 hub 还没统一。
- `ToolBenchPage` 目前更偏目录与概览。
- 自动工具模块的下一步重点不是“再加更多工具”，而是“把现有工具统一编排起来”。

建议完成度：
- 总览、运行状态：仅 UI / Mock
- 工具能力本身：部分完成到已完成不等

---

## 8. 设置模块现状

设置页是当前最成熟的配置中心之一，且已经按最新架构做了分类。

### 8.1 基础设置

状态：已完成。

包括：
- 启动
- 外观
- 快捷键

证据：
- [`src/renderer/pages/settings/SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx#L779)
- [`src/main/settings.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/settings.ts#L68)

### 8.2 Agent 设置

状态：已完成。

包括：
- 启用 Agent 对话
- Mock 模式
- 默认 Provider
- 默认模型 ID
- 系统 Prompt
- 最大上下文消息数
- 流式响应
- 超时时间
- 日程指令示例

证据：
- [`src/renderer/pages/settings/components/AgentChatSettings.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/components/AgentChatSettings.tsx)

### 8.3 日程表设置

状态：部分完成。

已存在的配置项包括：
- Obsidian 自动整理
- 周期任务自动确认
- 失败通知
- 默认日历视图
- 一周起始日
- SMTP 服务器
- 发件人邮箱

问题：
- 设置项已经存在，但 `SchedulePage` 本体仍然是占位页。

### 8.4 工作台设置

状态：部分完成。

包括：
- 收集规则
- 整理与审阅规则
- Capsule 相关配置

问题：
- 这些配置分散在设置页，而工作台主流程还没有全部把它们消化成统一体验。

### 8.5 自动工具设置

状态：仅 UI / Mock。

包括：
- 工具总览
- OCR 与文件转换

问题：
- 这一块更多是在讲“工具有哪些”，没有形成完整的运行控制面板。

### 8.6 桌面组件设置

状态：部分完成。

包括：
- 日程小组件
- 提醒浮窗
- 顶部 Notch 提醒
- 剪贴板历史
- 暂存架
- 截图与贴图
- 快速记录
- 桌面胶囊

问题：
- 这块更像功能入口集和说明集合，部分能力可配置，但不是纯设置。

### 8.7 语音设置

状态：已完成。

包括：
- 录音设备
- 听写开关
- 本地 / 外部 ASR
- Whisper 模型管理
- 诊断
- 快捷键
- 语言
- 翻译模式
- 剪贴板恢复

### 8.8 知识库设置

状态：已完成。

包括：
- Obsidian Vault 路径
- 默认文件夹
- 路径规则
- 冲突策略
- 自动 frontmatter

### 8.9 高级设置

状态：部分完成。

包括：
- 日志级别
- 数据目录
- 数据维护
- 开发者选项

问题：
- 其中有些是实操按钮，有些仍偏说明态。

### 8.10 设置模块总结

设置页是“真配置中心”，不是 mock。

但它也承担了过多横向职责：
- 功能说明
- 功能入口
- 配置中心
- 调试中心
- 模型管理中心

因此未来最好将设置页继续收拢成纯配置层，而执行层放回各自一级模块。

---

## 9. 当前产品结构和最新架构之间的差距

这一部分是当前最关键的交接重点。

### 9.1 一级架构已经新了，但二级结构还没统一

现状：
- 一级导航已经是 `Agent / 日程表 / 工作台 / 自动工具 / 设置`。
- 但是旧页面还大量存在。
- 旧页面里很多还是真实入口，不是历史残留。

影响：
- 用户容易迷路。
- 功能重复。
- 一个能力有多个入口。

### 9.2 Agent 还没有成为真正的“总调度器”

现状：
- Agent 有真实聊天。
- Agent 有快捷指令。
- Agent 有导航降级。
- Agent 还有一些 action handler。

缺口：
- 还没有形成统一的跨模块执行编排。
- 许多 action 还是“跳页代替执行”。

### 9.3 日程表已经有后台，但前端壳太空

现状：
- schedulerService 真实存在。
- scheduled agent tasks 真实存在。
- Settings 页面也能配置不少日程相关参数。

缺口：
- `SchedulePage` 仍然是占位页面。
- 用户很难在日程表一级模块里直接看到真实日程能力。

### 9.4 工作台是真实的，但入口分叉太多

现状：
- workbench 自身已经有真实数据链路。
- source items / distilled outputs / knowledge cards / export records / processing history 都能串起来。

缺口：
- `capture-inbox / staging-pool / distill / export / knowledge-cards` 这些旧页面仍然存在。
- “快速入库”没成为统一主入口。

### 9.5 自动工具的能力已经有了，但 hub 还没做成

现状：
- 文件转换、OCR、语音转写、监听、自动化、本地模型都存在。
- 但很多入口是从旧页面或设置页进入的。

缺口：
- `ToolBenchPage` 没有成为统一工具控制台。
- `runtime-status` 还是说明页。

### 9.6 设置页承担了过多“解释型职责”

现状：
- 设置页里有很多功能说明、示例文案、入口按钮、真配置、工具配置。

缺口：
- 某些功能本来应该在模块里直接完成，却被放到了设置页里解释。

### 9.7 Mock 与真实能力边界不够统一

现状：
- 有真能力。
- 有 fallback。
- 有 UI 占位。
- 有说明性卡片。

缺口：
- 这些状态如果不区分开，用户会把“说明页”误认为“真实功能页”。

### 9.8 数据流断点已经能识别出来

目前明确的断点包括：
- `sourceItems.saveUrl` 在后端与 preload 已经有，但前端 hook 里仍标记未实现。
- Agent 语音入口未闭环。
- 日程表页面没有接 scheduler 数据。
- 自动工具顶层 hub 没有接统一 runtime 状态。
- 快速入库仍是空壳。

### 9.9 UI / 交互问题

主要问题：
- 顶部搜索、ZTools、旧标签页仍然残留旧结构感。
- Right Inspector 仍围绕 capture item 的旧上下文逻辑。
- 各模块大量依赖 `window.dispatchEvent` 做导航和联动，未来可维护性一般。

### 9.10 架构风险

如果不尽快收敛，会出现：
- 一级架构有了，但二级能力仍然横向散。
- 新老页面长期共存，后续接更多自动化时会越来越乱。
- Agent、工作台、自动工具、日程表之间的责任边界模糊。

---

## 10. 明天继续开发建议

以下建议按“先收拢结构，再补真实体验”的优先级排序。

### 10.1 先把日程表从占位页变成真实页

目的：
- 补齐新一级架构里最明显的空白。
- 让日程表真正承接 scheduler / reminder / history。

涉及文件：
- [`src/renderer/pages/schedule/SchedulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/schedule/SchedulePage.tsx)
- [`src/main/services/scheduler/schedulerService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/scheduler/schedulerService.ts)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts)
- [`src/preload/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/preload/index.ts)

验收标准：
- 今日视图能显示真实任务或提醒。
- 至少一个 tab 能读取真实数据。
- 用户能从日程表页创建、查看或运行一个真实任务。

### 10.2 把自动工具 hub 收拢成统一控制台

目的：
- 让工具能力真正回到“自动工具”一级模块。
- 减少工具入口散落的问题。

涉及文件：
- [`src/renderer/pages/tool-bench/ToolBenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/tool-bench/ToolBenchPage.tsx)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts)
- [`src/preload/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/preload/index.ts)
- [`src/renderer/pages/file-converter/FileConverterPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/file-converter/FileConverterPage.tsx)
- [`src/renderer/pages/clipboard/ClipboardPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/clipboard/ClipboardPage.tsx)
- [`src/renderer/pages/automation/AutomationPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/automation/AutomationPage.tsx)

验收标准：
- 自动工具总览不再只是说明列表。
- 至少 3 个工具 tab 能跳到真实页面或真实状态。
- 运行状态 tab 至少能展示一类真实运行信息。

### 10.3 给 Agent 补上真正的语音入口

目的：
- 让 Agent 首页符合“文字 + 语音第一入口”的设计目标。

涉及文件：
- [`src/renderer/pages/agent-chat/AgentChatPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/agent-chat/AgentChatPage.tsx)
- [`src/main/voice/*`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/voice)
- [`src/main/services/capture/audioTranscriptionService.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/capture/audioTranscriptionService.ts)

验收标准：
- 按钮真的开始录音。
- 停止后能得到文本。
- 文本能直接进入 Agent 消息流或新会话。

### 10.4 把 Agent 的跨模块动作从“导航降级”升级为“真实执行”

目的：
- 让 Agent 从“会跳转”升级为“会办事”。

涉及文件：
- [`src/renderer/components/agent-chat/actionHandlers.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/agent-chat/actionHandlers.ts)
- [`src/main/services/chat/*`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/services/chat)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts)

验收标准：
- 至少一部分 action 能真正调用主进程任务，而不是仅跳页面。
- 蒸馏、导出、扫描、创建任务里至少有一个动作能完成真实执行闭环。

### 10.5 修掉 `useSourceItems.saveUrl` 的断点

目的：
- 让 URL 收集链路真正闭环。

涉及文件：
- [`src/renderer/hooks/useSourceItems.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/hooks/useSourceItems.ts)
- [`src/preload/index.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/preload/index.ts)
- [`src/main/ipc.ts`](/Volumes/White%20Atlas/03_Projects/AcMind/src/main/ipc.ts)

验收标准：
- 调用 saveUrl 真正生成 source item。
- 调用后列表自动刷新。
- 不再在 hook 层报“API 尚未实现”。

### 10.6 让工作台的“快速入库”变成真实入口

目的：
- 让工作台的一级职责更加完整。

涉及文件：
- [`src/renderer/pages/workbench/WorkbenchPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/workbench/WorkbenchPage.tsx)
- [`src/renderer/pages/capture-inbox/CaptureInboxPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/capture-inbox/CaptureInboxPage.tsx)
- [`src/renderer/pages/capsule/CapsulePage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/capsule/CapsulePage.tsx)

验收标准：
- 用户能在工作台里完成一次真正的快速收集。
- 不再只显示说明式 EmptyState。

### 10.7 统一设置页里的“真配置 / 说明 / 占位”标记

目的：
- 防止设置页给出过强的“能力已完成”错觉。

涉及文件：
- [`src/renderer/pages/settings/SettingsPage.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/SettingsPage.tsx)
- [`src/renderer/pages/settings/components/AgentChatSettings.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/pages/settings/components/AgentChatSettings.tsx)

验收标准：
- 真实可配的项继续保留。
- 说明性项明确标出。
- 占位项明确标出为 coming soon 或未开始。

### 10.8 逐步收尾旧路由和旧壳层

目的：
- 把新一级架构变成唯一主线。

涉及文件：
- [`src/renderer/App.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/App.tsx)
- [`src/renderer/components/layout/Sidebar.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/Sidebar.tsx)
- [`src/renderer/components/layout/TopBar.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/TopBar.tsx)
- [`src/renderer/components/layout/RightInspector.tsx`](/Volumes/White%20Atlas/03_Projects/AcMind/src/renderer/components/layout/RightInspector.tsx)

验收标准：
- Sidebar 只呈现 5 个一级模块。
- 旧页面只作为模块内二级入口存在。
- 不再把用户引导到只有说明没有行动的死路由。

### 10.9 建议优先顺序

如果明天只做 5 件事，建议顺序如下：

1. 日程表接真实数据。
2. 自动工具 hub 收拢。
3. Agent 语音闭环。
4. `saveUrl` 断点修复。
5. 快速入库变成真实入口。

这 5 件事做完，产品结构会比现在稳定很多，后续再补细节会轻松得多。

---

## 11. 额外补充：当前明确的真实能力清单

为了方便明天继续开发，这里再单独列一下“仓库里已经真实存在、可以继续接”的能力。

- SQLite 持久化已经存在。
- settings 的自动保存已经存在。
- source items 的 CRUD 已存在。
- knowledge cards 的读取已存在。
- export history 已存在。
- agent chat 会话 / 消息 / stream 已存在。
- distill pipeline 已存在。
- mock fallback 已存在。
- schedulerService 已存在。
- agentTasks / scheduledAgentTasks IPC 已存在。
- whisper 模型下载 / 修复 / 删除 / 状态已存在。
- OCR 服务已存在。
- clipboard watcher 已存在。
- capture service 已存在。
- voice watch service 已存在。
- Obsidan exporter 已存在。

这意味着明天开发的重点不是“从零造能力”，而是“把现有能力按新的架构接回去”。
