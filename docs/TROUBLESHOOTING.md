# AcMind 故障排查

## 权限问题

### 屏幕录制权限

**症状**：截图功能不可用，截图为黑屏

**解决**：
1. 系统设置 → 隐私与安全性 → 屏幕录制
2. 找到 AcMind（或 Terminal / IDE），勾选启用
3. 重启应用

### 辅助功能权限

**症状**：快捷键不生效，全局快捷键注册失败

**解决**：
1. 系统设置 → 隐私与安全性 → 辅助功能
2. 添加 AcMind（或 Terminal / IDE）
3. 重启应用

### 完全磁盘访问

**症状**：无法读取某些文件，文件导入失败

**解决**：
1. 系统设置 → 隐私与安全性 → 完全磁盘访问
2. 添加 AcMind

## AI Provider 问题

### Ollama 连接失败

**症状**：扫描本地模型无结果

**排查**：
1. 确认 Ollama 正在运行：`curl http://localhost:11434/api/tags`
2. 检查 Ollama 监听地址（默认 `localhost:11434`）
3. 在设置中手动添加 Provider

### API Key 无效

**症状**：云端 AI 处理失败，返回 401 错误

**排查**：
1. 检查 API Key 是否正确
2. 在 Keychain 中搜索 `com.acore.acmind` 查看存储的 Key
3. 重新配置 Provider

### 模型超时

**症状**：AI 任务长时间运行无结果

**排查**：
1. 检查网络连接
2. 尝试切换到其他模型
3. 查看日志：`~/Library/Application Support/AcMind/logs/ai.log`

## 存储问题

### 数据库损坏

**症状**：应用启动失败，日志显示 SQLite 错误

**解决**：
1. 备份数据目录
2. 删除 `acmind.db` 和 `acmind.db-wal`
3. 重启应用（会创建新数据库）

### 磁盘空间不足

**症状**：采集失败，日志显示写入错误

**解决**：
1. 检查存储目录大小
2. 在应用中清理不需要的 SourceItem
3. 清理旧日志文件

## 查看日志

日志位置：`~/Library/Application Support/AcMind/logs/`

| 文件 | 内容 |
|------|------|
| `app.log` | 应用生命周期事件 |
| `ai.log` | AI 处理相关日志 |
| `export.log` | 导出操作日志 |
| `error.log` | 错误日志（聚合所有通道错误） |
| `search.log` | 搜索相关日志 |

### 导出诊断包

在 **工具 → 导出诊断** 中可导出完整诊断信息（含脱敏日志），用于问题反馈。

## 构建问题

### `npm run build` 失败

```bash
# 清理后重新构建
npm run clean
npm install
npm run build
```

### Electron 版本不匹配

```bash
# 确保 electron 版本一致
npx electron --version
npm ls electron
```
