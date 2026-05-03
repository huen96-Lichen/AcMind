# AcMind v2.0 Native Workspace 设计规范

> **适用产品**：AcMind v2.0
> **适用阶段**：Phase 12.3 及之后
> **文档类型**：视觉规范 / Design System 基础规范
> **目标读者**：Trae / Codex / 设计执行者 / 开发执行者
> **核心方向**：Apple Native Productivity Workspace / 苹果原生式知识工作台
> **参考来源**：Apple Human Interface Guidelines、macOS App 设计资源、Apple Developer Documentation、ChatGPT / Codex 工作台界面体验
> **版本说明**：本规范整合自《AcMind v2.0 Native Workspace 视觉设计规范 v2.1》与《AcMind V2.0 Apple 原生风格设计规范 V2》，作为 AcMind v2.0 后续 UI 重构的统一依据。

---

## 0. 文档定位

AcMind v2.0 已经与早期 PinStack / AcMind 原型阶段产生明显版本差距。

早期阶段更像是功能验证、AI 蒸馏流程验证、本地优先存储验证、Obsidian 导出验证、Capture / Inbox / AI Console 等能力堆叠。

而 AcMind v2.0 的目标是成为一个真正可长期使用的本地优先 AI 知识整理工具。

因此，从 Phase 12.3 开始，视觉方案需要从"功能能用"进入"成熟产品体验"。

本规范的目标不是让界面变得炫酷，而是让 AcMind v2.0 变得更像 macOS 原生效率应用、更像 ChatGPT / Codex 一类现代 AI 工作台——更清楚、更简洁、更高效、更统一、更值得长期使用。

---

## 1. 一句话定义

AcMind v2.0 是一个面向 macOS 的本地优先 AI 知识整理工作台。

视觉上应接近 Apple 原生效率应用，结合 ChatGPT / Codex 式的简洁卡片工作台体验，以清晰、高效、可信、长期使用不疲劳为第一目标。

---

## 2. 视觉方向命名

```text
AcMind Native Workspace
```

中文解释：**苹果原生式知识工作台**

AcMind v2.0 不再追求强烈的"AI 科技感"或"未来玻璃感"，而是追求一种更成熟、更克制、更稳定的 macOS 应用质感。

---

## 3. 设计哲学转变

### 3.1 从 V1.0 到 V2.0

| 维度 | V1.0 | V2.0 |
|---|---|---|
| 颜色 | 自定义暖色调 | macOS 动态系统色 + 单一品牌强调色 |
| 材质 | 自定义 backdrop-filter | macOS 标准材质感 / vibrancy 模拟 |
| 字体 | 自定义字体栈 | SF Pro / 系统字体 |
| 图标 | 自定义 SVG 为主 | SF Symbols 气质优先，自定义为辅 |
| 布局 | 自定义三栏 | Sidebar + Toolbar + Main + Inspector |
| 交互 | 自定义反馈 | macOS 标准交互模式 |
| 外观 | 浅色优先 | 浅色 / 深色均支持 |
| 产品气质 | 原型工具感 | 原生效率应用感 |

V1.0 用自定义暖色系建立品牌感，但存在以下问题：
- 自定义 token 与 macOS 系统外观割裂，浅色/深色模式切换成本高
- 自定义玻璃效果与系统 Liquid Glass / vibrancy 不兼容
- 自定义图标体系维护成本高，无法与系统字体粗细自动对齐
- 暖白背景在多显示器、不同色域下表现不一致
- 容易看起来像"运行在 Mac 上的 Web 应用"

**V2.0 的核心转变**：

> AcMind 应该看起来像一个 Mac 原生应用，而不是一个运行在 Mac 上的 Web 应用。

### 3.2 不变的原则

以下 V1.0 原则在 V2.0 中继续保留：

```text
P0：可读性高于美观 — 文字永远优先清晰
P0：滚动高于布局完整 — 长页面必须可滚动
P0：状态真实高于视觉简洁 — AI 状态、Mock 模式、输出路径必须可见
P0：每页只有一个主动作
P0：本地优先可信 — 数据安全提示始终可见
```

具体要求：
- 文字永远优先清晰
- 长页面必须可滚动
- AI 状态、Mock 模式、规则模式、输出路径必须可见
- 每个页面最多只有一个 Primary Button
- 本地优先、隐私、安全相关提示必须真实可见
- 不可用功能不能伪装成已可用功能

---

## 4. 核心关键词

```text
Apple Native / macOS Productivity / ChatGPT-Codex-like
内容优先 / 简单 / 简约 / 高效率 / 高可读性 / 低噪音
圆角容器 / 自然阴影 / 柔和分隔 / 克制色彩
系统字体 / 系统图标感 / 少装饰 / 轻材质
长期使用不疲劳
```

### 反向关键词（明确不走的方向）

```text
赛博朋克 / 强霓虹 / 高饱和科技蓝紫 / 复杂网格背景
大面积发光 / 所有卡片都毛玻璃 / 过度渐变 / 过度动效
装饰大于内容 / 为了 AI 感牺牲阅读
所有按钮同等权重 / 页面像网页模板 / 管理后台 / 演示 Demo
```

---

## 5. 总体设计原则

### 5.1 内容优先

用户打开 AcMind v2.0，第一眼应该知道：我现在有什么内容待处理、下一步应该做什么、哪些内容已经整理完成、哪些任务失败或需要配置、最近导出了什么 Markdown。

界面不应把注意力浪费在装饰性图形、复杂背景、过度发光、炫酷动效上。

### 5.2 原生感优先

视觉上应尽量接近：
- Finder 的清楚层级
- Notes 的内容优先
- Reminders 的简洁任务感
- System Settings 的设置秩序感
- ChatGPT / Codex 的现代卡片工作台

### 5.3 低噪音

减少视觉噪音：少用高饱和颜色、少用大面积渐变、少用强边框、少用大面积毛玻璃、少用复杂图标、少用多层嵌套阴影、少用多个抢焦点按钮。

### 5.4 一个页面一个主焦点

每个主页面最多只有一个 Primary Button。每个页面都必须回答："这个页面最重要的一件事是什么？"

| 页面 | 主焦点 |
|---|---|
| 工作台 | 开始整理待处理内容 |
| 收集箱 | 整理选中内容 |
| AI 整理 | 确认并导出 |
| 导出记录 | 查看 / 打开最近导出 |
| 搜索 | 搜索内容 |
| 设置 | 保存当前配置 |

### 5.5 状态真实高于视觉简洁

以下状态必须明确标记，不能为了界面简洁而隐藏：

```text
Mock / 规则模式 / 本地规则 / 即将推出
未配置模型 / 依赖服务 / 失败 / 需要权限 / 冲突待处理
```

---

## 6. 页面总结构

AcMind v2.0 主页面统一采用以下结构：

```text
AppShell
├── Sidebar
├── MainArea
│   ├── Toolbar / TopBar
│   ├── PageShell
│   │   ├── PageHeader
│   │   ├── PageContent
│   │   └── Optional RightPanel / Inspector
│   └── Optional Status Area
```

