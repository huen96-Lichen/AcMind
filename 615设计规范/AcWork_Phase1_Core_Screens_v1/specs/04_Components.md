# 04 第一阶段统一组件

## 必须先实现

### AcWorkShell

负责：
- Sidebar
- Toolbar
- PageBody
- Inspector 响应式

### AcSidebar

状态：
- normal
- hover
- selected
- disabled

### AcPageToolbar

插槽：
- title
- context
- primaryAction
- secondaryActions
- search

### AcSection

用于无边框内容分区。

### AcCard

仅用于必要的独立内容块。

样式：
- Surface 背景
- 1 pt Border
- 12 pt 圆角
- 无常规阴影

### AcListRow

支持：
- leading icon
- title
- subtitle
- metadata
- trailing actions
- selected
- hover

### AcInspector

支持：
- empty summary
- selected detail
- fixed footer actions

### AcStatusBadge

语义：
- neutral
- active
- success
- warning
- danger

### AcSearchField

- Command+F 聚焦
- 可清除
- 支持 Search Token

### AcSegmentedControl

用于：
- 列表 / 网格
- 日 / 周 / 月 / 年
- 页面内部少量模式切换

### AcEmptyState

必须包含：
- 标题
- 一句说明
- 最多一个主要操作
- 可选次级操作

### AcTrendChart

- 轻网格
- 无外框
- Hover 值
- 支持 60 秒窗口

## 统一状态

所有主要页面和组件必须覆盖：

- Loading
- Empty
- Error
- Disabled
- Hover
- Selected
- Keyboard Focus
- Permission Required
