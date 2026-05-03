# Inbox 模块

## 职责

- 所有 SourceItem 的统一入口
- 未整理 / 已整理 / 已导出状态管理
- SourceItem 列表展示
- 多源内容统一展示
- 发起 Distill / Export

## 不负责

- 具体截图逻辑
- 具体模型调用细节
- 具体 Markdown 转换实现

## 输入

- 来自 Capture 的 SourceItem
- 来自 Clipboard 的 SourceItem
- 来自 Shelf 的 SourceItem
- 来自手动输入的 SourceItem

## 输出

- SourceItem（带状态流转）
- 触发 Distill 任务
- 触发 Export 任务

## 依赖

- `storage` — SourceItem CRUD
- `distill` — AI 整理
- `export` — 导出

## 现有代码映射

- `src/renderer/pages/capture-inbox/` — 采集收件箱 UI
- `src/renderer/components/inbox/` — Inbox 组件
- `src/main/services/pipeline/` — 内容管线（状态机驱动）
