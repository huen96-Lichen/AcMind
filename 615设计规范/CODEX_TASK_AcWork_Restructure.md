# AcWork UI Restructure Task for Codex

## 目标

将现有 AcMind UI 重构为 AcWork，并落地 `AcWork Focus Workspace` 设计体系。

## 第一阶段：品牌迁移

- 用户可见名称全部改为 AcWork。
- 保留旧数据目录读取兼容。
- 新代码逐步迁移为 AcWork 前缀。
- 不允许一次性破坏性修改数据路径。

## 第二阶段：导航重构

一级导航固定为：

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

删除“剪贴板”一级入口。

## 第三阶段：收集箱合并

统一 `InboxItem`、`ClipboardItem`、`PinItem` 为 `CollectedItem`。

必须支持：

- 多来源
- 多类型
- Pin
- 收藏
- 标签
- 处理状态
- 手机同步
- 粘贴队列
- 列表与网格视图
- 批量操作
- AI 提炼
- 转任务
- 转日程
- 导出与归档

## 第四阶段：统一 UI 基础层

先实现：

- AcWorkShell
- AcSidebar
- AcPageToolbar
- AcSection
- AcCard
- AcListRow
- AcInspector
- AcStatusBadge
- AcEmptyState
- AcSearchField
- AcSegmentedControl
- AcSettingRow
- AcTrendChart

所有页面只能使用统一 Token。

## 第五阶段：页面实施顺序

1. 统一外壳
2. 工作台
3. 收集箱
4. Agent
5. 日程
6. 工具台
7. 灵动大陆
8. 说入法
9. 状态
10. 模型
11. 设置

## 强制规则

- SwiftUI 原生实现。
- 不使用 WebView。
- 不使用 HTML 模拟 UI。
- 不引入第二套视觉 Token。
- 不写死纯展示数据。
- 使用 ViewModel + Repository。
- 未完成数据使用 Mock Repository。
- 支持 Loading / Empty / Error / Disabled / Hover / Focus。
- 1500 × 920 作为基准截图尺寸。
- 最小窗口尺寸 1180 × 720。
- 宽度低于 1320 时自动隐藏 Inspector。
- 所有控件提供 accessibilityLabel。
- 不使用大面积渐变、风景图和重阴影。
- 不允许页面标题重复出现。

## 验收标准

- 导航与本任务一致。
- 剪贴板不再作为一级页面。
- 收集箱能统一显示所有来源。
- 视觉风格统一。
- 所有页面在 1500 × 920 下布局稳定。
- 1180 × 720 下不出现重叠和裁切。
- 所有页面具备空状态和错误状态。
- 截图与规范逐页比对。
