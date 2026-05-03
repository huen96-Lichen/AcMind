# AcMind PRD v0.2

> 项目名称：AcMind  
> 产品全称：Acore AcMind  
> 产品定位：个人桌面 AI 信息中枢  
> 当前阶段：MVP 启动 / 工程底座已建立  
> 核心口号：先 Pin 住，再变成知识。  
> 核心目标：把零碎、破碎、分散的信息，低成本收进来，再筛理、清洗、沉淀为有价值的信息资产。  
> 版本变更：v0.2 基于 v0.1 整合 7 项工程执行边界优化。

---

## 0. 第一性原则

AcMind 不是笔记软件，不是截图工具，也不是语音输入法。

AcMind 的第一性原则是：

```text
降低个人信息从"出现"到"沉淀"的使用成本。
```

它负责信息进入正式知识库之前的四件事：

1. **快速留下** — 信息出现时，零摩擦捕获
2. **初步筛理** — AI 辅助判断价值和去重
3. **人工确认** — 用户决定是否入库
4. **标准化导出** — 输出为 Markdown / Obsidian 友好格式

后续所有功能判断都有锚点：

```text
能不能降低信息沉淀成本？不能就先不做。
```

---

## 1. 一句话定义

AcMind 是一个桌面级 AI 信息中枢。

它把复制、截图、语音、网页、文件和临时想法快速收集起来，先进入 Pin Pool 临时留存，再通过 AI 预筛、人工确认和蒸馏整理，最终沉淀为 Markdown / Obsidian 友好的知识资产。

AcMind 不是传统笔记软件，也不是单一截图工具、剪贴板工具或语音输入法。

它的核心位置是：

```text
信息进入知识库之前的桌面缓冲层、筛理层和处理层。
```

---

## 2. 项目资产分工

AcMind 不是从零幻想重写，而是整合三个已有项目中最有价值的部分。

```text
AcMind = 主数据模型 / AI 蒸馏 / Inbox / Review / Markdown Export
PinStack = 截图 / 剪贴板 / Pin 卡片 / 胶囊 / 托盘 / 快捷键
OpenLess = 语音输入 / 全局热键 / 录音 / ASR / AI 润色 / 词典 / 插入兜底经验
```

### 2.1 AcMind 的角色

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

### 2.2 PinStack 的角色

PinStack 是 AcMind 的桌面采集和前台手感来源。

迁入方向：

- 截图
- 固定比例截图
- 剪贴板自动收集
- hash 去重
- ignoreNextCopy
- 悬浮 Pin 卡片
- 桌面胶囊
- 托盘
- 快捷键

不迁入：

- JSONL 主存储
- 旧 Dashboard
- mock AI 主线
- 音乐控制
- Notch 深度集成作为 MVP 核心

### 2.3 OpenLess 的角色

OpenLess 是 AcMind 的语音核心资产来源。

AcMind 不把 OpenLess 作为独立语音输入法照搬，而是吸收其能力：

- 录音状态机：Idle → Starting → Listening → Processing
- ASR Provider 思路：Volcengine / Whisper-compatible
- AI polish 原则
- 词典 / 专有名词修正
- 历史记录经验
- 浮动胶囊体验

AcMind 的语音目标不是"插入当前光标"，而是：

```text
语音 → 转写 → 清洗 → Voice Pin → Pin Pool → Inbox → Distill → Export
```

### 2.4 obsidian-maintainer 的位置

`obsidian-maintainer` 不作为语音主线。

它后续只作为 VaultKeeper Engine 候选资产，用于：

- Markdown 清洗
- 文件导入
- PDF / DOCX / EPUB / TXT 转 Markdown
- 网页剪藏
- Obsidian vault 维护经验

---

## 3. 核心产品原则

### 3.1 先留下，再判断

用户遇到信息时不需要马上判断是否值得入库。

默认动作是先捕获、先 Pin 住。

### 3.2 Pin Pool 是核心中间层

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

### 3.3 本地优先

