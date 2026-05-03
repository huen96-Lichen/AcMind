# AcMind

Local-first AI Memory Distiller — 将碎片化信息蒸馏为结构化知识，导出到 Obsidian Vault。

## 功能概览

- **多源采集**：剪贴板、语音、截图、网页、PDF、DOCX 等 12 种内容类型
- **AI 蒸馏**：支持本地模型（Ollama）和云端 API（OpenAI 兼容），自动分层路由
- **Obsidian 导出**：生成带 Frontmatter 的 Markdown，直接写入 Vault
- **Capsule 悬浮窗**：独立的快速采集入口
- **知识卡片**：蒸馏结果以知识卡片形式管理，支持搜索和标签

## 环境要求

- **Node.js** >= 20
- **macOS** (arm64) — 当前仅支持 Apple Silicon Mac
- **Ollama**（可选）— 用于本地 AI 蒸馏

## 快速开始

```bash
# 安装依赖
npm install

# 启动开发环境（主进程 + 渲染进程 + Electron 并行启动）
npm run dev
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `npm run dev` | 启动开发环境 |
| `npm run build` | 构建生产版本 |
| `npm run typecheck` | TypeScript 类型检查 |
| `npm run lint` | ESLint 检查 |
| `npm run format` | Prettier 格式化 |
| `npm run test` | 运行测试 |
| `npm run test:watch` | 测试 watch 模式 |
| `npm run package` | 打包 macOS DMG |
| `npm run package:local` | 本地打包（跳过签名） |
| `npm run check` | 完整检查（typecheck + lint + build） |

## 项目结构

```
src/
├── main/           # Electron 主进程
│   ├── services/   # 业务服务层（AI、采集、蒸馏、导出等）
│   ├── index.ts    # 主进程入口
│   ├── ipc.ts      # IPC 通信注册
│   └── storage.ts  # SQLite 存储层
├── preload/        # Preload 脚本（安全桥接）
├── renderer/       # React 前端
│   ├── components/ # UI 组件
│   ├── pages/      # 页面
│   ├── hooks/      # 自定义 Hooks
│   └── services/   # 渲染进程服务
└── shared/         # 主进程 & 渲染进程共享类型
```

详细架构说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 开发指南

- [开发流程](docs/DEVELOPMENT.md)
- [验收标准](docs/ACCEPTANCE.md)

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Electron 35 + React 18 |
| 语言 | TypeScript (strict) |
| 构建 | Vite (渲染) + esbuild (主进程/Preload) |
| 样式 | Tailwind CSS 3 |
| 数据库 | better-sqlite3 (WAL 模式) |
| 测试 | Vitest |
| 代码质量 | ESLint 9 + Prettier + Husky |
| CI | GitHub Actions |

## License

MIT
