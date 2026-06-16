# AcWork 第一阶段 UI 重制详细任务单

> 状态：执行中  
> 日期：2026-06-15  
> 目标版本：AcWork Phase 1  
> 设计体系：AcWork Focus Workspace  
> 设计基准：1500 x 920 pt  
> 最小窗口：1180 x 720 pt

## 1. 本轮目标

把现有 AcMind 主窗口重构为 AcWork，并完成以下三个可交付部分：

1. 统一应用外壳
2. 工作台
3. 合并后的收集箱

其他页面在本轮只需要接入新外壳、导航和占位状态，不进行完整视觉重制。

## 2. 执行原则

- 用户可见品牌统一为 `AcWork`。
- 保留 `AcMindKit`、Bundle ID、数据库目录、通知名等内部兼容标识，除非任务明确要求迁移。
- 不直接删除或改名旧数据目录。
- 不直接把 `source_items` 和 `clipboard_items` 物理合并为一张表。
- 先建立统一领域模型与 Repository，再逐步迁移持久化结构。
- 所有主窗口页面复用同一套 Shell、Toolbar、Token 和基础组件。
- 不保留“剪贴板”一级导航入口。
- 不使用 WebView 或 HTML 模拟 UI。
- 不在 View 中写死业务数据；无真实数据时使用 Mock Repository。
- 每个核心页面必须覆盖 Loading、Empty、Error、Disabled、Hover、Selected、Keyboard Focus。
- 每个用户可操作控件必须提供可理解的 accessibility label 或原生可访问文本。
- 每个阶段完成后先构建和测试，再进入下一阶段。

## 3. 当前代码基线

### 3.1 已有能力

- 已有 SwiftUI 主窗口和自绘侧边栏。
- 已有 `WorkspacePageShell`，但尺寸、Toolbar 和响应式规则不符合新规范。
- 已有 `SourceItem`、`ClipboardItem` 两套持久化模型。
- 已有 `InboxViewModel`、`ClipboardViewModel` 和相应服务。
- 已有剪贴板监听、Pin、收藏标签、粘贴队列和保存到收集箱能力。
- 已有系统状态服务，可供工作台摘要使用。
- 已有大量 AcMindKit 单元测试。

### 3.2 与规范的主要差异

- `SidebarItem` 仍包含独立 `.clipboard` 路由。
- 首页仍叫“首页”，目标名称是“工作台”。
- 主导航分组和顺序与新规范不同。
- 侧边栏当前宽度为 208 pt，目标为 216 pt。
- Filter Rail 当前宽度为 208 pt，目标为 220 pt。
- Inspector 当前宽度为 224 pt，目标为 304 pt。
- 主窗口最小尺寸当前为 880 x 650，目标为 1180 x 720。
- 主窗口外壳没有统一的 60 pt Toolbar。
- Inspector 没有在 1320 pt 以下自动切换为 Sheet 或 Overlay。
- 现有工作台以系统监控为主，不符合“当前工作、下一步、待处理内容、系统摘要”的新职责。
- 现有收集箱和剪贴板仍是两套页面、两套 ViewModel、两套项目类型。
- `AcMindDesignTokens`、`AppSurfaceTokens`、`ProductPanelTokens` 存在重叠。
- 用户可见的 `AcMind` 文案仍广泛存在。
- 当前没有完整 UI 测试或截图基线目录。

## 4. 推荐实施策略

### 4.1 品牌迁移边界

本轮迁移：

- 应用标题
- 侧边栏品牌
- 菜单标题
- 欢迎语
- 设置和关于页面文案
- 通知展示文案
- 空状态和 Mock 文案
- 新建 Swift 类型和组件名称

本轮保留兼容：

- `AcMindKit` 模块名
- Bundle Identifier
- 数据库文件名和旧数据目录
- `AcMind.*` Notification.Name 原始值
- 已发布 URL、备份文件读取和配置 Key
- 现有日志 subsystem 和数据库 schema 名称

兼容标识可以在后续独立迁移任务中逐步改名，不能与 UI 重制同时做破坏性替换。

### 4.2 收集箱数据策略

建立统一展示和操作模型：

```swift
struct CollectedItem: Identifiable, Sendable, Equatable {
    let id: CollectedItemID
    var content: CollectedContent
    var contentType: CollectedContentType
    var source: CollectionSource
    var sourceApplication: String?
    var sourceDevice: String?
    var createdAt: Date
    var updatedAt: Date?
    var processingStatus: ProcessingStatus
    var isPinned: Bool
    var isFavorite: Bool
    var tags: [String]
    var projectID: String?
}
```

`CollectedItem` 是领域层统一模型，不要求本轮改写底层数据库：

- `SourceItem` 通过 Adapter 映射为 `CollectedItem`。
- `ClipboardItem` 通过 Adapter 映射为 `CollectedItem`。
- `CollectedItemRepository` 聚合 `StorageServiceProtocol` 与 `ClipboardServiceProtocol`。
- 更新、删除、Pin、收藏、归档等操作根据 ID 来源路由回原服务。
- 新增采集内容继续写入现有可靠的数据链。
- 保留 `saveToInbox` 兼容操作，但 UI 不再要求用户手动理解两套存储。

## 5. 阶段与依赖

| 阶段 | 内容 | 依赖 |
|---|---|---|
| P0 | 基线、保护和验收设施 | 无 |
| P1 | 品牌、导航和窗口迁移 | P0 |
| P2 | Design Tokens 与统一组件 | P1 |
| P3 | 统一应用外壳 | P2 |
| P4 | 工作台重制 | P3 |
| P5 | 收集箱领域模型与 Repository | P0，可与 P2 并行 |
| P6 | 收集箱 UI 重制 | P3、P5 |
| P7 | 状态、可访问性和交互收口 | P4、P6 |
| P8 | 测试、截图和发布验收 | P7 |

