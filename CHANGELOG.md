# Changelog

## 0.4.0 (2026-05-01) — Phase 11

### Added
- **今日知识流首页** (`/daily-flow`)：用户每天打开 PinMind 的第一个页面
  - 顶部 4 统计卡：今日收集 / 已整理 / 已进入 Obsidian / 需要处理
  - 今日知识流列表：每条显示标题、来源类型、用户可读状态、摘要、时间、主操作
  - 筛选标签：全部 / 已进入 Obsidian / 需要处理 / 等待处理 / 语音 / 网页 / 文件
  - 关键词搜索：标题、摘要、标签、来源类型、输出路径
  - 需要处理区：聚合失败和等待内容，用户可读错误文案
  - 最近进入 Obsidian 区：最近 10 条成功输出，支持打开文件和在 Finder 中显示
  - 本周回顾区：本周收集/写入统计、来源类型分布、高频标签、高价值内容推荐
  - 完整空状态设计（无收集/无失败/无输出/无本周数据）
- **状态映射**：内部状态 → 用户可读中文文案，不暴露工程概念
- **来源类型映射**：text/clipboard/url/screenshot/file/pdf/audio/voice/video → 中文标签
- **高价值内容规则**：基于 quality_flags / tags / 标题长度判断，不做模型推荐
  - UI 明确标注"规则推荐"标签，避免被误认为模型结果
- **主操作接入真实业务逻辑**：打开 Obsidian 文件 / 重试整理 / 查看详情 / 查看录音 / 忽略错误
- **数据口径映射文档**：CaptureRecord→CaptureItem / OutputHistory→ExportRecord / ErrorLog→ErrorRecord
- Sidebar 新增"今日"导航项（置顶）

### Changed
- 默认首页从 `capture-inbox` 改为 `daily-flow`
- onboarding 完成后导航到 `daily-flow`
- 版本号 0.3.0 → 0.4.0

## 0.3.0 (2026-05-01) — Phase 10

### Added
- 语音输入与录音工作流产品化
- VoiceWatchService / AudioTranscriptionService
- 语音设置面板

## 0.2.2 (2026-04-29)

### Added
- EditPage 审阅页产品化
- 导出 false-success 修复
- 真闭环修复（三轮）
