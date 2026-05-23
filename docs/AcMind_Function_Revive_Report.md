# AcMind 功能救活与闭环落地报告

> 这是一次迁移过程中的历史记录。文中提到的部分旧路径属于当时的落地点或迁移目标，当前判断入口时请以 README、当前源码结构和工程引用为准。

## 1. 本次目标
把 AcMind 当前可见入口从“静态 UI / mock 数据”尽量推进到“真实可用的本地 MVP”，优先救活收集箱、剪贴板、日程、工作台、Agent、灵动设置和工具页，并确保 Swift 原生工程可以正常构建与测试。

## 2. 新增基础能力

| 能力 | 文件 | 说明 |
|---|---|---|
| 剪贴板 ViewModel | `App/ViewModels/ClipboardViewModel.swift` | 统一封装剪贴板保存、复制、收藏、删除、清空与加载。 |
| 收集箱真实操作 | `App/ViewModels/InboxViewModel.swift` | 增加文本收集、文件导入、网页抓取、状态更新和 toast 反馈。 |
| 收集箱真实页面 | `历史路径中的收集箱页面` | 用 `SourceItem` 本地数据替换 mock 列表。 |
| 剪贴板真实页面 | `历史路径中的剪贴板页面` | 用 `ClipboardItem` 本地数据替换 mock 列表。 |
| 日程真实入口 | `Features/Native/Schedule/ScheduleDashboardView.swift` | 顶层页面直接切到 `ScheduleNativeView()`。 |
| 工作台本地文档库 | `Features/Native/Workbench/WorkbenchView.swift` | 支持导入 `.md/.txt`、本地保存、摘要/标签/双链解析。 |
| 工具中心启动器 | `Features/Native/Tools/ToolsView.swift` | 工具卡片点击后打开真实工具面板。 |
| Agent 工作台闭环 | `Features/Native/Agent/AgentWorkspaceView.swift` | 支持新建对话、历史切换、删除、标题自动更新、输入发送和本地规则回退。 |
| 灵动设置显示器选择 | `Features/Native/Settings/DynamicSurfaceSettingsView.swift`、`AcMindKit/Services/UI/DynamicSurfaceCoordinator.swift` | 支持为胶囊和大陆分别指定显示器，并持久化后生效。 |
| 兼容修补 | `AcMindKit/Models/CompanionCollapsedContentSettings.swift`、`AcMindKit/Models/AgentTask.swift`、`AcMindKit/Services/Agent/AgentToolRouter.swift` | 修复旧 API / Swift 并发 / 可空值问题。 |

## 3. 已救活功能清单

