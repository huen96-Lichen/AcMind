# AcMind PRD v1

> 项目名称：AcMind  
> 产品全称：Acore AcMind  
> 所属品牌：Acore  
> 产品定位：个人桌面 AI 信息中枢  
> 当前阶段：MVP 启动 / 工程底座已建立  
> 核心口号：先 Pin 住，再变成知识。  
> 核心目标：把零碎、破碎、分散的信息，低成本收进来，再筛理、清洗、沉淀为有价值的信息资产。  
> 当前版本：v1  
> 文档用途：作为 AcMind 新项目的产品总纲、工程执行边界、Trae/Codex 协作依据。

---

## 0. 第一性原则

AcMind 不是笔记软件，不是截图工具，也不是语音输入法。

AcMind 的第一性原则是：

> 降低个人信息从“出现”到“沉淀”的使用成本。

它负责信息进入正式知识库之前的四件事：

1. 快速留下
2. 初步筛理
3. 人工确认
4. 标准化导出

所有功能判断都围绕一个问题：

> 这个功能是否能让用户更轻松地把分散信息变成长期有价值的资产？

如果不能，MVP 阶段先不做。

---

## 1. 一句话定义

AcMind 是一个桌面级 AI 信息中枢。

它把复制、截图、语音、网页、文件和临时想法快速收集起来，先进入 Pin Pool 临时留存，再通过 AI 预筛、人工确认和蒸馏整理，最终沉淀为 Markdown / Obsidian 友好的知识资产。

AcMind 不是传统笔记软件，也不是单一截图工具、剪贴板工具或语音输入法。

它的核心位置是：

```text
信息进入知识库之前的桌面缓冲层、筛理层和处理层。
```

更具体地说：

```text
桌面信息入口
  ↓
临时 Pin Pool
  ↓
人工 / AI 筛理
  ↓
正式 Inbox
  ↓
蒸馏整理
  ↓
Markdown / Obsidian / 未来个人模型数据
```

---

## 2. 产品本质

AcMind 的本质不是“功能集合”，而是一个持续降低知识沉淀成本的系统。

如果用户手动完成整个流程，通常需要：

```text
看到信息
  ↓
判断是否有价值
  ↓
复制 / 截图 / 录音 / 下载
  ↓
找地方保存
  ↓
命名
  ↓
分类
  ↓
清洗
  ↓
总结
  ↓
打标签
  ↓
导出到知识库
  ↓
后续复盘
```

这个流程太长，所以大部分信息最终会丢失、遗忘或散落在不同软件里。

AcMind 要做的是把流程压缩成：

```text
先 Pin 住
  ↓
每天筛一下
  ↓
有价值的内容自动变成标准 Markdown
```

所以 AcMind 的核心不是“帮用户做更多事情”，而是：

> 让用户用更低的成本，完成原本应该做但很难坚持做的知识沉淀动作。

---

## 3. 项目资产分工

AcMind 不是从零幻想重写，而是整合三个已有项目中最有价值的部分。

```text
AcMind = 主数据模型 / AI 蒸馏 / Inbox / Review / Markdown Export
PinStack = 截图 / 剪贴板 / Pin 卡片 / 胶囊 / 托盘 / 快捷键
OpenLess = 语音输入 / 全局热键 / 录音 / ASR / AI 润色 / 词典 / 插入兜底经验
```

### 3.1 AcMind 的角色

AcMind 是 AcMind 的工程底座和知识处理主线。

保留：

- SQLite 主存储
- CaptureItem
- SourceItem
- AiTask
- DistilledOutput
- ExportRecord
- Capture Inbox
- AI Distill
- Review / Edit
- Markdown Preview
- Obsidian Export
- History / Errors
- 本地优先的数据处理经验

不保留或暂缓：

- 旧产品命名
- 旧 AcMind 视觉风格中不符合 AcMind 的部分
- 过重的 AI Console
- 尚未形成闭环的复杂训练概念

### 3.2 PinStack 的角色

PinStack 是 AcMind 的桌面采集和前台手感来源。

迁入方向：

- 截图
- 固定比例截图
- 剪贴板自动收集
- hash 去重
- ignoreNextCopy
- 悬浮 Pin 卡片
- 横向桌面小胶囊
- 托盘
- 快捷键
- 轻、快、漂亮、顺手的前台体验

