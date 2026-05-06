# AcMind 隐私说明

## 数据存储原则

AcMind 是 **本地优先** 的桌面应用。所有数据默认存储在本地，不会自动上传到云端。

### 本地存储

- **数据库**：SQLite，存储在 `~/Library/Application Support/AcMind/acmind.db`
- **原始内容**：文本、图片、音频等存储在 `~/Library/Application Support/AcMind/sources/`
- **日志**：存储在 `~/Library/Application Support/AcMind/logs/`

### 数据库内容

| 表 | 内容 | 敏感级别 |
|----|------|---------|
| `source_items` | 采集的原始内容引用 | 中 |
| `ai_tasks` | AI 处理任务记录（输入截断存储） | 低 |
| `distilled_outputs` | AI 处理结果 | 低 |
| `providers` | AI Provider 配置 | 低 |

## AI Provider 数据流向

当配置云端 AI Provider（如 OpenAI）时：

1. **发送内容**：原始文本会发送到配置的 API 端点
2. **API Key**：存储在 macOS Keychain（`com.acore.acmind.<provider>`），不会离开本机
3. **处理结果**：返回的结构化结果存储在本地数据库

### 隐私模式

在 **设置 → 模型策略** 中开启"隐私模式"后：
- 优先使用本地模型（Ollama）
- 云端处理前需要手动确认

## 诊断包

导出诊断包时（**工具 → 导出诊断**）：
- 日志中的 API Key、长文本会被自动脱敏
- 包含系统信息（OS 版本、内存、CPU）
- 不包含原始采集内容的全文

## Keychain 使用

AcMind 使用 macOS Keychain 安全存储 API Key：
- Service 名称：`com.acore.acmind.<provider>`
- Account：`apiKey`
- 数据不会通过网络传输
- 可在 **钥匙串访问** 应用中查看和删除

## 数据删除

- 在应用内删除 SourceItem 会同时删除关联的本地文件
- 卸载应用不会自动删除数据目录，需手动删除
- Vault 导出的文件不受应用管理