| 模块 | 功能 | 原问题 | 现在的真实行为 | 验收方式 |
|---|---|---|---|---|
| 收集箱 | 新建文本 | 之前只是按钮或 mock 入口 | 输入文本后会创建真实 `SourceItem` 并刷新列表 | 输入一段文字，列表出现新条目，toast 提示成功 |
| 收集箱 | 导入文件 | 之前没有真实导入链路 | 通过文件选择器导入本地文件并写入收集箱 | 选择 `.md/.txt` 文件后出现新条目 |
| 收集箱 | 抓取网页 | 之前没有真实行为 | 输入 URL 后调用抓取逻辑并保存为收集项 | 输入有效 URL 后列表更新 |
| 收集箱 | 删除 / 状态更新 / 蒸馏 | 入口有但不闭环 | 现在会更新本地状态、删除记录并显示 toast | 点击操作后列表和状态变化可见 |
| 剪贴板 | 保存当前剪贴板 | 之前是 mock / 空按钮 | 手动保存当前系统剪贴板文本或文件路径 | 复制一段文本后点击保存，历史出现新记录 |
| 剪贴板 | 复制回剪贴板 | 之前没有真实回填 | 点击后写回系统剪贴板并 toast 反馈 | 粘贴可得到刚复制的内容 |
| 剪贴板 | 收藏 / 删除 / 清空 | 之前是静态按钮 | 现在调用真实存储服务更新历史 | 收藏状态、条目删除、历史清空都可验证 |
| 剪贴板 | 搜索 / 分类筛选 | 之前是 mock 过滤 | 改为基于本地历史的真实筛选 | 输入关键词或切换分类，列表实时变化 |
| 日程 | 顶层入口 | 之前落在 mock Dashboard | 直接进入 `ScheduleNativeView` 真实日历页 | 点击“日程”打开真实周/月/年视图 |
| 工作台 | 文件导入 | 之前是静态笔记卡 | 选择 `.md/.txt` 后读取内容、生成摘要和标签并本地保存 | 导入文件后可在列表和详情看到内容 |
| 工作台 | 双链 / 标签识别 | 之前是 mock 关联 | 识别 `[[双链]]` 和 `#tag` 并展示关联列表 | 文档中写入双链/标签后能被解析 |
| 工具中心 | 工具卡片点击 | 之前只是静态展示 | 卡片会打开 JSON、Base64、Markdown、OCR、转换等真实工具面板 | 点击任一卡片会弹出对应面板 |
| Agent | 新建对话 / 历史对话 | 之前只有入口，没有真实会话闭环 | 现在会创建、切换、删除并持久化会话，标题会随首句自动更新 | 新建对话后刷新页面，历史仍在且标题变化可见 |
| Agent | 输入发送 / 规则回复 | 之前缺少真实交互反馈 | 输入框支持发送、空输入拦截、消息入流，并按意图返回本地规则或模型回复 | 输入一条任务、计划或分析类指令，能看到不同响应 |
| Agent | 执行计划 / 结果摘要 | 之前是静态展示 | 发送后根据指令生成 3-5 步本地执行链和结果摘要 | 发送任务后，执行条目与摘要卡同步变化 |
| 灵动设置 | 胶囊 / 大陆显示器 | 之前只有 UI 预览 | 现在可为胶囊和大陆分别指定显示器，设置会写入 `UserDefaults` 并影响停靠选择 | 切换显示器后重新进入页面，设置仍保留 |
| 设置页 | 记住窗口布局 / 截图相关选项 | 之前有占位项或未进入持久层 | 现在会写入本地存储，并让窗口布局记忆参与启动恢复逻辑 | 修改后重启或重新进入页面，设置仍保留 |
| 灵动大陆 | 展开态板块 / 模块配置 | 之前只在页面里临时存在 | 现在板块、模块勾选和当前选中板块都可持久化 | 切换板块或模块后刷新页面，状态仍在 |
| 设置兼容 | CollapsedContent | 之前新旧字段不一致 | 补回 `source` 旧别名与初始化器 | 旧测试和旧调用继续可用 |
| 构建稳定性 | Agent 模型路由文件重名 | SwiftPM 产物冲突 | 重命名其中一个同名源文件，解决 multiple producers | `swift build` 正常完成 |

## 4. 已替换 mock 数据清单

| 文件 | 原 mock 内容 | 替换方式 |
|---|---|---|
| `历史路径中的收集箱页面` | `inboxMockItems` 假列表 | 改成 `InboxViewModel` 读取真实 `SourceItem` |
| `历史路径中的剪贴板页面` | `clipboardMockItems` 假列表 | 改成 `ClipboardViewModel` 读取真实剪贴板历史 |
| `Features/Native/Schedule/ScheduleDashboardView.swift` | 硬编码统计卡和日程块 | 直接路由到真实 `ScheduleNativeView` |
| `Features/Native/Workbench/WorkbenchView.swift` | `workbenchNotes` 静态笔记数组 | 改成本地导入文档列表和 `UserDefaults` 持久化 |
| `Features/Native/Tools/ToolsView.swift` | 纯目录型卡片 | 改成可点击并打开真实工具面板 |
| `Features/Native/Agent/AgentWorkspaceView.swift` | 静态任务页 / 假历史 | 改成真实会话、新建、删除、标题更新与本地规则回退 |
| `Features/Native/Settings/DynamicSurfaceSettingsView.swift` | 只有视觉预览 | 增加胶囊 / 大陆显示器偏好选择并落盘 |
| `Features/Native/Settings/SettingsSuiteView.swift`、`App/ViewModels/SettingsViewModel.swift`、`App/AppState.swift` | 部分可见项是占位或未落盘 | 记住窗口布局、截图相关选项和保存反馈改为真实持久化 |
| `AcMindKit/Extensions/SourceItem+UI.swift` | 与模型重复的展示扩展 | 删除重复定义，避免 UI / 模型双份实现冲突 |