不迁入：

- JSONL 主存储
- 旧 Dashboard
- mock AI 主线
- 音乐控制
- Notch 深度集成作为 MVP 核心

### 3.3 OpenLess 的角色

OpenLess 是 AcMind 的语音核心资产来源。

AcMind 不把 OpenLess 作为独立语音输入法照搬，而是吸收其能力：

- 录音状态机：Idle → Starting → Listening → Processing
- ASR Provider 思路：Volcengine / Whisper-compatible
- AI polish 原则
- 词典 / 专有名词修正
- 历史记录经验
- 浮动胶囊体验
- 全局热键触发经验
- 插入兜底经验

AcMind 的语音目标不是优先“插入当前光标”，而是：

```text
语音 → 转写 → 清洗 → Voice Pin → Pin Pool → Inbox → Distill → Export
```

后续可以支持“直接插入当前输入框”，但它不是 MVP 主线。

### 3.4 obsidian-maintainer 的位置

`obsidian-maintainer` 不作为语音主线。

它后续只作为 VaultKeeper Engine 候选资产，用于：

- Markdown 清洗
- 文件导入
- PDF / DOCX / EPUB / TXT 转 Markdown
- 网页剪藏
- Obsidian vault 维护经验
- 文件命名和路径整理
- 批量标准化经验

---

## 4. 核心产品原则

### 4.1 先留下，再判断

用户遇到信息时不需要马上判断是否值得入库。

默认动作是先捕获、先 Pin 住。

用户不应该在信息出现的瞬间被迫思考：

- 这个信息有没有价值？
- 应该放到哪个文件夹？
- 要不要总结？
- 用什么标题？
- 要不要进入 Obsidian？

这些判断应该后移。

### 4.2 Pin Pool 是核心中间层

不是所有内容都直接进入 Inbox 或 Obsidian。

所有临时内容先进入 Pin Pool：

```text
Capture → Pin Pool → Promote to Inbox / Ignore / Delete / Merge
```

Pin Pool 的价值：

- 防止脏数据污染知识库
- 降低收集时的心理负担
- 支持每日集中筛理
- 给 AI 预筛提供空间
- 承接桌面 Pin 卡片体验
- 记录用户对信息价值的真实判断

### 4.3 PinItem 不等于 SourceItem

PinItem 是临时对象，SourceItem 是正式知识处理对象。

强约束：

```text
禁止所有捕获内容默认直接生成 SourceItem。
只有用户 promote，或规则明确 auto-promote 后，才允许创建 SourceItem。
```

这条边界非常重要。

AcMind 的价值不是“收集越多越好”，而是：

```text
先缓冲，后入库。
```

### 4.4 本地优先

AcMind 处理的是个人信息资产。

默认要求：

- 本地 SQLite
- 原始文件本地保存
- Markdown 可迁移
- Obsidian 友好
- 不强制云账号
- 不默认上传隐私内容
- 用户可随时导出和迁移
- 所有云端 AI 调用都必须可解释、可关闭、可替换

### 4.5 当前不训练个人 LLM

长期目标可以服务个人 LLM / RAG / 长期记忆系统，但 MVP 不做训练。

当前要积累的是：

- 原始信息
- AI 预筛结果
- AI 蒸馏结果
- 用户筛理动作
- 用户修改记录
- 最终 Markdown
- 标签和分类偏好
- 标题风格
- 高频概念
- 用户长期表达习惯

这些数据是未来个人模型 / RAG / 长期记忆系统的底座。

### 4.6 AI 只辅助，不越权

MVP 阶段 AI 不能替用户做不可逆决策。

AI 可以建议：

- promote_to_inbox
- ignore
- merge
- review_later
- add_tags
- rename
- summarize
- polish

AI 默认不允许：

- 自动永久删除
- 自动覆盖原文
- 自动修改用户 vault 中已有文件
- 自动编造不存在的信息
- 在语音 polish 中替用户回答问题
- 把用户的口述扩写成模型自己的结论

---

## 5. 核心模块边界

AcMind 的核心体验由四层组成：

```text
桌面胶囊 = 随手入口
Quick Desk = 当前工作台
Pin Pool = 数据中间层
Knowledge Flow = 正式处理区
```

### 5.1 桌面胶囊

