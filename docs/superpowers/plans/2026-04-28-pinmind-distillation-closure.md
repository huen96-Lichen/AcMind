# AcMind 蒸馏闭环落地实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 AcMind 的蒸馏链路从“看起来能用”推进到“捕获、入库、蒸馏、审阅、导出、重启恢复都是真闭环”的产品级状态。

**Architecture:** 保留 `SourceItem -> AiTask -> DistilledOutput -> ExportRecord` 作为蒸馏运行时主干，不再把 `CaptureItem` 直接当成蒸馏输入。新增一个显式的捕获桥接层，把 `CaptureItem` 按需转换为带来源追踪的 `SourceItem`，并让 Capture Inbox、EditPage、DistillReviewPanel、AI Console、Export Page 都读取同一条运行时状态链。这样既能快速闭环，又不会把现有蒸馏管线重写成两套。

**Tech Stack:** Electron 35、React 18、TypeScript、better-sqlite3、preload IPC、Obsidian Markdown export、existing taskQueue/distillPipeline/batchProcessor/realDistiller/mockDistiller.

---

## 0. 现状判断

当前 AcMind 已经具备这些能力：

- `capture_items` 能持久化，列表、详情、导出都是真实功能
- `source_items`、`ai_tasks`、`distilled_outputs`、`export_records` 的运行时链路已经存在
- `tierRouter -> distillPipeline -> taskQueue -> realDistiller/mockDistiller` 已经能跑

但还没有真正闭环的地方是：

- `CaptureItem` 和 `SourceItem` 仍是两套独立对象
- Capture Inbox 的“蒸馏”入口和 EditPage 的“重新整理”仍然在不同模型之间打转
- Distill Review 的编辑结果、接受结果、导出结果需要进一步和持久化状态咬合
- AI Console 里一些摘要卡片仍然偏展示，需要改成只反映真实运行时或明确标注为示例

本计划不做大规模 UI 返工，也不改 AI 算法本身，目标是先把工具真的落地。

---

## 1. 设计约束

- 不引入第二套蒸馏主数据模型
- 不把 `CaptureItem` 直接塞进 `distillPipeline`
- 不新增“看起来很高级、但 runtime 不消费”的设置项
- 不把 mock 当成独立功能面板暴露给用户
- 所有状态变更都要能在重启后恢复
- 所有主动作都要有 IPC、storage、renderer 三层的真实连通证据

---

## 2. 推荐闭环路径

### 路径定义

1. 用户在 `Capture Inbox` 创建或导入碎片
2. 用户点击“开始蒸馏”或“转入整理”
3. 系统通过桥接层把 `CaptureItem` 转成 `SourceItem`
4. `distillPipeline` 只处理 `SourceItem`
5. `AiTask` 和 `DistilledOutput` 持久化
6. `EditPage` / `DistillReviewPanel` 读取同一条 `SourceItem` 运行时状态
7. 用户接受、编辑、导出到 Obsidian
8. 导出记录、任务状态、源条目状态在重启后仍可恢复

### 为什么这样做

- `SourceItem` 已经是现有蒸馏体系的唯一运行时主键
- 直接统一 `capture_items` 和 `source_items` 的风险更高，会一次性碰坏太多存量逻辑
- 桥接层可以先把“工具真的落地”做出来，再决定未来是否合并模型

---

## 3. 任务拆分

### Task 1: 建立捕获桥接层和数据追踪

**Files:**
- Modify: `src/shared/types.ts`
- Modify: `src/main/storage.ts`
- Modify: `src/main/captureService.ts`
- Modify: `src/main/services/distiller/distillPipeline.ts`
- Modify: `src/main/ipc.ts`

**目标**

让 `CaptureItem` 能明确转换为 `SourceItem`，并把来源关系持久化下来，后续蒸馏、审阅、导出都能沿着这个关系追踪。

**具体改动**

