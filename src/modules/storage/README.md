# Storage 模块

## 职责

- SQLite 数据库管理（better-sqlite3）
- Schema 定义与迁移
- 文件资产存储
- 全文搜索索引
- 数据备份

## 现有代码映射

- `src/main/storage.ts` — 存储服务（Schema v13，15+ 张表）
- `src/main/services/search/` — 搜索服务
- `src/main/services/importer/` — Vault 导入

## Schema 版本

当前版本：v13

### 现有表

- `source_items` — 采集内容
- `ai_tasks` — AI 任务
- `distilled_outputs` — 蒸馏结果
- `knowledge_cards` — 知识卡片
- `knowledge_edges` — 知识关系
- `review_events` — 审核事件
- `training_examples` — 训练样本
- `dataset_snapshots` — 数据集快照
- `training_runs` — 训练运行
- `eval_runs` — 评估运行
- `model_versions` — 模型版本
- `export_records` — 导出记录
- `import_tasks` — 导入任务
- `capture_items` — 采集项
- `app_settings` — 应用设置
- `provider_configs` — Provider 配置
- `vault_config` — Vault 配置
- `_migration` — 迁移版本

### Phase 0 新增表（v14）

- `asset_files` — 资产文件
- `clipboard_items` — 剪贴板历史
- `shelf_items` — 文件临时架
- `ai_actions` — AI 动作定义
