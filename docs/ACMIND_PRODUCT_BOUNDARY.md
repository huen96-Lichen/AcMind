# AcMind 产品边界说明

> 最后更新：2026-05-07

> ⚠️ **迁移边界已冻结**（2026-05-07），详见 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)

## 一句话定位

> **AcMind — 个人桌面 AI 信息中枢**
> 把零散信息收集起来，整理成真正有价值的 Markdown 知识。

## 核心流程

```
收集 → 暂存 → 整理 → 审阅 → 导出 → 入库
```

> 暂存→整理→审阅→导出 管线已完成端到端贯通。

对应系统对象：

```
SourceItem → InboxItem → DistillTask → ReviewItem → ExportRecord → KnowledgeNote
```

## 功能边界

### 收集（Capture）

AcMind 支持以下内容来源：

- 手动文本输入
- 剪贴板自动监控
- 截图（自由/固定尺寸/区域）
- 网页内容
- 文件导入（PDF/DOCX/图片/音视频）
- 语音转写
- URL 粘贴

### 暂存（Staging Pool）

所有收集的内容先进入暂存池：

- 支持快速预览
- 支持 AI 预筛（价值评估）
- 支持批量操作（入 Inbox / 忽略 / 删除）
- 桌面胶囊作为快速收集入口

### 整理（Distill）

AI 蒸馏和人工审阅：

- 支持 Ollama / OpenAI 兼容模型
- 策略路由：根据内容类型选择不同处理策略
- 质量降级：模型不可用时自动降级
- 人工确认：AI 处理结果需用户确认

### 导出（Export）

最终知识沉淀：

- Markdown 格式输出
- Obsidian Vault 对接
- Frontmatter 规范化
- 冲突处理

## 导航结构

### 当前导航（Electron，逐步废弃）

一级导航（6 项）：

1. **工作台** — 首页，产品状态总览 + 快速动作
2. **暂存池** — 所有未整理的信息
3. **整理** — AI 蒸馏和人工审阅
4. **知识库** — 最终沉淀的知识卡片
5. **工具台** — 文件转换、OCR、ZTools、Agent 对话等
6. **设置** — 模型配置、导出路径、捕获设置、外观

### 目标导航（Swift，迁移主线）

> 已冻结，未经团队共识不得修改。

| 序号 | 导航项 | 职责 | Swift 视图 |
|------|--------|------|-----------|
| 1 | **Agent** | AI 对话入口、意图理解、任务调度、跨模块动作触发 | `AgentView.swift` |
| 2 | **Inbox** | 所有 SourceItem 统一入口，状态流转 | `InboxView.swift` |
| 3 | **Schedule** | 日程管理、定时任务、时间线 | `ScheduleNativeView.swift` |
| 4 | **Workbench** | 工作台总览：今日统计、快速入库、知识沉淀 | 待创建 |
| 5 | **Tools** | 工具台：文件转换、OCR、ZTools、Agent 任务管理 | 待创建 |
| 6 | **Settings** | AI Provider、Vault 路径、外观、权限、快捷键 | `SettingsView.swift` |

### 导航映射

| 旧导航 | → 新导航 | 处理方式 |
|--------|---------|---------|
| 工作台 | Workbench | 合并 |
| 暂存池 | Inbox | 合并 |
| 整理 | Inbox | 蒸馏操作在 Inbox 内触发 |
| 知识库 | Workbench | 合并 |
| 工具台 | Tools | 重命名 |
| 设置 | Settings | 保持不变 |

## 视觉调性

- Apple 风格，克制、轻玻璃感
- 大留白，低噪音
- 信息分层清楚
- 一个页面一个主焦点
- 不做成控制台/SaaS 后台/复杂统计面板

## 不做的事

- 不做通用笔记软件
- 不做单纯截图工具
- 不做 AI SaaS 后台系统
- 不做复杂插件系统（现阶段）
- 不做远程 Agent（现阶段）

## 迁移边界

> 已冻结（2026-05-07），完整映射表和优先级见 [Swift 迁移总表](./superpowers/plans/2026-05-07-swift-migration-plan.md)

### 三类边界

| 类别 | 标记 | 含义 | 模块 |
|------|------|------|------|
| **必须原生** | ✅ | 依赖 macOS 原生能力或为核心体验 | Capsule, Capture, Clipboard, Inbox, Distill, Export, AI Runtime, Settings, Storage, Agent, Scheduler, Design System |
| **可过渡** | 🔄 | 可通过 WebViewBridge 临时桥接 | Knowledge Base, Voice, Search, Shelf |
| **最后再删** | ⏳ | 低优先级，保留 Electron WebView | File Converter, Import/Vault, Projects/Datasets, VaultKeeper, Onboarding, Error/Retry/Diagnostics |