所有主页面都应尽量复用统一结构，不允许每个页面自行设计完全不同的顶部、边距和卡片系统。

---

## 7. 主导航结构

AcMind v2.0 主导航应保持 Phase 12.2 已收束后的结构：

```text
工作台
收集箱
AI 整理
导出记录
搜索
设置
```

不应把以下内容暴露在主导航一级：

```text
错误回看 / 处理历史 / 模型调试 / 开发者状态 / 高级日志
VaultKeeper 详细状态 / 数据维护 / 开发者选项
Prompt Profile 调试 / Provider 调试 / Task Queue 调试
```

这些内容应进入：设置 > 高级 / 工作台 > 需要处理 / AI 整理页内部。

---

## 8. 全局布局系统

### 8.1 macOS 标准模式

```text
┌───────────────────────────────────────────────────────────────┐
│ Window Title Bar / Toolbar                                    │
├──────────────┬─────────────────────────────┬──────────────────┤
│              │                             │                  │
│   Sidebar    │      Main Content Area      │   Inspector      │
│   220px      │      自适应                  │   320px          │
│              │                             │   可折叠          │
│              │                             │                  │
└──────────────┴─────────────────────────────┴──────────────────┘
```

### 8.2 布局参数

| 区域 | 建议 |
|---|---|
| Sidebar 宽度 | 220px |
| Inspector 宽度 | 320px |
| 内容区页面边距 | 20px |
| 卡片内边距 | 16px |
| 分组间距 | 16px / 20px / 24px |
| 最小窗口尺寸 | 960 × 640px |
| 推荐默认尺寸 | 1280 × 820px |

### 8.3 关键变化（对比 V1.0）

| 项目 | V1.0 | V2.0 | 原因 |
|---|---|---|---|
| 顶部栏 | 自定义 TopStatusBar | macOS Toolbar + 菜单栏 | 遵循 macOS 标准 |
| 侧边栏宽度 | 248px | 220px | macOS 标准侧边栏宽度 |
| Inspector 宽度 | 420px | 320px | macOS 标准 Inspector 宽度 |
| 底部状态栏 | 固定 BottomRuntimeBar | 移至工具栏/菜单栏 | macOS 应用通常无底部状态栏 |
| 窗口标题 | 无 | 显示当前视图/文档名 | macOS 标准 |
| 搜索 | 顶部搜索框 | 工具栏搜索栏 / ⌘K | macOS 标准搜索模式 |

### 8.4 响应式断点

| 断点 | 宽度 | 布局 |
|---|---|---|
| Full | ≥ 1200px | 三栏：Sidebar + Main + Inspector |
| Medium | 960–1199px | 两栏：Sidebar + Main，Inspector 折叠 |
| Compact | 720–959px | 单栏，Sidebar 折叠为图标模式 |
| Narrow | < 720px | 单栏，Sidebar 隐藏 |

---

## 9. Sidebar 规范

### 9.1 职责

Sidebar 是主导航，不是功能垃圾桶。它只负责帮助用户在主要 section 之间切换。

### 9.2 推荐结构

```text
AcMind
────────────────
主导航
  工作台
  收集箱
  AI 整理
  导出记录
  搜索
────────────────
设置
```

高级入口不默认展开。如果必须保留，应放入 `设置 > 高级`。

### 9.3 风格要求

```text
窄 / 安静 / 清楚 / 分组少 / 图标统一 / 文字短
选中态明确 / 不堆状态 / 不堆按钮
```

### 9.4 选中态

```text
浅色背景 + 柔和高亮 + 可选左侧细指示
```

禁止：强色块、大面积发光、复杂渐变、过重阴影、每个导航项都像主按钮。

### 9.5 样式规范

- 使用 macOS 标准侧边栏样式（vibrancy 背景）
- 选中项使用系统强调色背景（圆角 6px）
- 图标使用 SF Symbols，颜色跟随选中状态
- 项目高度 28px（macOS 标准行高）
- 支持显示/隐藏（⇧⌘S 或工具栏按钮）
- 内容延伸至侧边栏下方（background extension effect）
- 层级不超过两层
- 不在侧边栏底部放置关键信息（用户可能缩小窗口裁切底部）

---

## 10. Toolbar / TopBar 规范

### 10.1 职责

Toolbar 是窗口工具栏，不是状态堆叠区。提供：当前页面上下文、搜索入口、少量高频操作、少量关键状态、设置 / 用户入口。

### 10.2 应避免

Toolbar 不应同时堆叠：本地优先、当前 tier、Obsidian 状态、Vault 状态、通知、设置、用户、模型状态、一堆 chip、一堆图标按钮。过多状态 chip 会让 Toolbar 变成噪音区。

### 10.3 推荐结构

```text
左侧：Sidebar Toggle / 页面上下文
中间：当前视图标题
右侧：搜索入口 / 1-2 个关键状态 / 设置
```

### 10.4 规范

- 工具栏项目不使用边框（macOS 标准）
- 使用 SF Symbols 无边框图标
- 关键操作使用 `.prominent` 样式（强调色背景）
- 窗口变窄时，中间项目自动收起至溢出菜单
- 每个工具栏操作都必须在菜单栏中有对应命令
- 标题精简，少于 15 个字符

### 10.5 搜索入口

搜索入口应像 macOS 原生搜索控件：清楚、轻量、可点击、不伪装成无效输入框。点击后进入 Search 页面或打开搜索浮层。

**禁止**：看起来能输入，但实际上 readOnly 且无反馈。

---

## 11. Inspector 规范

Inspector 是右侧检查器，用于展示当前选中对象的详情、元数据和上下文操作。

```text
宽度：320px
位置：窗口右侧
状态：可折叠
滚动：独立滚动
背景：surface.elevated / thick material
```

适用场景：收集项详情、AI 整理元信息、导出路径与文件信息、错误详情、模型状态详情。

Inspector 不应承载主流程，主流程必须留在 Main Content 中完成。

---

## 12. 颜色系统

### 12.1 设计原则

- 使用语义化动态颜色，而非硬编码色值
- 所有颜色必须同时考虑浅色和深色模式
- 颜色用于表达层级和状态，不用于装饰
- 避免仅靠颜色区分信息，必须配合文本标签或图标
- 页面内不允许散落大量临时 Tailwind 色值

### 12.2 语义 Token

```text
background.app / background.window / background.page

surface.primary / surface.secondary / surface.tertiary / surface.elevated / surface.overlay

border.subtle / border.default / border.strong

text.primary / text.secondary / text.tertiary / text.disabled / text.inverse

accent.primary / accent.hover / accent.active / accent.soft / accent.ring

status.success / status.warning / status.danger / status.info / status.processing / status.neutral / status.mock
```

### 12.3 背景层级