---

## P0 基线与保护

### ACW-P0-01 建立当前基线记录

**目标**

记录重制前的构建、测试和页面状态，避免把已有问题误判为本轮回归。

**涉及文件**

- `README.md`
- `scripts/build.sh`
- `AcMindKitTests/`
- 新增 `docs/superpowers/plans/acwork-phase1-baseline.md`

**任务**

- [x] 记录当前 Git 分支和未提交文件，不修改或回滚现有用户改动。
- [x] 运行 `swift test --parallel`，记录通过数、失败数和失败原因。
- [x] 运行 `bash scripts/build.sh`，记录 Xcode 构建结果。
- [x] 启动当前应用，记录工作台、收集箱、剪贴板页面的现状截图。
- [x] 记录当前数据库路径、版本和旧数据目录。
- [x] 记录主窗口当前默认尺寸和最小尺寸。

**验收**

- 有一份可追溯的基线文档。
- 已知失败与本轮新增失败可以区分。
- 没有改动或清理用户当前工作区。

### ACW-P0-02 建立截图与 Mock 数据入口

**目标**

让页面能够稳定复现验收状态，不依赖个人真实数据。

**建议文件**

- 在 `Features/Native/Shared/WorkspaceSharedComponents.swift` 增加 `AcWorkPreviewData` 和 `AcWorkPreviewScenario`（当前 Xcode 工程使用显式文件列表，先避免新增 target 文件风险）
- `docs/screenshots/acwork-phase1/`

**任务**

- [x] 定义 `populated`、`loading`、`empty`、`error` 四种通用场景。
- [x] 为工作台准备固定日期、任务、日程、活动和系统状态 Mock。
- [x] 为收集箱准备文本、链接、图片、文件、代码、富文本、视频数据。
- [x] 为剪贴板、手机同步、说入法、截图、Agent、手动添加准备来源样本。
- [x] 支持通过 Preview 或启动参数进入指定场景。

**验收**

- 同一场景重复启动时内容和排序一致。
- Mock 不会写入用户真实数据库。
- Loading、Empty、Error 均可独立触发。

---

## P1 品牌、导航与窗口迁移

### ACW-P1-01 建立品牌常量与兼容规则

**目标**

集中管理用户可见品牌，避免全仓库散落硬编码。

**建议文件**

- 在 `AcMindKit/Models/SidebarItem.swift` 增加 `AcWorkBrand`（当前 Xcode 工程使用显式文件列表，先避免新增 target 文件风险）
- `Resources/Info.plist`
- `App/AcMindApp.swift`
- `App/AppDelegate.swift`
- `App/OOBEWindowController.swift`

**任务**

- [x] 定义产品显示名 `AcWork`。
- [x] 定义兼容说明，内部模块名、目录名、通知原始值暂不迁移。
- [x] 将主窗口、启动窗口、菜单、关于页、OOBE 的用户可见名称替换为 AcWork。
- [x] 更新隐私权限说明中的产品名。
- [x] 保留旧通知和数据路径，避免外部触发器及旧数据失效。
- [x] 区分“用户可见 AcMind”与“技术兼容 AcMind”，不能机械全局替换。

**验收**

- 用户正常操作路径中不再看到 AcMind。
- 旧数据库、设置和通知仍能工作。
- `rg -n '"[^"]*AcMind[^"]*"' App Features Resources` 的剩余结果均有兼容理由。

### ACW-P1-02 重构一级导航

**目标**

导航固定为规范定义的 10 个页面。

**涉及文件**

- `AcMindKit/Models/SidebarItem.swift`
- `AcMindKitTests/SidebarItemTests.swift`
- `App/AppState.swift`
- `App/ContentView.swift`
- `App/AcMindApp.swift`
- `App/AppDelegate.swift`
- `Features/Sidebar/SidebarView.swift`

**目标导航**

```text
工作
- 工作台
- Agent
- 收集箱
- 日程

处理
- 工具台

随身能力
- 灵动大陆
- 说入法

系统
- 状态
- 模型
- 设置
```

**任务**

- [x] 将 `.home` 的显示名称改为“工作台”，保留 rawValue 兼容或提供旧路由映射。
- [x] 从主导航数组、快捷键数组和菜单中移除 `.clipboard`。
- [x] 保留旧 `.clipboard` raw route 的兼容解析，并映射到 `.inbox` + 剪贴板来源筛选。
- [x] 将工作流、处理、随身能力、系统拆成四个分组。
- [x] 更新快捷键顺序并消除 `.inbox` / `.clipboard` 的 `Cmd+2` 冲突。
- [x] 更新 Companion、App Intent、通知和首页入口到统一收集箱。
- [x] 更新动态大陆中的内部路由选择器。
- [x] 为旧持久化选中值增加 fallback，未知值回到工作台。

**测试**

- [x] 更新 `SidebarItemTests`。
- [x] 新增旧 `clipboard` 路由映射测试。
- [x] 新增导航顺序和快捷键唯一性测试。

**验收**

- 主侧边栏恰好显示 10 个一级页面。
- 不出现独立“剪贴板”导航项。
- 原有打开剪贴板的入口会打开收集箱并选中剪贴板来源。
- 所有菜单和全局快捷键仍可达。

### ACW-P1-03 更新主窗口尺寸与恢复策略

**涉及文件**

- `App/ContentView.swift`
- `App/AppDelegate.swift`
- `App/AcMindApp.swift`

**任务**

- [x] 将主窗口默认内容尺寸设为 1500 x 920。
- [x] 将主窗口最小内容尺寸设为 1180 x 720。
- [x] 删除 `ContentView` 中 880 x 650 的旧约束。
- [x] 调整 `AppWindowGeometry`，区分默认尺寸与最小尺寸。
- [x] 恢复旧窗口位置时，对小于最小尺寸的历史窗口进行校正。
- [x] 在屏幕可用区域不足时保持窗口可见，不产生屏幕外定位。

