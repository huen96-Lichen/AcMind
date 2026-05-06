# AcMind Phase 2：整理链路打通

> 生成时间：2026-05-05
> 前置依赖：Phase 0.5（品牌收束）✅ + Phase 1（收集主链路）✅

---

## 背景

Phase 1 已完成「收集 → 暂存」主链路：
- 所有收集入口统一写入 sourceItems
- 暂存池基于 sourceItems 展示
- 数据持久化到 SQLite
- 支持手动文本、剪贴板、截图、文件导入、URL 保存

Phase 2 目标：打通「暂存 → 整理 → 审阅 → 导出」链路。

核心主流程：
```
收集 → 暂存 → 整理 → 审阅 → 导出 → 入库
                  ↑
              Phase 2 聚焦
```

---

## 一、阶段目标

完成后，用户应该能明确感受到：

1. 我可以从暂存池选择内容，送入整理流程。
2. 系统会用 AI 对内容进行蒸馏/提炼。
3. 整理结果可以预览和审阅。
4. 确认后可以导出为 Markdown 文件。
5. 导出的文件可以保存到指定目录或 Obsidian Vault。

---

## 二、当前项目状态（Phase 1 交付物）

### 已有数据结构

SourceItem（`src/shared/types.ts`）：
```typescript
interface SourceItem {
  id: string;
  type: 'text' | 'image' | 'url' | 'file' | 'audio' | 'video' | 'screenshot' | 'webpage';
  source: 'clipboard' | 'screenshot' | 'manual' | 'vault_import' | 'audio' | 'file_import' | 'url_paste';
  contentPath: string;
  previewText?: string;
  ocrText?: string;
  originalUrl?: string;
  filePath?: string;
  fileSize?: number;
  mimeType?: string;
  status: 'inbox' | 'distilling' | 'distilled' | 'exported' | 'archived';
  title?: string;
  metadata?: Record<string, unknown>;
  createdAt: number;
  updatedAt?: number;
}
```

### 已有服务

- `src/main/services/distiller/` — AI 蒸馏管线（已存在，需确认可用性）
- `src/main/services/exporter/` — Markdown/Obsidian 导出（已存在，需确认可用性）
- `src/main/services/strategy/` — AI 策略路由（已存在）
- `src/main/services/aiHub/` — AI 提供者管理（已存在）
- `src/main/services/pipeline/` — 内容处理管线 + 状态机（已存在）

### 已有 IPC 通道

sourceItems 相关：
- `sourceItems.list` / `sourceItems.get` / `sourceItems.delete`
- `sourceItems.search` / `sourceItems.createText`
- `sourceItems.importFile` / `sourceItems.saveUrl`
- `sourceItems.update`（Phase 1 新增，但 hook 层未接入）

### 已有页面

- `src/renderer/pages/staging-pool/StagingPoolPage.tsx` — 暂存池（Phase 1 重构）
- `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx` — 收集收件箱
- `src/renderer/pages/distill/DistillPage.tsx` — 蒸馏页面（需确认状态）
- `src/renderer/pages/distill/DistillationWorkbench.tsx` — 蒸馏工作台（需确认状态）
- `src/renderer/pages/export/ExportPage.tsx` — 导出页面（需确认状态）
- `src/renderer/pages/review/ReviewPage.tsx` — 审阅页面（需确认状态）

### 已有 Hook

- `src/renderer/hooks/useSourceItems.ts` — sourceItems hook（Phase 1 扩展）
  - ⚠️ `updateItem` 方法目前是乐观更新，未接入真实 IPC

---

## 三、需要先确认的事项

在开始实现之前，请先读取以下文件，确认已有整理/导出能力的实际状态：

1. `src/main/services/distiller/` — 蒸馏服务的入口和核心方法
2. `src/main/services/exporter/` — 导出服务的入口和核心方法
3. `src/renderer/pages/distill/DistillPage.tsx` — 蒸馏页面当前状态
4. `src/renderer/pages/export/ExportPage.tsx` — 导出页面当前状态
5. `src/renderer/pages/review/ReviewPage.tsx` — 审阅页面当前状态
6. `src/shared/types.ts` — DistillTask / DistilledOutput / ExportRecord 等类型定义
7. `src/main/services/pipeline/` — 内容处理管线

根据读取结果，判断：
- 哪些能力已经可用，只需接入 UI
- 哪些能力需要修复或补充
- 哪些能力需要新建

---

## 四、核心任务

### 任务 1：状态流转打通

确保 SourceItem 的状态能正确流转：
```
inbox → distilling → distilled → exported → archived
```

具体要求：
- 暂存池中「标记待整理」或「送入整理」将 status 从 `inbox` 改为 `distilling`
- AI 蒸馏完成后将 status 改为 `distilled`
- 导出完成后将 status 改为 `exported`
- 修复 `useSourceItems.updateItem`，接入真实 `sourceItems.update` IPC
- 暂存池列表中实时反映状态变化

### 任务 2：整理页面（Distill）接入