| 层级 | 语义 | 浅色模式 | 深色模式 | 用途 |
|---|---|---|---|---|
| App Background | 应用底色 | `#F5F5F7` / `#F6F6F8` | `#1C1C1E` / `#202124` | 应用整体背景 |
| Window Background | 窗口底色 | `#ffffff` | `#1e1e1e` | 窗口整体背景 |
| Content Background | 内容区底色 | `#ffffff` | `#262626` | 主工作区内容背景 |
| Sidebar Background | 侧边栏 | 系统 vibrancy 材质 | 系统 vibrancy 材质 | 侧边栏 |
| Toolbar Background | 工具栏 | 系统 Liquid Glass | 系统 Liquid Glass | 顶部工具栏 |
| Card / Grouped | 卡片/分组 | secondary surface | secondary surface | 卡片、分组内容 |
| Elevated | 浮层 | `#ffffff` + shadow | `#2d2d2d` + shadow | 弹出菜单、浮层 |

**实现要点**：
- Electron 中通过 `nativeTheme` API 检测系统外观
- 使用 CSS 自定义属性 + JavaScript 动态切换浅色/深色 token
- 侧边栏和工具栏使用 vibrancy/blur 材质模拟系统效果

### 12.4 文本颜色

| 语义 | 浅色模式 | 深色模式 | 用途 |
|---|---|---|---|
| Primary / Label | `#1D1D1F` | `#F5F5F7` | 标题、正文一级内容 |
| Secondary | `#6E6E73` | `#A1A1A6` | 副标题、描述、摘要 |
| Tertiary | `#AEAEB2` | `#6E6E73` | 占位符、禁用文本、时间戳 |
| Quaternary | `#D1D1D6` | `#48484A` | 水印、最低优先级文本 |

### 12.5 品牌强调色

AcMind v2.0 只保留一个品牌强调色。推荐继续保留 AcMind / Acore 的橙色，但必须克制使用。

| 模式 | 推荐值 | 用途 |
|---|---|---|
| 浅色 Accent | `#FF6B2B` | 主按钮、选中态、关键操作 |
| 深色 Accent | `#FF8F5E` | 深色模式关键操作 |
| Accent Hover | 浅色 `#E55A1B` / 深色 `#FFA87A` | hover |
| Accent Soft BG | 浅色 `#FFF2EC` / 深色 `#3D2A1E` | 选中背景 |

**约束**：
- 橙色只用于聚焦和主动作，不大面积铺满，不用于普通装饰
- 尊重用户在系统设置中选择的强调色（当用户设置非"多色"时，使用系统强调色）

### 12.6 状态颜色

| 状态 | 浅色前景 | 浅色背景 | 深色前景 | 深色背景 |
|---|---|---|---|---|
| 等待/排队 | `#92400E` | `#FEF3C7` | `#FBBF24` | `#422006` |
| 运行中 | `#1D4ED8` | `#DBEAFE` | `#60A5FA` | `#172554` |
| 成功 | `#15803D` | `#DCFCE7` | `#4ADE80` | `#052E16` |
| 错误 | `#DC2626` | `#FEE2E2` | `#F87171` | `#450A0A` |
| 静默/Mock | `#52525B` | `#F4F4F5` | `#A1A1AA` | `#27272A` |

状态色必须低饱和，不使用大面积刺眼色块。

### 12.7 AI 等级颜色

| 等级 | 浅色 | 深色 |
|---|---|---|
| 本地模型 | `#16A34A` | `#4ADE80` |
| 云端标准 | `#2563EB` | `#60A5FA` |
| 云端增强 | `#7C3AED` | `#A78BFA` |
| Mock 模式 | `#71717A` | `#A1A1AA` |

---

## 13. 字体排印

### 13.1 字体族

严格使用 Apple 系统字体栈：

```css
:root {
  --pm-font-sans:
    -apple-system,
    BlinkMacSystemFont,
    "SF Pro Text",
    "SF Pro Display",
    "Helvetica Neue",
    sans-serif;

  --pm-font-mono:
    "SF Mono",
    ui-monospace,
    "Cascadia Code",
    "Menlo",
    monospace;

  --pm-font-serif:
    "New York",
    "Songti SC",
    serif;

  --pm-font-cjk:
    "PingFang SC",
    "Noto Sans SC",
    "Microsoft YaHei",
    sans-serif;
}
```

### 13.2 文本样式层级

| 样式名称 | 字号 | 字重 | 行高 | 字间距 | 用途 |
|---|---|---|---|---|---|
| Large Title | 26px | 700 | 32px | -0.02em | 页面主标题 |
| Title 1 | 22px | 700 | 28px | -0.02em | 二级页面标题 |
| Title 2 | 17px | 600 | 22px | -0.01em | 区块标题 |
| Title 3 | 15px | 600 | 20px | 0 | 卡片标题、列表项标题 |
| Headline | 13px | 600 | 18px | 0 | 表头、分组标签 |
| Body | 13px | 400 | 18px | 0 | 正文内容（macOS 默认） |
| Callout | 12px | 400 | 16px | 0.01em | 辅助说明 |
| Subhead | 12px | 400 | 16px | 0.01em | 摘要、预览文本 |
| Footnote | 11px | 400 | 14px | 0.01em | 元信息、时间戳、路径 |
| Caption 1 | 10px | 500 | 13px | 0.02em | 状态标签、徽章 |
| Caption 2 | 10px | 400 | 13px | 0.02em | 最小辅助文本 |

**关键变化**（对比 V1.0）：
- macOS 默认正文字号从 V1.0 的 14px 调整为 **13px**（macOS 系统标准）
- 最小字号 **10px**（Apple HIG 推荐的 macOS 最小字号）
- 避免使用纤细体（Light / Thin），优先 Regular、Medium、Semibold、Bold

### 13.3 中文适配

- 中文正文行高建议为字号的 **1.6–1.8 倍**
- 中文标题行高建议为字号的 **1.3–1.4 倍**
- 中英文混排时，英文使用 SF Pro，中文使用苹方

### 13.4 字体规则

**禁止**：层级相同但字号不同、所有文字都加粗、过多小字号、说明文字颜色过浅、标题过大导致页面像宣传页、使用 Light / Thin 等过细字重。

**推荐**：标题克制、正文清楚、辅助文字能读、按钮文字稳定、路径和代码使用 mono。

---

## 14. 材质与玻璃感

### 14.1 核心原则

AcMind v2.0 不是强玻璃风格应用。材质用于建立层级，不用于制造炫酷感。

参照 Apple HIG 材质指南：
- 材质用于在前景和背景之间建立**景深感和层次感**
- **Liquid Glass** 用于控制和导航元素（工具栏、侧边栏）
- **标准材质**用于内容层内的视觉区分
- 材质效果不应影响文本可读性

### 14.2 材质层级映射

