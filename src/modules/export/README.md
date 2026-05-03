# Export 模块

## 职责

- Markdown 输出
- Obsidian / iCloud 目录写入
- frontmatter 生成
- 文件命名规则
- 导出记录管理
- Markdown 规范兼容

## 不负责

- AI prompt
- 原始截图采集
- 剪贴板监听

## 输入

- DistilledNote（来自 Distill）
- ExportConfig（导出配置）

## 输出

- ExportRecord（导出记录）
- 文件系统写入（Markdown 文件）

## 依赖

- `storage` — 持久化导出记录
- `distill` — 读取蒸馏结果

## 现有代码映射

- `src/main/services/exporter/` — 导出服务
  - `markdownBuilder.ts` — Markdown 构建
  - `obsidianExporter.ts` — Obsidian 导出
  - `frontmatter.ts` — Frontmatter 生成
  - `safeWrite.ts` — 安全写入
  - `pathResolver.ts` — 路径解析
  - `conflictHandler.ts` — 冲突处理
- `src/renderer/pages/export/` — 导出 UI