桌面胶囊是 AcMind 的随手入口。

它不是主界面里的普通按钮，而是独立的桌面级快捷入口。

MVP 方向：

- 横向小胶囊
- 默认轻量常驻
- 可展开
- 可收起
- 可拖拽
- 可贴边
- 可触发快速输入
- 可触发截图
- 可触发语音
- 可打开 Quick Desk

胶囊的重点不是展示复杂信息，而是降低启动成本。

原则：

```text
胶囊负责“叫出 AcMind”，不负责承载完整工作台。
```

### 5.2 Quick Desk

Quick Desk 是 AcMind 首屏。

它不是传统知识库后台，而是桌面快捷工具台。

它负责回答：

> 我现在有什么刚收进来的东西需要处理？

结构建议：

- 左侧：快捷动作
  - 截图
  - 收集剪贴板
  - 录音 / Voice Pin
  - 输入想法
- 中间：Pin Pool
  - 当前 Pin
  - 最近捕获
  - 待筛理
  - AI 建议
- 右侧：当前选中内容
  - 预览
  - AI 预筛结果
  - 入 Inbox
  - 忽略
  - 删除

Quick Desk 的职责：

- 展示今日待处理内容
- 快速收集
- 快速预览
- 快速筛理
- 快速进入正式处理区

Quick Desk 不应该变成：

- 完整知识库后台
- AI Console
- 复杂设置页
- 大型文件管理器
- 全功能 Dashboard

### 5.3 Pin Pool

Pin Pool 是 AcMind 的核心中间层。

它不是普通列表，而是临时信息池。

Pin Pool 承接：

- 复制文本
- 截图
- 图片剪贴板
- 语音 transcript
- 手动输入
- 网页片段
- 文件导入占位
- 后续扩展的移动端 / iCloud 输入

Pin Pool 中的每条内容都应该有明确状态。

状态建议：

```text
captured
pinned
prefiltering
prefiltered
promoted_to_inbox
ignored
deleted
merged
```

Pin Pool 的用户操作：

- 预览
- promote to Inbox
- ignore
- delete
- merge
- edit title
- edit tags
- mark important
- review later

### 5.4 Knowledge Flow

Knowledge Flow 是正式知识处理区。

包含：

- Inbox
- Distill
- Review / Edit
- Markdown Preview
- Export
- History
- Errors

Knowledge Flow 负责把 SourceItem 变成可以长期维护的 Markdown 知识资产。

原则：

```text
Pin Pool 负责“筛选是否值得处理”。
Knowledge Flow 负责“把值得处理的内容变成知识”。
```

---

## 6. MVP 主流程

AcMind MVP 的最小闭环：

```text
桌面胶囊 / Quick Desk
  ↓
截图 / 复制 / 语音 / 手动输入
  ↓
Pin Pool
  ↓
人工筛理 / AI 预筛
  ↓
Promote to Inbox
  ↓
基础蒸馏
  ↓
Review
  ↓
Markdown / Obsidian Export
```

### 6.1 MVP 首批必须闭环

必须优先跑通：

```text
手动输入 → Pin Pool → Promote to Inbox → Markdown Export
复制文本 → Pin Pool → Promote to Inbox → Markdown Export
语音 transcript → Voice Pin → Pin Pool → Promote to Inbox
截图 → Pin Pool → Promote to Inbox → Markdown Export
```

其中最优先的是：

```text
手动输入 / 复制文本 → Pin Pool → Promote → Markdown
```

原因：

- 它最简单
- 它最能验证 Pin Pool 是否成立
- 它最能验证用户是否愿意每天把碎片信息丢进来
- 它最早产生 Obsidian 可见结果

### 6.2 MVP 不应过早追求

MVP 不应过早追求：

- 大规模 AI 自动整理
- 完整知识图谱
- 复杂 RAG
- 完整个人模型训练
- 复杂插件系统
- 多窗口复杂交互
- 过度拟物化 UI
- 重型 AI Console
- 过度自动删除或自动入库

---

## 7. 信息架构

### 7.1 顶层导航

MVP 顶层导航建议：

```text
Quick Desk
Pin Pool
Inbox
Review
Export
History
Settings
```

不建议 MVP 阶段展示过多入口。

可隐藏或后置：

```text
AI Console
VaultKeeper
Model Training
Knowledge Graph
Plugin Market
```