| Apple 材质 | AcMind 用途 | 实现方式 |
|---|---|---|
| Liquid Glass (Regular) | 侧边栏、工具栏 | `backdrop-filter: blur(20px) saturate(180%)` + 半透明背景 |
| Liquid Glass (Clear) | 浮层菜单、弹出面板 | `backdrop-filter: blur(40px)` + 高透明度背景 |
| Thick Material | Inspector 面板 | `backdrop-filter: blur(30px) saturate(150%)` |
| Regular Material | 卡片、分组 | `backdrop-filter: blur(12px)` + 轻微半透明 |
| Thin Material | 悬浮提示、标签 | `backdrop-filter: blur(8px)` |

### 14.3 可使用轻材质的区域

```text
Sidebar / Toolbar / TopBar / Modal / Floating Panel
Right Panel / Inspector / Capsule / Popover / Command / Search Panel
```

### 14.4 禁止强玻璃的区域

```text
长文本阅读区 / AI 输出正文 / Markdown 编辑区
设置表单 / 导出记录列表 / 搜索结果列表
错误详情 / 普通内容卡片
```

原因：这些区域以阅读和操作为主，强透明会降低效率和可读性。

### 14.5 CSS 参考

```css
/* 侧边栏 - Liquid Glass Regular */
.pm-sidebar {
  background: rgba(246, 246, 246, 0.72);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-right: 0.5px solid rgba(0, 0, 0, 0.12);
}

[data-theme="dark"] .pm-sidebar {
  background: rgba(44, 44, 46, 0.72);
  border-right-color: rgba(255, 255, 255, 0.08);
}

/* 工具栏 - Liquid Glass */
.pm-toolbar {
  background: rgba(246, 246, 246, 0.65);
  backdrop-filter: blur(24px) saturate(200%);
  -webkit-backdrop-filter: blur(24px) saturate(200%);
  border-bottom: 0.5px solid rgba(0, 0, 0, 0.1);
}

/* 卡片 - Standard Material */
.pm-card {
  background: rgba(255, 255, 255, 0.80);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 0.5px solid rgba(0, 0, 0, 0.08);
  border-radius: 10px;
}

[data-theme="dark"] .pm-card {
  background: rgba(44, 44, 46, 0.80);
  border-color: rgba(255, 255, 255, 0.06);
}
```

普通卡片默认使用干净 surface，不强制使用 blur。

---

## 15. 圆角系统

### 15.1 macOS 克制圆角

| 元素 | 圆角 | 说明 |
|---|---|---|
| 窗口 | 10px | macOS 窗口标准圆角 |
| 标准按钮 | 6px | macOS 标准按钮 |
| 输入框 | 6px | 文本输入框 |
| 工具栏项目 | 6px | 工具栏内按钮 |
| 侧边栏选中项 | 6px | 侧边栏高亮行 |
| 卡片/分组 | 10px | 内容卡片 |
| 浮层/弹窗 | 12px | 弹出菜单、Popover |
| 缩略图/头像 | 8px 或圆形 | 根据内容决定 |
| 状态标签 | 999px | 全圆角 |
| 胶囊按钮 | 999px | 全圆角按钮 |

### 15.2 Token 建议

```text
radius.xs: 4px
radius.sm: 6px
radius.md: 8px
radius.lg: 10px
radius.xl: 12px
radius.2xl: 16px
radius.full: 999px
```

### 15.3 关键变化

```text
卡片圆角：16px → 10px
按钮圆角：12px → 6px
输入框圆角：10px → 6px
```

---

## 16. 阴影系统

### 16.1 原则

阴影必须自然、克制、轻柔。不要使用网页感强烈的大黑影。从 V1.0 的暖色调阴影改为 macOS 标准中性阴影。

### 16.2 Token

```css
:root {
  /* 浅色模式 */
  --pm-shadow-sm:
    0 1px 3px rgba(0, 0, 0, 0.06),
    0 1px 2px rgba(0, 0, 0, 0.04);

  --pm-shadow-md:
    0 4px 12px rgba(0, 0, 0, 0.08),
    0 2px 4px rgba(0, 0, 0, 0.04);

  --pm-shadow-lg:
    0 12px 40px rgba(0, 0, 0, 0.12),
    0 4px 12px rgba(0, 0, 0, 0.06);

  --pm-shadow-xl:
    0 24px 64px rgba(0, 0, 0, 0.16),
    0 8px 20px rgba(0, 0, 0, 0.08);
}

[data-theme="dark"] {
  /* 深色模式阴影更深 */
  --pm-shadow-sm:
    0 1px 3px rgba(0, 0, 0, 0.24),
    0 1px 2px rgba(0, 0, 0, 0.16);

  --pm-shadow-md:
    0 4px 12px rgba(0, 0, 0, 0.32),
    0 2px 4px rgba(0, 0, 0, 0.16);

  --pm-shadow-lg:
    0 12px 40px rgba(0, 0, 0, 0.40),
    0 4px 12px rgba(0, 0, 0, 0.20);
}
```

---

## 17. 间距系统

### 17.1 基础间距

采用 4px 基础网格：

```css
:root {
  --pm-space-0: 0px;
  --pm-space-1: 4px;
  --pm-space-2: 8px;
  --pm-space-3: 12px;
  --pm-space-4: 16px;
  --pm-space-5: 20px;
  --pm-space-6: 24px;
  --pm-space-8: 32px;
  --pm-space-10: 40px;
  --pm-space-12: 48px;
  --pm-space-16: 64px;
}
```

### 17.2 组件间距

| 场景 | 间距 |
|---|---|
| 工具栏内项目间距 | 8px |
| 工具栏分组间距 | 16px |
| 侧边栏项目间距 | 2px |
| 侧边栏分组间距 | 12px |
| 卡片内边距 | 16px |
| 列表项内边距 | 12px 16px |
| 内容区页面边距 | 20px |
| Inspector 内边距 | 16px |
| 分组标题与内容 | 8px |
| 表单标签与输入框 | 6px |

---

## 18. 图标系统

### 18.1 方向

图标应接近 SF Symbols 的气质：线性、圆润、清楚、一致 stroke、与文字对齐、不抢主内容。即使使用 lucide，也应遵守类似原则。

### 18.2 SF Symbols 映射表