**测试**

- [x] 为窗口尺寸常量增加源码或纯值测试。
- [x] 覆盖历史 880 x 650 恢复到 1180 x 720 的场景。

**验收**

- 新启动默认 1500 x 920。
- 用户不能将主窗口缩小到 1180 x 720 以下。
- 旧用户窗口恢复不会出现裁切或屏幕外窗口。

---

## 本轮执行记录 2026-06-15 12:15 Asia/Shanghai

已完成：

- P0 基线文档：`docs/superpowers/plans/acwork-phase1-baseline.md`
- P0-02 Mock / Preview 场景入口：`populated`、`loading`、`empty`、`error`
- P1-01 品牌常量与用户可见品牌迁移第一批
- P1-02 一级导航、旧 `clipboard` route 兼容、动态大陆 route picker 显示兼容、未知 route 回工作台
- P1-03 主窗口默认尺寸、最小尺寸和恢复策略
- P2-01 第一批 AppSurface / Design token 收口
- P2-02 第一批基础组件补齐：`AcListRow`、`AcInspector`、`AcMetric`
- P5-01 统一收集箱领域模型第一批
- P5-02 `SourceItem` / `ClipboardItem` Adapter 第一批
- P5-03 `CollectedItemRepository` 聚合层第一批
- P5-04 类型安全收集箱 ViewModel 状态机第一批
- P5-04 收集箱 ViewModel 接入现有 `InboxView` 第一批：现有卡片通过兼容 Adapter 展示 `CollectedItem`
- P6-01 / P6-02 / P6-03 / P6-04 第一批：收集箱改用原生 `CollectedItem` 卡片，加入顶部筛选 Chips、搜索、排序、列表/网格切换和单项操作
- P6-01 第二批：收集箱左侧改为 220 pt 原生 Filter Rail，移除“剪贴板工作区”二级页面切换，来源/类型/状态改为多条件筛选
- P6-05 第一批：右侧改为 `CollectedInboxInspector`，支持无选中摘要、有选中内容预览、元信息、AI/去向入口和固定底部操作
- P6-07 第一批：新增批量操作条，接通批量归档、批量删除、批量加入粘贴队列和退出批量选择
- P6-07 第二批：批量删除增加二次确认弹窗，确认后才执行删除
- P6-07 第三批：批量归档/删除逐项捕获失败，显示成功数、失败数和失败项摘要，失败项保留选择以便重试
- P6-03 键盘操作第一批：方向键循环选择，Space/Return 打开快速预览，Delete 确认删除，Escape 关闭预览或清除选择
- P3-03 / P6-05 响应式 Inspector 第一批：1320 pt 以上固定右栏，1180-1319 pt 隐藏固定右栏并通过页头按钮打开同内容 Sheet
- P6-03 / P6-04 缩略图第一批：图片通过 AssetStore 异步解码，文件/文档/视频通过 Quick Look 生成，列表、网格、Inspector 和快速预览共享 NSCache
- P6-04 展示收口：链接异步加载并缓存 origin favicon，文件大小从 metadata、本地属性或 AssetStore 解析并展示
- P5-03 / P6-05 workflow 第一批：`CollectedItem` 可生成任务、日程、知识卡片和 Markdown 草稿，Inspector 接通发送 Agent、转任务、转日程、保存知识库和导出
- P6-07 workflow 第一批：批量接通发送 Agent、转任务、转日程和目录化 Markdown 导出，并统一显示成功/失败反馈
- P6-05 AI workflow 第一批：自动标题、摘要、提取待办、提取日程和润色接入 `AIRuntimeProtocol`；结构化结果可回写收集项或创建真实任务/日程
- P6-05 操作状态第一批：单项 AI 动作显示具体处理中状态，执行期间禁用重复 workflow，完成后统一显示成功/失败反馈
- P6-07 批量标签：支持为选中项合并多个标签，逐项隔离错误并复用批量结果反馈
- P6-06 Pin 管理第一批：统一收集箱透传现有 Pin window manager 的显示全部、隐藏全部和关闭全部语义
- P6-06 粘贴队列第一批：非空时显示数量入口，支持粘贴下一条、单项移除、清空和上下重排
- P6-01 Facet 数量：快捷视图、来源、类型和状态均基于未筛选全集显示分项数量
- P6-02 添加内容：页头菜单复用快速记录、截图/文件和语音记录现有入口
- P6-03 密度收口：列表提供持久化的标准 84 pt 与紧凑 64 pt 行高
- P6-04 网格尺寸收口：卡片宽度限制为 240–300 pt、高度 188 pt，1180 pt 窗口断点保持至少两列
- P6-02 剪贴板监听：剪贴板来源筛选激活时展示真实 active/paused/stopped 状态，并支持暂停/恢复
- P6-08 旧页面组合清理：主内容直接进入统一 `InboxView`，移除 `CaptureWorkspaceView.Mode`、双页头和 `ClipboardView` 页面切换
- P2-02 第一批基础组件接入：设置页侧栏切换改用 `AcListRow`，收集箱 Inspector 改用 `AcInspector`
- P7-02 收集箱键盘收口：`Cmd+F` 聚焦搜索，Escape 关闭预览或退出批量选择，Delete 继续走危险操作确认
- P7-04 收集箱任务稳定性：防抖搜索可取消，页面退出使在途刷新失效，慢旧查询不会覆盖新结果
- P7-04 系统采样生命周期：工作台和系统状态页进入时启动、离开时停止，避免后台持续轮询
- P7-01 权限真值与入口：权限快照按真实授权状态标记可用性，工作台和状态页统一显示原因并直达对应系统设置
- P7-01 Disabled 解释第一批：剪贴板监听与 Inspector 处理中动作提供 Help 和 accessibility hint
- P7-02 主导航菜单：`Cmd+1...` 从窗口列表迁到专用“导航”菜单，避免重复绑定并提升发现性
- P7-03 收集箱卡片语义：列表/网格卡片合并标题、类型、来源、状态、时间、Pin/收藏/批量选择和预览描述，状态 pill 增加图标与状态标签
- P7-03 高对比度与装饰图第一批：共享状态组件响应 Increase Contrast，Inbox 装饰图标隐藏，搜索清除按钮补充 label
- P7-03 文本放大第一批：批量操作条横向滚动，共享对话按钮和 Inspector 动作增加 minimumScaleFactor
- P7-02 焦点顺序：主侧边栏、页面工具栏、筛选栏、内容区和详情栏设置明确 accessibility sort priority 与区域 label