### 7.2 Quick Desk 页面结构

Quick Desk 是默认打开页面。

建议布局：

```text
┌────────────────────────────────────────────┐
│ 顶部：AcMind / 今日状态 / 胶囊状态 / 设置入口 │
├──────────────┬────────────────┬────────────┤
│ 快捷动作      │ Pin Pool 列表    │ 当前预览     │
│              │                │            │
│ + 输入想法    │ 今日待筛理       │ 标题         │
│ + 截图        │ 最近捕获         │ 内容预览     │
│ + 录音        │ AI 建议          │ 操作按钮     │
│ + 剪贴板      │                │            │
└──────────────┴────────────────┴────────────┘
```

Quick Desk 的核心体验：

- 一眼知道今天收了什么
- 一眼知道哪些需要处理
- 点一条就能预览
- 一键 promote / ignore / delete
- 没有内容时有清晰空状态
- 出错时能告诉用户下一步怎么办

### 7.3 Pin Pool 页面结构

Pin Pool 可以作为 Quick Desk 的扩展页面。

用于更集中处理临时内容。

建议能力：

- 状态筛选
- 类型筛选
- 时间筛选
- 搜索
- 单条操作
- 批量操作
- AI 预筛状态
- 用户决策记录

MVP 阶段可以先做单条，后做批量。

### 7.4 Inbox 页面结构

Inbox 只接收已经 promote 的内容。

每个 SourceItem 进入 Inbox 后才可以进行正式处理。

Inbox 操作：

- 查看原始内容
- 启动 AI Distill
- 编辑标题
- 编辑标签
- 编辑分类
- 进入 Review
- 标记无需处理
- 返回 Pin Pool

### 7.5 Review 页面结构

Review 是正式导出前的确认区。

Review 需要展示：

- 原始内容引用
- AI 蒸馏结果
- Markdown Preview
- frontmatter
- 标签
- 输出路径
- 导出按钮

Review 的核心目标：

> 让用户在最终入库前，有一次轻量但可信的确认。

### 7.6 Export 页面结构

Export 负责 Markdown / Obsidian 输出。

MVP 必须支持：

- 输出到指定目录
- 文件名规则
- frontmatter
- tags
- 原始来源引用
- 导出记录
- 冲突处理

后续支持：

- Obsidian vault 自动识别
- 多 Format Profile
- 批量导出
- 文件移动
- vault 维护

---

## 8. 数据模型

### 8.1 CaptureItem

来自 AcMind，表示一次捕获记录。

用于承接文本、链接、图片、音频等原始输入。

建议字段：

- id
- sourceType
- rawText
- rawFilePath
- sourceUrl
- metadata
- createdAt
- updatedAt

CaptureItem 是原始捕获层，不直接代表正式知识。

### 8.2 PinItem

AcMind MVP 新增模型。

表示进入 Pin Pool 的临时内容。

核心字段：

- id
- captureItemId
- originalId
- sourceType
- title
- previewText
- thumbnailPath
- rawFilePath
- rawText
- status
- position
- valueScore
- duplicateScore
- suggestedAction
- suggestedTags
- userDecision
- prefilterReason
- createdAt
- pinnedAt
- updatedAt

状态：

```text
captured
pinned
prefiltering
prefiltered
promoted_to_inbox
ignored
deleted
merged
```

PinItem 必须能追踪：

- 它来自哪里
- 当前处于什么状态
- AI 给过什么建议
- 用户做过什么决策
- 是否已经进入正式知识流

### 8.3 SourceItem

正式进入 Inbox 后的知识处理对象。

Pin Pool 中的内容只有被 promote 后才生成或关联 SourceItem。

建议字段：

- id
- pinItemId
- captureItemId
- sourceType
- title
- content
- rawFilePath
- sourceUrl
- status
- createdAt
- updatedAt

SourceItem 是正式知识处理对象。

### 8.4 AiTask

AI 任务记录。

用于追踪：

- 预筛任务
- 蒸馏任务
- 语音 polish
- 标题生成
- 标签建议
- 分类建议
- 失败重试

建议字段：

- id
- taskType
- targetType
- targetId
- provider
- model
- status
- inputHash
- output
- error
- createdAt
- updatedAt

### 8.5 DistilledOutput

AI 蒸馏结果。

