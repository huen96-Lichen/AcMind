# AcWork 工作台当前布局审计

本文件只记录当前运行态的真实布局，不做视觉重构建议。

## 窗口与根布局

| 项目 | 当前值 | 来源文件 |
|---|---|---|
| 默认窗口宽度 | 1500 | `/Volumes/White Atlas/03_Projects/AcMind/App/AcMindApp.swift:11-18` |
| 默认窗口高度 | 920 | `/Volumes/White Atlas/03_Projects/AcMind/App/AcMindApp.swift:11-18` |
| 最小窗口宽度 | 1180 | `/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift:70-81`，`/Volumes/White Atlas/03_Projects/AcMind/App/ContentView.swift:74-79`，`/Volumes/White Atlas/03_Projects/AcMind/App/AppDelegate.swift:2515-2520` |
| 最小窗口高度 | 720 | 同上 |
| 最大窗口宽度 | 未显式设置 | 未设置 `maxWidth` / `windowResizability` |
| 最大窗口高度 | 未显式设置 | 未设置 `maxHeight` / `windowResizability` |
| 根视图实际宽度 | 1500 | 运行时测量，`contentLayoutRect` |
| 根视图实际高度 | 888 | 运行时测量，`contentLayoutRect` |
| 标题栏占用高度 | 32 | 运行时测量，`frame.height - contentLayoutRect.height` |
| 安全区域顶部 | 32 | 运行时测量，`contentLayoutRect.minY` 相对内容区域 |

说明：

- 默认窗口定义来自 `Settings.defaultSize(width: 1500, height: 920)`。
- `MainWindowController` 使用 `NSWindow(contentRect: width: 1500, height: 920, ...)`。
- `AppWindowGeometry.minimumContentSize` 为 1180×720；`ContentView` 也用这组值约束根视图。

## 主要区域坐标

以下坐标统一以窗口内容区域左上角为原点，来自 `docs/audit/AcWork_Workbench_Runtime_Frames.json`。

| 区域 | X | Y | 宽度 | 高度 |
|---|---:|---:|---:|---:|
| 左侧导航 | 0 | 0 | 216 | 960 |
| 顶部工具栏 | 231 | 14 | 1203 | 31 |
| 主内容区域 | 217 | 0 | 1223 | 960 |
| 工作总览卡片 | 231 | 57 | 1079 | 408 |
| 中间空白区域 | 231 | 465 | 1079 | 273 |
| 右侧状态栏 | 1324 | 57 | 118 | 598 |
| 运行概览区域 | 231 | 738 | 987 | 194 |
| 底部状态区域 | 231 | 1403 | 1203 | 74 |

补充说明：

- `TopToolbar` 的顶部偏移 14 来自首页容器的 `padding(.vertical, 14)`。
- `WorkbenchContent` 的左起点为 217，来源是 `216px` 侧栏宽度加 `1px` 分隔线。
- `WorkOverviewCard` 与 `RightStatusRail` 同处 `HStack(alignment: .top, spacing: 14)`，但右栏更高，导致该行整体高度被右栏驱动。

## 运行时框架数据

`/Volumes/White Atlas/03_Projects/AcMind/docs/audit/AcWork_Workbench_Runtime_Frames.json`

核心数据如下：

```json
{
  "window": {
    "width": 1440,
    "height": 960
  }
}
```

同一份 JSON 中还记录了主要组件的实际 frame，便于后续做对齐和回归比较。

## 空白来源结论

- 当前页面中，`WorkOverviewCard` 下方的大面积空白不是单独的 `Spacer()` 造成的，而是 `homePrimaryDeck` 这一行的高度被右侧 `RightStatusRail` 撑高了。
- 左侧 `WorkOverviewCard` 只有 408px 高，右侧 `RightStatusRail` 约 598px，高差约 190px。左卡片所在列没有补齐高度，所以卡片底部到行底之间会留白。
- `WorkspaceHomeView` 外层又使用了 `ScrollView` + `VStack` + `frame(minHeight: proxy.size.height)`，因此这段空白不会被压缩，而是保留成可滚动内容的一部分。
- 结论上，“中间大面积空白”由 `homePrimaryDeck` 的右栏驱动行高，再叠加滚动容器的最小高度约束共同形成。

## 截图产物

已导出到：

- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-min-normal.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-min-debug.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-default-normal.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-default-debug.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-1440x960-normal.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-1440x960-debug.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-1728x1117-normal.png`
- `/Volumes/White Atlas/03_Projects/AcMind/docs/audit/screenshots/workbench-1728x1117-debug.png`

