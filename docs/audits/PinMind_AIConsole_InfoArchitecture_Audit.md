# AcMind AI 控制台信息架构审计报告

## 1. 审计结论摘要

当前 AI 控制台的最大问题不是“没有功能”，而是**一个页面同时承载了四种不同职责**：模型来源管理、数据集管理、训练运行记录、模型版本管理，再叠加了全局统计、任务队列、运行日志和运行概览，导致信息层级被稀释，四个 tab 的边界不清晰。

结论上看：

- `模型来源` tab 最接近“控制台首页”，因为它承载了真实 provider 管理、启停状态、模型等级展示和任务队列入口。
- `数据集`、`训练运行`、`模型版本` 三个 tab 都是真实接口驱动，但当前更像“记录面板 / 管理子页”，而不是完整的独立工作台。
- 目前大量共享信息在四个 tab 中重复露出，主要是顶部统计卡片、模型状态卡片、任务队列、日志、运行概览与回退说明。
- `RightInspector` 在 AI Console 中已经被隐藏，当前问题不在右侧详情面板，而在**页面内部的信息叠层和职责混放**。

推荐方向：把 AI Console 收敛为“模型来源首页 + 三个专用管理页”，并将重复的总览内容只保留在 `模型来源` tab 里。

## 2. 当前 AI 控制台页面结构

### 2.1 总入口现在展示了什么

| 区域 | 当前内容 | 评估 |
|---|---|---|
| 顶部标题区 | `AI 控制台` 标题、说明文案、新建 AI 任务按钮 | 真实存在，但按钮语义更像“新建任务入口”，不是控制台总览动作 |
| 顶部统计卡片 | 可用模型、运行任务、失败任务、总任务数 | 真实统计，但属于全局概览，四个 tab 中都会出现 |
| tab 栏 | `模型来源` / `数据集` / `训练运行` / `模型版本` | 真实存在，但职责边界不够清楚 |
| 主内容区 | 当前 tab 对应内容 | 真实存在 |
| 共享区块 | 模型状态、任务队列、AI 日志、运行概览、运行模式、回退说明、最近错误 | 这些是重复信息的主要来源 |
| 右侧详情面板 | 当前 AI Console 已不挂载全局 `RightInspector` | 这点是正确的，不再是当前问题 |
| 底部空间 | 使用 `ScrollContainer bottomPadding={120}` 避免底部栏遮挡 | 基本可用，但页面内部仍偏“长而重” |

### 2.2 当前结构的核心问题

1. 顶部统计卡片不属于任何单一 tab，但却和 tab 页面内容并列出现，造成“总览 + 子页”混合。
2. `模型来源` tab 内其实塞了“控制台首页”应有的所有全局内容。
3. `数据集`、`训练运行`、`模型版本` 三个 tab 各自只有一小块专属内容，但仍被全局模块包围。
4. `任务队列`、`AI 日志`、`运行概览`、`回退说明` 都是跨页共享信息，但当前没有明确的收敛位置。

## 3. 四个 tab 当前信息清单

### 3.1 模型来源 tab

文件入口：`src/renderer/pages/ai-console/AiConsolePage.tsx`

| 展示内容 | 当前状态 | 真实接口 | 备注 |
|---|---|---|---|
| Provider / 模型来源卡片 | real | `providers.list` / `providers.add` / `providers.update` / `providers.delete` / `providers.testConnection` | 这是最核心、最真实的 AI 控制台能力 |
| 新增模型来源按钮 | real | `providers.add` | 应该只保留在这里，避免其它 tab 重复出现 |
| 模型状态分 tier 展示 | real | `providers.list` | 真实按 `local_light` / `cloud_standard` / `cloud_strong` 分层 |
| 任务队列 | real | `aiTasks.list` + `aiTasks.cancel` + `aiTasks.retry` | 是真实任务监控，但不一定应该在所有 tab 都重复强化 |
| AI 日志 | real | `logger.read('ai')` | 属于运行时观察信息，不是 tab 专属业务功能 |
| 运行概览 | real | `providers.list` + `useAiTasks()` | 和模型来源有关，但更像总览信息 |
| 模拟模式 / 回退说明 | real + placeholder | `tierRouter` / `mockDistiller` | 真实存在，但说明性文字偏多，容易让页面职责模糊 |

