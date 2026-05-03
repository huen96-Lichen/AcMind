# AcMind 数据模型

## 概述

AcMind 使用统一数据模型管理所有进入系统的原始信息、资产文件、处理任务和输出结果。

数据存储在本地 SQLite（better-sqlite3），WAL 模式，schema 版本通过 `_migration` 表管理（当前 v14）。

---

## 一、当前已有对象（pinmind-main 遗留）

### SourceItem

所有采集内容的统一表示。当前主链路的核心数据对象。

```typescript
// src/shared/types.ts
export interface SourceItem {
  id: string;
  type: 'text' | 'image' | 'audio' | 'video' | 'pdf' | 'docx' | 'unknown_file';
  source: 'manual' | 'clipboard' | 'screenshot' | 'webpage' | 'file';
  contentPath: string;          // 本地文件路径
  title?: string;
  previewText?: string;
  status: SourceItemStatus;     // pending → capturing → captured → ... → exported
  createdAt: number;
  updatedAt?: number;
  // ... 更多字段见 types.ts
}
```

**对应表**：`source_items`

### AiTask

AI 处理任务队列。当前蒸馏管线的任务模型。

```typescript
export interface AiTask {
  id: string;
  sourceId: string;
  operation: AiOperation;       // 'rename' | 'summarize' | 'classify' | 'tag' | 'valueScore' | 'cleanSuggest' | 'prefilter'
  status: AiTaskStatus;         // pending → running → succeeded / failed
  tier: AiTier;                 // local_light | cloud_standard | cloud_advanced
  providerId?: string;
  modelId?: string;
  // ... 更多字段见 types.ts
}
```

**对应表**：`ai_tasks`

### DistilledOutput

AI 蒸馏结果。当前蒸馏管线的输出模型。

```typescript
export interface DistilledOutput {
  id: string;
  sourceId: string;
  taskId?: string;
  title: string;
  summary: string;
  tags: string[];
  category?: string;
  bodyMarkdown: string;
  qualityScore?: number;
  modelProvider?: string;
  modelName?: string;
  // ... 更多字段见 types.ts
}
```

**对应表**：`distilled_outputs`

### ExportRecord

导出记录。

```typescript
export interface ExportRecord {
  id: string;
  sourceId: string;
  distilledOutputId?: string;
  target: 'obsidian' | 'icloud' | 'local';
  outputPath?: string;
  status: 'pending' | 'exported' | 'failed';
  // ... 更多字段见 types.ts
}
```

**对应表**：`export_records`

### CaptureItem

采集任务（管线状态机驱动）。

```typescript
export interface CaptureItem {
  id: string;
  sourceId: string;
  status: CaptureItemStatus;    // pending → capturing → ... → exported
  // ... 更多字段见 types.ts
}
```

**对应表**：`capture_items`

### pin_pool_items

Pin 池（截图钉图暂存）。当前由 pinPool.* IPC 管理。

**对应表**：`pin_pool_items`

---

## 二、AcMind 目标对象

以下类型已在 `src/shared/types.ts` 中定义，作为 AcMind 的统一数据模型目标。

### AssetFile

图片、截图、音频、PDF、DOCX 等资产文件。

```typescript
export interface AssetFile {
  id: string;
  sourceItemId?: string;
  kind: AssetFileKind;          // 'image' | 'audio' | 'video' | 'pdf' | 'docx' | 'html' | 'markdown' | 'other'
  originalName?: string;
  localPath: string;
  mimeType?: string;
  sizeBytes?: number;
  sha256?: string;
  createdAt: number;
  metadata?: Record<string, unknown>;
}
```

**对应表**：`asset_files`（Phase 0 新增，schema v14）

### ClipboardItem

剪贴板历史记录。

```typescript
export interface ClipboardItem {
  id: string;
  sourceItemId?: string;
  contentType: ClipboardContentType;  // 'text' | 'image' | 'file' | 'url' | 'rich_text'
  text?: string;
  assetFileIds?: string[];
  sourceApp?: string;
  isSensitive?: boolean;
  isPinned?: boolean;
  createdAt: number;
}
```

**对应表**：`clipboard_items`（Phase 0 新增，schema v14）

