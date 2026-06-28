# AcWork 工作台组件映射

本表只记录当前真实工程结构中的组件，不按设计稿臆测。当前主路径是 `AcMindApp -> MainWindowController -> ContentView -> MainContent(.home) -> WorkspaceHomeView`。

## 组件映射

| 组件名称 | Swift 文件路径 | 父级组件 | 固定尺寸 | GeometryReader | ScrollView | 重复组件或重复菜单 |
|---|---|---|---|---|---|---|
| `AcMindApp` | `../../App/AcMindApp.swift` | 无，应用入口 | 否 | 否 | 否 | 否 |
| `MainWindowController` | `../../App/AppDelegate.swift` | `AppDelegate` | 是，窗口默认 1500×920 | 否 | 否 | 否 |
| `ContentView` | `../../App/ContentView.swift` | `MainWindowController` | 是，根视图最小 1180×720 | 否 | 否 | 否 |
| `AcSidebar` | `../../Features/Native/Shared/AppSurfaceStyle.swift` | `ContentView` | 否 | 否 | 否 | 否 |
| `SidebarView` | `../../Features/Sidebar/SidebarView.swift` | `AcSidebar` | 是，宽度 216 / 折叠 84 | 否 | 是 | 否。`SidebarItem` 数据源没有重复追加 |
| `SidebarItemRow` | `../../Features/Sidebar/SidebarView.swift` | `SidebarView` | 否，行高由内容+padding 决定 | 否 | 否 | 否 |
| `SidebarCompactItemRow` | `../../Features/Sidebar/SidebarView.swift` | `SidebarView` | 否，折叠态菜单项 | 否 | 否 | 否 |
| `MainContent` | `../../App/ContentView.swift` | `ContentView` | 否 | 否 | 否 | 否 |
| `WorkspaceHomeView` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `MainContent(.home)` | 否 | 是 | 是 | 否 |
| `greetingHeader` / `TopToolbar` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否，实际由内容撑开 | 否 | 否 | 否 |
| `homePrimaryDeck` / `WorkOverviewCard` / `RightStatusRail` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否，左卡和右栏为并排自适应布局 | 否 | 否 | 否 |
| `overviewRow` / `RuntimeOverviewCard` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否 | 否 | 否 | 否 |
| `kpiRow` / `MetricsGrid` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否 | 否 | 否 | 否 |
| `summaryFooter` / `BottomSummary` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否 | 否 | 否 | 否 |
| `workspaceClosingBoard` / `CurrentRhythm` | `../../Features/Native/Home/WorkspaceHomeView.swift` | `WorkspaceHomeView` | 否 | 否 | 否 | 否 |
| `AcWorkShell` | `../../Features/Native/Shared/AppSurfaceStyle.swift` | 共享壳层组件 | 否 | 是 | 否 | 否。它和 `ContentView` 共享同一套调试标签，但当前首页路径未直接使用它 |
| `AcPageToolbar` | `../../Features/Native/Shared/AppSurfaceStyle.swift` | `AcWorkShell` | 否 | 否 | 否 | 否 |
| `LayoutDebugOverlay` | `../../Features/Native/Shared/AppSurfaceStyle.swift` | Debug 运行层 | 否 | 否 | 否 | 否 |

## 菜单与重复性核对

- `SidebarItem.coreWorkflow`、`processingItems`、`companionCapabilities`、`systemItems` 是当前侧栏的唯一菜单数据源。
- `ForEach(items)` 在 `SidebarView` 中只使用一次，没有看到重复嵌套追加。
- `SidebarItem.shortcutItems` 只在 `CommandMenu("导航")` 中使用一次。
- `modelManagement` 只在 `systemItems` 中出现一次，但它会在不同上下文里被渲染为同一个文案 `模型`，例如侧栏、命令菜单、页面标题和侧栏底部状态文案。这更像“文案复用”，不是数据重复。

## 关键来源

- 侧栏固定宽度与滚动容器：`../../Features/Sidebar/SidebarView.swift:17-28`
- 首页滚动根与调试标签：`../../App/ContentView.swift:35-80`
- 首页实际区块：`../../Features/Native/Home/WorkspaceHomeView.swift:167-185`、`:234-370`、`:638-903`
- 共享调试壳：`../../Features/Native/Shared/AppSurfaceStyle.swift:16-150`、`:165-270`
- 菜单枚举：`../../AcMindKit/Models/SidebarItem.swift:32-174`

