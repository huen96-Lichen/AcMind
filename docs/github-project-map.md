# AcMind / GitHub 文件夹项目地图

> 说明：本文基于 `/Volumes/White Atlas/03_Projects/GitHub` 顶层项目与 README 速览整理，目标不是逐仓库穷举源码，而是先建立“项目地图”和“能力地图”，方便后续判断哪些能力应当并入 AcMind，哪些只作为参考，哪些应当进入高级区。

## 1. AcMind 的产品理解

AcMind 是一个本地优先的桌面 AI 信息中枢，也是一个可扩展的个人 AI 工具台。

它有两条并行主线：

1. **信息主线**
   - 先 Pin 住碎片信息
   - 再筛理、蒸馏、确认
   - 最后入库到 Markdown / Obsidian

2. **工具主线**
   - 收纳网上看到的开源项目、脚本、转换器和实用工具
   - 统一启动、编排和调用
   - 形成自己的桌面小工具集合

除此之外，还有一层重要底座：

- 桌面壳层：notch / menu bar / 浮窗 / capsule
- AI 与基础设施：截图、OCR、语音、本地模型、转换器

---

## 2. GitHub 文件夹项目地图

| 项目 | 核心能力 | 更像 AcMind 的哪一层 | 建议角色 |
|---|---|---|---|
| `macshot-main` | 截图、标注、滚动截图、OCR、翻译、录屏、脱敏、上传 | 信息主线的采集层 | 高优先级吸收 |
| `snow-shot-main` | 截图、标注、滚动、固定到屏幕、保存/复制 | 信息主线的采集层 + Pin 能力 | 高优先级吸收 |
| `markitdown-main` | 把 PDF / DOCX / 图片 / 音频 / HTML 等转成 Markdown | 信息主线的入库前转换层 | 高优先级吸收 |
| `openless-main` | 语音输入、语音转写、结构化润色、直接写入光标 | 信息主线的输入层 | 高优先级吸收 |
| `NotesBar-master` | Obsidian / Apple Notes 统一搜索、浮窗、上下文保留 | 信息主线的回看层 / 浮窗层 | 强参考 |
| `cai-master` | 选中文本/图片后直接调用 AI、脚本、连接器 | 工具主线的动作执行层 | 强参考 |
| `ZTools-main` | 启动器、插件平台、剪贴板管理 | 工具主线的工具收纳层 | 强参考 |
| `autoclawd-main` | 常驻式 AI、悬浮胶囊、语音、OCR、自动执行 | 工具主线 + 桌面常驻 AI 层 | 强参考 |
| `omlx-main` | 本地 LLM 推理、批处理、KV cache、菜单栏控制 | AI 基础设施层 | 中高优先级参考 |
| `Atoll-main` | notch / Dynamic Island 风格命令面板、媒体、系统信息 | 桌面壳层 | UI 参考 |
| `boring.notch-main` | notch 音乐控制中心、视觉化、日历、文件 shelf、HUD 替代 | 桌面壳层 | UI 参考 |
| `dodopulse-main` | 菜单栏系统指标监控 | 桌面状态层 | 弱参考 |
| `extensions-main` | Raycast 扩展仓库 | 工具生态 / 插件生态 | 生态参考 |
| `Cent-main` | 记账 / 财务 Web 应用 | 与 AcMind 目标不一致 | 不建议整合 |

---

## 3. 按能力族拆分

### 3.1 信息主线能力族

这类能力直接服务 AcMind 的核心心智：

- 截图 / 采集
  - `macshot-main`
  - `snow-shot-main`
- 语音输入
  - `openless-main`
- 文档转换
  - `markitdown-main`
- 知识回看 / 浮窗
  - `NotesBar-master`

它们共同回答的是：

> 我先把东西留住，再慢慢变成知识。

这就是 AcMind 的信息主线。

### 3.2 工具主线能力族

这类能力服务“个人 AI 工具台”的心智：

- 上下文动作 / AI 操作
  - `cai-master`
- 工具收纳 / 启动器 / 插件
  - `ZTools-main`
  - `extensions-main`
- 常驻式 AI / 自动执行
  - `autoclawd-main`

它们共同回答的是：

> 我看到一个工具、脚本、转换器，就能把它收进来、调起来、编排起来。

这就是 AcMind 的工具主线。

### 3.3 桌面壳层能力族

这类能力不是主流程，但会决定 AcMind 的“桌面感”和“存在感”：

- `Atoll-main`
- `boring.notch-main`
- `dodopulse-main`

它们提供的是：

- notch / menu bar 的轻量入口
- 系统状态
- 媒体控制
- 小型信息面板
- 桌面常驻感

### 3.4 AI / 转换 / 基础设施能力族

这类能力是 AcMind 的地基：

- `omlx-main`：本地模型推理
- `openless-main`：语音输入
- `markitdown-main`：结构化转换
- `macshot-main` / `snow-shot-main`：采集
- `autoclawd-main`：常驻 AI

它们不一定都要前台暴露，但会决定 AcMind 能不能“顺手”。

---

## 4. 对 AcMind 的实际意义

### 4.1 AcMind 不应该只是一条知识流

如果只看“收集 → 整理 → 导出”，AcMind 会变普通。

更准确的是：

- **信息主线**：先 Pin 住，再筛理成知识
- **工具主线**：把外部开源项目和实用工具收纳成自己的桌面小工具集合

### 4.2 AcMind 的首页不该只是 Dashboard

首页应该同时告诉用户两件事：

- 今天有没有新碎片要 Pin 住
- 有没有现成工具可以直接用

也就是说，首页要同时承接：

- 今日信息缓冲
- 今日工具入口

### 4.3 AcMind 的“工具箱”不是杂物间，而是能力编排台

工具箱里放的不是“临时残余”，而是：

- 截图
- OCR
- 语音
- 转换器
- 自动化
- 插件
- 选中即动作
- 本地 AI 小能力

它是 AcMind 的第二主线，不是附属页。

---

## 5. 建议的 AcMind 信息架构

如果按当前产品定义，推荐结构如下：

- **Quick Desk**
  - 负责信息主线的首屏
  - Pin Pool、临时留住、今日处理
- **工具台**
  - 负责工具主线
  - 启动、收纳、编排、常用小工具
- **收集箱**
  - 正式收集入口
- **AI 整理**
  - 蒸馏、确认、入库前处理
- **知识库 / 导出**
  - Obsidian、Markdown、历史
- **设置**
  - 高级能力、模型、provider、系统配置

---

## 6. 哪些项目更适合怎么落进 AcMind

### 6.1 高优先级吸收

- `macshot-main`
- `snow-shot-main`
- `markitdown-main`
- `openless-main`
- `cai-master`

这些最能补强 AcMind 的主价值。

### 6.2 中优先级吸收

- `NotesBar-master`
- `ZTools-main`
- `autoclawd-main`
- `omlx-main`

这些更像“把 AcMind 做成真正桌面中枢”的关键拼图。

### 6.3 低优先级参考

- `Atoll-main`
- `boring.notch-main`
- `dodopulse-main`
- `extensions-main`

它们主要提供桌面交互、状态展示、生态组织的灵感。

### 6.4 不建议整合

- `Cent-main`

方向不一致，和 AcMind 目标无关。

---

## 7. 一句话总结

这个 GitHub 文件夹不是一个项目，而是 AcMind 可以吸收的两类资产库：

- 一类是把碎片信息 Pin 住并变成知识的能力
- 一类是把开源工具收纳成个人 AI 工具台的能力