本轮验证：

- `swift test --filter SidebarItemTests` 通过
- `swift test --filter SystemStatusCleanupTests/testPrimarySidebarMatchesAcWorkNavigationSections` 通过
- `swift test --filter SystemStatusCleanupTests/testAcWorkPreviewScenariosProvideDeterministicInboxStates` 通过
- `swift test --filter SystemStatusCleanupTests/testMainWindowUsesAcWorkDefaultAndMinimumSizes` 通过
- `swift test --filter SystemStatusCleanupTests/testAppSurfaceTokensMatchAcWorkPhaseOneLayout` 通过
- `swift test --filter CollectedItemRepositoryTests` 通过
- `swift test --filter CollectedInboxViewModelTests` 通过
- `swift test --filter SystemStatusCleanupTests/testCaptureWorkspaceViewUnifiesInboxAndClipboardModes` 通过
- `swift test --filter SystemStatusCleanupTests/testInboxViewUsesNativeCollectedItemCardsAndActions` 通过
- `git diff --check` 通过
- `bash scripts/build.sh` 通过，产物为 `build/Debug/AcMind.app`

保留不改的兼容项：

- `AcMindKit` 模块名、Xcode scheme、app executable、bundle identifier
- `AcMind.*` 通知原始值
- `~/Library/Application Support/AcMind` 数据目录和旧模型目录
- GitHub 仓库 URL、日志 subsystem fallback、Keychain label、数据库 schema/table 名

未完成：

- P0 页面现状截图
- P1-03 历史 880 x 650 窗口恢复的行为级测试
- P3 统一 Shell / Toolbar 深度重制
- P4 工作台真实职责重制
- P5-03 Mock Repository
- P6 Pin 顺序与非剪贴板悬浮窗能力

---

## P2 Design Tokens 与统一组件

### ACW-P2-01 收口 AcWork Design Tokens

**目标**

建立主窗口唯一 Token 来源，停止页面自行定义第二套颜色、圆角、字号和间距。

**涉及文件**

- `Design/AcMindDesignTokens.swift`
- `Features/Native/Shared/AppSurfaceStyle.swift`
- `Features/Native/Shared/WorkspaceSharedComponents.swift`
- 新增或重命名为 `Design/AcWorkDesignTokens.swift`

**任务**

- [ ] 定义 Layout：216 Sidebar、60 Toolbar、20 Padding、16 Gap、220 Filter Rail、304 Inspector。
- [ ] 定义响应式阈值 1320 和最小窗口 1180 x 720。
- [ ] 定义 Radius：16、12、10、9、18、pill。
- [ ] 定义 Spacing：4、8、12、16、20、24、32。
- [ ] 定义 Typography：24、28、15、13、11、22。
- [ ] 定义语义色：window、sidebar、surface、secondarySurface、border、primary/secondary/tertiaryText、accent、success、warning、danger。
- [ ] 主窗口优先使用系统语义色，保证深浅色和高对比度可读。
- [ ] 保留 Notch/Companion 独立暗色 Token，但禁止主窗口页面引用它。
- [ ] 标记旧 Token 为兼容层，逐页迁移后再删除。

**验收**

- 第一阶段页面只使用 AcWork 主窗口 Token。
- 没有新增页面级硬编码颜色体系。
- 常规卡片没有明显阴影。

### ACW-P2-02 实现第一阶段基础组件

**建议目录**

- 新增 `Features/Native/AcWork/Components/`

**组件任务**

- [x] `AcWorkShell`
- [x] `AcSidebar`
- [x] `AcPageToolbar`
- [x] `AcSection`
- [x] `AcCard`
- [x] `AcListRow`
- [x] `AcInspector`
- [x] `AcStatusBadge`
- [x] `AcMetric`
- [x] `AcEmptyState`
- [x] `AcSearchField`
- [x] `AcSegmentedControl`
- [x] `AcActionButton`
- [x] `AcSettingRow`
- [x] `AcPermissionRow`
- [x] `AcTrendChart`
- [x] `AcProgressRow`

**状态要求**

- [ ] Normal
- [ ] Hover
- [ ] Selected
- [ ] Disabled
- [ ] Keyboard Focus
- [ ] Loading
- [ ] Error
- [ ] Permission Required

**组件约束**

- [ ] 使用专用子 View，不把整个组件库堆进单个 Swift 文件。
- [ ] 组件通过明确参数和 Binding 接收状态，不直接读取整个 AppState。
- [x] `AcPageToolbar` 支持 title、context、primaryAction、secondaryActions、search 插槽。
- [x] `AcInspector` 支持 summary、detail、固定 footer actions。
- [x] `AcSearchField` 支持 `Cmd+F` 聚焦与清除。
- [ ] `AcEmptyState` 最多一个主要操作。
- [x] `AcSegmentedControl` 支持选择态、悬停态与禁用态。
- [x] `AcActionButton` 支持主次级样式、加载态与禁用态提示。
- [x] `AcSettingRow` 支持标题、说明和右侧控件槽位。
- [x] `AcPermissionRow` 支持状态、申请和前往设置操作。
- [x] `AcTrendChart` 作为共享趋势图入口。
- [x] `AcProgressRow` 作为共享进度条行。