**Phase 1A 实现状态**：
- `captureService.handleNewClipboardContent` 在检测到新剪贴板内容时自动写入 `clipboard_items`
- `storage.searchClipboardItems` 支持按关键词和内容类型搜索
- `storage.clearClipboardItems` 清除非固定记录
- `storage.updateClipboardItemSourceItemId` 关联 SourceItem（保存到 Inbox 时）
- ClipboardItem 与 SourceItem 的关系：保存到 Inbox 时创建 SourceItem，通过 `source_item_id` 关联
- URL 自动识别：`/^https?:\/\/[^\s]+$/i` 匹配时 contentType 设为 `url`

### ShelfItem

文件临时架项目。

```typescript
export interface ShelfItem {
  id: string;
  sourceItemId?: string;
  assetFileIds: string[];
  label?: string;
  origin?: ShelfItemOrigin;     // 'drag_drop' | 'capture' | 'clipboard' | 'manual'
  status: ShelfItemStatus;      // 'temporary' | 'saved_to_inbox' | 'processed' | 'removed'
  createdAt: number;
  updatedAt: number;
}
```

**对应表**：`shelf_items`（Phase 0 新增，schema v14）

**Phase 1B 实现状态**：
- `storage.insertShelfItem` / `getShelfItem` / `listShelfItems` / `updateShelfItemStatus` / `deleteShelfItem` 完整可用
- `storage.updateShelfItemSourceItemId` 关联 SourceItem（保存到 Inbox 时）
- `storage.updateShelfItemLabel` 更新标签
- ShelfItem 与 SourceItem 的关系：保存到 Inbox 时创建 SourceItem，通过 `source_item_id` 关联
- ShelfItem 与 AssetFile 的关系：通过 `asset_file_ids` JSON 数组关联
- 文件拖拽时自动创建 AssetFile 记录

### ProcessJob

AI / 转换 / OCR / 转写任务。

```typescript
export interface ProcessJob {
  id: string;
  type: ProcessJobType;         // 'ocr' | 'asr' | 'markitdown' | 'distill' | 'summarize' | 'tag' | 'export'
  sourceItemId?: string;
  assetFileIds?: string[];
  status: ProcessJobStatus;     // 'queued' | 'running' | 'succeeded' | 'failed' | 'cancelled'
  progress?: number;
  errorMessage?: string;
  createdAt: number;
  updatedAt: number;
  startedAt?: number;
  completedAt?: number;
  metadata?: Record<string, unknown>;
}
```

**对应表**：当前映射到 `ai_tasks`，Phase 2 起可独立建表

### DistilledNote

AI 整理后的结构化笔记。

```typescript
export interface DistilledNote {
  id: string;
  sourceItemIds: string[];
  title: string;
  summary: string;
  tags: string[];
  suggestedFolder?: string;
  bodyMarkdown: string;
  qualityFlags: string[];
  modelProvider?: string;
  modelName?: string;
  createdAt: number;
  updatedAt: number;
  metadata?: Record<string, unknown>;
}
```

**对应表**：当前映射到 `distilled_outputs`，Phase 2 起可独立建表

### AIAction

AI 动作定义。

```typescript
export interface AIAction {
  id: string;
  name: string;
  inputTypes: SourceType[];
  actionType: AIActionType;     // 'summarize' | 'rewrite' | 'translate' | 'extract_todos' | 'to_markdown' | 'save_to_inbox' | 'custom'
  promptProfileId?: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}
```

**对应表**：`ai_actions`（Phase 0 新增，schema v14）

---

## 三、新旧映射关系

| AcMind 目标对象 | 当前等价/承接 | 映射方式 | 独立建表时机 |
|---|---|---|---|
| **SourceItem** | `SourceItem`（已有） | 直接等价，已落地 | 已有 `source_items` |
| **AssetFile** | 无直接等价 | Phase 0 新增独立表 | 已有 `asset_files`（v14） |
| **ClipboardItem** | 无直接等价 | Phase 0 新增独立表 | 已有 `clipboard_items`（v14） |
| **ShelfItem** | `pin_pool_items`（部分） | Phase 0 新增独立表，pin_pool_items 保留为 legacy | 已有 `shelf_items`（v14） |
| **ProcessJob** | `AiTask`（已有） | 当前兼容映射到 `ai_tasks` | Phase 2 起可拆分 |
| **DistilledNote** | `DistilledOutput`（已有） | 当前兼容映射到 `distilled_outputs` | Phase 2 起可拆分 |
| **ExportRecord** | `ExportRecord`（已有） | 直接等价，已落地 | 已有 `export_records` |
| **AIAction** | 无直接等价 | Phase 0 新增独立表 | 已有 `ai_actions`（v14） |

### 映射策略说明

