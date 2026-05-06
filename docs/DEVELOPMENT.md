# 开发指南

## 环境搭建

```bash
# 1. 克隆仓库
git clone <repo-url>
cd acmind

# 2. 安装依赖
npm install

# 3. 启动开发环境
npm run dev
```

### 环境要求

- Node.js >= 20
- macOS (arm64)
- Ollama（可选，用于本地 AI 蒸馏）

## 开发工作流

### 启动开发环境

`npm run dev` 会并行启动 4 个进程：

1. `dev:renderer` — Vite dev server (localhost:5173)
2. `dev:main` — esbuild watch 编译主进程
3. `dev:preload` — esbuild watch 编译 preload
4. `dev:electron` — 等待上述就绪后启动 Electron

### 代码规范

项目使用 ESLint + Prettier + Husky 强制代码规范：

- **提交时自动检查**：pre-commit hook 运行 lint-staged
- **手动检查**：`npm run lint` / `npm run format:check`
- **自动修复**：`npm run lint:fix` / `npm run format`

### 类型检查

```bash
npm run typecheck
```

TypeScript 严格模式开启，所有 `any` 使用需要 `eslint-disable` 注释说明原因。

## 测试

### 运行测试

```bash
# 单次运行
npm run test

# Watch 模式
npm run test:watch
```

### 测试规范

- 测试文件使用 `.test.ts` 后缀，与被测文件同目录
- 测试框架：Vitest
- 测试环境：Node（主进程逻辑）
- 渲染进程组件测试：使用 `@testing-library/react`（待完善）

### 编写测试

```typescript
import { describe, it, expect } from 'vitest';

describe('featureName', () => {
  it('should do something', () => {
    expect(result).toBe(expected);
  });
});
```

## 构建与打包

```bash
# 构建生产版本
npm run build

# 打包 macOS DMG
npm run package

# 本地打包（跳过签名和公证）
npm run package:local
```

### 构建产物

```
dist/
├── main/index.cjs      # 主进程
├── preload/index.cjs   # Preload 脚本
└── renderer/            # 渲染进程（Vite 输出）
```

## 完整检查

发布前运行完整检查：

```bash
npm run check
# 等同于: npm run typecheck && npm run lint && npm run build
```

## CI/CD

GitHub Actions 在 push/PR 到 main 时自动运行：

1. **Lint** — ESLint 检查
2. **Typecheck** — TypeScript 类型检查
3. **Test** — Vitest 测试
4. **Build** — 生产构建（依赖 lint + typecheck 通过）
5. **Security Audit** — npm audit

## 错误诊断

日志文件位于 `{storageRoot}/logs/` 目录：

| 文件 | 内容 |
|------|------|
| `app.log` | 应用生命周期 |
| `ai.log` | AI 调用 |
| `export.log` | 导出操作 |
| `error.log` | 所有错误 |
| `search.log` | 搜索操作 |

所有日志为 JSON-lines 格式，每行一个 JSON 对象。

## 常见问题

### Electron 启动失败

确保 `dist/main/index.cjs` 和 `dist/preload/index.cjs` 已构建完成。

### AI 蒸馏不工作

检查 Ollama 是否运行：`ollama list`。如使用云端 API，在设置中配置 API Key。

### 数据库损坏

SQLite 数据库位于 `{storageRoot}/acmind.db`。如遇损坏，删除该文件后重启应用会自动重建。