包含：

- id
- sourceItemId
- suggestedTitle
- summary
- tags
- category
- contentMarkdown
- valueScore
- qualityFlags
- reviewStatus
- createdAt
- updatedAt

### 8.6 ExportRecord

最终导出记录。

记录 Markdown / Obsidian 输出路径、frontmatter、冲突处理和导出状态。

建议字段：

- id
- sourceItemId
- distilledOutputId
- exportPath
- filename
- frontmatter
- status
- conflictStrategy
- error
- createdAt
- updatedAt

---

## 9. 数据目录规范

默认数据目录：

```text
~/AcMind/
```

建议结构：

```text
~/AcMind/
  acmind.db
  raw/
    images/
    audio/
    files/
    webpages/
    clipboard/
  exports/
    markdown/
  logs/
  cache/
  thumbnails/
  temp/
```

### 9.1 raw/

保存原始输入。

要求：

- 不覆盖
- 不随意改写
- 与数据库记录可追踪
- 删除必须有明确用户动作

### 9.2 exports/

保存导出的 Markdown 文件。

MVP 可以默认：

```text
~/AcMind/exports/markdown/
```

后续可以设置为用户的 Obsidian vault 目录。

### 9.3 logs/

保存关键运行日志。

至少包括：

- capture 日志
- ai task 日志
- export 日志
- error 日志

### 9.4 thumbnails/

保存图片 / 截图缩略图。

用于 Pin Pool 快速预览。

### 9.5 cache/

保存可重建缓存。

用户清理 cache 不应导致核心数据丢失。

---

## 10. AI 分层

### 10.1 AI 预筛

发生在 Pin Pool。

目标是快、轻、便宜，不生成长文。

输出示例：

```json
{
  "suggested_title": "AcMind 与 PinStack 合并思路",
  "value_score": 82,
  "duplicate_score": 12,
  "suggested_action": "promote_to_inbox",
  "reason": "内容涉及产品核心决策，建议长期保留",
  "tags": ["AcMind", "产品设计", "信息中枢"]
}
```

AI 预筛可以建议：

- promote_to_inbox
- ignore
- merge
- review_later

AI 预筛不允许默认：

- 永久删除
- 覆盖原始内容
- 无确认自动入库
- 对截图无 OCR 时伪造内容
- 对音频无 transcript 时伪造总结
- 对网页无正文时伪造正文

### 10.2 AI 蒸馏

发生在 Inbox 后。

目标是把内容整理成可读、可维护、可导出的 Markdown。

输出应包含：

- 标题
- 摘要
- 正文
- 标签
- 分类
- 来源
- frontmatter
- quality_flags

AI 蒸馏的原则：

```text
整理、压缩、结构化，不编造。
```

### 10.3 语音 Polish

来自 OpenLess 原则。

AI 只整理用户说的话，不回答、不执行、不新增事实。

正确目标：

```text
把口语转成清晰、结构化、可沉淀的文字。
```

错误目标：

```text
替用户回答问题，或把口述内容扩写成模型自己的结论。
```

语音 Polish 输出建议：

- clean_text
- summary
- possible_title
- tags
- uncertain_terms
- dictionary_suggestions

### 10.4 AI Provider 策略

MVP 不强绑定单一模型。

建议保留 Provider 抽象：

- Local Provider
- Cloud Provider
- Mock Provider
- Whisper-compatible ASR Provider
- Volcengine ASR Provider

所有 AI 调用都应记录：

- provider
- model
- prompt version
- input hash
- output
- error
- createdAt

---

## 11. Markdown 输出规范

AcMind 的正式输出必须 Obsidian 友好。

### 11.1 默认 Markdown 结构

```md
---
title: 标题
created: 2026-05-03
source_type: clipboard_text
source: AcMind
tags:
  - AcMind
  - 信息中枢
status: distilled
---

# 标题

## 摘要

这里是摘要。

## 正文

这里是整理后的正文。

## 关键点

- 关键点 1
- 关键点 2

## 来源

- 来源类型：clipboard_text
- 原始记录：AcMind 内部记录 ID

## 处理记录

- Capture：已完成
- Pin Pool：已 Promote
- AI Distill：已完成
- Review：已确认
```

### 11.2 命名原则

默认文件名：

```text
YYYY-MM-DD_标题.md
```

