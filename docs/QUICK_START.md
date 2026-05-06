# AcMind 快速开始

## 安装与启动

### 环境要求

- macOS 14+ (Apple Silicon)
- Node.js 20+
- npm 10+

### 开发模式

```bash
npm install
npm run dev
```

### 构建生产版本

```bash
npm run build
npm run package:mac:arm64
```

## 数据存储位置

AcMind 默认将数据存储在用户目录下：

```
~/Library/Application Support/AcMind/
├── acmind.db          # SQLite 数据库
├── sources/           # 采集的原始内容
├── exports/           # 导出的 Markdown 文件
├── logs/              # 应用日志
└── capsule/           # Capsule 配置
```

可在 **设置 → 存储** 中修改存储路径。

## 核心功能

### 剪贴板监控

- 默认开启，自动捕获复制的内容（文本、图片、链接）
- 在 **设置 → 剪贴板** 中可暂停/恢复监控
- 支持按应用过滤（scope mode）

### Capsule 浮窗

- 桌面浮窗，显示最近采集的内容
- 在 **设置 → Capsule** 中可开关、调整位置和大小
- 快捷键 `Cmd+Shift+D` 切换显示

### 截图采集

- 快捷键 `Cmd+Shift+S` 全屏截图
- 支持区域截图（框选区域）
- 截图自动进入收件箱

### AI Provider 配置

1. 打开 **设置 → AI Provider**
2. 点击"扫描本地"检测 Ollama
3. 或手动添加 OpenAI-compatible API：
   - 名称：自定义
   - Base URL：API 端点
   - API Key：密钥（存储在 macOS Keychain）
   - 模型 ID：如 `gpt-4o-mini`

### 导出到 Obsidian / Markdown

1. 配置 Vault 路径：**设置 → Vault**
2. 选择导出文件夹和模板
3. 在 Review 页面审核后一键导出
4. 也支持直接导出为 Markdown 文件

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+S` | 截图 |
| `Cmd+Shift+D` | 切换 Dashboard |
| `Cmd+Shift+V` | 语音输入 |

## 常见问题

- **权限弹窗**：首次使用需要授予"屏幕录制"、"辅助功能"权限
- **Keychain 访问**：API Key 存储在系统 Keychain，需要授权
- **日志位置**：`~/Library/Application Support/AcMind/logs/`
