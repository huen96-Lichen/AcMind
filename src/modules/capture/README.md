# Capture 模块

## 职责

- 截图（全屏/区域/窗口）
- 贴图 / 钉图
- OCR 文字识别
- 标注
- 录音入口
- 语音采集入口
- 剪贴板文本采集
- 网页内容采集
- 文件导入采集

## 不负责

- AI 总结逻辑
- Obsidian 导出逻辑
- 长期知识库逻辑

## 输入

- 用户截图操作
- 剪贴板变化
- 文件拖拽
- URL 输入
- 语音录制

## 输出

- CaptureRecord → 进入管线
- SourceItem → 进入 Inbox
- AssetFile → 存储到资产目录

## 依赖

- `storage` — 持久化采集记录
- `ai-runtime` — OCR / ASR 能力

## 现有代码映射

- `src/main/captureService.ts` — 采集服务主入口
- `src/main/services/capture/` — 12 种采集适配器
- `src/main/services/strategy/` — 内容策略处理
- `src/renderer/pages/capture/` — 采集 UI
- `src/renderer/pages/capture-inbox/` — 采集收件箱 UI
