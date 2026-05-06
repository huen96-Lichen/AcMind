> ⚠️ 历史文档，路径和内容可能已过时，仅供参考。

# AcMind V2.0 Apple 原生风格设计规范

版本：v2.0-draft  
日期：2026-05-01  
目标读者：Trae / Codex / 设计 & 开发执行者  
参考来源：[Apple HIG](https://developer.apple.com/cn/design/human-interface-guidelines/) · [macOS 设计资源](https://developer.apple.com/design/resources/#macos-apps) · [Apple Developer Documentation](https://developer.apple.com/documentation/)

---

## 0. 设计哲学转变

### V1.0「暖阳橙 / Warm Focus」→ V2.0「Apple Native / 原生融入」

V1.0 用自定义暖色系建立品牌感，但存在以下问题：
- 自定义 token 与 macOS 系统外观割裂，浅色/深色模式切换成本高
- 自定义玻璃效果与系统 Liquid Glass / vibrancy 不兼容
- 自定义图标体系维护成本高，无法与系统字体粗细自动对齐
- 暖白背景在多显示器、不同色域下表现不一致

V2.0 的核心转变：

> **AcMind 应该看起来像一个「Mac 原生应用」，而不是一个「运行在 Mac 上的 Web 应用」。**

具体而言：
1. **颜色**：从自定义暖色调 → macOS 动态系统颜色 + 品牌强调色
2. **材质**：从自定义 backdrop-filter → macOS 标准材质（NSVisualEffectView 等效）
3. **字体**：从自定义字体栈 → SF Pro 系统字体 + 标准文本样式
4. **图标**：从自定义 SVG → SF Symbols 为主，自定义图标为辅
5. **布局**：从自定义三栏 → macOS 标准 Sidebar + Toolbar + Inspector 模式
6. **交互**：从自定义反馈 → macOS 标准交互模式（菜单栏、键盘快捷键、触控板手势）
7. **外观**：同时支持浅色和深色模式

### 不变的原则

以下 V1.0 原则在 V2.0 中完全保留：

- **P0：可读性高于美观** — 文字永远优先清晰
- **P0：滚动高于布局完整** — 所有长页面必须可滚动
- **P0：状态真实高于视觉简洁** — AI 状态、Mock 模式、输出路径必须可见
- **P0：每页只有一个主动作**
- **本地优先可信** — 数据安全提示始终可见

---

## 1. 颜色系统

### 1.1 设计原则

参照 Apple HIG 颜色指南：
- 使用**语义化动态颜色**，而非硬编码色值
- 所有颜色必须同时提供**浅色和深色**变体
- 颜色传达**层级和状态**，不用于装饰
- 避免仅靠颜色区分信息，需配合文本标签或图标

### 1.2 背景层级

采用 macOS 标准背景层级体系：

| 层级 | 语义 | 浅色模式 | 深色模式 | 用途 |
|---|---|---|---|---|
| Window Background | 窗口底色 | `#ffffff` / `windowBackgroundColor` | `#1e1e1e` | 窗口整体背景 |
| Content Background | 内容区底色 | `#ffffff` / `textBackgroundColor` | `#262626` | 主工作区内容背景 |
| Sidebar Background | 侧边栏 | 系统 vibrancy 材质 | 系统 vibrancy 材质 | 侧边栏（使用系统材质） |
| Toolbar Background | 工具栏 | 系统 Liquid Glass | 系统 Liquid Glass | 顶部工具栏 |
| Card / Grouped | 卡片/分组 | `secondarySystemBackground` | `secondarySystemBackground` | 卡片、分组内容 |
| Elevated | 浮层 | `#ffffff` + shadow | `#2d2d2d` + shadow | 弹出菜单、浮层 |

**实现要点**：
- Electron 中通过 `nativeTheme` API 检测系统外观
- 使用 CSS 自定义属性 + JavaScript 动态切换浅色/深色 token
- 侧边栏和工具栏使用 vibrancy/blur 材质模拟系统效果

### 1.3 文本颜色

| 语义 | 浅色模式 | 深色模式 | 用途 |
|---|---|---|---|
| Label / Primary | `#1d1d1f` | `#f5f5f7` | 标题、正文一级内容 |
| Secondary Label | `#6e6e73` | `#a1a1a6` | 副标题、描述、摘要 |
| Tertiary Label | `#aeaeb2` | `#6e6e73` | 占位符、禁用文本、时间戳 |
| Quaternary Label | `#d1d1d6` | `#48484a` | 水印、最低优先级文本 |

### 1.4 品牌强调色（Accent Color）

AcMind 保留一个品牌强调色，用于：
- 当前选中的侧边栏项目
- 当前激活的 Tab 指示器
- 主按钮背景
- 选中卡片边框
- 关键操作高亮

**推荐色值**：

| 模式 | 色值 | 说明 |
|---|---|---|
| 浅色 Accent | `#ff6b2b` | 比 V1.0 的 `#f97316` 稍深，对比度更好 |
| 深色 Accent | `#ff8f5e` | 深色模式下提亮，保持可读性 |
| Accent Hover | 浅色 `#e55a1b` / 深色 `#ffa87a` | 悬停状态 |
| Accent Soft BG | 浅色 `#fff2ec` / 深色 `#3d2a1e` | 选中项背景 |

**约束**（与 V1.0 一致）：
- 橙色只用于聚焦和主动作，不大面积铺满
- 尊重用户在系统设置中选择的强调色（当用户设置非"多色"时，使用系统强调色）

### 1.5 状态颜色

保持 V1.0 的状态色体系，但适配深色模式：

| 状态 | 浅色前景 | 浅色背景 | 深色前景 | 深色背景 |
|---|---|---|---|---|
| 等待/排队 | `#92400e` | `#fef3c7` | `#fbbf24` | `#422006` |
| 运行中 | `#1d4ed8` | `#dbeafe` | `#60a5fa` | `#172554` |
| 成功 | `#15803d` | `#dcfce7` | `#4ade80` | `#052e16` |
| 错误 | `#dc2626` | `#fee2e2` | `#f87171` | `#450a0a` |
| 静默/Mock | `#52525b` | `#f4f4f5` | `#a1a1aa` | `#27272a` |

### 1.6 AI 等级颜色

| 等级 | 浅色 | 深色 |
|---|---|---|
| 本地模型 | `#16a34a` | `#4ade80` |
| 云端标准 | `#2563eb` | `#60a5fa` |
| 云端增强 | `#7c3aed` | `#a78bfa` |
| Mock 模式 | `#71717a` | `#a1a1aa` |

---

## 2. 字体排印

### 2.1 系统字体

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
}
```

### 2.2 文本样式层级

参照 Apple HIG 的文本样式体系，适配 macOS 默认字号（13pt）：

| 样式名称 | 字号 | 字重 | 行高 | 字间距 | 用途 |
|---|---|---|---|---|---|
| Large Title | 26px | 700 | 32px | -0.02em | 页面主标题（收集箱、设置） |
| Title 1 | 22px | 700 | 28px | -0.02em | 二级页面标题 |
| Title 2 | 17px | 600 | 22px | -0.01em | 区块标题 |
| Title 3 | 15px | 600 | 20px | 0 | 卡片标题、列表项标题 |
| Headline | 13px | 600 | 18px | 0 | 表头、分组标签 |
| Body | 13px | 400 | 18px | 0 | 正文内容（macOS 默认） |
| Callout | 12px | 400 | 16px | 0.01em | 辅助说明、描述 |
| Subhead | 12px | 400 | 16px | 0.01em | 摘要、预览文本 |
| Footnote | 11px | 400 | 14px | 0.01em | 元信息、时间戳、路径 |
| Caption 1 | 10px | 500 | 13px | 0.02em | 状态标签、徽章 |
| Caption 2 | 10px | 400 | 13px | 0.02em | 最小辅助文本 |

**关键变化**（对比 V1.0）：
- macOS 默认正文字号从 V1.0 的 14px 调整为 **13px**（macOS 系统标准）
- 最小字号 **10px**（Apple HIG 推荐的 macOS 最小字号）
- 避免使用纤细体（Light / Thin），优先 Regular、Medium、Semibold、Bold

### 2.3 中文适配

```css
:root {
  --pm-font-cjk:
    "PingFang SC",     /* macOS / iOS */
    "Noto Sans SC",    /* Linux fallback */
    "Microsoft YaHei", /* Windows fallback */
    sans-serif;
}
```

- 中文正文行高建议为字号的 **1.6-1.8 倍**
- 中文标题行高建议为字号的 **1.3-1.4 倍**
- 中英文混排时，英文使用 SF Pro，中文使用苹方

---

## 3. 材质与深度

### 3.1 设计原则

参照 Apple HIG 材质指南：
- 材质用于在前景和背景之间建立**景深感和层次感**
- **Liquid Glass** 用于控制和导航元素（工具栏、侧边栏）
- **标准材质**用于内容层内的视觉区分
- 材质效果不应影响文本可读性

### 3.2 材质层级映射

| Apple 材质 | AcMind 用途 | 实现方式 |
|---|---|---|
| Liquid Glass (Regular) | 侧边栏、工具栏 | `backdrop-filter: blur(20px) saturate(180%)` + 半透明背景 |
| Liquid Glass (Clear) | 浮层菜单、弹出面板 | `backdrop-filter: blur(40px)` + 高透明度背景 |
| Thick Material | Inspector 面板 | `backdrop-filter: blur(30px) saturate(150%)` |
| Regular Material | 卡片、分组 | `backdrop-filter: blur(12px)` + 轻微半透明 |
| Thin Material | 悬浮提示、标签 | `backdrop-filter: blur(8px)` |

### 3.3 CSS 实现

```css
/* 侧边栏 - Liquid Glass Regular */
.pm-sidebar {
  background: rgba(246, 246, 246, 0.72);  /* 浅色 */
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-right: 0.5px solid rgba(0, 0, 0, 0.12);
}