要求：

- 文件名可读
- 避免过长
- 避免非法字符
- 冲突时自动追加序号
- 标题可由用户最终确认

### 11.3 输出原则

Markdown 输出必须：

- 保留用户原意
- 不引入编造事实
- 保留来源信息
- 支持 Obsidian 双链后续扩展
- 支持标签和 frontmatter
- 支持未来批量迁移

---

## 12. 设置项

MVP 设置保持克制。

必须包含：

- 自动收集剪贴板
- 胶囊默认开启
- 截图后默认动作
- 语音转写 Provider
- Obsidian vault 路径
- Markdown 输出目录
- AI Provider
- 快捷键
- 数据目录

### 12.1 剪贴板设置

- 是否自动收集文本
- 是否自动收集图片
- 忽略密码类内容
- 暂停收集
- ignoreNextCopy
- hash 去重

### 12.2 胶囊设置

- 是否启动时显示
- 默认位置
- 是否贴边
- 是否置顶
- 快捷键
- 展开默认动作

### 12.3 AI 设置

- Provider
- Model
- 是否启用预筛
- 是否启用蒸馏
- 是否启用语音 polish
- 隐私提示
- 本地 / 云端调用说明

### 12.4 导出设置

- Markdown 输出路径
- Obsidian vault 路径
- 文件命名规则
- frontmatter 默认字段
- 冲突策略

---

## 13. 当前已落地工程状态

当前 AcMind 已完成第一版可运行底座：

- 从 AcMind 同步为 AcMind 工程底座
- `package.json` 改为 `acmind`
- 产品名改为 `AcMind`
- appId 改为 `com.acore.acmind`
- 默认存储目录改为 `~/AcMind`
- SQLite 文件改为 `acmind.db`
- 新增 `pin_pool_items` 表
- 新增 Pin Pool 类型、CRUD、IPC、preload API
- 新增 Quick Desk 页面
- 新增 Voice transcript → Voice Pin → Pin Pool 入口
- 新增 OpenLess-informed voice 模块边界：
  - recorder
  - asr
  - polish
  - dictionary
- 新增 `window.acmind` preload alias，同时保留 `window.acmind` 兼容旧页面

验证结果：

```text
npm run typecheck 通过
npm run build     通过
npm test          17 files / 410 tests 通过
```

已知环境问题：

```text
npm install 在本机 Node 25 + Python 3.14 下会因 better-sqlite3 原生编译失败。
原因是 node-gyp 依赖 distutils，而 Python 3.14 环境缺失 distutils。
当前验证复用了 AcMindV2.0 已存在的 node_modules。
```

建议后续处理：

- 锁定推荐 Node 版本
- 锁定 Python 构建说明
- 增加 `.nvmrc`
- 增加环境准备文档
- CI 中验证 clean install
- 避免只依赖旧 node_modules 通过

---

## 14. MVP 不做什么

MVP 不做：

- 个人 LLM 训练
- 完整 RAG
- 知识图谱
- 多人协作
- 账户系统
- 云同步
- 商业化
- 插件市场
- 音乐控制
- Swift Notch 深度集成
- 完整 AI Console
- 大规模 Vault 批处理
- 独立 VaultKeeper 产品页面
- 自动批量改写 Obsidian vault
- 高风险自动删除
- 复杂插件市场
- 移动端 App

第一阶段只回答一个问题：

```text
用户会不会愿意每天把碎片信息丢进 AcMind？
```

---

## 15. 版本路线

### Phase 0：工程底座

状态：已完成。

目标：

- AcMind → AcMind 底座
- AcMind 命名
- Pin Pool schema
- Quick Desk 初版
- Voice Pin 骨架
- typecheck / build / tests 通过

验收：

- 应用可运行
- 名称替换完成
- 数据库可初始化
- Pin Pool 基础 CRUD 可用
- Quick Desk 可进入
- 测试通过

---

### Phase 1：Pin Pool 单条闭环

目标：

- 手动输入进入 Pin Pool
- Pin Pool 列表稳定展示
- 单条 Pin 可预览
- 单条 Pin 可 promote / ignore / delete
- Pin 状态变化可追踪
- Quick Desk 空状态、错误状态、加载状态完整

不做：

- 批量筛理
- 复杂 AI 预筛
- 截图迁移
- 语音完整 ASR

