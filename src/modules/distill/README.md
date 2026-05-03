# Distill 模块

## 职责

- AI 整理（标题生成、摘要、标签、分类）
- 结构化 Markdown 草稿生成
- quality_flags 质量评估
- 批量蒸馏处理
- 蒸馏结果审核

## 不负责

- 数据采集
- 截图 / 剪贴板监听
- UI 常驻入口

## 输入

- SourceItem（来自 Inbox）
- AI 模型配置（来自 AI Runtime）

## 输出

- DistilledNote（蒸馏结果）
- ProcessJob（处理任务记录）

## 依赖

- `ai-runtime` — 模型调用
- `storage` — 持久化蒸馏结果
- `inbox` — 读取 SourceItem

## 现有代码映射

- `src/main/services/distiller/` — 蒸馏管线
  - `distillPipeline.ts` — 主管线
  - `realDistiller.ts` — 真实模型蒸馏
  - `mockDistiller.ts` — 本地规则蒸馏
  - `tierRouter.ts` — 模型层级路由
  - `distillPrompts.ts` — 提示词模板
- `src/main/services/strategy/` — 策略系统
- `src/renderer/pages/distill/` — 蒸馏 UI