| AcMind 功能 | SF Symbol 名称 | 说明 |
|---|---|---|
| 工作台 | `house` | 主页 |
| 收集箱 | `tray` | 标准收件箱 |
| AI 整理 | `sparkles` | AI / 智能处理 |
| 导出记录 | `arrow.up.doc` | 文档导出 |
| 搜索 | `magnifyingglass` | 标准搜索 |
| 设置 | `gearshape` | 标准设置 |
| 处理历史 | `clock.arrow.circlepath` | 历史记录 |
| 错误回看 | `exclamationmark.triangle` | 警告/错误 |
| 新增捕获 | `plus` | 添加 |
| 文本捕获 | `text.cursor` | 文本输入 |
| 剪贴板 | `doc.on.clipboard` | 剪贴板 |
| 文件导入 | `doc.badge.plus` | 文件添加 |
| 网页剪藏 | `safari` | 网页 |
| 截图 | `camera.viewfinder` | 截图 |
| Obsidian 输出 | `arrow.right.doc` | 输出到文档 |
| 删除 | `trash` | 标准删除 |
| 编辑 | `pencil` | 编辑 |
| 更多操作 | `ellipsis.circle` | 更多菜单 |
| 筛选 | `line.3.horizontal.decrease.circle` | 过滤 |
| 日志 | `list.bullet.rectangle` | 日志列表 |
| 模板 | `doc.plaintext` | 文档模板 |
| 本地优先 | `lock.shield` | 本地安全 |
| AI 运行中 | `arrow.triangle.2.circlepath` | 循环/处理中 |
| 成功 | `checkmark.circle.fill` | 完成 |
| 错误 | `xmark.circle.fill` | 失败 |
| 等待 | `hourglass` | 等待 |
| Vault | `folder` | 文件夹/Vault |

### 18.3 图标尺寸

| 场景 | 尺寸 | SF Symbol Scale |
|---|---|---|
| 侧边栏图标 | 18px | Medium |
| 工具栏图标 | 18px | Medium |
| 按钮内图标 | 16px | Medium |
| 列表项图标 | 16px | Medium |
| 状态图标 | 14px | Small |
| 大功能图标 | 24px | Large |

如果使用 lucide 图标，建议：`size: 16/18/20`、`stroke-width: 1.75-2`、`color: text.secondary`、`active color: text.primary 或 accent.primary`。

### 18.4 自定义图标规范

当 SF Symbols 无法满足时，自定义图标需遵循：

```text
格式：SVG（矢量，支持自动缩放）
线条粗细：1.5px（匹配 SF Symbols Regular weight）
视觉框：24×24px，内容区 20×20px（留 2px 内边距）
颜色：使用 currentColor 继承文本颜色
端点：round cap / round join
```

---

## 19. 组件规范

### 19.1 Button

#### Variants

统一 Button 组件至少支持：`primary` / `secondary` / `plain` / `ghost` / `danger` / `icon`

#### Primary Button

```css
.pm-btn-primary {
  height: 32px;
  padding: 0 14px;
  border-radius: 6px;
  background: var(--pm-accent);
  color: #ffffff;
  font-size: 13px;
  font-weight: 600;
  font-family: var(--pm-font-sans);
  border: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  cursor: default;
  transition: background 80ms ease-out;
  -webkit-app-region: no-drag;
}

.pm-btn-primary:hover {
  background: var(--pm-accent-hover);
}

.pm-btn-primary:active {
  background: var(--pm-accent-active);
  transform: scale(0.98);
}

.pm-btn-primary:disabled {
  opacity: 0.4;
  pointer-events: none;
}
```

规则：一个页面最多一个 Primary Button，一个区块最多一个主按钮。

#### Secondary Button

```css
.pm-btn-secondary {
  height: 32px;
  padding: 0 14px;
  border-radius: 6px;
  background: transparent;
  border: 0.5px solid var(--pm-border-default);
  color: var(--pm-text-primary);
  font-size: 13px;
  font-weight: 500;
}

.pm-btn-secondary:hover {
  background: var(--pm-fill-secondary);
}
```

#### Plain / Ghost Button

```css
.pm-btn-plain {
  height: 28px;
  padding: 0 10px;
  border-radius: 6px;
  background: transparent;
  border: none;
  color: var(--pm-text-secondary);
  font-size: 13px;
}

.pm-btn-plain:hover {
  background: var(--pm-fill-tertiary);
}
```

#### Icon Button

```css
.pm-btn-icon {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  background: transparent;
  border: none;
  color: var(--pm-text-secondary);
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.pm-btn-icon:hover {
  background: var(--pm-fill-tertiary);
  color: var(--pm-text-primary);
}
```

规则：尺寸 28px 或 32px、必须有 hover 态、必须有 aria-label。

#### Danger Button

用于删除、清空、重置等不可逆操作。必须和普通按钮区分，不使用刺眼大红色，危险动作需要二次确认或明确提示。

---

### 19.2 Input / Text Field

```css
.pm-input {
  height: 28px;
  padding: 0 8px;
  border-radius: 6px;
  border: 0.5px solid var(--pm-border-default);
  background: var(--pm-bg-textfield);
  color: var(--pm-text-primary);
  font-size: 13px;
  font-family: var(--pm-font-sans);
}

.pm-input:focus {
  outline: none;
  border-color: var(--pm-accent);
  box-shadow: 0 0 0 3px var(--pm-accent-ring);
}

.pm-input::placeholder {
  color: var(--pm-text-tertiary);
}
```

---

### 19.3 Search Field

```css
.pm-search-field {
  height: 28px;
  width: 240px;
  padding: 0 8px 0 28px;
  border-radius: 6px;
  border: 0.5px solid var(--pm-border-default);
  background: var(--pm-fill-tertiary);
  font-size: 13px;
}

.pm-search-field:focus {
  background: var(--pm-bg-textfield);
  border-color: var(--pm-accent);
  box-shadow: 0 0 0 3px var(--pm-accent-ring);
  width: 320px;
  transition: width 200ms ease-out;
}
```

搜索框必须是真实输入框或真实搜索入口。**禁止**：看起来可以输入，但 readOnly 且点击无反馈。

---

### 19.4 Card

#### Variants

统一 Card 组件至少支持：`base` / `grouped` / `interactive` / `selected` / `elevated`

#### 样式

```css
.pm-card {
  background: var(--pm-bg-card);
  border: 0.5px solid var(--pm-border-subtle);
  border-radius: 10px;
  padding: 16px;
}

.pm-card-interactive {
  cursor: default;
  transition: background 80ms ease-out, border-color 80ms ease-out;
}

.pm-card-interactive:hover {
  background: var(--pm-bg-card-hover);
}

.pm-card-selected {
  background: var(--pm-accent-soft-bg);
  border-color: var(--pm-accent);
}
```

#### 结构

```text
Card
├── CardHeader
│   ├── Title
│   ├── Description / Meta
│   └── Optional Action
├── CardBody
└── CardFooter / Actions
```

---

### 19.5 StatusBadge

#### Variants

统一 StatusBadge 至少支持：`neutral` / `info` / `success` / `warning` / `danger` / `processing` / `disabled` / `mock`

#### 样式

```css
.pm-badge {
  height: 20px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 500;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.pm-badge-waiting  { color: #92400e; background: #fef3c7; }
.pm-badge-running  { color: #1d4ed8; background: #dbeafe; }
.pm-badge-success  { color: #15803d; background: #dcfce7; }
.pm-badge-error    { color: #dc2626; background: #fee2e2; }
.pm-badge-muted    { color: #52525b; background: #f4f4f5; }

[data-theme="dark"] .pm-badge-waiting  { color: #fbbf24; background: #422006; }
[data-theme="dark"] .pm-badge-running  { color: #60a5fa; background: #172554; }
[data-theme="dark"] .pm-badge-success  { color: #4ade80; background: #052e16; }
[data-theme="dark"] .pm-badge-error    { color: #f87171; background: #450a0a; }
[data-theme="dark"] .pm-badge-muted    { color: #a1a1aa; background: #27272a; }
```

