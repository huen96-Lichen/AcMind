# AcMind Agent v1 设计稿

> 目标：把 AcMind 的 `Agent` 板块做成一个 Hermes 风格的本地 Agent 入口。
>
> 原则：
> - 不把 AcMind 和 Hermes 直接耦合
> - 不把 Agent 做成单纯聊天页
> - Agent 负责理解、调度、执行建议和结果回填
> - 工作台、自动工具、设置保持各自边界

## 1. 设计目标

AcMind 的 Agent v1 不追求“什么都能做”，而追求以下四件事：

1. 用户一进入 AcMind，就知道可以直接对 Agent 说任务
2. Agent 能理解自然语言、快捷命令和上下文
3. Agent 能把任务分发到工作台、自动工具或设置里的能力
4. Agent 的输出不是一句话结束，而是能回填成结构化结果

### Agent v1 的定位

- 不是聊天机器人
- 不是模型配置页
- 不是工具台的替代品
- 是 AcMind 的意图入口和任务调度层

## 2. 体验目标

用户打开 AcMind 后，Agent 页应该像一个“会做事的入口”：

- 可以直接输入任务
- 可以使用 slash 命令
- 可以查看会话历史
- 可以看到 Agent 给出的动作建议
- 可以把结果送去工作台、自动工具、日程表
- 可以在需要时中断、重试、压缩上下文

### 用户心智

用户对 Agent 的期待应该是：

- “帮我理解这句话是什么意思”
- “帮我把这批内容整理一下”
- “帮我搜索历史信息”
- “帮我发起一个定时任务”
- “帮我打开对应的工作区页面”

而不是：

- “这里只是个聊天框”

## 3. Hermes 能力对照到 AcMind 的实现方向

| Hermes 能力 | AcMind Agent v1 目标 |
|---|---|
| 多模型接入与切换 | Agent 页展示当前模型状态，支持模型切换和降级提示 |
| 会话系统 | 会话不仅是聊天记录，而是任务执行上下文 |
| Slash 命令 | 提供统一命令入口，补齐 `/new`、`/reset`、`/model`、`/search`、`/compact`、`/tasks` |
| 工具调用 | 从“动作建议”升级为“结构化动作 + 执行入口” |
| 记忆 | 增加短期上下文和长期偏好记忆 |
| 技能系统 | 先做任务模板，再扩展为可复用技能 |
| 定时自动化 | Agent 能创建、查看、重试、暂停任务 |
| 子代理 / 并行 | 先做任务委派模型，再考虑并行执行 |
| MCP / 外部扩展 | 先做统一工具注册层，再考虑开放扩展协议 |
| 跨会话搜索 | 整合历史对话、工作台、知识库、任务日志搜索 |
| 上下文压缩 | 支持手动压缩和自动摘要 |
| 结构化输出 | Agent 回复带 `answer`、`actions`、`requires_confirmation` 等字段 |

## 4. 页面层设计

### 4.1 Agent 首页

Agent 首页保留以下区域：

- 会话列表
- 新对话按钮
- 输入框
- 流式消息区
- 快捷命令区
- 语音入口
- 动作建议区

### 4.2 右侧或展开面板

建议给 Agent 增加一个可切换的辅助信息区，用于显示：

- 当前会话状态
- 当前模型与 provider
- 可用命令
- 任务动作建议
- 当前上下文摘要

### 4.3 不做成独立控制台

Agent 页不应该变成：

- 密密麻麻的表格后台
- 很多折叠面板的配置页
- 工具和知识混杂的总控面板

## 5. Agent v1 的核心能力

### 5.1 对话能力

必须支持：

- 新建会话
- 切换会话
- 发送消息
- 流式输出
- 停止生成
- 历史加载

### 5.2 命令能力

建议支持：

- `/new` 新建任务会话
- `/reset` 重置当前会话
- `/model` 切换模型
- `/search` 搜索历史、工作台或知识库
- `/compact` 压缩上下文
- `/tasks` 查看任务
- `/skills` 查看可用模板或技能

### 5.3 动作能力

Agent 的回复可以包含动作建议，例如：

