# Workbench V2 HTML Prototype

## 设计目标

这是一份基于现有 `WorkbenchV2` 骨架制作的正式 HTML 视觉原型，用作后续 SwiftUI 重构的唯一视觉基准。

## 画布尺寸

- 标准内容画布：`1500 × 888`
- 紧凑预览尺寸：`1180 × 720`

## 布局尺寸

- 左侧栏：`216px`
- 分隔线：`1px`
- 主内容区：`1283px`
- 主内容内边距：`24 / 24 / 20 / 20`
- 顶部栏：`48px`
- 主体区：`927px + 16px + 292px`
- 设备状态栏：`68px`

## 组件映射

| HTML 组件 | SwiftUI 组件 |
| --- | --- |
| `.current-focus-card` | `CurrentFocusCard` |
| `.pending-items-card` | `PendingItemsCard` |
| `.recent-collection-card` | `RecentCollectionCard` |
| `.activity-trend-card` | `ActivityTrendCard` |
| `.today-status-panel` | `TodayStatusPanel` |
| `.quick-actions-card` | `QuickActionsCard` |
| `.device-status-bar` | `DeviceStatusBar` |

## 交互说明

- 侧栏菜单支持选中状态切换。
- 顶部搜索框支持展开与收起。
- `CurrentFocusCard` 主按钮支持按压反馈。
- 快捷动作按钮支持 hover 与 active。
- 图表支持 hover，并显示当前点位和提示。
- 支持标准 / 紧凑预览切换。
- 支持普通模式 / 调试模式切换。
- 调试模式会显示主要容器名称和尺寸。

## 响应式规则

- `1500 × 888`：标准双列布局。
- `1180 × 720`：紧凑布局，页面内边距缩小，右栏收窄到 `252px`。
- 紧凑模式下隐藏部分辅助文字，减少卡片内部间距。
- 页面始终禁止根级纵向滚动和横向滚动。

## SwiftUI 对应组件

- `WorkbenchHeader`
- `CurrentFocusCard`
- `PendingItemsCard`
- `RecentCollectionCard`
- `ActivityTrendCard`
- `TodayStatusPanel`
- `QuickActionsCard`
- `DeviceStatusBar`

## 已知限制

- 当前图表为 Mock 数据。
- 当前页面不接入真实业务数据。
- 不修改旧版 SwiftUI 工作台。
- Debug 信息仅在 HTML 原型的调试模式下显示。

## 运行方式

直接在浏览器中打开 `index.html` 即可。

如果需要本地服务，可以在该目录运行：

```bash
python3 -m http.server 8080
```

然后访问：

```text
http://127.0.0.1:8080/docs/design/workbench-v2/
```