判断：

- `模型来源` tab 现在实际上是**AI Console 的首页**。
- 这里应该承载“模型接入、模型可用性、任务流入、运行状态”的总览。
- 这里保留任务队列是合理的，但不建议其它三个 tab 再重复展示同样的队列或运行统计。

### 3.2 数据集 tab

文件入口：`src/renderer/pages/ai-console/AiConsolePage.tsx`

| 展示内容 | 当前状态 | 真实接口 | 备注 |
|---|---|---|---|
| 创建数据集快照 | real | `datasets.createSnapshot` | 是真实可用接口 |
| 快照名称 / 描述输入 | real | `datasets.createSnapshot` | 属于该页的主操作 |
| 快照列表 | real | `datasets.list` | 真实可用 |
| 快照状态 / counts | real | `datasets.list` 返回值 | 说明快照有落库数据 |
| 额外的共享统计卡片 | repeat | `providers.list` + `useAiTasks()` | 和数据集职责无直接关系 |
| 共享模型状态 / 任务队列 / 日志 / 运行概览 | repeat | 多接口 | 这部分明显不该在数据集页重复出现 |

判断：

- 数据集页的真实职责应该是**数据集快照管理**。
- 当前已经有真实的快照创建和列表接口，所以这个页面不是 mock。
- 但页面主体被模型管理和运行观测内容包围，导致“数据集”看起来像附属功能。

### 3.3 训练运行 tab

文件入口：`src/renderer/pages/ai-console/AiConsolePage.tsx`

| 展示内容 | 当前状态 | 真实接口 | 备注 |
|---|---|---|---|
| 训练运行列表 | real | `trainingRuns.list` | 真实接口返回 |
| baseModel / snapshotId / status | real | `trainingRuns.list` | 这是训练记录的核心字段 |
| “外部 trainer 产出的运行记录回流入口”说明 | placeholder | 无 | 这是业务说明，不是独立功能 |
| “导入后的结果展示，不做常驻训练服务”说明 | placeholder | 无 | 明确表达能力边界，但不是操作能力 |
| 共享模型状态 / 任务队列 / 日志 / 概览 | repeat | 多接口 | 与训练运行职责弱相关 |

判断：

- `训练运行` tab 更像**外部训练仓的结果记录页**，而不是训练编排页。
- 当前代码没有提供“在这里直接训练”的闭环，所以这里的主要职责应当是“导入结果、查看记录、观察状态”。
- 这里不应该继续重复 provider 卡片或任务队列，否则会误导用户以为这是 AI 总控页。

### 3.4 模型版本 tab

文件入口：`src/renderer/pages/ai-console/AiConsolePage.tsx`

| 展示内容 | 当前状态 | 真实接口 | 备注 |
|---|---|---|---|
| 模型版本列表 | real | `modelVersions.list` | 真实可用 |
| candidate / active / archived | real | `ModelVersion.status` | 枚举真实存在 |
| 激活按钮 | real | `modelVersions.activate` | 真实接口 |
| 回滚按钮 | real | `modelVersions.rollback` | 真实接口 |
| 版本说明 / 导入提示 | placeholder | 无 | 用于解释当前能力边界 |
| 共享模型状态 / 任务队列 / 日志 / 概览 | repeat | 多接口 | 这里重复展示会削弱“版本管理”职责 |

判断：

- `模型版本` tab 是真实的版本管理页。
- 这里的核心能力是**激活、回滚、查看版本状态**。
- 它不应该再附带模型来源卡片和任务队列，否则页面会看起来像“什么都想做但什么都不聚焦”。

## 4. 重复信息与空间浪费分析

### 4.1 重复信息