- 在 `SourceItem` 中补一个明确的来源字段，例如 `captureItemId?: string`
- 在 `source_items` 表中增加 `capture_item_id` 列和索引
- 新增一个桥接方法，例如：
  - `storage.createSourceItemFromCaptureItem(captureItemId: string): SourceItem`
  - `storage.getSourceItemByCaptureItemId(captureItemId: string): SourceItem | null`
- 如果同一 `CaptureItem` 已经有对应 `SourceItem`，直接复用，不重复创建
- `distillPipeline.distill()` 只接受 `sourceItemId`
- `CaptureItem` 仍保留原始碎片职责，不直接进入蒸馏引擎

**验收**

- 同一个碎片重复触发蒸馏不会生成重复的 SourceItem
- SourceItem 可以追溯到原始 CaptureItem
- 重启后桥接关系仍在

---

### Task 2: 让 Capture Inbox 真正成为蒸馏入口

**Files:**
- Modify: `src/renderer/pages/capture-inbox/CaptureInboxPage.tsx`
- Modify: `src/renderer/components/capture-inbox/CaptureItemDetail.tsx`
- Modify: `src/renderer/hooks/useCaptureItems.ts`
- Modify: `src/main/ipc.ts`
- Modify: `src/preload/index.ts`

**目标**

用户在收集箱里点“蒸馏”时，不是弹提示或只做导出，而是能把当前碎片推进到真实蒸馏队列。

**具体改动**

- 列表和详情面板都要暴露真实的“转入蒸馏”动作
- 点击后先确保有对应 `SourceItem`
- 再调用 `distill.run` 或 `distill.runSingle`
- 蒸馏失败时，给出明确错误和重试路径
- 删除当前项、筛选变化后，自动维护 `selectedItem` 不悬空

**验收**

- 从 Capture Inbox 点蒸馏，会看到真实 `AiTask` 进入队列
- 详情面板能显示蒸馏状态，而不是只显示原始碎片
- 蒸馏入口不是死按钮，也不是“先去别的页面”的空提示

---

### Task 3: 打通 EditPage 到蒸馏结果的真实回写

**Files:**
- Modify: `src/renderer/pages/edit/EditPage.tsx`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/storage.ts`
- Modify: `src/preload/index.ts`

**目标**

EditPage 不再只是假装能“重新整理”，而是能读取、编辑、保存、导出同一条 SourceItem 的蒸馏结果。

**具体改动**

- `EditPage` 的输入必须是 `SourceItem` 主键
- `distilledOutputs.list({ sourceItemId })` 必须能拿到当前条目的结果
- 编辑摘要、标题、分类、标签后，调用真实 IPC 持久化回写
- “重新整理”要重新提交蒸馏任务，而不是 toast 提示
- 保存草稿后，返回的内容必须和刷新后的结果一致

**验收**

- 页面刷新后，编辑过的结果仍在
- 同一个 SourceItem 的蒸馏结果只会显示在当前页，不会串到别的条目
- 重新整理会生成新的任务或新的输出版本，而不是静默失败

---

### Task 4: 让 Distill Review 成为正式审阅终点

**Files:**
- Modify: `src/renderer/components/distill/DistillReviewPanel.tsx`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/storage.ts`
- Modify: `src/preload/index.ts`

**目标**

审阅面板要能接受、拒绝、编辑、导出，并把结果真实写回数据库。

**具体改动**

- 审阅面板继续使用 `SourceItemId -> DistilledOutput` 的映射
- 编辑后的内容必须写回 `distilled_outputs`
- 接受 / 拒绝操作必须改变状态，而不是只改 UI
- 导出成功后，要写入 `export_records`
- 失败时要保留可恢复的错误信息，避免“点了但不知道发生什么”

**验收**

- 编辑、接受、拒绝三种动作都能重启恢复
- 审阅面板和导出中心看到的是同一份结果状态
- 导出记录能回查到对应源条目和输出版本

---

### Task 5: 把 AI Console 变成真实运行工具，而不是状态展板

**Files:**
- Modify: `src/renderer/pages/ai-console/AiConsolePage.tsx`
- Modify: `src/main/services/aiHub/taskQueue.ts`
- Modify: `src/main/services/distiller/tierRouter.ts`
- Modify: `src/main/services/distiller/distillPipeline.ts`
- Modify: `src/main/storage.ts`

