# PinMind 架构文档

## 总体架构

PinMind 是一个 Electron 桌面应用，采用三层架构：

```
┌─────────────────────────────────────────────┐
│  Renderer (React + Vite)                    │
│  - 页面、组件、设计系统                       │
│  - 通过 window.pinmind.* 调用主进程           │
├─────────────────────────────────────────────┤
│  Preload (contextBridge)                    │
│  - 安全暴露 IPC 接口                          │
│  - contextIsolation: true                   │
├─────────────────────────────────────────────┤
│  Main Process (Node.js + esbuild)           │
│  - 业务服务、数据库、文件系统                   │
│  - AI 蒸馏、采集、导出、调度                    │
└─────────────────────────────────────────────┘
```

## 主进程服务层

### 采集服务 (capture/)

12 种采集适配器通过注册表模式管理：

- `manualTextAdapter` — 手动输入
- `clipboardTextAdapter` — 剪贴板监听
- `screenshotAdapter` — 截图采集
- `webpageAdapter` — 网页采集
- `fileAdapter` — 文件采集
- `imageAdapter` / `audioAdapter` / `videoAdapter` — 媒体采集

### 策略系统 (strategy/)

每种内容类型对应一个策略，负责后处理和元数据提取。策略注册表统一管理 12 种策略类型。

### AI 蒸馏 (distiller/)

```
内容 → tierRouter(选择模型层级) → distiller(mock/real) → 蒸馏结果
```

- `tierRouter` — 根据配置和内容类型选择 local_light / cloud_standard / cloud_advanced
- `mockDistiller` — 本地规则蒸馏（不依赖 AI）
- `realDistiller` — 调用 Ollama / OpenAI 兼容 API

### 导出服务 (exporter/)

将蒸馏结果写入 Obsidian Vault：

- `markdownBuilder` — 生成 Frontmatter + Markdown
- `safeWrite` — 安全写入（防冲突、防覆盖）
- `exportStatus` — 导出状态跟踪

### 管线 (pipeline/)

内容状态机驱动完整处理流程：

```
pending → capturing → captured → parsing → parsed → distilling → distilled → exporting → exported
```

## 数据存储

使用 better-sqlite3，WAL 模式，核心表：

| 表 | 用途 |
|---|---|
| `source_items` | 采集内容 |
| `capture_items` | 采集任务 |
| `distilled_outputs` | 蒸馏结果 |
| `export_records` | 导出记录 |
| `knowledge_cards` | 知识卡片 |
| `ai_tasks` | AI 任务队列 |
| `error_log` | 错误日志 |
| `settings` | 应用设置 |

数据库路径：`{storageRoot}/pinmind.db`，schema 版本通过 `_migration` 表管理。

## IPC 通信

所有主进程 ↔ 渲染进程通信通过 IPC channel 进行，channel 定义在 `src/shared/types.ts` 的 `IPC_CHANNELS` 中。

渲染进程通过 `window.pinmind.*` 调用，preload 层使用 `contextBridge` 安全暴露。

## 安全模型

- `contextIsolation: true` — 渲染进程无法直接访问 Node.js API
- `nodeIntegration: false` — 禁用 Node.js 集成
- CSP 策略 — 生产环境严格限制资源加载
- preload 脚本 — 唯一的 IPC 桥接层

## 日志系统

自研 5 通道 JSON-lines 日志：

| 通道 | 用途 |
|---|---|
| `app` | 应用生命周期 |
| `ai` | AI 调用记录 |
| `export` | 导出操作 |
| `error` | 错误记录（所有通道的 error 级别也会写入此文件） |
| `search` | 搜索操作 |

日志路径：`{storageRoot}/logs/`

## 前端架构

- **设计系统**：`renderer/design-system/` — tokens、primitives、icons、components
- **页面**：`renderer/pages/` — 每个页面独立目录
- **状态管理**：React Context + useState（无全局状态库）
- **路由**：基于 `activeView` 状态的条件渲染（无 react-router）