**验收**

- Preview 或测试宿主可查看每个组件的主要状态。
- 组件可在工作台和收集箱复用。
- 所有交互控件具备可访问名称。

---

## P3 统一应用外壳

### ACW-P3-01 实现稳定 Root Shell

**涉及文件**

- `App/ContentView.swift`
- `Features/Sidebar/SidebarView.swift`
- `Features/Native/Shared/WorkspacePageShell.swift` 或现有 Shell 文件

**任务**

- [x] 将 `ContentView` 保持为根布局和页面组合，不承载页面业务逻辑。
- [x] 固定 Sidebar 216 pt。
- [x] 固定 Toolbar 60 pt。
- [x] Page Body 支持可选 Filter Rail、Main Content、Inspector。
- [x] 页面切换时根布局不发生整体结构替换或尺寸跳动。
- [x] 将 Toolbar 从各页面正文中上移到统一 Shell。
- [x] 页面标题只在 Toolbar 出现一次。
- [x] 保留 Voice、Capture、Quick Note Sheet。
- [ ] 收口通知路由到命名清晰的导航方法。

**验收**

- 11 张核心稿均可复用同一 Shell。
- Sidebar 和 Toolbar 切页时尺寸不变。
- 1180 x 720 无重叠和裁切。

### ACW-P3-02 重制 Sidebar

**任务**

- [ ] 品牌区高度 72 pt，显示 AcWork。
- [ ] 导航项高度 38 pt，圆角 10 pt，图标 16-18 pt。
- [ ] 分组标题 11 pt semibold。
- [ ] 选中状态为浅蓝背景和系统蓝图标。
- [ ] Hover 为浅灰背景。
- [ ] 快捷键只在 Hover 或键盘导航时提示，不永久占位。
- [ ] 移除当前每个分组外层的大卡片。
- [ ] 底部显示本地服务状态和当前模型。
- [ ] 正常状态使用中性色，小状态点可使用绿色。
- [ ] 支持键盘上下移动与激活。

**验收**

- 视觉密度接近原生 macOS source list。
- 主内容比侧边栏获得更高视觉优先级。
- 侧边栏滚动时底部状态保持可用。

### ACW-P3-03 实现响应式 Inspector

**任务**

- [x] 宽度大于等于 1320 时显示 304 pt Inspector。
- [x] 1180-1319 时隐藏固定 Inspector。
- [x] 紧凑宽度点击详情时使用右侧 Sheet 或 Overlay。
- [x] Filter Rail 在收集箱紧凑宽度下仍保留。
- [x] 高度低于 760 时收紧垂直间距，不隐藏核心操作。
- [x] Inspector 展开和关闭保持当前选中项。

**测试**

- [x] 抽取纯布局决策类型并测试 1179、1180、1319、1320 四个边界。

**验收**

- 两个规定尺寸下布局均稳定。
- Inspector 切换不导致内容选择丢失。

### ACW-P3-04 接入其他页面占位

**任务**

- [x] Agent、日程、工具台、灵动大陆、说入法、状态、模型、设置接入新 Shell。
- [x] 暂未重制页面保留现有内容，但去除重复页头。
- [x] 对暂不适配的页面提供明确占位，不制造空白区域。

**验收**

- 10 个导航目标都能打开。
- 切页无崩溃、无重复标题、无 Shell 尺寸变化。

---

## P4 工作台重制

### ACW-P4-01 建立工作台数据契约

**建议文件**

- 新增 `Features/Native/Workspace/WorkspaceDashboardModel.swift`
- 新增 `Features/Native/Workspace/WorkspaceDashboardRepository.swift`
- 新增 `Features/Native/Workspace/WorkspaceDashboardViewModel.swift`

**数据内容**

- [ ] 当前问候和当前项目
- [ ] 当前重点
- [ ] Agent 当前任务与进度
- [ ] 下一日程
- [ ] 待整理内容数量与来源分布
- [ ] 最近剪贴板与 Pin
- [ ] 最近活动
- [ ] 今日计划
- [ ] 压缩系统状态

**任务**

- [ ] 定义 Repository 协议。
- [ ] 使用真实 Service 组合数据。
- [ ] 提供 Mock Repository。
- [ ] ViewModel 明确输出 Loading、Loaded、Empty、Error。
- [ ] 避免工作台直接依赖多个 ServiceContainer 细节。

**测试**

- [ ] 数据聚合成功测试。
- [ ] 部分服务失败时降级测试。
- [ ] Empty 和 Error 状态测试。

### ACW-P4-02 实现 Focus Header

**任务**

- [ ] 高度约 140 pt，横向满宽。
- [ ] 左侧展示问候、项目、重点和一句状态摘要。
- [ ] 右侧展示快速记录、说入法、全局搜索。
- [ ] 仅快速记录使用主要按钮。
- [ ] 使用极浅蓝灰语义表面，不使用图片和强渐变。

**验收**

- 第一眼能回答“现在正在做什么”。
- 不重复 Toolbar 页面标题。

### ACW-P4-03 实现四个差异化摘要模块

**任务**

- [ ] Agent 当前任务。
- [ ] 下一日程。
- [ ] 待整理内容。
- [ ] 最近剪贴板与 Pin。
- [ ] 1500 宽度使用 4 列。
- [ ] 宽度不足时使用 2 x 2。
- [ ] 四个模块不得只是同一 Metric Card 换文案。
- [ ] 每个模块提供进入对应详情的操作。

**验收**

- 每个模块结构与信息优先级不同。
- 1180 x 720 下无横向裁切。

### ACW-P4-04 实现最近活动与今日计划

**任务**