验收：

- 用户可以手动输入一条内容
- 内容进入 Pin Pool
- 用户可以查看该内容
- 用户可以 promote 到 Inbox
- 用户可以 ignore
- 用户可以 delete
- 所有状态都写入数据库
- UI 不出现“点了没反应”

---

### Phase 2：剪贴板文本自动进入 Pin Pool

目标：

- 文本剪贴板自动捕获
- hash 去重
- ignoreNextCopy
- 暂停收集
- 剪贴板内容默认进入 Pin Pool
- 设置中可开关

验收：

- 复制普通文本后生成 PinItem
- 重复复制不会无限生成重复内容
- 应用内部复制不会被错误收集
- 暂停收集后不再捕获
- 恢复收集后正常工作
- 捕获失败有日志和提示

---

### Phase 3：Promote to Inbox + Markdown Export

目标：

- Pin Pool promote 到 Inbox
- 创建 SourceItem
- 基础 Distill
- Markdown Preview
- Obsidian / Markdown Export
- ExportRecord

验收：

- PinItem promote 后生成 SourceItem
- SourceItem 可进入 Inbox
- 用户可生成 Markdown
- 用户可预览 Markdown
- 用户可导出到指定目录
- ExportRecord 记录导出路径和状态
- 导出的 Markdown 可被 Obsidian 正常读取

---

### Phase 4：PinStack 截图直接 Pin

目标：

- 迁入 PinStack 截图 controller
- 自由截图
- 固定比例截图
- 截图后直接生成 Image Pin
- 缩略图预览
- 原图本地归档
- Pin Card 悬浮预览

验收：

- 用户可触发截图
- 截图文件保存到 raw/images
- Pin Pool 出现 Image Pin
- Image Pin 可预览
- Image Pin 可 promote 到 Inbox
- 无 OCR 时不伪造图片内容
- 截图权限异常有明确提示

---

### Phase 5：AI 预筛

目标：

- 接入真实 AI Provider
- 重复判断
- 价值评分
- 建议动作
- 建议标题
- 建议标签
- 用户决策记录

验收：

- PinItem 可触发 AI prefilter
- 输出 value_score
- 输出 duplicate_score
- 输出 suggested_action
- 输出 reason
- 输出 tags
- AI 失败不影响手动筛理
- AI 不自动永久删除内容
- 用户最终决策被记录

---

### Phase 6：OpenLess 语音能力深化

目标：

- 胶囊录音
- 全局快捷键
- Volcengine / Whisper-compatible ASR
- 词典热词
- AI polish
- Voice Pin 自动进入 Pin Pool

验收：

- 用户可开始 / 停止录音
- 录音文件保存到 raw/audio
- ASR 成功后生成 transcript
- transcript 生成 Voice Pin
- AI polish 只整理不代答
- 词典可影响专有名词修正
- ASR 失败有重试和错误提示

---

### Phase 7：桌面胶囊体验深化

目标：

- 横向小胶囊
- 展开 / 收起
- 快速输入
- 快速截图
- 快速录音
- 贴边
- 拖拽
- 置顶
- 状态反馈

验收：

- 胶囊可稳定显示
- 胶囊不会遮挡核心操作
- 展开后可快速输入
- 展开后可触发截图 / 录音
- 收起后轻量存在
- 多屏环境下位置合理
- 崩溃或异常时不影响主窗口

---

### Phase 8：VaultKeeper Engine

目标：

- 文件导入
- 网页剪藏
- PDF / DOCX / EPUB / TXT 转 Markdown
- Markdown 标准化
- 原始文件归档
- Obsidian vault 维护能力候选

验收：

- 用户可导入文件
- 文件保存到 raw/files
- 可生成待处理 PinItem
- 可转换为 Markdown
- 不可解析时生成占位和错误说明
- 不直接污染正式 vault
- 用户确认后才导出

---

## 16. 成功标准

### 16.1 一周内

用户可以稳定完成：

- 手动输入进入 Pin Pool
- 复制内容进入 Pin Pool
- Pin Pool 单条预览
- Pin Pool promote 到 Inbox
- 基础 Markdown 输出

### 16.2 一个月内

用户可以形成：

- 每日 Pin Pool
- 每日筛理记录
- 每周 Markdown 知识沉淀
- Obsidian 中结构统一的知识资产
- 初步标签习惯
- 初步标题风格

