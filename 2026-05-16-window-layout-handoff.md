# AcMind 窗口与布局交接记录

日期：2026-05-16

## 当前目标

你提到的两个问题是同一类布局问题：

1. 窗口缩小后，一级菜单优先级不够高，容易被挤掉或显示不完整。
2. Agent 页面在小显示器上没有自适应，内容区会被硬挤，影响阅读。

这次处理方向应当是“统一修复窗口壳和二级页面壳”，而不是只改某一个页面。

## 已经确认的关键信息

### 1. 主窗口最小尺寸现在过于宽松

文件：

- [App/AppDelegate.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/App/AppDelegate.swift)

已看到：

- `MainWindowController` 里当前 `window.minSize = NSSize(width: 120, height: 300)`
- `AppWindowGeometry.mainFrame` 仍然是 `1200 x 800`

这意味着窗口可以被缩得非常窄，导致侧边栏和内容区按系统默认方式一起被压缩，而不是保住一级菜单。

### 2. 一级菜单在 `AppShell` 中是固定宽度，但内容区没有明确的响应式退让策略

文件：

- [App/ContentView.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/App/ContentView.swift)

已看到：

- `AppShell` 里 primary rail 宽度固定为 `88` 或 `220`
- 主内容区通过 `ScrollView` 承接，但没有专门的窄宽度布局切换
- 结果是窗口变窄时，内容区会先被压缩，视觉上像是一级菜单“被挤坏了”

### 3. 二级工作台壳是统一入口

文件：

- [Shared/DesignSystem/ACWorkspaceShell.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACWorkspaceShell.swift)
- [Shared/DesignSystem/ACSettingsShell.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACSettingsShell.swift)
- [Shared/DesignSystem/ACSecondaryPageShell.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACSecondaryPageShell.swift)

已确认这些壳被多个页面共用：

- `ACWorkspaceShell`：Agent、Inbox、Clipboard、Workbench、Schedule
- `ACSettingsShell`：SettingsSuite
- `ACSecondaryPageShell`：Tools、DynamicSurfaceSettings、Companion

所以如果把这几个壳做成响应式，能一次性覆盖大多数二级界面。

### 4. Agent 页面目前是硬三栏布局

文件：

- [Features/Native/Agent/AgentWorkspaceView.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Features/Native/Agent/AgentWorkspaceView.swift)

已看到：

- 左栏、中心栏、右栏全部按固定宽度思路在排版
- 右侧详情栏使用了 `ACLayout.inspectorWidth`
- 中心区域至少有 `minHeight: 420`
- `ACWorkspaceShell` 自身也在用固定的左右栏尺寸

这就是小屏下不自适应的直接原因。

### 5. 设计常量里已经有一套未被利用的窗口尺寸

文件：

- [Shared/DesignSystem/ACLayout.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACLayout.swift)

已看到：

- `windowMinWidth = 1440`
- `windowMinHeight = 900`
- `workspaceLeftPanel = 360`
- `workspaceMainMin = 520`
- `inspectorWidth = 320`

这些常量目前没有真正接到窗口最小尺寸逻辑里。

## 当前仓库状态提醒

我离开前查看到工作区已经有一批未提交改动，不是空仓：

- `App/ContentView.swift`
- `App/AppDelegate.swift`
- `Shared/DesignSystem/ACLayout.swift`
- `Features/Native/Agent/AgentWorkspaceView.swift`
- `Features/Native/Settings/SettingsSuiteView.swift`
- 以及多个其他页面和设计系统文件

还有一些新文件已经出现，但是否全部属于同一轮改动需要你接手时再确认：

- `Shared/DesignSystem/ACWorkspaceShell.swift`
- `Shared/DesignSystem/ACSettingsShell.swift`
- `Shared/DesignSystem/ACSecondaryPageShell.swift`
- `Shared/DesignSystem/ACFrostedCard.swift`

结论：这是一个脏工作树，继续前请先 `git status` 看一下，不要误回退别人的内容。

## 推荐的下一步实现方案

### 目标

把布局规则统一成：

- 一级菜单优先级最高
- 主窗口缩小时，先压缩内容区，再保护一级菜单
- 二级工作台在小屏时自动从三栏切换到双栏或单栏
- 所有复用壳都遵循同一套断点和最小宽度规则

### 建议拆分

1. 先在 `ACLayout` 里补一组响应式断点和最小宽度计算。
2. 给 `ACWorkspaceShell`、`ACSettingsShell`、`ACSecondaryPageShell` 加响应式布局分支。
3. 视情况调整 `MainWindowController` 的 `minSize`，不要再允许窗口小到把一级菜单挤坏。
4. 如果 Tools / Settings / Agent 还有固定网格或固定列宽，再按断点收窄列数。

## 建议测试点

后续最好补几类测试：

- 窗口最小尺寸/断点常量是否符合预期
- Workspace 壳在窄宽度下是否切到单列或双列
- Settings 壳在窄宽度下是否还能保住侧栏
- Agent 页面是否不再依赖固定三栏宽度

## 如果你要继续做

建议你下一步先从这三个文件开始：

1. [Shared/DesignSystem/ACLayout.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACLayout.swift)
2. [Shared/DesignSystem/ACWorkspaceShell.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACWorkspaceShell.swift)
3. [App/AppDelegate.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/App/AppDelegate.swift)

这样能最快把“一级菜单优先级最高”和“Agent 小屏自适应”一起打通。