#### 必须明确标记的状态

```text
未整理 / 整理中 / 待确认 / 已导出 / 失败 / 即将推出
本地规则 / 规则模板 / Mock / 未配置模型 / 依赖服务 / 需要权限 / 冲突待处理
```

尤其是以下状态不能隐藏：Mock / 规则模式 / 即将推出 / 未配置模型 / 依赖服务。

---

### 19.6 Table / List

#### Table

macOS 标准表格样式：
- 表头高度 28px，使用 Headline 文本样式
- 行高 32px（紧凑）或 44px（标准）
- 支持交替行背景
- 选中行使用系统选中色
- 支持多选（⌘+点击）和范围选择（⇧+点击）
- 表格外部可滚动

#### List Item

列表项用于：收集项、搜索结果、导出记录、错误记录、处理历史。

```text
高度：根据内容自适应
最小高度：44px
内边距：12px 16px
标题：13-15px / 600
摘要：12-13px / 400
元信息：11-12px / 400
状态标签置于右侧或标题旁
```

---

### 19.7 Empty / Loading / Error 状态

#### EmptyState

不能只显示"暂无数据"。必须告诉用户为什么为空、下一步可以做什么。

示例：
```text
还没有待整理内容。
你可以复制文字、拖入文件，或从胶囊入口快速收集灵感。
```

#### LoadingState

加载状态应说明正在做什么，不要只显示一个无语义 spinner。

示例：
```text
正在读取导出记录…
正在整理内容…
正在连接本地模型…
```

#### ErrorState

错误状态应包含：标题、原因、建议操作、主操作、次操作。

示例：
```text
AI 整理失败

可能原因：
- 当前模型未配置
- 本地模型未运行
- 内容过长

建议：
- 前往模型设置
- 使用规则模板保存
- 稍后重试
```

---

### 19.8 Toast / 通知

```text
位置：窗口右上角
成功：2 秒自动消失
错误：5 秒或手动关闭
错误 Toast 必须附带操作按钮或下一步说明
样式：轻量浮层，接近 macOS 通知卡片
```

严重错误、系统级提醒可以考虑使用系统通知。

---

### 19.9 Tabs

Tabs 用于：AI 整理页、设置页、导出记录、搜索筛选、模型配置。

规则：选中态清楚、未选中态低噪音、不要过度分割、不要所有 Tab 都像大按钮。

---

### 19.10 Split View（分割视图）

```css
.pm-split-view {
  display: flex;
  height: 100%;
}

.pm-split-divider {
  width: 1px;
  background: var(--pm-border-subtle);
  cursor: col-resize;
  flex-shrink: 0;
}

.pm-split-divider:hover {
  background: var(--pm-accent);
  width: 3px;
}
```

---

## 20. 菜单栏规范

AcMind v2.0 作为 macOS 应用，应逐步补齐菜单栏能力。

### 推荐结构

```text
AcMind
  关于 AcMind
  设置… ⌘,
  ─────────
  隐藏 AcMind ⌘H
  隐藏其他 ⌘⌥H
  显示全部
  ─────────
  退出 AcMind ⌘Q

文件
  新建捕获 ⌘N
  导入文件… ⇧⌘I
  从剪贴板导入 ⇧⌘V
  ─────────
  关闭窗口 ⌘W

编辑
  撤销 ⌘Z
  重做 ⇧⌘Z
  ─────────
  剪切 ⌘X
  拷贝 ⌘C
  粘贴 ⌘V
  全选 ⌘A
  ─────────
  查找… ⌘F

显示
  显示/隐藏侧边栏 ⇧⌘S
  显示/隐藏检查器 ⇧⌘I
  ─────────
  进入全屏 ⌃⌘F
  ─────────
  工作台
  收集箱
  AI 整理
  导出记录
  搜索

操作
  开始 AI 处理 ⇧⌘P
  输出到 Obsidian ⇧⌘O
  ─────────
  重试失败任务
  清除已完成任务

窗口
  最小化 ⌘M
  ─────────
  将窗口拼贴到屏幕左侧
  将窗口拼贴到屏幕右侧

帮助
  AcMind 帮助
  键盘快捷键
```

---

## 21. 快捷键规范

| 操作 | 快捷键 |
|---|---|
| 新建捕获 | ⌘N |
| 搜索 / Command | ⌘K |
| 设置 | ⌘, |
| 显示/隐藏侧边栏 | ⇧⌘S |
| 显示/隐藏检查器 | ⇧⌘I |
| 开始 AI 处理 | ⇧⌘P |
| 输出到 Obsidian | ⇧⌘O |
| 全屏 | ⌃⌘F |
| 关闭窗口 | ⌘W |
| 退出 | ⌘Q |

---

## 22. 动效规范

### 22.1 原则

动效用于反馈和引导，不用于装饰。所有动效必须支持 Reduce Motion。

### 22.2 Token