| 重复模块 | 出现位置 | 是否应保留为全局 | 结论 |
|---|---|---|---|
| 顶部统计卡片 | 四个 tab 都在 | 可保留，但应只作为总览层，不应和子页内容混写 | 建议只保留一处，且信息量减少 |
| 模型状态卡片 | `模型来源` tab 主体 | 应保留在模型来源页 | 不建议在其它 tab 再出现 |
| 任务队列 | 主体区 + 观测区 | 应保留一处 | 目前最容易显得冗余 |
| AI 日志 | 主体区 | 可保留，但更适合“调试/观测”区域 | 不建议放到所有 tab 的主视觉里 |
| 运行概览 / 回退说明 / 最近错误 | 底部信息卡 | 应收敛 | 这是最典型的“共享状态堆叠” |

### 4.2 空间浪费

1. `模型来源` tab 已经承担了首页职责，但下面又继续堆任务队列、日志和运行概览，视觉和职责都过满。
2. `数据集` / `训练运行` / `模型版本` tab 的专属内容很少，但页面仍然保留相同体量的共享信息区域，导致专属内容被稀释。
3. 当前页面的“长页结构”并不等于“信息丰富”，更多是“共享区块重复出现”。

### 4.3 不建议继续重复展示的模块

- `ProviderCard` 列表不应出现在 `数据集`、`训练运行`、`模型版本` tab。
- `TaskQueueTable` 不应出现在 `数据集`、`训练运行`、`模型版本` tab 的主体区。
- `运行概览 / 运行模式 / 回退说明 / 最近错误` 这组底部状态卡不应在四个 tab 中重复堆叠。
- “新建 AI 任务”按钮如果保留，应明确属于 `模型来源` 首页入口，而不是四个 tab 的共用主动作。

## 5. 真实接口 / mock / placeholder 区分

### 5.1 接口能力分类

| 能力 | 状态 | 依据 | 备注 |
|---|---|---|---|
| `providers.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` + `src/shared/types.ts` | 真实 provider CRUD / 测试连接 |
| `aiTasks.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` | 真实任务队列 / 取消 / 重试 |
| `datasets.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` + `src/main/storage.ts` | 真实 snapshot 存取 |
| `trainingRuns.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` + `src/main/storage.ts` | 真实训练记录存取 |
| `modelVersions.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` + `src/main/storage.ts` | 真实版本管理 |
| `distilledOutputs.*` | real | `src/main/ipc.ts` + `src/preload/index.ts` + `src/main/storage.ts` | 真实蒸馏结果与审核流 |
| `tierRouter` | real | `src/main/services/distiller/tierRouter.ts` | 真实路由器，决定 provider 或 mock |
| `mockDistiller` | mock / fallback | `src/main/services/distiller/mockDistiller.ts` | 真实存在，但用于回退 |
| `localModelService` | real / fallback | `src/main/services/localModel/localModelService.ts` | 真实服务，包含 mock 回退路径 |

### 5.2 需要特别标记的占位能力

| 位置 | 状态 | 说明 |
|---|---|---|
| `训练运行` tab 的说明文案 | placeholder | 这是能力边界说明，不是训练编排 UI |
| `模型版本` tab 的导入提示 | placeholder | 说明主应用只做展示与切换 |
| `运行模式` 里的 Mock 说明 | placeholder | 页面上在解释“没有独立开关” |
| `回退说明` 里的 `tierRouter 自动处理` 文案 | placeholder | 在说明运行机制，而非提供操作 |

## 6. 推荐的新信息架构

### 6.1 推荐方向

你的倾向是正确的，而且与现有代码现状匹配：

- `模型来源` = AI 控制台总览页
- `数据集` = 数据集管理页
- `训练运行` = 训练任务页
- `模型版本` = 版本管理页

这个方向比“一个页里放所有观测面板”更符合当前接口能力，也更符合未来扩展。

### 6.2 推荐表