AcMind 处理的是个人信息资产。

默认要求：

- 本地 SQLite
- 原始文件本地保存
- Markdown 可迁移
- Obsidian 友好
- 不强制云账号
- 不默认上传隐私内容

### 3.4 当前不训练个人 LLM

长期目标可以服务个人 LLM / RAG / 长期记忆系统，但 MVP 不做训练。

当前要积累的是：

- 原始信息
- AI 预筛结果
- AI 蒸馏结果
- 用户筛理动作
- 用户修改记录
- 最终 Markdown
- 标签和分类偏好

### 3.5 PinItem 不等于 SourceItem（强约束）

PinItem 是临时对象，SourceItem 是正式知识处理对象。

```text
禁止所有捕获内容默认直接生成 SourceItem。
只有用户 promote，或规则明确 auto-promote 后，才允许创建 SourceItem。
```

这是 AcMind 的核心产品边界。AcMind 的价值不是"收集越多越好"，而是"先缓冲，后入库"。

违反此约束的代码视为 bug。

### 3.6 AI 只建议，不代决策

AI 预筛只提供建议，不替用户最终入库。

AI 可以建议：

- `promote_to_inbox`
- `ignore`
- `merge`
- `review_later`

但默认：

- **不自动删除** — 用户未确认的 Pin 永远不会被 AI 主动删除
- **不自动永久入库** — 未经用户 promote 的 Pin 永远不会生成 SourceItem
- **不自动覆盖用户决策** — 用户已做出的决策不会被 AI 后续覆盖

原因：MVP 早期 AI 误判概率高，自动决策会破坏用户信任。宁可慢，不可错。

---

## 4. 四层架构：职责边界

AcMind 的前台体验由四层组成，每层职责明确，禁止越界。

### 4.1 桌面胶囊 = 随手入口

职责：随时叫出来。

- 全局快捷键唤起
- 最小化状态常驻
- 一键触发：截图、录音、输入想法、粘贴
- 不展示列表，不做筛理

### 4.2 Quick Desk = 当前工作台

职责：今天处理什么。

- 展示今日 Pin Pool 内容
- 单条 Pin 预览和操作（promote / ignore / delete）
- 快捷动作入口
- 空状态、加载状态、错误状态完整
- **不做**：批量操作面板、知识库浏览、设置管理

### 4.3 Pin Pool = 数据中间层

职责：临时内容池。

- 所有捕获内容的暂存区
- 支持状态流转：captured → pinned → prefiltered → promoted / ignored / deleted
- AI 预筛结果挂载
- 去重检测
- **不做**：长期存储、知识检索、内容编辑

### 4.4 Knowledge Flow = 正式处理区

职责：正式知识沉淀。

- Inbox：已 promote 的待处理内容
- Distill：AI 蒸馏
- Review / Edit：人工审阅和修改
- Export：Markdown / Obsidian 输出
- History / Errors：处理记录

```text
胶囊负责"随时叫出来"
Quick Desk 负责"今天处理什么"
Pin Pool 负责"临时内容池"
Knowledge Flow 负责"正式知识沉淀"
```

---

## 5. MVP 主流程

AcMind MVP 的最小闭环：

```text
桌面胶囊 / Quick Desk
  ↓
截图 / 复制 / 语音 / 手动输入
  ↓
Pin Pool
  ↓
AI 预筛（只建议）
  ↓
用户确认 Promote to Inbox
  ↓
基础蒸馏
  ↓
Review
  ↓
Markdown / Obsidian Export
```

首批必须闭环：

- 手动输入 → Pin Pool → Promote → Markdown Export
- 剪贴板文本 → Pin Pool → Promote → Markdown Export
- 截图 → Pin Pool → Promote → Markdown Export
- 语音 transcript → Voice Pin → Pin Pool → Promote → Markdown Export

---

## 6. 信息架构

### 6.1 Quick Desk

Quick Desk 是 AcMind 首屏。

