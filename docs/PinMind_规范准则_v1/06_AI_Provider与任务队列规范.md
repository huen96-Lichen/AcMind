# AcMind AI Provider 与任务队列规范 v1

## 1. 设计目标

AcMind 的 AI 系统必须做到：

- 可插拔
- 可降级
- 可关闭
- 可观察
- 可追踪
- 可替换模型
- 不绑定具体模型名称

产品层不应该强行写死某个模型。

## 2. 模型等级

产品中只暴露三个模型等级：

```txt
本地轻量模型
云端常驻模型
云端强力模型
```

对应内部标识：

```ts
type AiProviderTier =
  | 'local_light'
  | 'cloud_standard'
  | 'cloud_strong';
```

## 3. 不绑定具体模型名称

禁止在业务逻辑中写死：

- 某个具体本地模型名称
- 某个具体云端模型名称
- 某个具体厂商名称
- 某个固定 API 地址

具体模型只属于 Provider 配置，不属于业务主链路。

## 4. Provider 抽象

```ts
interface AiProvider {
  id: string;
  name: string;
  tier: AiProviderTier;
  enabled: boolean;
  status: 'available' | 'unavailable' | 'checking' | 'error';
  runTask(task: AiTask, input: AiTaskInput): Promise<AiTaskResult>;
}
```

## 5. 任务类型

```ts
type AiTaskType =
  | 'summarize'
  | 'rename'
  | 'tag'
  | 'clean'
  | 'distill'
  | 'export';
```

## 6. 默认任务分配

| 任务 | 默认模型等级 |
|---|---|
| 改标题 | 本地轻量模型 |
| 提取标签 | 本地轻量模型 |
| 简短总结 | 本地轻量模型 |
| 清理口语化文本 | 本地轻量模型 |
| 长文蒸馏 | 云端常驻模型 |
| 多文档合并 | 云端常驻模型 |
| 深度分析 | 云端强力模型 |
| 复杂知识重构 | 云端强力模型 |

## 7. AI 任务状态

```ts
type AiTaskStatus =
  | 'pending'
  | 'running'
  | 'success'
  | 'failed'
  | 'cancelled';
```

## 8. 必须队列化

禁止：

```txt
按钮点击
↓
直接调用模型
↓
UI 等待返回
```

必须：

```txt
按钮点击
↓
创建 AiTask
↓
进入任务队列
↓
任务运行
↓
状态更新
↓
结果保存
↓
UI 读取状态
```

## 9. Mock Provider 规则

早期必须先支持 Mock Provider。

Mock Provider 的作用：

- 不依赖真实模型
- 跑通产品链路
- 方便演示
- 方便测试 UI
- 方便 Codex 核验主链路

Mock 必须清楚标注：

```txt
当前为 Mock 模式，仅用于链路演示。
```

禁止把 Mock 功能伪装成真实 AI。

## 10. 失败处理

AI 失败必须：

- 保存失败状态
- 显示错误原因
- 写入日志
- 允许重试
- 不影响原文
- 不导致应用崩溃

错误示例：

```txt
Error: undefined
```

正确示例：

```txt
AI 处理失败：当前云端模型 API Key 未配置，请前往设置页补充。
```

## 11. 成本提示

如果任务使用云端模型，UI 应提示：

- 当前使用的是云端模型
- 任务类型
- 大致成本等级
- 是否使用强力模型
- 是否允许继续

早期可以先做简单提示，不必立刻做精确 token 计费。

## 12. 降级策略

建议顺序：

```txt
本地轻量模型不可用
↓
提示用户或使用 Mock
```

```txt
云端常驻模型失败
↓
允许重试
↓
必要时切换云端强力模型
```

```txt
云端强力模型失败
↓
保留任务
↓
提示稍后重试
```

## 13. AI 输出约束

AI 不能直接覆盖用户原文。

必须：

- 原文保留
- 输出另存
- 预览后确认
- 支持撤销或重新生成
- 输出失败不影响原文
- 归档前用户可检查