## 5. 当前仍是最小 MVP 的功能

| 功能 | 当前最小实现 | 后续增强方向 |
|---|---|---|
| 网页正文提取 | 能抓 URL、尝试提取内容并保存 | 继续增强正文抽取质量和失败回退 |
| OCR | 以现有面板提供最小识别链路 | 接入更稳定的 OCR 引擎与批量预处理 |
| 语音转文字 | 现有语音链路仍偏最小可用 | 接入更完整的 ASR / 纠错 / 润色 |
| 工作台知识网络 | 先以双链关联列表呈现 | 再升级为真正图谱视图 |
| 工具页大部分工具 | 已能打开真实面板，但仍是工具面板级 MVP | 逐个补成与本地存储联动的持续工作流 |

## 6. 无法完全救活的功能及原因

| 功能 | 原因 | 当前处理 | 后续建议 |
|---|---|---|---|
| 系统级自动启动 / 常驻能力 | 需要 macOS 系统权限与安装级别配置 | 仅保留设置与反馈，不伪装成已接入 | 后续接系统服务或安装器 |
| 外部日历同步 | 需要账号授权与远端日历写入 | 先保留本地日程 MVP | 再接云同步和冲突处理 |
| 持续后台剪贴板监听 | 需要更稳定的后台代理与权限链路 | 先支持手动保存当前剪贴板 | 后续补常驻监听与去重 |
| Agent 多工具长链路 | 需要更完整的任务编排与真实模型接入 | 目前主要是本地 MVP 与现有工具路由 | 后续接 Agent 计划执行与工具调度 |
| 真实多屏停靠记忆 | 需要更完整的窗口管理与显示器变化监听 | 当前已支持手动指定目标显示器并按偏好停靠 | 后续可增加显示器拔插后的自动纠正 |
| 灵动大陆运行态模块驱动 | 需要把设置页配置真正喂给展开态面板 | 当前已实现设置页持久化，运行态暂未完全接入 | 后续把配置直接驱动顶部大陆面板 |

## 7. 本地存储 key 清单

当前本次直接落地或沿用的本地存储 key 主要包括：
- `app.theme`
- `app.language`
- `app.defaultProviderId`
- `app.defaultModelId`
- `app.vaultPath`
- `app.autoCaptureClipboard`
- `app.captureScreenshotHotkey`
- `app.defaultExportTarget`
- `app.autoFrontmatter`
- `app.rememberWorkspaceLayout`
- `vault.path`
- `vault.defaultFolder`
- `vault.template`
- `vault.pathRule`
- `vault.conflictStrategy`
- `vault.autoFrontmatter`
- `capture.autoRedactFaces`
- `capture.autoDetectPII`
- `capture.scrollCaptureAutoScroll`
- `capture.scrollCaptureSpeed`
- `capture.scrollCaptureMaxHeight`
- `companion_config`
- `AppSettings.companionCollapsedContent`
- `acmind.workbench.documents`
- `DynamicSurface.visibilityState`
- `DynamicSurface.continentTopDockScreenID`
- `DynamicSurface.preferredCapsuleScreenID`
- `DynamicSurface.preferredContinentScreenID`
- `DynamicSurfaceSettings.continentTabs`
- `DynamicSurfaceSettings.selectedContinentTabID`
- `DynamicSurfaceSettings.selectedWidgetIDs`
- `DynamicSurfaceSettings.selectedFeatureIDs`

## 8. 验收结果

- typecheck: 通过
- build: 通过
- manual test pages: 收集箱、剪贴板、日程、工作台、Agent、灵动设置、工具中心已接入真实最小闭环
- tests: `swift test` 通过
- 已知风险:
  - 仍有部分能力属于 MVP 级，尤其是 OCR / ASR / 多工具链路。
  - 工作台文档库当前使用 `UserDefaults` 保存，后续可以迁移到更适合的本地持久层。

## 9. 下一步建议

1. 继续救活 Agent 页面，把计划生成、步骤状态流、结果摘要做成真正的本地任务编排。
2. 把设置页和灵动胶囊的状态面板进一步连到本地持久化，减少“看得见但未接通”的入口。
3. 逐个把工具面板补成可保存结果的本地工作流，优先 OCR、网页正文提取和 SRT 转换。
