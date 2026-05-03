# PinMind Phase 1 — 项目交接文档

> 版本: 0.2.1 | 日期: 2026-04-29

---

## 1. 项目概述

PinMind 是一个 **本地优先的 AI 记忆蒸馏器**（Local-first AI Memory Distiller），核心链路：

```
手动输入 → source_items → ai_tasks → distill → distilled_outputs → 审阅编辑 → 导出 Markdown → export_records
```

技术栈：Electron + React + TypeScript + SQLite (better-sqlite3) + esbuild

## 2. 数据库 Schema（当前版本 v9）

| 表 | 用途 | 关键字段 |
|---|---|---|
| `source_items` | 源素材（文本/链接/图片） | id, type, source, contentPath, status, title, tags |
| `capture_items` | 捕获中间态（Web Clipper/文件导入） | id, type, status, rawText, sourceUrl, filePath |
| `ai_tasks` | AI 蒸馏任务 | id, sourceItemId, operation, status, **updatedAt**, error |
| `distilled_outputs` | 蒸馏结果 | id, sourceItemId, taskId, suggestedTitle, summary, contentMarkdown |
| `export_records` | 导出记录 | id, status, **error**, vaultPath, relativeFilePath |
| `vault_config` | Vault 配置 | vaultPath, defaultFolder |
| `knowledge_cards` | 知识卡片 | id, sourceItemId, canonicalTitle, body |

Schema 版本迁移在 `src/main/storage.ts` 的 `migrate()` 方法中管理。

## 3. 主链路关键文件

### 主进程 (src/main/)

| 文件 | 职责 |
|---|---|
| `ipc.ts` | 所有 IPC handler 注册（~900 行） |
| `storage.ts` | SQLite 存储层（schema + CRUD + migration） |
| `captureService.ts` | 碎片捕获服务（文本/链接/图片） |
| `services/distiller/distillPipeline.ts` | 蒸馏管线（入队 → 执行 → 落库） |
| `services/distiller/mockDistiller.ts` | Mock 蒸馏器（无 AI Provider 时的 fallback） |
| `services/aiHub/taskQueue.ts` | FIFO 任务队列（内存 + 状态回调） |
| `services/exporter/obsidianExporter.ts` | Obsidian Markdown 导出器 |
| `services/exporter/markdownBuilder.ts` | Markdown 内容生成 |

### 渲染进程 (src/renderer/)

| 文件 | 职责 |
|---|---|
| `pages/capture-inbox/CaptureInboxPage.tsx` | 收集箱（读 source_items） |
| `pages/inbox/InboxPage.tsx` | 收件箱（读 source_items） |
| `pages/edit/EditPage.tsx` | 审阅编辑页 |
| `pages/export/ExportPage.tsx` | 导出管理页 |
| `hooks/useSourceItems.ts` | source_items 数据 hook |
| `hooks/useCaptureItems.ts` | capture_items 数据 hook |
| `components/inbox/SourceItemCard.tsx` | SourceItem 卡片（含蒸馏/删除按钮） |

### 共享 (src/shared/)

| 文件 | 职责 |
|---|---|
| `types.ts` | 所有 TypeScript 类型定义 |
| `markdownSpec.ts` | Markdown 导出规范（frontmatter 模板） |

## 4. IPC 通道一览

| 通道 | 方向 | 用途 |
|---|---|---|
| `sourceItems.createText` | renderer→main | 手动文本直接写 source_items |
| `sourceItems.list` | renderer→main | 列出 source_items |
| `sourceItems.get` | renderer→main | 获取单个 source_item |
| `sourceItems.ensureFromCapture` | renderer→main | CaptureItem → SourceItem 桥接（幂等） |
| `distill.run` | renderer→main | 对 source_items 执行蒸馏 |
| `distill.bridgeAndRun` | renderer→main | CaptureItem → SourceItem → 蒸馏 |
| `distilledOutputs.list` | renderer→main | 列出蒸馏结果 |
| `distilledOutputs.review` | renderer→main | 审阅保存蒸馏结果 |
| `export.single` | renderer→main | 单条导出（返回 ExportRecord，含 status） |
| `export.batch` | renderer→main | 批量导出（返回 ExportRecord[]） |
| `settings.get` / `settings.save` | renderer→main | 设置读写 |

## 5. 已知限制 & Mock 使用

| 场景 | 当前行为 | 后续计划 |
|---|---|---|
| AI 蒸馏 | 无 Provider 时使用 `mockDistiller`（日志标注 `[Mock Fallback]`） | 接入本地 LLM（Ollama） |
| 蒸馏操作 | Phase 1 只用 `summarize` | 恢复 6 种操作 |
| 导出路径 | 需用户在设置中配置 Vault 路径 | 自动检测 Obsidian Vault |
| `confidence` | AI 返回时使用，否则 fallback 0.8 | 模型校准 |

## 6. 构建与测试

```bash
npm run typecheck    # tsc --noEmit
npm test             # vitest run（109 tests）
npm run build        # esbuild 打包
npm run dev          # 开发模式（renderer + main + preload + electron）
```

## 7. 版本历史

| 版本 | 日期 | 关键变更 |
|---|---|---|
| 0.2.1 | 2026-04-29 | Phase 1 真闭环：收集箱读 source_items、导出 false-success 修复、AiTask.updatedAt、标题编辑覆盖修复 |
| 0.2.0 | 2026-04-28 | EditPage 真实闭环、蒸馏管线 mock fallback |