- [ ] 主区采用左侧自适应、右侧约 320 pt。
- [ ] 最近活动最多显示 6 条。
- [ ] 活动覆盖 Agent、收集箱、日程和工具执行。
- [ ] 支持项目筛选。
- [ ] 今日计划展示日程、待办和快速操作。
- [ ] 避免卡片套卡片。

### ACW-P4-05 实现压缩系统状态条

**任务**

- [ ] 高度 44 pt。
- [ ] 展示 CPU、内存、网络、电池、温度等摘要。
- [ ] 正常项全部使用中性颜色。
- [ ] 只有异常项使用语义色。
- [ ] 点击进入状态页。
- [ ] 系统状态服务失败时显示“状态暂不可用”，不阻塞整个工作台。

### ACW-P4-06 工作台状态与验收

**任务**

- [ ] Loading 骨架或进度状态。
- [ ] 首次使用 Empty 引导。
- [ ] Error 状态和重试。
- [ ] 快速操作 Disabled 状态。
- [ ] 键盘焦点顺序。
- [ ] 1500 x 920 首屏无需滚动即可看到四层结构。
- [ ] 1180 x 720 可滚动但不裁切核心操作。

---

## P5 收集箱领域模型与 Repository

### ACW-P5-01 定义统一领域模型

**建议文件**

- 在 `AcMindKit/Models/SourceItem.swift` 增加 `CollectedItem`、`CollectionSource`、`CollectedContent`、`ProcessingStatus`（当前 Xcode 工程使用显式文件列表，先避免新增 target 文件风险）

**任务**

- [x] ID 能区分 SourceItem 与 ClipboardItem 来源，避免 ID 冲突。
- [x] 内容类型覆盖文本、链接、图片、文件、代码、富文本、视频。
- [x] 来源覆盖剪贴板、手机同步、说入法、截图/OCR、Agent、手动添加。
- [x] 状态覆盖待整理、已提炼、已归档、已导出。
- [x] 支持 Pin、收藏、标签、项目关联、来源应用和来源设备。
- [x] 定义从现有模型到领域模型的无损映射原则。

**测试**

- [x] `SourceItem` 映射测试。
- [x] 每种 `ClipboardContentType` 映射测试。
- [x] 状态兼容映射测试。
- [x] 编解码或持久化标识稳定性测试。

### ACW-P5-02 实现 Adapter

**建议文件**

- 在 `AcMindKit/Models/SourceItem.swift` 增加 `SourceItem` / `ClipboardItem` 到 `CollectedItem` 的 Adapter 初始化器（当前 Xcode 工程使用显式文件列表，先避免新增 target 文件风险）

**任务**

- [x] 映射标题、预览、来源、时间、类型和标签。
- [x] 从 SourceItem metadata 读取兼容字段。
- [x] 从 ClipboardItem 保留 sourceApp、codeLanguage、isPinned、tags。
- [x] 明确 `isFavorite` 的存储位置，避免与 Pin 混用。
- [x] 图片和文件只传递资源引用，不在列表层加载完整大文件。

### ACW-P5-03 实现 CollectedItemRepository

**建议文件**

- 在 `AcMindKit/Protocols/StorageServiceProtocol.swift` 增加 `CollectedItemRepositoryProtocol` 和 `CollectedItemRepository`（当前 Xcode 工程使用显式文件列表，先避免新增 target 文件风险）
- 新增 `AcMindKit/Services/Collection/MockCollectedItemRepository.swift`

**接口能力**

- [x] 列表、分页或限制数量。
- [x] 搜索。
- [x] 来源、类型、状态、Pin、收藏、最近使用组合筛选。
- [x] 排序。
- [x] 更新标签。
- [x] Pin / Unpin。
- [x] 收藏 / 取消收藏。
- [x] 归档。
- [x] 删除。
- [x] 保存到知识库。
- [x] 发送给 Agent。
- [x] 转任务。
- [x] 转日程。
- [x] 导出 Markdown。
- [x] 获取和操作粘贴队列。

**实现要求**

- [x] 聚合 `StorageServiceProtocol` 和 `ClipboardServiceProtocol`。
- [x] 操作按 ID 来源路由回正确服务。
- [x] ClipboardItem 不要求先复制为 SourceItem 才能展示。
- [x] 需要工作流能力时，可在 Repository 内显式转换并返回新 ID。
- [x] 单项失败不能清空整个列表。

**测试**

- [x] 两种来源合并与排序测试。
- [x] 组合筛选测试。
- [x] 更新操作路由测试。
- [x] Clipboard 转 SourceItem 测试。
- [x] 一侧服务失败时的部分结果测试。

### ACW-P5-04 收集箱 ViewModel

**建议文件**

- 在 `AcMindKit/Protocols/StorageServiceProtocol.swift` 增加 `CollectedInboxViewModel` 和 `InboxFilterState`（SwiftPM 测试 target 可直接覆盖行为；后续 UI 接入再迁移到独立文件）

**任务**

- [x] 统一管理列表、网格、选择、批量选择、搜索、筛选和排序。
- [x] 使用类型安全 Filter，不继续使用 `"all"`、`"voice"` 等字符串状态。
- [x] 支持单选详情和多选批量操作互斥。
- [x] 搜索请求可取消或防抖。
- [x] 刷新时保持有效选择。
- [x] 删除当前项后选择合理的相邻项。
- [x] Error 状态保留已加载内容并提供重试。
- [x] 第一批接入现有 `InboxView`，用 `CollectedInboxViewModel` 驱动列表、搜索、筛选、加载和错误态。
- [x] 增加 App target 桥接 Repository，使 Preview 场景和真实服务都能输出 `CollectedItem`。

**测试**

- [x] 筛选状态测试。
- [x] 列表/网格模式持久化测试。
- [x] 单选与多选切换测试。
- [x] 删除后选择测试。
- [x] 异步搜索竞态测试。
- [x] 预览场景接入测试。
- [x] 应用构建验证。

---

## P6 收集箱 UI 重制