| 页面 | 当前问题 | 应保留内容 | 应移除内容 | 应新增 / 改造内容 | 接口风险 |
|---|---|---|---|---|---|
| 模型来源 | 现在承担了太多首页职责，但也最适合作为总览入口 | Provider 卡片、增删改查、测试连接、任务队列、运行总览 | 数据集列表、训练运行列表、模型版本列表 | 明确标注“控制台首页 / 总览” | 低，接口最完整 |
| 数据集 | 专属信息太少，被全局模块淹没 | 快照创建、快照列表、快照状态 | Provider 卡片、任务队列、日志、版本管理 | 可补“导出 bundle / 数据集详情”作为专属能力 | 低，`datasets.*` 已真实 |
| 训练运行 | 更像外部训练仓结果入口，不像独立工作台 | 训练记录、状态、baseModel、snapshotId、metrics | Provider 卡片、任务队列、运行概览 | 可补“导入结果 / 查看 eval 结果” | 中，当前更偏结果展示 |
| 模型版本 | 真实但偏薄，只承担版本状态和切换 | candidate / active / archived、激活、回滚 | Provider 卡片、任务队列、日志 | 可补版本详情、notes、artifactPath 预览 | 低，接口真实 |

## 7. 每个 tab 的推荐职责

### 7.1 模型来源

- 作为 AI 控制台首页。
- 展示 provider 体系、启停状态、模型等级、任务队列和运行态。
- 负责新增、编辑、删除、测试连接。
- 可保留 AI 日志和运行错误，但不建议把更多子页内容继续塞进来。

### 7.2 数据集

- 只负责快照管理。
- 提供创建快照、查看快照、必要时导出 bundle。
- 用清楚的空状态表达“当前没有快照”，不要复制模型页或任务页的内容。

### 7.3 训练运行

- 只负责训练结果记录。
- 以导入结果、查看运行记录、观察状态为主。
- 如果未来没有训练编排能力，就不要伪装成“训练中心”。

### 7.4 模型版本

- 只负责版本管理。
- 提供版本列表、状态、激活、回滚。
- 如果没有更多版本控制能力，保持页面克制，宁可空，也不要堆别的 tab 的信息。

## 8. UI 重排风险点

1. **误把“总览”拆散**  
   如果把模型来源页里的任务队列、日志和运行态全部拆掉，而其它 tab 又没有承担这些信息的地方，控制台会失去总览入口。

2. **误把“专属能力”藏掉**  
   `datasets.createSnapshot`、`trainingRuns.list`、`modelVersions.activate/rollback` 都是真接口，重排时不能让它们变成纯说明页。

3. **重复信息继续扩散**  
   最需要防的是：每个 tab 都保留一套运行概览 + 任务队列 + 说明卡。

4. **把 placeholder 当成功能删掉**  
   训练运行和模型版本页里有不少说明文字只是边界说明，不要误判成无用文案而直接删除掉能力边界。

5. **过度依赖“首页即万能页”**  
   模型来源页可以是首页，但首页不该继续把所有未来能力都塞进去。

## 9. 给 Trae 的执行建议

1. 先把 `模型来源` tab 明确为 AI Console 首页，保留 provider 管理、任务队列和运行总览。
2. 把 `数据集`、`训练运行`、`模型版本` 的共享运行信息尽量移除，只保留各自专属数据和动作。
3. 对三个非首页 tab 使用更克制的空状态和说明，而不是重复复制首页内容。
4. 让四个 tab 的信息层级一致：**首页负责观察和操作入口，子页负责专属管理**。
5. 不要改接口名、不改数据结构，只做信息组织与内容归属收敛。

## 10. 给 Codex 后续核验清单

- `providers.list/add/update/delete/testConnection` 是否仍然能从 `模型来源` 页触发。
- `datasets.createSnapshot` 是否仍然可用，快照列表是否仍然真实刷新。
- `trainingRuns.list` 是否仍然是外部训练结果入口，没有被改成假数据。
- `modelVersions.activate/rollback` 是否仍然是真实操作。
- `aiTasks.cancel/retry` 是否仍然在控制台里可用。
- `tierRouter` / `mockDistiller` 的 fallback 是否只在运行时作用，不被 UI 误解成独立功能。
- AI Console 是否只保留一处总览信息，而不是四个 tab 重复展示同一批状态。

