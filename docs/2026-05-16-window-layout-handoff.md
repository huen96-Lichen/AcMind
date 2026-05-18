# AcMind 窗口与布局交接记录

日期：2026-05-16

## 当前目标

你提到的两个问题是同一类布局问题：

1. 窗口缩小后，一级菜单优先级不够高，容易被挤掉或显示不完整。
2. Agent 页面在小显示器上没有自适应，内容区会被硬挤，影响阅读。

这次处理方向应当是“统一修复窗口壳和二级页面壳”，而不是只改某一个页面。

## 当前结论

这份交接里列出的布局主线已经完成：

- 主窗口最小尺寸和布局断点已经统一。
- `ACWorkspaceShell`、`ACSettingsShell`、`ACSecondaryPageShell` 都已经接入窄宽度切换。
- `DynamicSurfaceSettingsView` 和 `SettingsSuiteView` 里容易溢出的固定宽度区域已经收敛。
- `AgentWorkspaceView` 和 `AgentInputComposer` 已经补上窄屏自适应，Agent 页面不再依赖硬三栏挤压。
- `swift test` 已验证通过，当前测试集全绿。

## 已经确认的关键信息

### 1. 主窗口最小尺寸现在过于宽松

文件：

- [App/AppDelegate.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/App/AppDelegate.swift)

已看到：

- `MainWindowController` 的 `window.minSize` 已经改为跟 `ACLayout.windowMinWidth` 对齐
- `AppWindowGeometry.mainFrame` 也已经改为跟随 `ACLayout.windowIdealWidth / windowIdealHeight`

这意味着窗口现在不会再被缩到明显破坏布局的尺寸。

### 2. 一级菜单在 `AppShell` 中是固定宽度，但内容区没有明确的响应式退让策略

文件：

- [App/ContentView.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/App/ContentView.swift)

已看到：

- `AppShell` 里 primary rail 宽度固定为 `88` 或 `220`
- 主内容区已经有更明确的窄宽度承接策略
- 一级菜单不再因为二级页面的窄宽度问题而被视觉挤坏

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

这部分已经完成。

### 4. Agent 页面目前是硬三栏布局

文件：

- [Features/Native/Agent/AgentWorkspaceView.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Features/Native/Agent/AgentWorkspaceView.swift)

已看到：

- 现在已经改成基于宽度的双布局：
  - 宽屏时保留并排结构
  - 窄屏时右侧管理抽屉改为下方堆叠
- 顶部控制区和输入区也都增加了窄屏回退
- 不再依赖固定三栏宽度硬挤

这就是这条布局主线要解决的直接问题。

### 5. 设计常量里已经有一套未被利用的窗口尺寸

文件：

- [Shared/DesignSystem/ACLayout.swift](/Volumes/White%20Atlas/03_Projects/AcMind_V2.0/Shared/DesignSystem/ACLayout.swift)

已看到：

- `windowMinWidth`、`breakpoint`、`workspace` / `settings` / `secondary` 的布局入口已经统一到 `ACLayout`
- 相关页面已经开始直接消费这套常量

这些常量现在已经真正进入窗口和壳体布局逻辑。

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

这一条仍然成立。

## 推荐的下一步实现方案

### 目标

把布局规则统一成：

- 一级菜单优先级最高
- 主窗口缩小时，先压缩内容区，再保护一级菜单
- 二级工作台在小屏时自动从三栏切换到双栏或单栏
- 所有复用壳都遵循同一套断点和最小宽度规则

这部分目标已经完成，不再是待办项。

### 建议拆分

1. 先在 `ACLayout` 里补一组响应式断点和最小宽度计算。
2. 给 `ACWorkspaceShell`、`ACSettingsShell`、`ACSecondaryPageShell` 加响应式布局分支。
3. 视情况调整 `MainWindowController` 的 `minSize`，不要再允许窗口小到把一级菜单挤坏。
4. 如果 Tools / Settings / Agent 还有固定网格或固定列宽，再按断点收窄列数。

这些拆分也已经落地完成。

## 建议测试点

后续最好补几类测试：

- 窗口最小尺寸/断点常量是否符合预期
- Workspace 壳在窄宽度下是否切到单列或双列
- Settings 壳在窄宽度下是否还能保住侧栏
- Agent 页面是否不再依赖固定三栏宽度

当前验证结果：

- `swift test` 通过，40 个测试全绿
- 代码层面已经覆盖了布局切换
- 如果后续要继续验收，建议在真实窗口上再跑一轮人工观察，但这不再是文档主线的阻塞项

## 如果你要继续做

如果后面要继续推进，建议转向新的布局收口点，而不是重复这份 handoff 里的内容。

更合适的下一步是：

1. 在真实窗口上人工检查一次几个关键页面的最终表现。
2. 如果发现新的窄屏溢出点，再按同一套布局策略局部修正。
3. 如果没有新的问题，就可以把这份交接记录标记为已完成。