它不是传统知识库后台，而是桌面快捷工具台。

结构：

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

### 6.2 Knowledge Flow

正式知识处理区。

包含：

- Inbox
- Distill
- Review / Edit
- Export
- History
- Errors

### 6.3 Settings

MVP 设置保持克制。

包含：

- 自动收集剪贴板
- 胶囊默认开启
- 截图后默认动作
- 语音转写 Provider
- Obsidian vault 路径
- Markdown 输出目录
- AI Provider
- 快捷键
- 数据目录

---

## 7. 数据模型

### 7.1 CaptureItem

来自 AcMind，表示一次捕获记录。

用于承接文本、链接、图片、音频等原始输入。

### 7.2 PinItem

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

### 7.3 SourceItem

正式进入 Inbox 后的知识处理对象。

Pin Pool 中的内容只有被 promote 后才生成或关联 SourceItem。

```text
约束：禁止任何代码路径在未经用户 promote 的情况下创建 SourceItem。
```

### 7.4 DistilledOutput

AI 蒸馏结果。

包含：

- suggestedTitle
- summary
- tags
- category
- contentMarkdown
- valueScore
- reviewStatus

### 7.5 ExportRecord

最终导出记录。

记录 Markdown / Obsidian 输出路径、frontmatter、冲突处理和导出状态。

---

## 8. AI 分层

### 8.1 AI 预筛

发生在 Pin Pool。

目标是快、轻、便宜，不生成长文。

输出：

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

边界：

- AI 预筛只输出建议，不执行任何写入操作
- `suggested_action` 仅为建议，最终由用户决定
- AI 不会自动删除、自动 promote、自动 merge
- 用户可以一键采纳建议，也可以忽略

### 8.2 AI 蒸馏

发生在 Inbox 后。

目标是把内容整理成可读、可维护、可导出的 Markdown。

### 8.3 语音 Polish

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

---

## 9. 数据目录规范

默认存储根目录：`~/AcMind/`

```text
~/AcMind/
  acmind.db                    # SQLite 主数据库
  raw/                         # 原始文件存储
    images/                    # 截图、图片 Pin 原始文件
    audio/                     # 录音、Voice Pin 原始文件
    files/                     # 导入的文档、PDF 等
    webpages/                  # 网页剪藏原始 HTML
  exports/                     # 导出产物
    markdown/                  # Markdown / Obsidian 导出文件
  logs/                        # 运行日志
  cache/                       # 临时缓存（可清理）
  thumbnails/                  # 缩略图缓存
```

规则：

- 所有原始文件必须落盘到 `raw/` 对应子目录，禁止只存内存引用
- 导出文件统一进 `exports/`，禁止散落在根目录
- `cache/` 和 `thumbnails/` 可安全清理，不包含不可再生数据
- `acmind.db` 是唯一权威数据源，文件路径变更需同步更新数据库记录

---

## 10. 当前已落地工程状态

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

---

## 11. MVP 不做什么

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

第一阶段只回答一个问题：

```text
用户会不会愿意每天把碎片信息丢进 AcMind？
```

---

## 12. 版本路线

### Phase 0：工程底座 ✅

已完成：

- AcMind → AcMind 底座
- AcMind 命名
- Pin Pool schema
- Quick Desk 初版
- Voice Pin 骨架
- typecheck / build / tests 通过

### Phase 1：Pin Pool 单条闭环

目标：打磨单条 Pin 的完整生命周期，不引入批量操作。

- 手动输入进入 Pin Pool
- 剪贴板文本进入 Pin Pool
- Pin Pool 列表稳定展示
- 单条 Pin 可预览
- 单条 Pin 可 promote / ignore / delete
- Pin 状态变化可追踪
- Quick Desk 空状态、错误状态、加载状态完整

验收标准：用户可以手动输入一条内容，预览它，promote 它，看到状态变化。

### Phase 2：剪贴板文本自动进入 Pin Pool

目标：让信息收集从"手动"升级为"半自动"。