[data-theme="dark"] .pm-sidebar {
  background: rgba(44, 44, 46, 0.72);     /* 深色 */
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

### 3.4 阴影

从 V1.0 的暖色调阴影改为 macOS 标准中性阴影：

```css
:root {
  /* macOS 标准阴影 - 浅色模式 */
  --pm-shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);
  --pm-shadow-md: 0 4px 12px rgba(0, 0, 0, 0.08), 0 2px 4px rgba(0, 0, 0, 0.04);
  --pm-shadow-lg: 0 12px 40px rgba(0, 0, 0, 0.12), 0 4px 12px rgba(0, 0, 0, 0.06);
  --pm-shadow-xl: 0 24px 64px rgba(0, 0, 0, 0.16), 0 8px 20px rgba(0, 0, 0, 0.08);

  /* 深色模式阴影更深 */
  --pm-shadow-sm-dark: 0 1px 3px rgba(0, 0, 0, 0.24), 0 1px 2px rgba(0, 0, 0, 0.16);
  --pm-shadow-md-dark: 0 4px 12px rgba(0, 0, 0, 0.32), 0 2px 4px rgba(0, 0, 0, 0.16);
  --pm-shadow-lg-dark: 0 12px 40px rgba(0, 0, 0, 0.40), 0 4px 12px rgba(0, 0, 0, 0.20);
}
```

---

## 4. 圆角

### 4.1 macOS 标准圆角

macOS 系统组件使用以下标准圆角值：

| 元素 | 圆角 | 说明 |
|---|---|---|
| 窗口 | 10px | macOS 窗口标准圆角 |
| 按钮（标准） | 6px | macOS 标准按钮 |
| 按钮（胶囊） | 999px | 全圆角按钮 |
| 输入框 | 6px | 文本输入框 |
| 卡片/分组 | 10px | 内容卡片 |
| 浮层/弹窗 | 12px | 弹出菜单、Popover |
| 工具栏项目 | 6px | 工具栏内按钮 |
| 侧边栏选中项 | 6px | 侧边栏高亮行 |
| 状态标签 | 999px | StatusPill 全圆角 |
| 缩略图/头像 | 8px 或圆形 | 根据内容决定 |

**关键变化**（对比 V1.0）：
- V1.0 的卡片圆角 16px → V2.0 的 **10px**（macOS 标准）
- V1.0 的按钮圆角 12px → V2.0 的 **6px**（macOS 标准）
- 整体更克制，与系统外观一致

---

## 5. 间距系统

### 5.1 基础间距

采用 4px 基础网格，与 macOS 标准一致：

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

### 5.2 组件间距规范

| 场景 | 间距 | 说明 |
|---|---|---|
| 工具栏内项目间距 | 8px | 工具栏按钮之间 |
| 工具栏分组间距 | 16px | 工具栏不同功能组之间 |
| 侧边栏项目间距 | 2px | 侧边栏导航项之间 |
| 侧边栏分组间距 | 12px | 侧边栏不同分组之间 |
| 卡片内边距 | 16px | 卡片内容区域 |
| 列表项内边距 | 12px 16px | 列表行的 padding |
| 内容区页面边距 | 20px | 主工作区内容的外边距 |
| Inspector 内边距 | 16px | 右侧面板内容边距 |
| 分组标题与内容 | 8px | 分组标题下方到第一个元素 |
| 表单标签与输入框 | 6px | 标签和对应输入框之间 |

---

## 6. 图标系统

### 6.1 SF Symbols 优先

Apple HIG 明确推荐使用 SF Symbols 作为界面图标。AcMind V2.0 应：

1. **优先使用 SF Symbols**：所有标准操作（搜索、编辑、删除、设置等）使用 SF Symbols
2. **自定义图标作为补充**：仅在 SF Symbols 无法表达的业务概念上使用自定义图标
3. **保持视觉一致性**：自定义图标需匹配 SF Symbols 的线条粗细（Regular = 1.5px @1x）

### 6.2 SF Symbols 映射表

| AcMind 功能 | SF Symbol 名称 | 说明 |
|---|---|---|
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

### 6.3 图标尺寸

| 场景 | 尺寸 | SF Symbol Scale |
|---|---|---|
| 侧边栏图标 | 18px | Medium |
| 工具栏图标 | 18px | Medium |
| 按钮内图标 | 16px | Medium |
| 列表项图标 | 16px | Medium |
| 状态图标 | 14px | Small |
| 大功能图标 | 24px | Large |

### 6.4 自定义图标规范

当 SF Symbols 无法满足时，自定义图标需遵循：

- 格式：SVG（矢量，支持自动缩放）
- 线条粗细：1.5px（匹配 SF Symbols Regular weight）
- 视觉框：24×24px，内容区 20×20px（留 2px 内边距）
- 颜色：使用 `currentColor` 继承文本颜色
- 圆角端点：round cap / round join

---

## 7. 布局系统

### 7.1 全局骨架（macOS 标准模式）

```
┌─────────────────────────────────────────────────────────────────┐
│ Window Title Bar (系统红黄绿按钮 + 标题)                          │
├─────────────────────────────────────────────────────────────────┤
│ Toolbar (Liquid Glass)                                          │
│ [Sidebar Toggle] [Navigation] [Title] [Actions] [Search]        │
├────────────┬─────────────────────────────────┬──────────────────┤
│            │                                 │                  │
│  Sidebar   │      Main Content Area          │   Inspector      │
│  (Liquid   │      (Content Background)       │   (可折叠)        │
│  Glass)    │                                 │                  │
│            │                                 │                  │
│  220px     │      自适应                      │   320px          │
│            │                                 │                  │
│            │                                 │                  │
├────────────┴─────────────────────────────────┴──────────────────┤
│ Status Bar (可选，仅在需要时显示)                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 关键变化（对比 V1.0）

| 项目 | V1.0 | V2.0 | 原因 |
|---|---|---|---|
| 顶部栏 | 自定义 TopStatusBar | macOS Toolbar + 菜单栏 | 遵循 macOS 标准 |
| 侧边栏宽度 | 248px | 220px | macOS 标准侧边栏宽度 |
| Inspector 宽度 | 420px | 320px | macOS 标准 Inspector 宽度 |
| 底部状态栏 | 固定 BottomRuntimeBar | 移至工具栏/菜单栏 | macOS 应用通常无底部状态栏 |
| 窗口标题 | 无 | 显示当前视图/文档名 | macOS 标准 |
| 搜索 | 顶部搜索框 | 工具栏搜索栏 / ⌘K | macOS 标准搜索模式 |

### 7.3 侧边栏（Sidebar）

参照 Apple HIG 侧边栏指南：

**结构**：
```
[Logo / App Name]
─────────────────
主导航
  ▸ 工作台 (house)
  ▸ 收集箱 (tray)
  ▸ AI 整理 (sparkles)
  ▸ 导出记录 (arrow.up.doc)
  ▸ 搜索 (magnifyingglass)
─────────────────
高级
  ▸ 处理历史 (clock.arrow.circlepath)
  ▸ 错误回看 (exclamationmark.triangle)
─────────────────
  ▸ 设置 (gearshape)
```

**样式规范**：
- 使用 macOS 标准侧边栏样式（vibrancy 背景）
- 选中项使用系统强调色背景（圆角 6px）
- 图标使用 SF Symbols，颜色跟随选中状态
- 项目高度 28px（macOS 标准行高）
- 支持显示/隐藏（⌘⇧S 或工具栏按钮）
- 内容延伸至侧边栏下方（background extension effect）

**约束**：
- 层级不超过两层
- 不在侧边栏底部放置关键信息（用户可能缩小窗口裁切底部）
- 允许用户隐藏侧边栏

### 7.4 工具栏（Toolbar）

参照 Apple HIG 工具栏指南：

**结构**：
```
[前缘]                    [中间]                    [后缘]
Sidebar Toggle            当前视图标题               搜索栏
返回/前进                  (可选)                    Inspector Toggle
                                                      更多菜单
```

**规范**：
- 工具栏项目不使用边框（macOS 标准）
- 使用 SF Symbols 无边框图标
- 关键操作使用 `.prominent` 样式（强调色背景）
- 窗口变窄时，中间项目自动收起至溢出菜单
- 每个工具栏操作都必须在菜单栏中有对应命令
- 标题精简，少于 15 个字符

### 7.5 Inspector（检查器）

参照 macOS 标准 Inspector 模式：

- 宽度 320px，可折叠
- 从窗口右侧滑入
- 使用较厚材质背景
- 包含所选内容的详细信息、操作和元数据
- 独立滚动

### 7.6 响应式断点

| 断点 | 宽度 | 布局 |
|---|---|---|
| Full | ≥ 1200px | 三栏（Sidebar + Main + Inspector） |
| Medium | 960–1199px | 两栏（Sidebar + Main），Inspector 折叠 |
| Compact | 720–959px | 单栏，Sidebar 折叠为图标模式 |
| Narrow | < 720px | 单栏，Sidebar 隐藏 |

---

## 8. 菜单栏

### 8.1 macOS 菜单栏结构

AcMind 作为 macOS 应用，必须提供完整的菜单栏：

```
AcMind ▸
  关于 AcMind
  设置… (⌘,)
  ─────────
  隐藏 AcMind (⌘H)
  隐藏其他 (⌘⌥H)
  显示全部
  ─────────
  退出 AcMind (⌘Q)

文件 ▸
  新建捕获 (⌘N)
  导入文件… (⌘⇧I)
  从剪贴板导入 (⌘⇧V)
  ─────────
  关闭窗口 (⌘W)

编辑 ▸
  撤销 (⌘Z)
  重做 (⌘⇧Z)
  ─────────
  剪切 (⌘X)
  拷贝 (⌘C)
  粘贴 (⌘V)
  全选 (⌘A)
  ─────────
  查找… (⌘F)

显示 ▸
  显示/隐藏侧边栏 (⌘⇧S)
  显示/隐藏检查器 (⌘⇧I)
  ─────────
  进入全屏 (⌘⌃F)
  ─────────
  工作台
  收集箱
  AI 整理
  导出记录
  搜索

操作 ▸
  开始 AI 处理 (⌘⇧P)
  输出到 Obsidian (⌘⇧O)
  ─────────
  重试失败任务
  清除已完成任务

窗口 ▸
  最小化 (⌘M)
  ─────────
  将窗口拼贴到屏幕左侧
  将窗口拼贴到屏幕右侧

帮助 ▸
  AcMind 帮助
  键盘快捷键
```

### 8.2 快捷键

| 操作 | 快捷键 |
|---|---|
| 新建捕获 | ⌘N |
| 搜索 | ⌘K |
| 设置 | ⌘, |
| 显示/隐藏侧边栏 | ⌘⇧S |
| 显示/隐藏检查器 | ⌘⇧I |
| 开始 AI 处理 | ⌘⇧P |
| 输出到 Obsidian | ⌘⇧O |
| 全屏 | ⌘⌃F |
| 关闭窗口 | ⌘W |
| 退出 | ⌘Q |

---

## 9. 组件规范

### 9.1 按钮（Button）

#### 主按钮（Primary / Prominent）

```css
.pm-btn-primary {
  height: 32px;                    /* macOS 标准按钮高度 */
  padding: 0 14px;
  border-radius: 6px;              /* macOS 标准圆角 */
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
  cursor: default;                 /* macOS 标准光标 */
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

#### 次按钮（Secondary / Bordered）

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

#### 无边框按钮（Borderless / Plain）

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

#### 图标按钮（Icon Button）

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

### 9.2 输入框（Text Field）

```css
.pm-input {
  height: 28px;                    /* macOS 标准输入框高度 */
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

### 9.3 搜索栏（Search Field）

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
  width: 320px;                    /* 聚焦时展开 */
  transition: width 200ms ease-out;
}
```

### 9.4 卡片（Card / Group Box）

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

### 9.5 状态标签（Badge / Status Pill）

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

### 9.6 表格（Table）

macOS 标准表格样式：

- 表头高度 28px，使用 `Headline` 文本样式
- 行高 32px（紧凑）或 44px（标准）
- 交替行背景色（`alternatingContentBackgroundColors`）
- 选中行使用系统选中色
- 支持多选（⌘+点击）和范围选择（⇧+点击）
- 表格外部可滚动

### 9.7 Toast / 通知

macOS 标准通知风格：

- 使用系统通知中心（如果 Electron 支持）
- 应用内 Toast 使用轻量浮层，位于窗口右上角
- 成功：2 秒自动消失
- 错误：5 秒或手动关闭，附带操作按钮
- 样式遵循 macOS 通知卡片风格

### 9.8 分割视图（Split View）

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

## 10. 动效

### 10.1 原则

- 动效用于**反馈和引导**，不用于装饰
- 遵循 macOS 系统动效时长和缓动曲线
- 所有动效必须在 **Reduce Motion** 辅助功能设置下可禁用

### 10.2 时长与缓动

```css
:root {
  /* macOS 标准动效 */
  --pm-duration-instant: 50ms;
  --pm-duration-fast: 100ms;
  --pm-duration-normal: 200ms;
  --pm-duration-slow: 300ms;

  --pm-ease-default: cubic-bezier(0.25, 0.1, 0.25, 1.0);  /* macOS 标准 */
  --pm-ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1.0);   /* 弹性 */
  --pm-ease-decelerate: cubic-bezier(0, 0, 0.2, 1);        /* 减速进入 */
}

/* Reduce Motion */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 10.3 标准动效场景

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

---

## 11. 深色模式

### 11.1 实现策略

- 使用 CSS 自定义属性 + `data-theme` 属性切换
- JavaScript 监听 `nativeTheme` API 的 `updated` 事件
- 支持三种模式：跟随系统、浅色、深色

### 11.2 深色模式设计原则

参照 Apple HIG 深色模式指南：
- 不要简单反转颜色
- 使用更深的背景色（而非纯黑），让内容"浮"在上面
- 降低对比度，减少视觉疲劳
- 半透明元素在深色模式下更明显
- 阴影在深色模式下需要更深才能产生同样的层次感

### 11.3 深色模式 Token 映射

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

## 12. 辅助功能

### 12.1 最低要求

- 所有交互元素的对比度 ≥ 4.5:1（WCAG AA）
- 所有图标提供 `aria-label` 或备选文本
- 支持完整键盘导航（Tab、Enter、Escape、方向键）
- 支持 macOS VoiceOver
- 支持 Reduce Motion 设置
- 支持 Increase Contrast 设置

### 12.2 键盘导航

- Tab 键在交互元素间移动焦点
- Enter / Space 激活按钮和链接
- Escape 关闭浮层、弹窗
- 方向键在列表、表格中导航
- ⌘+Tab 在应用间切换（系统级）

---

## 13. 窗口行为

### 13.1 主窗口

- 支持自由调整大小
- 最小尺寸：960 × 640px
- 推荐默认尺寸：1280 × 820px
- 支持全屏模式
- 支持 macOS 窗口平铺（左侧/右侧）
- 标题栏显示当前视图名称

### 13.2 快速捕获窗口

- 独立窗口，始终置顶（可选）
- 尺寸：560 × 480px
- 最小尺寸：420 × 360px
- 使用紧凑标题栏
- 支持快速关闭（Escape）

---

## 14. V1.0 → V2.0 迁移清单

### 14.1 Design Token 迁移

| V1.0 Token | V2.0 Token | 变化说明 |
|---|---|---|
| `--pm-bg-app: #fff8ef` | `--pm-bg-app: #ffffff` | 暖白 → 纯白（系统标准） |
| `--pm-bg-sidebar: rgba(255,247,235,0.88)` | 系统 vibrancy 材质 | 自定义 → 系统材质 |
| `--pm-primary-500: #f97316` | `--pm-accent: #ff6b2b` | 色值微调，对比度优化 |
| `--pm-shadow-card` (暖色调) | `--pm-shadow-md` (中性) | 阴影去掉暖色偏移 |
| `--pm-radius-md: 12px` | `10px` | 匹配 macOS 标准 |
| `--pm-radius-sm: 8px` | `6px` | 匹配 macOS 标准 |

### 14.2 组件迁移

| 组件 | 变化 |
|---|---|
| TopStatusBar → Toolbar | 改用 macOS 标准工具栏 |
| BottomRuntimeBar | 移至工具栏状态指示器或菜单栏 |
| Sidebar | 改用 macOS 标准侧边栏样式和行高 |
| PrimaryButton | 高度 40→32px，圆角 12→6px |
| Card | 圆角 16→10px，去掉暖色阴影 |
| StatusPill → Badge | 尺寸缩小，适配深色模式 |
| 自定义图标 → SF Symbols | 替换为 SF Symbols |
| 搜索框 | 移至工具栏，使用 macOS 标准搜索栏 |

### 14.3 新增能力

| 能力 | 说明 |
|---|---|
| 深色模式 | 全新的深色模式 Token 体系 |
| 菜单栏 | 完整的 macOS 菜单栏 |
| 键盘快捷键 | 标准 macOS 快捷键 |
| Reduce Motion | 动效可禁用 |
| 窗口管理 | 全屏、平铺、多窗口 |
| 系统强调色 | 尊重用户系统设置 |

---

## 15. 实现优先级

### Phase 1：基础框架（必须）
1. Design Token 体系（浅色 + 深色）
2. 系统字体和文本样式
3. macOS 标准圆角和间距
4. 背景材质（vibrancy / blur）
5. 侧边栏改为 macOS 标准样式

### Phase 2：组件升级（必须）
1. 按钮组件（Primary / Secondary / Plain / Icon）
2. 输入框和搜索栏
3. 卡片和分组
4. 状态标签（Badge）
5. 表格样式

### Phase 3：系统集成（重要）
1. macOS 菜单栏
2. 键盘快捷键
3. SF Symbols 图标替换
4. 工具栏标准化
5. 窗口行为（全屏、平铺）

### Phase 4：体验增强（可选）
1. 深色模式完整支持
2. Reduce Motion 支持
3. VoiceOver 支持
4. 系统强调色适配
5. 动效精细化

---

## 16. 验收标准

```
[ ] 所有背景色使用系统标准色值，非自定义暖色
[ ] 浅色和深色模式均可正常显示
[ ] 侧边栏使用 vibrancy 材质，行高 28px
[ ] 工具栏使用 Liquid Glass 材质
[ ] 所有按钮圆角 6px，高度 32px
[ ] 所有卡片圆角 10px
[ ] 正文字号 13px（macOS 默认）
[ ] 字体栈以 SF Pro / -apple-system 开头
[ ] 图标优先使用 SF Symbols
[ ] 阴影为中性色调，无暖色偏移
[ ] 菜单栏完整，包含所有主要操作
[ ] 快捷键遵循 macOS 标准
[ ] 窗口支持调整大小、全屏、平铺
[ ] 所有交互元素支持键盘导航
[ ] 对比度满足 WCAG AA 标准
[ ] Reduce Motion 设置下动效可禁用
[ ] 底部状态栏已移除或移至工具栏
[ ] 搜索使用 macOS 标准搜索栏样式
```

---

## 附录 A：参考资源

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

## 附录 B：与 V1.0 设计规范的关系

V2.0 不是完全推翻 V1.0，而是在 V1.0 的产品逻辑和交互设计基础上，将视觉语言从「自定义暖阳橙」切换为「Apple 原生风格」。

**保留的 V1.0 内容**：
- 产品定位和核心链路（捕获→理解→蒸馏→归档→复用）
- 页面结构和信息架构
- 状态透明原则（AI 状态、Mock 模式、输出路径必须可见）
- 每页一个主动作原则
- 滚动优先原则
- 文案规范（中文语境）

**替换的 V1.0 内容**：
- 所有 Design Token（颜色、阴影、圆角）
- 材质实现方式
- 图标体系
- 顶部栏和底部栏的实现
- 组件尺寸和样式

V1.0 规范文档（`AcMind_UI设计规范/` 目录）在 V2.0 落地完成后标记为归档。
