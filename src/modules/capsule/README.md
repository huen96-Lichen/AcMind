# Capsule 模块

## 职责

- 桌面横向胶囊（Desktop Muse Capsule）
- 菜单栏 / tray 入口
- 快速输入
- 快速拖拽
- 当前状态展示
- 进入 Capture / Inbox / AI Action 的轻入口

## 不负责

- 复杂知识管理
- 具体 AI 整理逻辑
- 文件转换逻辑

## 输入

- 用户快速输入文本
- 拖拽文件/图片
- 快捷键触发

## 输出

- SourceItem（发送到 Inbox）
- CaptureRecord（发送到 Capture 管线）

## 依赖

- `capture` — 截图/采集能力
- `inbox` — 统一收集入口
- `ai-runtime` — 快速 AI 动作

## 现有代码映射

- `src/main/capsuleController.ts` — 胶囊窗口控制
- `src/renderer/pages/capsule/` — 胶囊 UI
- `src/shared/capsuleSettings.ts` — 胶囊配置