```css
:root {
  --pm-duration-instant: 50ms;
  --pm-duration-fast: 100ms;
  --pm-duration-normal: 200ms;
  --pm-duration-slow: 300ms;

  --pm-ease-default: cubic-bezier(0.25, 0.1, 0.25, 1.0);
  --pm-ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1.0);
  --pm-ease-decelerate: cubic-bezier(0, 0, 0.2, 1);
}

@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 22.3 标准场景

| 场景 | 时长 | 缓动 | 说明 |
|---|---|---|---|
| 按钮悬停 | 100ms | default | 背景色变化 |
| 按钮点击 | 50ms | default | scale(0.98) 反馈 |
| 面板展开/折叠 | 200ms | default | Inspector、侧边栏 |
| 页面切换 | 200ms | decelerate | 内容淡入 |
| Toast 出现 | 200ms | spring | 从右上角滑入 |
| Toast 消失 | 150ms | default | 淡出 |
| 搜索框展开 | 200ms | default | 宽度过渡 |
| 列表项选中 | 100ms | default | 背景色过渡 |
| 浮层弹出 | 200ms | spring | Popover、菜单 |

**禁止**：大幅弹跳、复杂路径动画、装饰性粒子、频繁闪烁、过度缩放、影响阅读的背景动画。

---

## 23. 深色模式

### 23.1 实现策略

- 使用 CSS 自定义属性 + `data-theme` 属性切换
- JavaScript 监听 Electron `nativeTheme` API 的 `updated` 事件
- 支持三种模式：跟随系统、浅色、深色

### 23.2 设计原则

参照 Apple HIG 深色模式指南：
- 不要简单反转颜色
- 使用更深的背景色（而非纯黑），让内容"浮"在上面
- 降低对比度，减少视觉疲劳
- 半透明元素在深色模式下更明显
- 阴影在深色模式下需要更深才能产生同样的层次感

### 23.3 深色 Token

```css
[data-theme="dark"] {
  /* 背景 */
  --pm-bg-app: #1e1e1e;
  --pm-bg-content: #262626;
  --pm-bg-card: rgba(58, 58, 60, 0.80);
  --pm-bg-card-hover: rgba(68, 68, 70, 0.90);
  --pm-bg-card-selected: rgba(255, 107, 43, 0.12);
  --pm-bg-textfield: rgba(28, 28, 30, 0.80);

  /* 文本 */
  --pm-text-primary: #f5f5f7;
  --pm-text-secondary: #a1a1a6;
  --pm-text-tertiary: #6e6e73;
  --pm-text-disabled: #48484a;

  /* 边框 */
  --pm-border-subtle: rgba(255, 255, 255, 0.06);
  --pm-border-default: rgba(255, 255, 255, 0.10);
  --pm-border-strong: rgba(255, 255, 255, 0.18);

  /* 填充 */
  --pm-fill-secondary: rgba(120, 120, 128, 0.24);
  --pm-fill-tertiary: rgba(120, 120, 128, 0.16);

  /* 强调色 */
  --pm-accent: #ff8f5e;
  --pm-accent-hover: #ffa87a;
  --pm-accent-active: #ff6b2b;
  --pm-accent-soft-bg: rgba(255, 107, 43, 0.12);
  --pm-accent-ring: rgba(255, 143, 94, 0.24);
}
```

---

## 24. 辅助功能

### 24.1 最低要求

- 所有交互元素的对比度 ≥ 4.5:1（WCAG AA）
- 所有图标提供 `aria-label` 或备选文本
- 支持完整键盘导航（Tab、Enter、Escape、方向键）
- 支持 macOS VoiceOver
- 支持 Reduce Motion 设置
- 支持 Increase Contrast 设置
- 不仅依赖颜色表达状态
- 禁用状态必须视觉明确

### 24.2 键盘导航

- Tab：在交互元素间移动焦点
- Enter / Space：激活按钮和链接
- Escape：关闭浮层、弹窗
- 方向键：在列表、表格中导航
- ⌘K：进入搜索 / Command
- ⌘,：进入设置

---

## 25. 窗口行为

### 25.1 主窗口

```text
支持自由调整大小
最小尺寸：960 × 640px
推荐默认尺寸：1280 × 820px
支持全屏模式
支持 macOS 窗口平铺（左侧/右侧）
标题栏显示当前视图名称
```

### 25.2 快速捕获窗口

```text
独立窗口，可选始终置顶
默认尺寸：560 × 480px
最小尺寸：420 × 360px
使用紧凑标题栏
支持 Escape 快速关闭
```

---

## 26. 页面级规范

### 26.1 工作台

**目标**：告诉用户今天有什么、下一步做什么、最近产出了什么。

**必须包含**：今日概览、待整理数量、正在处理、需要处理、最近导出、下一步建议。

**主操作**：开始整理待处理内容。

**视觉要求**：清楚、轻量、行动导向，不要只是统计面板。

### 26.2 收集箱

**目标**：展示所有待处理内容，并让用户选择进入 AI 整理。

**要求**：状态清楚、筛选轻量、列表可读、批量操作不抢焦点、失败/待处理明确显示。

**主操作**：整理选中内容。

### 26.3 AI 整理

**目标**：让用户完成 原文 → AI 输出 → 人工确认 → 导出。

**推荐布局**：左侧原始内容、中间整理结果/Markdown、右侧标签/路径/模型/质量状态。

**要求**：
- AI 输出正文必须高可读
- Mock / 规则模式必须明确标记
- 未配置模型必须提示
- 不允许无提示生成假 AI 结果

**主操作**：确认并导出。

### 26.4 导出记录

**目标**：让用户查看已经导出的 Markdown 和导出路径。

**要求**：文件名清楚、路径清楚、时间清楚、来源清楚、可以打开文件、可以打开来源、失败记录有原因。

### 26.5 搜索

**目标**：快速找到内容、标签、导出记录。

**要求**：搜索框真实可用、结果列表清楚、空状态有提示、搜索索引状态可见但不抢焦点。

### 26.6 设置

**目标**：配置 AcMind v2.0，而不是展示所有开发调试能力。

**要求**：分类清楚、高级项收起、禁用项明确说明、不可用功能标记"即将推出"、不要让普通用户误入调试区。

---

## 27. Design Token 建议结构

建议文件：`src/renderer/design-system/tokens.ts`

```ts
export const tokens = {
  color: {
    background: {
      app: '',
      window: '',
      page: '',
    },
    surface: {
      primary: '',
      secondary: '',
      tertiary: '',
      elevated: '',
      overlay: '',
    },
    border: {
      subtle: '',
      default: '',
      strong: '',
    },
    text: {
      primary: '',
      secondary: '',
      tertiary: '',
      disabled: '',
      inverse: '',
    },
    accent: {
      primary: '',
      hover: '',
      active: '',
      soft: '',
      ring: '',
    },
    status: {
      success: '',
      warning: '',
      danger: '',
      info: '',
      processing: '',
      neutral: '',
      mock: '',
    },
  },

  radius: {
    xs: '4px',
    sm: '6px',
    md: '8px',
    lg: '10px',
    xl: '12px',
    '2xl': '16px',
    full: '999px',
  },

  space: {
    0: '0px',
    1: '4px',
    2: '8px',
    3: '12px',
    4: '16px',
    5: '20px',
    6: '24px',
    8: '32px',
    10: '40px',
    12: '48px',
    16: '64px',
  },

  shadow: {
    sm: '',
    md: '',
    lg: '',
    xl: '',
  },

  typography: {
    largeTitle: {},
    title1: {},
    title2: {},
    title3: {},
    headline: {},
    body: {},
    callout: {},
    subhead: {},
    footnote: {},
    caption1: {},
    caption2: {},
    mono: {},
  },

  motion: {
    instant: '50ms',
    fast: '100ms',
    normal: '200ms',
    slow: '300ms',
    easeDefault: 'cubic-bezier(0.25, 0.1, 0.25, 1.0)',
    easeSpring: 'cubic-bezier(0.34, 1.56, 0.64, 1.0)',
    easeDecelerate: 'cubic-bezier(0, 0, 0.2, 1)',
  },
}
```

---

## 28. 组件建设优先级

### Phase 12.3 优先建设

```text
Button / Card / PageHeader / PageShell / Section
StatusBadge / Input / Textarea / SearchField / Tabs
EmptyState / LoadingState / ErrorState
Modal / Dialog / Toolbar / RightPanel / Inspector
```

### 优先替换页面

```text
工作台 / 收集箱 / AI 整理 / 导出记录 / 搜索
```

### P1 页面

```text
设置 / 错误回看 / 处理历史
```

---

## 29. V1.0 → V2.0 迁移清单

### 29.1 Design Token 迁移

| V1.0 | V2.0 | 说明 |
|---|---|---|
| 暖白背景 `#fff8ef` | 系统背景 / window background | 原生化 |
| 自定义暖色阴影 | 中性阴影 | 去网页感 |
| 大圆角卡片 16px | macOS 克制圆角 10px | 更原生 |
| 自定义玻璃 | 轻材质 / vibrancy 模拟 | 更接近系统 |
| 多色状态点缀 | 低饱和状态标签 | 降低噪音 |
| 页面内联样式 | token + 组件 | 提升一致性 |
| `--pm-primary-500: #f97316` | `--pm-accent: #ff6b2b` | 色值微调，对比度优化 |

