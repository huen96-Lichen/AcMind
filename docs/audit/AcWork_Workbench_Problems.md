# AcWork 工作台问题清单

本文件只写结论，不修改视觉设计。

## 1. 中间大面积空白

结论：

- 空白不是由单独的 `Spacer()` 直接制造出来的。
- 真实来源是 `WorkspaceHomeView` 中 `homePrimaryDeck` 的横向布局。
- 左侧 `WorkOverviewCard` 高度约 408px，右侧 `RightStatusRail` 约 598px，`HStack` 的行高被右侧更高的列撑大。
- 左侧卡片没有使用 `fillHeight` 去补齐这 190px 的高度差，所以会在它下方留下空白。
- 由于外层又包了一层 `ScrollView`，并且 `VStack` 使用了 `frame(minHeight: proxy.size.height)`，这个空白会被保留成滚动内容的一部分，而不会自动折叠。

可消除空白的约束点：

- 优先检查 `WorkspaceHomeView.homePrimaryDeck` 的右侧栏固定/半固定高度。
- 如需彻底消除空白，最直接的是让左侧卡片与右侧栏脱离同一行高驱动，或者去掉 `WorkspaceHomeView` 根 `VStack` 的 `minHeight: proxy.size.height` 约束。
- 另一个可选方向是把右侧状态栏改成内部滚动区，而不是让它决定整个 `HStack` 高度。

## 2. 系统监控区域被推到底部

结论：

- 不是 `system monitoring` 自己在往下推，而是首页内容从上到下顺序排列，前面的 `homePrimaryDeck` 先占掉了大量垂直空间。
- `overviewRow`、`kpiRow`、`infoRow`、`sensorRow`、`summaryFooter`、`workspaceClosingBoard` 都在同一个滚动 `VStack` 里顺序渲染。
- 因为最上方行高被右栏撑大，后续的监控区块自然整体下移。

## 3. “模型”菜单看起来重复

结论：

- 没有发现 `SidebarItem` 数据被重复追加。
- `SidebarItem.systemItems` 只包含一次 `modelManagement`。
- `SidebarItem.shortcutItems` 也只包含一次 `modelManagement`。
- `SidebarView` 的 `ForEach` 没有重复嵌套。

更可能的原因：

- 同一个文案 `模型` 被多个界面复用：
  - 侧栏系统区条目
  - 顶部命令菜单
  - `MainContent(.modelManagement)` 的页面标题
  - 侧栏底部状态里“模型 · xxx”的文案
- 因此截图里看起来像“重复模型”，实际是跨位置的文案复用，不是列表重复。

## 4. 滚动与留白的结构原因

- `SidebarView` 自己就是 `ScrollView`，这是固定成立的。
- `WorkspaceHomeView` 也是 `ScrollView`。
- 首页滚动区使用了 `GeometryReader`，再把内部 `VStack` 绑定到 `proxy.size.height` 的最小高度。
- 这意味着内容不足时也会撑满高度，内容过多时又会进入滚动态，所以空白更容易被“保留”为视觉留白。

## 5. 当前审计状态

- 已确认默认窗口尺寸与最小窗口尺寸。
- 已确认一级菜单真实宽高与布局来源。
- 已确认主区域 frame。
- 已确认调试层可以显示实时尺寸。
- 已导出截图和 JSON。
- 当前未修改视觉设计。

