# AcMind Phase 1：核心收集主链路固定

> 最后更新：2026-05-05

## 阶段目标

完成 AcMind 的「收集 → 暂存」主链路，让用户能从多个入口收集内容，统一进入暂存池，数据持久化。

## 核心流程

```
Capture → SourceItem → 暂存池（sourceItems, status=inbox）
```

## 完成事项

### 1. 数据结构统一

**SourceItem 类型扩展**（`src/shared/types.ts`）：

- `type` 扩展为：`'text' | 'image' | 'url' | 'file' | 'audio' | 'video' | 'screenshot' | 'webpage'`
- `source` 扩展为：`'clipboard' | 'screenshot' | 'manual' | 'vault_import' | 'audio' | 'file_import' | 'url_paste'`
- 新增字段：`filePath`、`thumbnailPath`、`updatedAt`、`fileSize`、`mimeType`

### 2. 数据库迁移

v21 迁移新增列：
- `file_path TEXT` — 原始文件路径
- `thumbnail_path TEXT` — 缩略图路径
- `updated_at INTEGER` — 更新时间
- `file_size INTEGER` — 文件大小
- `mime_type TEXT` — MIME 类型

### 3. 数据源统一

废弃 pinPool，所有收集内容统一写入 sourceItems：
- 暂存池页面改用 `window.acmind.sourceItems` API
- 工作台快速输入改用 `sourceItems.createText()`
- 剪贴板自动监听改为写入 sourceItems

### 4. 收集入口

| 入口 | 类型 | 来源 | 状态 |
|------|------|------|------|
| 手动文本输入 | text | manual | ✅ |
| 剪贴板文本（自动监听） | text | clipboard | ✅ |
| 剪贴板文本（手动收集） | text | clipboard | ✅ |
| 截图 | screenshot | screenshot | ✅ |
| 通用文件导入 | file | file_import | ✅ 新增 |
| URL 保存 | webpage | url_paste | ✅ 新增 |
| 音频文件 | audio | audio | ✅ |
| Vault 导入 | text | vault_import | ✅ |

### 5. 暂存池页面

基于 sourceItems 的完整暂存池：
- 类型筛选：全部/文本/图片/截图/文件/网页/音频
- 搜索：标题和预览文本
- 列表展示：类型图标 + 标题 + 来源标签 + 时间 + 状态
- 详情面板：元数据 + 内容预览 + 操作按钮
- 操作：复制/删除/标记待整理/打开文件
- 空状态引导

### 6. IPC 通道

新增：
- `sourceItems.importFile` — 通用文件导入
- `sourceItems.saveUrl` — URL 保存
- `sourceItems.update` — 更新 sourceItem

## 当前未完成的能力

- PDF / DOCX 内容解析（仅保存文件引用）
- 网页全文抓取（仅保存 URL）
- OCR 图片文字识别
- AI 蒸馏/整理流程
- Obsidian 最终导出
- 小龙虾 Agent

## 下一阶段（Phase 2）建议

Phase 2 应聚焦「整理」链路：
- AI 蒸馏管线接入
- 人工审阅流程
- 状态流转：inbox → processing → review_required → exported
- Markdown 输出
- Obsidian Vault 导出

## 修改文件清单

| 文件 | 变更 |
|------|------|
| `src/shared/types.ts` | SourceItem 类型扩展 + IPC 通道常量 |
| `src/main/storage.ts` | DB 迁移 v21 + 新方法 |
| `src/main/ipc.ts` | 3 个新 IPC handler |
| `src/preload/index.ts` | 3 个新 preload API |
| `src/main/captureService.ts` | 剪贴板改写 sourceItems + importFile/saveUrl |
| `src/renderer/pages/staging-pool/StagingPoolPage.tsx` | 完全重构 |
| `src/renderer/pages/daily-flow/DailyKnowledgeFlowPage.tsx` | 移除 pinPool |
| `src/renderer/hooks/useSourceItems.ts` | 扩展方法 |
| `src/renderer/components/inbox/SourceItemDetail.tsx` | 新类型映射 |
| `src/renderer/components/inbox/SourceItemCard.tsx` | 新类型映射 |