### 29.2 组件迁移

| 旧方向 | 新方向 |
|---|---|
| 自定义 TopStatusBar | Toolbar |
| BottomRuntimeBar | 移至 Toolbar 状态区或页面状态区 |
| 自定义 Sidebar | macOS 风格 Sidebar |
| PrimaryButton 高 40px | Button 高 32px |
| Card 圆角 16px | Card 圆角 10px |
| StatusPill | StatusBadge |
| 自定义图标 | SF Symbols 气质图标 |
| 假搜索框 | 真实 SearchField / 搜索入口 |

### 29.3 新增能力

| 能力 | 说明 |
|---|---|
| 深色模式 | 全新的深色模式 Token 体系 |
| 菜单栏 | 完整的 macOS 菜单栏 |
| 键盘快捷键 | 标准 macOS 快捷键 |
| Reduce Motion | 动效可禁用 |
| 窗口管理 | 全屏、平铺、多窗口 |
| 系统强调色 | 尊重用户系统设置 |

---

## 30. 实现优先级

### Phase 12.3A：基础视觉框架（必须）

1. Design Token 体系（浅色 + 深色）
2. 系统字体和文本样式
3. macOS 克制圆角和中性阴影
4. Sidebar / Toolbar 基础风格

### Phase 12.3B：基础组件升级（必须）

1. Button（Primary / Secondary / Plain / Icon / Danger）
2. Card
3. Input / SearchField
4. StatusBadge
5. PageHeader / PageShell
6. EmptyState / LoadingState / ErrorState

### Phase 12.3C：主页面替换（必须）

1. 工作台
2. 收集箱
3. AI 整理
4. 导出记录
5. 搜索

### Phase 12.3D：系统集成增强（后续推进）

1. macOS 菜单栏
2. 键盘快捷键
3. 工具栏标准化
4. Inspector 标准化
5. 深色模式完整支持
6. Reduce Motion 支持
7. VoiceOver 支持

---

## 31. 验收标准

Phase 12.3 完成后，必须满足：

```text
[ ] AcMind v2.0 的视觉方向明确为 AcMind Native Workspace
[ ] 页面更接近 macOS 原生效率应用，而不是网页 Dashboard
[ ] 页面更接近 ChatGPT / Codex 的简洁工作台，而不是科技炫酷风
[ ] Sidebar 保持 Phase 12.2 收束后的主导航结构
[ ] Toolbar 不再堆过多状态 chip
[ ] 存在统一 Design Token
[ ] 存在统一 Button 组件
[ ] 存在统一 Card 组件
[ ] 存在统一 PageHeader / PageShell
[ ] 存在统一 StatusBadge
[ ] 存在统一 Input / SearchField
[ ] 存在统一 Empty / Loading / Error 状态
[ ] 正文字号以 13px 为基础
[ ] 字体栈以 -apple-system / SF Pro 开头
[ ] 所有主卡片圆角接近 10px
[ ] 所有按钮圆角接近 6px
[ ] 阴影为中性色调，无暖色偏移
[ ] 普通内容卡片不使用强玻璃
[ ] 长文本区域不使用强玻璃
[ ] 文字可读性没有下降
[ ] Mock / 规则模式 / 即将推出 / 未配置模型必须明确标记
[ ] 不恢复 Phase 12.2 已隐藏或灰态的不可用功能
[ ] 不新增业务功能
[ ] npm run typecheck 通过
[ ] npm run build 通过
```

---

## 32. Codex 核验重点

Codex 核验 Phase 12.3 时，应重点检查：

```text
1.  是否符合 AcMind Native Workspace，而不是 Glass / Cyber / AI OS 风格
2.  是否更接近 Apple 原生效率应用
3.  是否更接近 ChatGPT / Codex 的简洁工作台
4.  是否存在统一 tokens
5.  是否存在统一 Button / Card / PageHeader / StatusBadge 等基础组件
6.  是否主页面开始使用统一组件
7.  是否还有大量页面内联随手写样式
8.  是否所有主容器有圆角和自然阴影
9.  是否玻璃效果被克制使用
10. 是否文字可读性良好
11. 是否按钮层级清楚
12. 是否一个页面只有一个主要操作
13. 是否状态表达清楚
14. 是否没有把不可用功能伪装成可用功能
15. 是否没有恢复 Phase 12.2 已隐藏或灰态的功能
16. 是否通过 typecheck 和 build
```

---

## 33. 与旧规范的关系

AcMind v2.0 不是完全推翻 V1.0，而是在 V1.0 的产品逻辑和交互设计基础上，将视觉语言从「自定义暖阳橙」切换为「Apple 原生风格」。

### 保留的 V1.0 内容

```text
产品定位
核心链路：捕获 → 理解 → 蒸馏 → 归档 → 复用
状态透明原则
每页一个主动作原则
滚动优先原则
中文语境文案规范
本地优先可信原则
```

### 替换的 V1.0 内容

```text
Design Token / 颜色系统 / 阴影系统 / 圆角系统
材质实现方式 / 图标体系
顶部栏和底部栏实现
组件尺寸和样式
```

V1.0 规范在 V2.0 落地完成后应标记为归档。

---

## 34. 参考资源

| 资源 | 链接 |
|---|---|
| Apple HIG 首页 | https://developer.apple.com/cn/design/human-interface-guidelines/ |
| macOS 设计 | https://developer.apple.com/cn/design/human-interface-guidelines/designing-for-macos |
| 颜色 | https://developer.apple.com/cn/design/human-interface-guidelines/color |
| 字体排印 | https://developer.apple.com/cn/design/human-interface-guidelines/typography |
| 材质 | https://developer.apple.com/cn/design/human-interface-guidelines/materials |
| 布局 | https://developer.apple.com/cn/design/human-interface-guidelines/layout |
| 图标 | https://developer.apple.com/cn/design/human-interface-guidelines/icons |
| 工具栏 | https://developer.apple.com/cn/design/human-interface-guidelines/toolbars |
| 边栏 | https://developer.apple.com/cn/design/human-interface-guidelines/sidebars |
| macOS 设计资源 | https://developer.apple.com/design/resources/#macos-apps |
| SF Symbols | https://developer.apple.com/cn/design/human-interface-guidelines/sf-symbols |
| Apple Developer 文档 | https://developer.apple.com/documentation/ |
