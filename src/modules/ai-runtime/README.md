# AI Runtime 模块

## 职责

- 本地模型 / 云端模型 provider 管理
- OpenAI-compatible endpoint 支持
- Ollama 本地模型支持
- Action Registry（AI 动作注册）
- Prompt Profile 管理
- AI 任务队列
- 失败回退策略
- 模型路由（tierRouter）

## 不负责

- UI 页面直接状态
- 业务数据存储 schema 的主导权

## 输入

- AIAction（动作定义）
- ProviderConfig（模型配置）
- 处理请求（来自 Distill / Capture）

## 输出

- AI 处理结果
- 任务状态变更事件

## 依赖

- `storage` — 持久化 provider 配置和任务记录

## 现有代码映射

- `src/main/services/aiHub/` — AI 中心
  - `taskQueue.ts` — 任务队列
  - `secretStore.ts` — 密钥管理
- `src/main/services/strategy/` — 策略系统
  - `modelRouter.ts` — 模型路由
  - `promptProfile.ts` — 提示词配置
  - `qualityFallback.ts` — 质量回退
- `src/shared/ai/modelRegistry.ts` — 模型注册表
