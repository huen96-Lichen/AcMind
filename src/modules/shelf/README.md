# Shelf 模块

## 职责

- 文件临时架
- 拖拽暂存
- 文件 / 图片 / 链接批量暂存
- 发送到 Inbox
- 后续可接 MarkItDown 文件转换

## 不负责

- 完整文件管理器
- 云盘同步
- Finder 替代品

## 输入

- 用户拖拽文件/图片
- 从剪贴板粘贴
- 从 Capture 发送

## 输出

- ShelfItem（临时架项目）
- SourceItem（发送到 Inbox）

## 依赖

- `storage` — 持久化暂存记录
- `inbox` — 发送到收集箱
- `capture` — 接收采集内容

## 现有代码映射

本模块为新增模块，当前项目中无直接对应代码。
Phase 0 建立数据模型和模块边界，Phase 1 从 PinStack 吸收 Shelf 能力。