**目标**

AI Console 只展示真实 provider、真实任务、真实失败原因和真实回退策略，不再混入伪运行态。

**具体改动**

- 去掉或收口任何独立的 Mock 开关
- 统计卡只展示真实的 provider / queue / failed task 信息
- 回退策略只显示 runtime 的实际策略，不伪造独立开关
- 任务队列支持取消、重试、失败原因追踪
- 模型状态、任务状态、日志状态三者之间要能互相对上

**验收**

- 任务队列变化会真实反映在 AI Console
- 没有可用 provider 时，用户能看见明确的降级原因
- 不再出现“看起来可配置，但其实不生效”的状态卡

---

### Task 6: 让导出中心和知识库输出可追踪

**Files:**
- Modify: `src/renderer/pages/export/ExportPage.tsx`
- Modify: `src/main/ipc.ts`
- Modify: `src/main/storage.ts`
- Modify: `src/main/services/exporter/obsidianExporter.ts`
- Modify: `src/main/services/exporter/markdownBuilder.ts`

**目标**

蒸馏结果导出后，要能从导出记录反查到源条目、输出版本和最终文件路径。

**具体改动**

- 导出成功后，写入 `export_records`
- 导出失败时，保留错误原因和冲突处理信息
- 导出路径、frontmatter、冲突策略要和设置页保持一致
- 导出中心要显示真实的成功 / 失败 / 重试状态

**验收**

- 结果导出后能在导出中心看到记录
- 重新打开应用后导出记录还在
- 冲突处理不会丢失原始蒸馏结果

---

### Task 7: 加上端到端验证和回归测试

**Files:**
- Create or modify: `src/main/services/distiller/*.test.ts`
- Create or modify: `src/main/storage.test.ts`
- Create or modify: `src/renderer/pages/edit/EditPage.test.tsx`
- Create or modify: `src/renderer/pages/capture-inbox/CaptureInboxPage.test.tsx`
- Modify: `package.json` if test scripts need a narrower command

**目标**

用测试和最小手工流程证明闭环真的通了，不靠“看起来差不多”判断完成。

**建议覆盖**

- `CaptureItem -> SourceItem` 桥接只生成一次
- `distillPipeline.distill()` 能为同一 SourceItem 创建任务
- `distilledOutputs.review('edit')` 能真正写回 storage
- `export.single()` 会写入 `export_records`
- `EditPage` 在重启后仍能读回保存结果

**验收**

- typecheck 通过
- build 通过
- vitest 全绿
- 手工链路可重复：
  - 新建碎片
  - 转入蒸馏
  - 审阅编辑
  - 导出到 Obsidian
  - 重启后再看结果仍在

---

## 4. 今晚执行顺序

建议按这个顺序推进：

1. Task 1，先把捕获桥接和数据追踪钉住
2. Task 2，把 Capture Inbox 蒸馏入口真正接到 runtime
3. Task 3，把 EditPage 变成真实整理页
4. Task 4，把审阅结果写回数据库
5. Task 5，把 AI Console 的运行态收口成真实状态
6. Task 6，把导出和知识库输出串起来
7. Task 7，补测试和回归验证

---

## 5. 非目标

本计划暂时不做：

- 新增新的大模型品牌入口
- 重写整个 settings 系统
- 再做一轮大规模 UI 重构
- 把 `CaptureItem` 和 `SourceItem` 两套表彻底合并
- 引入云端协作或多用户功能

这些可以留到闭环之后再做。

---

## 6. 完成标准

当且仅当以下条件同时满足，才算“蒸馏工具真的落地”：

- Capture Inbox 能把一条碎片推进到真实蒸馏任务
- EditPage 能读写真实蒸馏结果
- Distill Review 能编辑并持久化结果
- Export 能把结果送入 Obsidian 并保留记录
- AI Console 能反映真实任务状态和失败原因
- 重启后，这条链路上的关键状态仍然存在

