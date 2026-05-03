# AcMind PRD v0.1

> 项目名称：AcMind  
> 产品全称：Acore AcMind  
> 产品定位：个人桌面 AI 信息中枢  
> 当前阶段：MVP 启动 / 工程底座已建立  
> 核心口号：先 Pin 住，再变成知识。  
> 核心目标：把零碎、破碎、分散的信息，低成本收进来，再筛理、清洗、沉淀为有价值的信息资产。

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

AcMind 的语音目标不是“插入当前光标”，而是：

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

---

## 4. MVP 主流程

AcMind MVP 的最小闭环：

```text
桌面胶囊 / Quick Desk
  ↓
截图 / 复制 / 语音 / 手动输入
  ↓
Pin Pool
  ↓
AI 预筛
  ↓
Promote to Inbox
  ↓
基础蒸馏
  ↓
Review
  ↓
Markdown / Obsidian Export
```

首批必须闭环：

- 复制文本 → Pin Pool → AI 预筛 → Inbox → Markdown Export
- 截图 → Pin Pool → Inbox → Markdown Export
- 语音 transcript → Voice Pin → Pin Pool → Inbox

---

## 5. 信息架构

### 5.1 Quick Desk

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

### 5.2 Knowledge Flow

正式知识处理区。

包含：

- Inbox
- Distill
- Review / Edit
- Export
- History
- Errors

### 5.3 Settings

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

## 6. 数据模型

### 6.1 CaptureItem

来自 AcMind，表示一次捕获记录。

用于承接文本、链接、图片、音频等原始输入。

### 6.2 PinItem

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

### 6.3 SourceItem

正式进入 Inbox 后的知识处理对象。

Pin Pool 中的内容只有被 promote 后才生成或关联 SourceItem。

### 6.4 DistilledOutput

AI 蒸馏结果。

包含：

- suggestedTitle
- summary
- tags
- category
- contentMarkdown
- valueScore
- reviewStatus

### 6.5 ExportRecord

最终导出记录。

记录 Markdown / Obsidian 输出路径、frontmatter、冲突处理和导出状态。

---

## 7. AI 分层

### 7.1 AI 预筛

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

### 7.2 AI 蒸馏

发生在 Inbox 后。

目标是把内容整理成可读、可维护、可导出的 Markdown。

### 7.3 语音 Polish

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

## 8. 当前已落地工程状态

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

## 9. MVP 不做什么

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

## 10. 版本路线

### Phase 0：工程底座

已完成：

- AcMind → AcMind 底座
- AcMind 命名
- Pin Pool schema
- Quick Desk 初版
- Voice Pin 骨架
- typecheck / build / tests 通过

### Phase 1：Quick Desk + Pin Pool 完整体验

目标：

- Pin Pool 批量筛理
- 今日待筛理
- 空状态和错误状态精修
- 手动输入默认进入 Pin Pool
- 剪贴板内容默认进入 Pin Pool

### Phase 2：PinStack 截图直接 Pin

目标：

- 迁 PinStack 截图 controller
- 自由截图
- 固定比例截图
- 截图后直接生成 Image Pin
- Pin Card 悬浮窗

### Phase 3：剪贴板增强

目标：

- 文本 / 图片剪贴板自动捕获
- hash 去重
- ignoreNextCopy
- 暂停收集
- 收集规则

### Phase 4：AI 预筛

目标：

- 接入真实 AI Provider
- 重复判断
- 价值评分
- 建议动作
- 用户决策记录

### Phase 5：Inbox + Markdown 输出闭环

目标：

- Pin Pool promote 到 Inbox
- Distill
- Review
- Markdown Preview
- Obsidian Export
- ExportRecord

### Phase 6：OpenLess 语音能力深化

目标：

- 胶囊录音
- 全局快捷键
- Volcengine / Whisper-compatible ASR
- 词典热词
- AI polish
- Voice Pin 自动进入 Pin Pool

### Phase 7：VaultKeeper Engine

目标：

- 文件导入
- 网页剪藏
- PDF / DOCX / EPUB / TXT 转 Markdown
- Markdown 标准化
- 原始文件归档

---

## 11. 成功标准

### 一周内

用户可以稳定完成：

- 复制内容进入 Pin Pool
- 手动输入进入 Pin Pool
- 语音 transcript 生成 Voice Pin
- Pin Pool promote 到 Inbox

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

## 12. 最终判断

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