### 16.3 三个月内

用户拥有：

- 高质量原始内容
- AI 清洗结果
- 用户修改记录
- 标签习惯
- 标题风格
- 分类偏好
- 可用于个人模型 / RAG 的数据基础
- 对 AcMind 的稳定使用习惯

---

## 17. 体验判断标准

AcMind 的体验好坏，不用功能数量判断。

应该用这些问题判断：

1. 用户是否愿意每天打开？
2. 用户是否愿意把碎片信息丢进去？
3. 用户是否觉得收集成本明显降低？
4. 用户是否能在一天结束时快速筛理？
5. 用户是否能看到最终沉淀到 Obsidian 的成果？
6. 用户是否信任 AcMind 不会乱删、乱改、乱编？
7. 用户是否觉得它比手动复制、命名、总结、归档更轻松？

如果这些问题答案是“是”，AcMind 就成立。

---

## 18. UI 与产品调性

AcMind 属于 Acore 品牌体系。

整体调性：

```text
安静、克制、清晰、可信、轻盈、精致、有长期使用感。
```

视觉关键词：

- Apple-like
- OpenAI-like
- frosted glass
- soft shadow
- quiet hierarchy
- clean typography
- rounded capsule
- low-noise interface
- local-first confidence

UI 原则：

- 一页一个主目标
- 一个区域最多一个主按钮
- 状态必须清楚
- 错误必须可理解
- 空状态必须告诉用户下一步
- 动效轻，不打扰
- 信息密度适中
- 不为了炫技牺牲可用性

桌面胶囊调性：

```text
像一个安静但随时可用的桌面 AI 入口。
```

Quick Desk 调性：

```text
像一个当天信息的清爽工作台，而不是复杂后台。
```

Knowledge Flow 调性：

```text
像一个可信的知识处理流水线，而不是花哨编辑器。
```

---

## 19. Trae 执行约束

后续交给 Trae 时必须强调：

1. 不允许大范围自由重构。
2. 每个 Phase 只完成当前 Phase 范围。
3. 不允许绕过 Pin Pool 直接写入 SourceItem。
4. 不允许捕获内容默认进入 Obsidian。
5. 所有新增功能必须有错误状态和空状态。
6. 所有数据库变更必须有 migration 或初始化兼容。
7. 所有 IPC / preload API 必须有类型定义。
8. 所有状态变更必须可追踪。
9. 所有文件保存路径必须符合 `~/AcMind` 数据目录规范。
10. 完成后必须更新：
    - package/version 如有需要
    - CHANGELOG
    - WORKLOG
    - docs/PROJECT_HANDOVER.md
    - 对应测试或验证说明

---

## 20. Codex 核验约束

每个 Phase 完成后，Codex 需要核验：

1. 是否符合当前 Phase 范围。
2. 是否误做了后续 Phase 的复杂功能。
3. 是否破坏已有 AcMind / AcMind 主流程。
4. 是否所有新增 API 有类型。
5. 是否数据库读写稳定。
6. 是否状态变化可追踪。
7. 是否 UI 有空状态、加载状态、错误状态。
8. 是否 `npm run typecheck` 通过。
9. 是否 `npm run build` 通过。
10. 是否测试通过或有明确原因说明。
11. 是否存在隐私风险。
12. 是否存在 AI 编造内容的风险。
13. 是否存在自动删除 / 自动覆盖风险。
14. 是否符合本 PRD 的第一性原则。

---

## 21. 最终判断

AcMind 的核心不是功能多。

AcMind 的核心是让用户愿意把分散信息交给它，并相信它能把这些信息变成长期有价值的资产。

前台像 PinStack：

- 轻
- 快
- 漂亮
- 顺手
- 随时可用

内核像 AcMind：

- 结构化
- 可追踪
- 可清洗
- 可导出
- 可积累

语音像 OpenLess：

- 快速说
- 准确转
- 只整理
- 不代答
- 保留个人词典和表达习惯

一句话：

```text
AcMind 先帮你把信息留住，再帮你把信息变成知识。
```

最终长期方向：

```text
AcMind 不只是一个收集工具。
它是个人知识资产、个人表达习惯、个人长期记忆和未来个人模型的前置中枢。
```