1. **ProcessJob ↔ AiTask**：ProcessJob 是 AcMind 的统一任务模型，当前阶段通过 `ai_tasks` 表承接。ProcessJob 类型定义在 types.ts 中，但不创建独立表。UI 开发时应通过 `aiRuntime.*` IPC 调用，底层透明映射到 `ai_tasks`。

2. **DistilledNote ↔ DistilledOutput**：DistilledNote 支持多源聚合（sourceItemIds 为数组），DistilledOutput 为单源。当前阶段通过 `distilled_outputs` 表承接。Phase 2 起如需多源聚合，再独立建表。

3. **ShelfItem ↔ pin_pool_items**：ShelfItem 是更通用的临时架模型，pin_pool_items 是 acmind 遗留的 Pin 池。两者并存，Phase 1B 起新 UI 优先使用 `shelf.*` IPC 和 `shelf_items` 表。

4. **AssetFile**：当前 SourceItem 的 `contentPath` 字段临时承接文件路径。Phase 0 新增 `asset_files` 表后，新采集的内容应同时写入 `asset_files`。旧数据通过 `source_items.content_path` 兼容。

5. **ClipboardItem**：当前无独立存储，剪贴板内容通过 `source_items` 表（type='clipboard_text'）承接。Phase 0 新增 `clipboard_items` 表后，新剪贴板记录写入新表。

6. **AIAction**：当前无独立存储，AI 动作通过 `provider_configs` 和 prompt profile 临时承接。Phase 0 新增 `ai_actions` 表后，新动作定义写入新表。

### 原则

- **不允许 UI 直接依赖未来未实现表**：Phase 0 已落地的表（asset_files、clipboard_items、shelf_items、ai_actions）可直接使用。ProcessJob/DistilledNote 的独立表为未来规划，当前通过旧表兼容。
- **新旧并存，逐步迁移**：旧表不删除，新表逐步接管。Phase 1 起新 UI 优先使用新表。
- **类型先行，表后补**：所有目标类型已在 types.ts 中定义，表按需建立。

---

## 四、Storage 当前状态

### 已落地的表（schema v14）

| 表名 | 版本 | 用途 |
|---|---|---|
| `source_items` | v1 | 采集内容 |
| `ai_tasks` | v1 | AI 任务队列 |
| `distilled_outputs` | v1 | 蒸馏结果 |
| `knowledge_cards` | v1 | 知识卡片 |
| `knowledge_edges` | v1 | 知识关系 |
| `review_events` | v1 | 审核事件 |
| `training_examples` | v1 | 训练样本 |
| `dataset_snapshots` | v1 | 数据集快照 |
| `training_runs` | v1 | 训练运行 |
| `eval_runs` | v1 | 评估运行 |
| `model_versions` | v1 | 模型版本 |
| `export_records` | v1 | 导出记录 |
| `import_tasks` | v1 | 导入任务 |
| `capture_items` | v1 | 采集任务 |
| `app_settings` | v1 | 应用设置 |
| `provider_configs` | v1 | Provider 配置 |
| `vault_config` | v1 | Vault 配置 |
| `pin_pool_items` | v1 | Pin 池（legacy） |
| `asset_files` | v14 | 资产文件（Phase 0 新增） |
| `clipboard_items` | v14 | 剪贴板历史（Phase 0 新增） |
| `shelf_items` | v14 | 文件临时架（Phase 0 新增） |
| `ai_actions` | v14 | AI 动作定义（Phase 0 新增） |

### 未来规划的表

| 表名 | 计划版本 | 用途 | 当前承接 |
|---|---|---|---|
| `process_jobs` | Phase 2 | 统一任务模型 | `ai_tasks` |
| `distilled_notes` | Phase 2 | 多源聚合笔记 | `distilled_outputs` |

---

## 五、数据对象关系

```
SourceItem ──1:N──→ AssetFile
SourceItem ──1:1──→ ClipboardItem (可选)
SourceItem ──1:N──→ ShelfItem (可选)
SourceItem ──1:N──→ ProcessJob (当前映射到 AiTask)
SourceItem ──N:M──→ DistilledNote (当前映射到 DistilledOutput)
DistilledNote ──1:N──→ ExportRecord
AIAction ──引用──→ PromptProfile
```

---

## 六、Schema 版本历史

| 版本 | 变更 |
|---|---|
| v1-v12 | 历史迁移（详见 storage.ts） |
| v13 | 添加 source_items.metadata 列 |
| v14 | 新增 asset_files、clipboard_items、shelf_items、ai_actions 四张表 |