- 跳转到工作台某个 Tab
- 打开自动工具某个能力页
- 创建定时任务
- 生成整理建议
- 回填到知识库

### 5.4 记忆能力

Agent v1 先不追求复杂的向量记忆系统，但至少要支持：

- 当前会话上下文
- 最近任务摘要
- 用户偏好设置
- 当前页面上下文

### 5.5 结果回填

Agent 的输出应该能回填为结构化记录，例如：

- 暂存建议
- 整理建议
- 待确认项
- 任务记录
- 导航动作

## 6. 数据结构建议

### 6.1 会话

建议把 Agent 会话抽象为“任务会话”，而不是普通聊天会话。

字段建议：

- `id`
- `title`
- `status`
- `createdAt`
- `updatedAt`
- `modelId`
- `providerId`
- `contextSummary`
- `lastActionAt`

### 6.2 消息

字段建议：

- `id`
- `sessionId`
- `role`
- `content`
- `status`
- `createdAt`
- `updatedAt`
- `modelId`
- `providerId`
- `actionProposals`

### 6.3 动作建议

字段建议：

- `id`
- `type`
- `label`
- `description`
- `requiresConfirmation`
- `target`
- `params`
- `status`
- `createdAt`

### 6.4 记忆摘要

建议单独保存一份轻量摘要：

- `recentTopics`
- `preferredCommands`
- `frequentTargets`
- `lastSuccessfulActions`
- `userDefaults`

## 7. 协议层建议

Agent v1 最重要的是把输出从自然语言升级成结构化结果。

### 推荐输出格式

```ts
type AgentResult = {
  answer: string;
  actions?: Array<{
    type: 'navigate' | 'search' | 'create_task' | 'export' | 'distill' | 'open_tool';
    label: string;
    target?: string;
    params?: Record<string, unknown>;
    requiresConfirmation?: boolean;
  }>;
  contextSummary?: string;
  needsFollowUp?: boolean;
  error?: string;
};
```

### 设计原则

- 自然语言给用户看
- 结构化字段给系统用
- 不要让 UI 只能靠字符串解析

## 8. 路由和页面归属

### 8.1 Agent 只负责入口

Agent 不应该直接承担这些职责：

- 长期知识管理
- 文件格式处理
- OCR / 文档转换
- 导出实现细节

这些应该继续归到：

- `工作台`
- `自动工具`
- `设置`

### 8.2 Agent 可以发起的跳转

建议允许 Agent 跳转到：

- `workbench`
- `auto-tools`
- `schedule`
- `settings`

### 8.3 Agent 不应该再扩张成第三层主入口

避免把这些再做成一级心智：

- 搜索页
- 暂存池页
- 整理页
- 知识库页
- 工具台页

它们应该更多变成 Agent 可调度的内部能力或工作台内部 Tab。

## 9. MVP 验收标准

### 功能验收

- 默认打开就是 Agent
- 能创建和切换会话
- 能发送消息并流式返回
- 没配模型时能明确降级到 Mock 或提示配置
- 能通过快捷命令触发页面跳转
- 能把动作建议结构化展示出来
- 能保存和恢复会话上下文

### 产品验收

- 用户不会把 Agent 误认为普通聊天页
- 用户会自然把 Agent 当成入口
- Agent 回复可以引导用户进入工作台或自动工具
- Agent 的行为和产品定性一致

### 技术验收

- `typecheck` 通过
- `test` 通过
- `build` 通过
- 关键交互路径无报错

## 10. 推荐的实施顺序

1. 统一 Agent 的命令入口
2. 让 Agent 回复支持结构化动作建议
3. 增加会话上下文摘要
4. 增加记忆摘要
5. 增加任务状态视图
6. 再补上下文压缩
7. 最后补更强的工具协议

## 11. 不建议一开始就做的事

- 不要先做复杂多代理编排
- 不要先做技能市场
- 不要先做可视化工作流编辑器
- 不要先把所有工具都塞进 Agent 页面
- 不要先把搜索、工作台、自动工具重新并成一个大页面

## 12. 一句话定义

AcMind 的 Agent v1 应该是：

> 一个能理解任务、调用能力、生成动作建议、回填结果，并持续保持上下文的本地 Agent 入口。