### ACW-P6-01 实现 Filter Rail

**任务**

- [x] 固定宽度 220 pt。
- [x] 快捷视图：全部、待整理、已 Pin、已收藏、最近使用。
- [x] 来源：剪贴板、手机同步、说入法、截图与 OCR、Agent、手动添加。
- [x] 类型：文本、链接、图片、文件、代码、富文本、视频。
- [x] 状态：待整理、已提炼、已归档、已导出。
- [x] 筛选项高 34 pt。
- [x] 支持多条件组合和分项数量。
- [x] 当前条件在 Toolbar 下方显示 Filter Chips。
- [x] 支持清除单项筛选和全部清除。

**验收**

- [x] Filter Rail 不再包含“剪贴板工作区”二级页面切换。
- [x] 筛选变化不会重建整个页面。

### ACW-P6-02 实现内容操作栏

**任务**

- [x] 当前筛选摘要。
- [x] 搜索。
- [x] 排序。
- [x] 列表 / 网格切换。
- [x] 批量选择第一批：卡片级加入/移除批量选择。
- [x] 添加内容。
- [x] 剪贴板筛选激活时显示监听状态和暂停/恢复。
- [x] 粘贴队列非空时显示入口和数量。

### ACW-P6-03 实现列表视图

**任务**

- [x] 标准行高 84 pt，紧凑行高 64 pt。
- [x] 展示类型、标题、两行预览、来源、时间、状态、标签、Pin、收藏。
- [x] Hover 时显示快捷操作。
- [x] 选中状态使用极浅蓝背景。
- [x] 支持键盘上下选择、Space 预览、Delete 删除、Return 打开主要操作。
- [x] 图片和文件缩略图异步加载并缓存。

**验收**

- 100 条数据滚动无明显卡顿。
- 行高和列对齐稳定。

### ACW-P6-04 实现网格视图

**任务**

- [x] 卡片宽度 240-300 pt，高度 188 pt。
- [x] 图片展示缩略图。
- [x] 链接展示站点图标、标题、摘要。
- [x] 代码使用等宽字体和语言标签第一批：等宽预览已接入，语言来自现有标题/预览数据。
- [x] 文件展示图标、名称和大小。
- [x] 文本最多展示 5 行。
- [x] 底部固定元信息区域第一批：来源、时间、应用和标签。
- [x] 1180 宽度下至少两列。

### ACW-P6-05 实现 Inspector

**无选中项**

- [x] 总数量。
- [x] 待整理数量。
- [x] Pin 数量。
- [x] 手机同步状态第一批：显示当前筛选列表中的手机同步数量。
- [x] 粘贴队列数量第一批：显示可加入粘贴队列的剪贴板项数量。

**有选中项**

- [x] 完整内容或安全预览第一批：文本、链接、文件、代码、富文本等使用安全文本预览。
- [x] 来源、应用/设备、创建时间、类型、标签、项目。
- [x] AI：自动标题、摘要、提取待办、提取日程、润色和发送给 Agent 均已接通。
- [x] 去向：转任务、添加到日程、保存到知识库、导出 Markdown、归档、删除、保存剪贴板和加入粘贴队列均已接可执行操作。
- [x] 底部固定主要操作区。
- [x] 操作进行中显示单项进度和 Disabled 状态。

**紧凑宽度**

- [x] 通过右侧 Sheet 或 Overlay 展示相同内容。

### ACW-P6-06 实现 Pin 与粘贴队列

**任务**

- [ ] Pin 作为所有 CollectedItem 的通用能力。
- [x] 支持显示全部、隐藏全部、关闭全部。
- [ ] 支持 Pin 顺序调整。
- [x] 队列仅在非空时显示。
- [x] 支持顺序调整、单项移除、清空和连续粘贴第一批：当前使用上下移动按钮调整顺序。
- [x] 保留现有 ClipboardPinWindowManager 行为。
- [x] UI 迁移不改变 Pin 窗口持久化和关闭语义。

### ACW-P6-07 实现批量操作

**任务**

- [x] 添加标签。
- [x] 发送给 Agent。
- [x] 转任务。
- [x] 转日程。
- [x] 归档。
- [x] 导出。
- [x] 删除。
- [x] 加入粘贴队列。
- [x] 退出批量选择。
- [x] 批量删除必须二次确认。
- [x] 部分失败时显示成功数、失败数和可重试项。

### ACW-P6-08 移除旧页面组合

**涉及文件**

- `Features/Native/Shared/CaptureWorkspaceView.swift`
- `Features/Native/Inbox/InboxView.swift`
- `Features/Native/Clipboard/ClipboardView.swift`

**任务**

- [x] 新收集箱稳定后，删除 `CaptureWorkspaceView.Mode` 页面切换。
- [x] `ClipboardView` 中可复用能力拆为组件或迁入统一收集箱。
- [x] 不删除底层 ClipboardService、Pin Manager 和 PasteQueue。
- [x] 清理旧 `.clipboard` 页面路由和重复页头。

**验收**

- 用户只看到一个收集箱页面。
- 剪贴板能力没有丢失。

---

## P7 状态、交互与可访问性收口

### ACW-P7-01 页面状态矩阵

| 页面 | Loading | Empty | Error | Disabled | Permission |
|---|---|---|---|---|---|
| Shell | N/A | N/A | 服务状态 | 导航项 | N/A |
| 工作台 | 必须 | 必须 | 必须 | 快速操作 | 状态摘要 |
| 收集箱 | 必须 | 必须 | 必须 | 操作 | 来源能力 |
| Inspector | 单项进度 | 无选择 | 操作失败 | 动作 | AI/日历等 |

**任务**

- [x] 每种状态使用统一组件。
- [x] Error 不用空白页替代。
- [x] Disabled 必须解释原因。
- [x] Permission Required 提供系统设置入口。

### ACW-P7-02 键盘与菜单