- 剪贴板文本自动捕获
- hash 去重
- ignoreNextCopy
- 暂停收集
- 收集规则（白名单 / 黑名单）

验收标准：复制一段文本，自动出现在 Pin Pool 中，重复复制不重复创建。

### Phase 3：Promote to Inbox + Markdown Export

目标：跑通 AcMind 核心闭环 —— 收集 → Pin Pool → Promote → Markdown。

- Pin Pool promote 到 Inbox
- 基础 Distill
- Review / Edit
- Markdown Preview
- Markdown Export 到 `~/AcMind/exports/markdown/`
- Obsidian Export
- ExportRecord

验收标准：一条 Pin 可以 promote 到 Inbox，经过蒸馏，导出为 Markdown 文件，文件内容可读。

### Phase 4：截图直接 Pin

目标：让截图成为一等公民输入方式。

- 迁 PinStack 截图 controller
- 自由截图
- 固定比例截图
- 截图后直接生成 Image Pin
- Pin Card 悬浮窗

验收标准：截图后自动出现在 Pin Pool 中，可预览、可 promote、可导出。

### Phase 5：AI 预筛

目标：引入 AI 辅助判断，但不替用户决策。

- 接入真实 AI Provider
- 重复判断
- 价值评分
- 建议动作（promote / ignore / merge / review_later）
- 用户决策记录
- AI 不自动执行任何写入操作

验收标准：AI 给出建议，用户可以一键采纳或忽略，AI 不会自动操作。

### Phase 6：语音 Voice Pin

目标：让语音成为快速捕获方式。

- 胶囊录音
- 全局快捷键
- Volcengine / Whisper-compatible ASR
- 词典热词
- AI polish（只整理，不代答）
- Voice Pin 自动进入 Pin Pool

验收标准：按快捷键录音，转写后自动进入 Pin Pool，可 promote 到 Inbox。

### Phase 7：桌面胶囊体验深化

目标：打磨胶囊的日常使用手感。

- 胶囊常驻桌面
- 快捷键唤起 / 隐藏
- 最近 Pin 快速预览
- 一键操作：截图、录音、输入、粘贴
- 胶囊与 Quick Desk 联动

验收标准：胶囊成为日常最常用的入口，操作路径最短。

### Phase 8：VaultKeeper Engine

目标：扩展输入源，支持更多文件类型。

- 文件导入
- 网页剪藏
- PDF / DOCX / EPUB / TXT 转 Markdown
- Markdown 标准化
- 原始文件归档

验收标准：拖入一个 PDF，自动转为 Markdown，进入 Pin Pool，可 promote 导出。

---

## 13. 成功标准

### 一周内

用户可以稳定完成：

- 手动输入进入 Pin Pool
- 复制内容进入 Pin Pool
- 单条 Pin 预览、promote、ignore、delete
- promote 后导出 Markdown

### 一个月内

用户可以形成：

- 每日 Pin Pool
- 每日筛理记录
- 每周 Markdown 知识沉淀
- Obsidian 中结构统一的知识资产

### 三个月内

用户拥有：

- 高质量原始内容
- AI 清洗结果
- 用户修改记录
- 标签习惯
- 标题风格
- 分类偏好
- 可用于个人模型 / RAG 的数据基础

---

## 14. 最终判断

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

---

## 附录：v0.1 → v0.2 变更摘要

| # | 变更 | 位置 |
|---|------|------|
| 1 | 新增第一性原则 | Section 0 |
| 2 | 拆清四层架构职责边界 | Section 4（新增） |
| 3 | Phase 1 聚焦单条 Pin 闭环 | Section 12 |
| 4 | 新增数据目录规范 | Section 9（新增） |
| 5 | 强化 PinItem / SourceItem 边界约束 | Section 3.5、7.3 |
| 6 | AI 预筛加"只建议不代决策"原则 | Section 3.6、8.1 |
| 7 | Phase 路线微调，Markdown Export 提前至 Phase 3 | Section 12 |
