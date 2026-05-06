# AcMind Phase 2: 整理链路打通（Distill → Export）

> 日期：2026-05-05
> 前置：Phase 1（核心收集主链路固定）

## 目标

将 Phase 1 建立的收集链路延伸到整理阶段，打通 inbox → distilling → distilled → exported 完整状态流。

## 变更概要

### 1. useSourceItems.updateItem 接入真实 IPC

- **之前**：乐观更新占位，未持久化
- **之后**：调用 `sourceItems.update` IPC，写入数据库

### 2. DistillPage 整理页

| 功能 | 说明 |
|------|------|
| handleDistill | 调用真实 `distill.run` IPC |
| handleRetry | 调用真实 `distill.run` IPC（重试失败条目） |
| 进度 UI | spinner + 状态文案，实时反馈整理进度 |
| 批量整理 | "全部整理"按钮，一键处理所有待整理条目 |
| distilling 状态 | 整理中的条目显示在待整理标签页 |
| 错误重试 | 失败条目显示错误状态 + 单条重试按钮 |

### 3. StagingPoolPage 暂存池

| 功能 | 说明 |
|------|------|
| 单条送入整理 | 每条 item 新增"送入整理"按钮 |
| 批量送入整理 | 表头新增批量"送入整理"按钮 |
| distilling 追踪 | 逐条追踪整理状态 |
| 流程替换 | "标记待整理" → 直接"送入整理" |

### 4. Sidebar 导航修正

- "整理"导航路由从 `capture-inbox` 改为 `distill`
- 现在正确指向 DistillPage

## 状态流

```
inbox（暂存池）
  ↓ 送入整理
distilling（整理中）
  ↓ 整理完成
distilled（已整理）
  ↓ 导出
exported（已导出）
```

## 修改文件

- `src/renderer/hooks/useSourceItems.ts`
- `src/renderer/pages/distill/DistillPage.tsx`
- `src/renderer/pages/staging-pool/StagingPoolPage.tsx`
- `src/renderer/components/layout/Sidebar.tsx`