**任务**

- [x] `Cmd+F` 聚焦当前页面搜索。
- [x] `Cmd+1...` 导航快捷键无冲突。
- [x] Escape 退出批量选择或关闭当前快速预览。
- [x] Delete 删除当前项并按危险操作规则确认。
- [x] Sidebar、Toolbar、内容区和 Inspector 焦点顺序正确。
- [x] 主要导航操作可通过菜单和快捷键发现。

### ACW-P7-03 可访问性

**任务**

- [x] 图标按钮提供 accessibility label。
- [x] 状态不仅依赖颜色表达。
- [x] 支持 Increase Contrast。
- [x] 文本在系统字体放大后不截断关键操作。
- [x] 装饰图片对辅助技术隐藏。
- [x] 列表和网格项提供合并后的可读描述。

### ACW-P7-04 性能与稳定性

**任务**

- [x] 列表使用 Lazy 容器。
- [x] 缩略图按需加载。
- [x] 搜索和筛选不在 View body 中重复执行重计算。
- [x] ViewModel 任务在页面退出或查询变化时可取消。
- [x] 系统状态轮询在工作台离开后停止或降频。
- [x] 视图切换不重复启动剪贴板监听。

---

## P8 测试、截图与发布验收

### ACW-P8-01 单元测试

**必须覆盖**

- [x] 导航顺序和旧路由兼容。
- [x] 窗口布局边界。
- [x] CollectedItem Adapter。
- [x] Repository 聚合、筛选、排序和操作路由。
- [x] 收集箱 ViewModel 状态。
- [x] 工作台 Repository 和状态。
- [x] Pin、收藏和粘贴队列不回归。
- [x] 数据迁移和旧数据库读取不回归。

**命令**

```bash
swift test --parallel
```

### ACW-P8-02 构建验收

**命令**

```bash
bash scripts/build.sh
```

**验收**

- [x] Debug 构建成功。
- [ ] 无新增 Swift 编译警告。
- [ ] 主窗口启动成功。
- [ ] 设置窗口、灵动大陆和 Pin 窗口仍可打开。

### ACW-P8-03 必须输出的截图

- [x] `1500x920-workspace-populated.png`
- [x] `1500x920-inbox-list.png`
- [x] `1500x920-inbox-grid.png`
- [x] `1180x720-workspace.png`
- [x] `1180x720-inbox.png`
- [x] `workspace-loading.png`
- [x] `workspace-empty.png`
- [x] `workspace-error.png`
- [x] `inbox-loading.png`
- [x] `inbox-empty.png`
- [x] `inbox-error.png`

**截图要求**

- 固定 Mock 数据和日期。
- 不包含用户隐私内容。
- 与参考图逐页对照 Sidebar、Toolbar、间距、层级和信息密度。

### ACW-P8-04 手工回归清单

- [ ] 从菜单打开工作台、Agent、收集箱和日程。
- [ ] 旧剪贴板快捷入口进入收集箱剪贴板筛选。
- [ ] 复制文本后收集箱能看到新项目。
- [ ] 暂停和恢复剪贴板监听。
- [ ] Pin、隐藏、显示和关闭窗口。
- [ ] 添加并执行粘贴队列。
- [ ] 收集项转 Agent、任务、日程和 Markdown。
- [ ] 窗口从 1500 x 920 缩到 1180 x 720。
- [ ] 1320 阈值前后 Inspector 正确切换。
- [ ] 重启后窗口、视图模式和筛选偏好符合预期。
- [ ] 旧数据仍能读取。

## 6. 第一阶段完成定义

只有同时满足以下条件，Phase 1 才算完成：

- [ ] 用户可见品牌已统一为 AcWork。
- [ ] 主导航与规范一致，剪贴板不再是一级页面。
- [ ] 所有主页面复用统一 Shell。
- [ ] 工作台按四层结构完成，不再以系统监控为核心。
- [ ] 收集箱统一展示所有来源。
- [ ] 收集箱支持列表、网格、组合筛选、Inspector 和批量操作。
- [ ] Pin、收藏、手机同步入口和粘贴队列可用。
- [ ] 1500 x 920 和 1180 x 720 布局稳定。
- [ ] Loading、Empty、Error 状态完整。
- [ ] 所有新增测试通过。
- [ ] 全量 `swift test --parallel` 没有新增失败。
- [ ] `bash scripts/build.sh` 成功。
- [ ] 必需截图已输出并完成逐页比对。
- [ ] 旧数据目录和数据库仍可读取。

## 7. 明确不在第一阶段完成

- Agent 页面完整重制。
- 日程页面完整重制。
- 工具台完整重制。
- 灵动大陆完整重制。
- 说入法完整重制。
- 状态、模型、设置页面完整重制。
- `AcMindKit` 模块和 Xcode Target 的整体改名。
- Bundle ID 迁移。
- 数据库文件和旧数据目录改名。
- `AcMind.*` 通知原始值的一次性替换。
- 删除旧数据库表。

## 8. 推荐执行批次

### 批次 A：基础与外壳

`ACW-P0-01` -> `ACW-P1-01` -> `ACW-P1-02` -> `ACW-P1-03` -> `ACW-P2-01` -> `ACW-P2-02` -> `ACW-P3-*`

### 批次 B：数据统一

`ACW-P0-02` -> `ACW-P5-01` -> `ACW-P5-02` -> `ACW-P5-03` -> `ACW-P5-04`

### 批次 C：核心页面

`ACW-P4-*` 与 `ACW-P6-*`

### 批次 D：收口

`ACW-P7-*` -> `ACW-P8-*`

## 9. 首个实施任务

从 `ACW-P0-01` 开始：

1. 固化当前测试和构建基线。
2. 保存现有三个核心页面截图。
3. 确认旧数据和窗口恢复路径。
4. 再开始导航与品牌迁移。
