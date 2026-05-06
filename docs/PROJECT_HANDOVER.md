# AcMind 项目交接文档

> 最后更新：2026-05-05

## 项目概况

| 项目 | 值 |
|------|---|
| 应用名 | AcMind |
| 母品牌 | Acore |
| 版本 | 0.12.0 |
| 定位 | 个人桌面 AI 信息中枢 |
| 技术栈 | Electron 35 + React 18 + TypeScript + Vite + TailwindCSS |
| 平台 | macOS Apple Silicon |
| 数据库 | better-sqlite3 |
| 包管理 | npm |

## 产品线关系

```
Acore（母品牌）
├── AcMind          主应用
├── PinStack        快速捕获层（AcMind 内部能力）
├── VaultKeeper     整理引擎（AcMind 内部服务）
└── 小龙虾 Agent    未来本地 AI 执行代理（架构预留）
```

详见 [ACORE_PRODUCT_MAP.md](./ACORE_PRODUCT_MAP.md) 和 [ACMIND_PRODUCT_BOUNDARY.md](./ACMIND_PRODUCT_BOUNDARY.md)。

## 核心流程

```
收集 → 暂存 → 整理 → 审阅 → 导出 → 入库
```

Phase 1 已完成前两段（收集 → 暂存），数据统一存储在 sourceItems 表中。

详见 [ACMIND_PHASE_1_CAPTURE_INBOX.md](./ACMIND_PHASE_1_CAPTURE_INBOX.md)。

## 导航结构

一级导航 6 项：工作台、暂存池、整理、知识库、工具台、设置。

Agent 对话和定时任务已降级为工具台子页，仍可通过 URL 参数 `?view=agent-chat` 和 `?view=agent-tasks` 直接访问。

## 架构概览

三层 Electron 架构：
- **Main**：`src/main/index.ts` — 主进程入口
- **Preload**：`src/preload/index.ts` — IPC 桥接
- **Renderer**：`src/renderer/App.tsx` — React 应用入口

核心服务目录：`src/main/services/`
- `aiHub/` — AI 提供者管理 + 任务队列
- `capture/` — 内容采集
- `chat/` — Agent 聊天 + 技能系统
- `distiller/` — AI 蒸馏管线
- `exporter/` — Markdown/Obsidian 导出
- `importer/` — Obsidian Vault 导入
- `parser/` — 文档解析
- `pipeline/` — 内容处理管线 + 状态机
- `strategy/` — AI 策略路由
- `vaultkeeper/` — 外部结果回写

## 数据存储

- 数据目录：`~/Library/Application Support/AcMind/`
- 数据库：`acmind.db`（schema version 21）
- 导出目录：`acmind-datasets/`
- 核心数据表：`source_items`（所有收集内容统一存储）

### SourceItem 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT | 主键 |
| type | TEXT | text/image/url/file/audio/video/screenshot/webpage |
| source | TEXT | clipboard/screenshot/manual/vault_import/audio/file_import/url_paste |
| status | TEXT | inbox/distilling/distilled/exported/archived |
| title | TEXT | 标题 |
| contentPath | TEXT | 内容文件路径 |
| previewText | TEXT | 预览文本 |
| filePath | TEXT | 原始文件路径 |
| fileSize | INTEGER | 文件大小 |
| mimeType | TEXT | MIME 类型 |
| originalUrl | TEXT | 原始 URL |
| createdAt | INTEGER | 创建时间 |
| updatedAt | INTEGER | 更新时间 |

## 开发命令

```bash
npm run dev          # 启动开发环境
npm run build        # 生产构建
npm run typecheck    # TypeScript 类型检查
npm run lint         # ESLint 检查
npm run test         # Vitest 测试
npm run check        # typecheck + lint + build
```

## 关键约定

- 品牌命名统一使用 AcMind，Acore 仅作为母品牌
- CSS 类名使用 `acmind-*` 或 `pm-*` 前缀
- IPC 事件使用 `acmind:` 前缀
- preload API 暴露为 `window.acmind`
- `window.pinmind` 保留为 deprecated 兼容别名

## 已知问题与技术债务

- Phase 2 follow-up：修复 3 个既有类型检查错误（ResultCard、EditPage），清理 StagingPoolPage 死代码，修复 distillPipeline 失败路径缺失 RECORDS_CHANGED 广播
