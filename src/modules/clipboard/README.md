# Clipboard 模块

## 职责

- 剪贴板监听（文本 / 图片 / 链接 / 文件）
- 剪贴板历史记录
- 智能卡片展示
- 重新复制
- 转纯文本 / 转 Markdown
- 发送到 Inbox

## 不负责

- 全局知识库搜索
- 模型路由
- 文件转换处理

## 输入

- 系统剪贴板变化事件
- 用户手动复制操作

## 输出

- ClipboardItem（剪贴板历史记录）
- SourceItem（发送到 Inbox）

## 依赖

- `capture` — 底层剪贴板监听
- `storage` — 持久化剪贴板记录
- `inbox` — 发送到收集箱

## 现有代码映射

- `src/main/clipboardWatcher.ts` — 剪贴板监听
- `src/main/services/capture/clipboardTextAdapter.ts` — 剪贴板文本适配器

## Phase 0 说明

本模块当前功能分散在 capture 和 clipboardWatcher 中。
Phase 0 目标是建立清晰的模块边界和 ClipboardItem 数据模型，
后续 Phase 1 将从 PinStack 吸收完整的剪贴板管理能力。
