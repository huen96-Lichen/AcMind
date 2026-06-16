# AcWork 工作台当前 Tokens

本文件整理当前页面中可见的硬编码值和通用设计 Token，并标记其来源类型。

## 分类说明

- `固定常量`：直接写死在 Swift 代码里的值。
- `系统默认`：来自 `NSColor`、系统样式或 macOS 默认窗口行为。
- `动态计算`：根据时间、状态、数据快照即时生成。
- `GeometryReader 计算`：依赖父容器实时尺寸。
- `父容器继承`：继承上层 `frame` / `padding` / `Spacer` 结果。

## 尺寸

| Token | 值 | 来源 |
|---|---:|---|
| 侧栏宽度 | 216 | 固定常量，`AppSurfaceTokens.Layout.sidebarWidth` |
| 折叠侧栏宽度 | 84 | 固定常量，`SidebarView` |
| 顶部栏高度 | 60 | 固定常量，`AppSurfaceTokens.Layout.toolbarHeight` |
| 左侧筛选栏宽度 | 220 | 固定常量，`AppSurfaceTokens.Layout.leadingRailWidth` |
| 右侧状态栏宽度 | 304 | 固定常量，`AppSurfaceTokens.Layout.trailingRailWidth` |
| 页面最大宽度 | 1240 | 固定常量，`AppSurfaceTokens.Layout.pageMaxWidth` |
| 最小窗口宽度 | 1180 | 固定常量 |
| 最小窗口高度 | 720 | 固定常量 |
| 卡片图标尺寸 | 30×30 / 32×32 / 44×44 | 固定常量，分散在各卡片实现中 |
| 搜索框尺寸 | 128×23.5 | 固定常量，`WorkspaceHomeView.topSearchField` |
| 主卡最小高度 | 144 / 52 / 50 等 | 固定常量，来自各卡片内容区 |
| 按钮高度 | 32 | 固定常量，`AppSurfaceTokens.Layout.buttonHeight` |

## 间距

| Token | 值 | 来源 |
|---|---:|---|
| 页面外边距 | 20 | 固定常量，`AppSurfaceTokens.Spacing.lg` |
| 侧栏内边距 | 12 / 14 | 固定常量，`SidebarView` |
| 内容区内边距 | 14 | 固定常量，`WorkspaceHomeView` |
| 卡片间距 | 12 / 14 / 8 / 3.5 | 固定常量，分散在页面各 `VStack` / `HStack` |
| 分组间距 | 16 / 12 / 10 | 固定常量，`AppSurfaceTokens.Spacing.md/sm` 及局部写死值 |
| 文本行间距 | 3 / 4 / 6 / 8 | 固定常量，局部 `VStack` spacing |
| 侧栏与内容间距 | 1 | 固定常量，`Divider` 占位 |

## 样式

| Token | 值 | 来源 |
|---|---:|---|
| 大卡片圆角 | 16 | 固定常量，`AppSurfaceTokens.Radius.main` |
| 卡片圆角 | 12 | 固定常量，`AppSurfaceTokens.Radius.card` |
| 小块圆角 | 10 | 固定常量，`AppSurfaceTokens.Radius.section` |
| 控件圆角 | 9 | 固定常量，`AppSurfaceTokens.Radius.control` |
| 侧栏圆角 | 18 | 固定常量，`AppSurfaceTokens.Radius.sidebar` |
| 按钮/胶囊圆角 | 999 | 固定常量，`AppSurfaceTokens.Radius.pill` |
| 边框宽度 | 1 | 固定常量，几乎所有卡片 stroke 都是 1 |
| 阴影参数 | `radius: 2, x: 0, y: 1` | 固定常量 |
| 背景透明度 | `0.96` / `0.95` / `0.90` / `0.88` | 固定常量 |

## 字体

| Token | 值 | 来源 |
|---|---:|---|
| 页面标题 | 24 | 固定常量，`AppSurfaceTokens.Typography.pageTitle` |
| 页面副标题 | 13 | 固定常量 |
| 区域标题 | 15 | 固定常量，`AppSurfaceTokens.Typography.sectionTitle` |
| 卡片标题 | 14 | 固定常量，`AppSurfaceTokens.Typography.cardTitle` |
| 正文 | 13 | 固定常量，`AppSurfaceTokens.Typography.body` |
| 辅助文字 | 11 / 12 / 12.75 | 固定常量，分散在页面局部 |
| 数据大字 | 18 / 19.5 / 28 | 固定常量，页面局部写死 |
| 标签文字 | 8 / 9 / 9.5 / 10 | 固定常量 |

## 当前页面里最值得关注的硬编码值

- `WorkspaceHomeView.greetingHeader`：
  - 标题字号 17.5
  - 副标题字号 8
  - 顶部按钮间距 3
  - 搜索框宽高 128×23.5
- `homePrimaryDeck`：
  - 左右栏间距 14
  - 右侧状态栏最大宽度 332
- `overviewRow`：
  - 卡片间距 3.5
  - 左侧运行概览最小高度 144
  - 右侧进程卡最大宽度 278
  - 右侧提醒卡最大宽度 184
- `kpiRow`：
  - 5 列网格，间距 3.5
- `summaryFooter`：
  - 外层 padding 1.5
- `SidebarView`：
  - 展开态标题区 12px 间距，内边距 12/14
  - 菜单行内边距 9×7
  - 图标底块 26×26

## 来源归类总览

- `固定常量`：当前占绝大多数。
- `系统默认`：AppKit 默认色彩与窗口风格占少量。
- `动态计算`：例如 greeting 文本、系统状态文案、运行图表曲线。
- `GeometryReader 计算`：例如 `WorkspaceHomeView` 的根滚动区域尺寸。
- `父容器继承`：例如 `ContentView` 根内容区和侧栏宽度由父容器及根窗口决定。