确认或重构整理页面，使其能：
- 从暂存池选择一条或多条 sourceItem 送入整理
- 展示当前正在整理的内容
- 展示 AI 蒸馏的进度/状态
- 展示蒸馏结果预览
- 支持人工编辑蒸馏结果
- 支持确认或重新蒸馏

### 任务 3：AI 蒸馏管线接入

确认 AI 蒸馏服务可用：
- 读取 sourceItem 的内容（文本/图片/URL）
- 根据内容类型选择合适的蒸馏策略
- 调用 AI 模型进行蒸馏
- 生成结构化的蒸馏结果（标题、摘要、标签、正文）
- 将结果保存为 DistilledOutput

如果蒸馏服务已存在，只需确认可用性并接入 UI。
如果蒸馏服务不完整，需要补充最小可用实现。

### 任务 4：审阅流程

确认或实现审阅流程：
- 蒸馏完成后，结果进入审阅状态
- 用户可以查看、编辑、确认或退回
- 确认后进入导出流程

### 任务 5：Markdown 导出

确认或实现 Markdown 导出：
- 将蒸馏结果导出为 Markdown 文件
- 支持 Frontmatter（标题、标签、日期、来源）
- 保存到指定目录
- 如果配置了 Obsidian Vault，保存到 Vault 目录
- 导出后更新 sourceItem 状态为 `exported`

### 任务 6：整理页面导航整合

确保导航流程顺畅：
- 暂存池 → 选择内容 → 送入整理 → 整理页面
- 整理页面 → 查看结果 → 审阅 → 确认
- 确认后 → 导出 → 知识库

Sidebar 一级导航保持 6 项不变：
1. 工作台
2. 暂存池
3. 整理（对应 capture-inbox 或 distill）
4. 知识库
5. 工具台
6. 设置

---

## 五、UI 要求

- 保持 AcMind 的克制、Apple 风格
- 整理过程要有清晰的进度反馈
- 蒸馏结果用卡片式展示，不要做成表格
- 审阅时支持内联编辑
- 导出成功要有明确反馈
- 错误状态要有清晰的错误信息和重试入口
- 不要做成复杂的后台管理系统

---

## 六、本阶段不做的事

1. 不做复杂的多轮对话式整理
2. 不做个人模型训练
3. 不做远程 Agent
4. 不做插件市场
5. 不做网页全文抓取（仅用已有内容）
6. 不做 PDF/DOCX 深度解析（仅用已有文本）
7. 不做大规模底层重构
8. 不清理 pinPool 代码（留到后续）
9. 不破坏已有功能

---

## 七、验收标准

1. `npm run typecheck` 通过
2. `npm run build` 通过
3. 暂存池内容可以送入整理流程
4. AI 蒸馏能产生结果（需要配置 AI Provider）
5. 蒸馏结果可以预览和编辑
6. 确认后可以导出为 Markdown
7. 导出的 Markdown 文件格式正确（含 Frontmatter）
8. 状态流转正确：inbox → distilling → distilled → exported
9. 整理过程有进度反馈
10. 错误状态有明确提示
11. 不伪造 AI 结果
12. 不破坏已有收集能力
13. 更新文档

---

## 八、文档要求

更新以下文档：
- `docs/PROJECT_HANDOVER.md`
- `docs/ACMIND_PRODUCT_BOUNDARY.md`
- `CHANGELOG.md`
- `docs/WORKLOG.md`

新增：
- `docs/ACMIND_PHASE_2_DISTILL_EXPORT.md`

---

## 九、技术债提醒（来自 Phase 1）

1. `useSourceItems.updateItem` 需要接入真实 IPC
2. 剪贴板去重用全量查询，可优化为索引查询
3. pinPool 代码残留（本轮不清理）

---

## 十、给 Codex 的核验口令

```md
# Codex 核验任务：AcMind Phase 2 整理链路打通

请核验以下内容：

1. 状态流转：inbox → distilling → distilled → exported 是否完整实现
2. AI 蒸馏：是否能从 sourceItem 读取内容并调用 AI 生成蒸馏结果
3. 审阅流程：用户是否能预览、编辑、确认蒸馏结果
4. Markdown 导出：是否能导出含 Frontmatter 的 Markdown 文件
5. UI 流程：暂存池 → 整理 → 审阅 → 导出 是否顺畅
6. 错误处理：AI 调用失败、导出失败是否有明确提示
7. 不伪造 AI 结果
8. 不破坏已有功能
9. typecheck + build 通过
10. 文档已更新
```

---

## 十一、建议执行顺序

1. 先读取已有代码，确认蒸馏/导出服务的实际状态（30 分钟）
2. 修复 `useSourceItems.updateItem` 接入真实 IPC（15 分钟）
3. 接入整理页面，实现「送入整理」→「AI 蒸馏」→「结果展示」（核心，60 分钟）
4. 实现审阅流程（30 分钟）
5. 实现 Markdown 导出（30 分钟）
6. 整合导航流程（15 分钟）
7. 更新文档（15 分钟）
8. typecheck + build 验证（10 分钟）
