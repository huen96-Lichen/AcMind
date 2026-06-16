# AcWork UI Architecture v1.0

## 1. 产品定位

AcWork 是一款面向 macOS 的本地优先个人 AI 工作台。

核心目标不是“展示功能”，而是把以下流程连接起来：

```text
捕获信息
→ 进入收集箱
→ AI 理解与整理
→ 转化为任务 / 日程 / 知识
→ 执行与跟踪
→ 归档或导出
```

关键词：

- 工作
- 执行
- 信息流
- AI 协作
- 自动化
- 本地优先
- 内容优先

---

## 2. 品牌与命名

产品正式名称：

```text
AcWork
```

用户可见内容中停止使用 AcMind。

建议内部命名逐步迁移：

```text
AcMindApp       → AcWorkApp
AcMindAgent     → AcWorkAgent
AcMindSettings  → AcWorkSettings
```

旧数据目录需要保留迁移兼容，不得直接改名导致旧数据失效。

---

## 3. 一级导航

### 工作

- 工作台
- Agent
- 收集箱
- 日程

### 处理

- 工具台

### 随身能力

- 灵动大陆
- 说入法

### 系统

- 状态
- 模型
- 设置

共 10 个主页面。

加上统一应用外壳，共 11 张核心设计稿。

---

## 4. 收集箱与剪贴板合并

剪贴板不再作为一级页面。

收集箱负责统一承载：

- 剪贴板
- 手机同步
- 说入法
- 截图与 OCR
- Agent
- 手动添加
- 后续浏览器扩展
- 后续文件夹监听

### 收集箱三栏结构

```text
来源与筛选 220 pt
内容工作区 自适应
详情与处理 304 pt
```

### 左侧筛选

快捷视图：

- 全部内容
- 待整理
- 已 Pin
- 已收藏
- 最近使用

来源：

- 剪贴板
- 手机同步
- 说入法
- 截图与 OCR
- Agent
- 手动添加

内容类型：

- 文本
- 链接
- 图片
- 文件
- 代码
- 富文本
- 视频

处理状态：

- 待整理
- 已提炼
- 已归档
- 已导出

### 中间内容区

支持：

- 列表视图
- 网格视图
- 批量选择
- 搜索
- 组合筛选
- 排序

### 右侧详情

无选中项时：

- 总数量
- 待整理数量
- Pin 数量
- 手机同步状态
- 粘贴队列数量

选中项后：

- 完整内容
- 原始来源
- 来源应用或设备
- 创建时间
- 内容类型
- 标签
- 关联项目
- AI 提炼
- 转任务
- 转日程
- 保存到知识库
- 导出 Markdown
- 归档
- 删除

---

## 5. 页面职责

### 5.1 工作台

回答四个问题：

1. 当前正在做什么
2. 接下来应该做什么
3. 哪些内容等待处理
4. AcWork 是否正常运行

页面结构：

- 当前工作状态
- Agent 当前任务
- 下一日程
- 待整理内容
- 最近剪贴板与 Pin
- 最近活动
- 今日计划
- 快速操作
- 压缩系统状态栏

系统状态不应成为页面核心。

### 5.2 Agent

核心：

- 连续对话
- 项目上下文
- 工具调用
- 任务执行
- 结果追溯
- 权限请求
- 输入与附件

布局：

```text
会话栏 220 pt
对话区 自适应
任务详情栏 304 pt，可收起
```

### 5.3 收集箱

统一采集、浏览、整理和分发。

不是“剪贴板历史页”，也不是“知识库”。

### 5.4 日程

默认周视图。

核心：

- 日 / 周 / 月 / 年
- 时间轴
- 下一事件
- 空闲时间
- 冲突
- 全天事件
- 今日计划

### 5.5 工具台

不是应用商店。

结构：

```text
分类 220 pt
工具列表 自适应
工具配置与结果 304 pt
```

### 5.6 灵动大陆

结构：

- 收起态真实预览
- 展开态真实预览
- 模块管理
- 行为
- 外观
- 权限
- 调试

预览必须复用真实组件和数据模型。

### 5.7 说入法

完整链路：

```text
触发
→ 录音
→ 转写
→ 修正
→ 输出
```

结构：

- 触发方式
- 快捷键
- ASR 引擎
- 润色规则
- 纠错词典
- 输出方式
- 连续输入
- 输入设备

### 5.8 状态

负责完整系统状态。

工作台只显示摘要。

包括：

- CPU
- 内存
- 网络
- 磁盘
- 电池
- 温度
- 风扇
- GPU
- 权限
- 诊断

### 5.9 模型

统一管理：

- 云端 AI
- 本地 AI
- 云端 ASR
- 本地 ASR
- 系统语音识别
- 语音克隆

### 5.10 设置

分类：

- 通用
- 随身能力
- AI 与模型
- 数据与知识库
- 捕获与输入
- 权限与安全
- 关于

---

## 6. 统一应用外壳

设计基准：

```text
1500 × 920 pt
```

尺寸：

| 区域 | 尺寸 |
|---|---:|
| 主侧边栏 | 216 pt |
| 顶部工具栏 | 60 pt |
| 页面边距 | 20 pt |
| 区块间距 | 16 pt |
| 右侧详情栏 | 288–304 pt |
| 最小窗口宽度 | 1180 pt |
| 最小窗口高度 | 720 pt |

响应式规则：

- ≥1320 pt：允许三栏
- 1180–1319 pt：自动隐藏右侧详情栏
- <1180 pt：不允许继续缩小

---

## 7. 视觉方向

正式风格名称：

```text
AcWork Focus Workspace
```

中文定义：

> 克制、沉浸、内容优先的个人 AI 工作台。

视觉关键词：

- Apple 原生
- 内容优先
- 中等偏高信息密度
- 浅色冷灰体系
- 弱装饰
- 清晰状态
- 专业工具感
- 轻量沉浸

禁止：

- 风景大图
- 高饱和渐变
- 大面积毛玻璃
- 装饰性 3D 插画
- 所有内容都做成卡片
- 网页后台模板感
- 营销概念稿感
- 重阴影
- 重复标题与摘要

---

## 8. 颜色与容器

基础色建议：

```text
窗口背景       #F3F4F6
侧边栏背景     #EAECF0
主内容表面     #FFFFFF
次级表面       #F7F8FA
描边           #DDE0E6
主文字         #181A1F
次级文字       #686E78
弱文字         #979CA5
系统蓝         #0A84FF
```

SwiftUI 中优先使用系统语义色。

容器分为四类：

1. 页面分区
2. 基础卡片
3. 选中容器
4. 浮动容器

圆角：

| 组件 | 圆角 |
|---|---:|
| 主容器 | 14–16 |
| 普通卡片 | 10–12 |
| 输入框 | 9–10 |
| 按钮 | 8–10 |
| 弹窗 | 16–18 |

常规容器依赖 1 pt 描边，不使用明显阴影。

---

## 9. 页面模板

| 模板 | 页面 |
|---|---|
| 工作台型 | 工作台 |
| 对话型 | Agent |
| 主从列表型 | 收集箱、模型 |
| 时间轴型 | 日程 |
| 工具配置型 | 工具台 |
| 配置预览型 | 灵动大陆、说入法 |
| 数据监控型 | 状态 |
| 系统设置型 | 设置 |

---

## 10. 统一组件

必须先实现：

```text
AcWorkShell
AcSidebar
AcPageToolbar
AcSection
AcCard
AcListRow
AcInspector
AcStatusBadge
AcMetric
AcEmptyState
AcSearchField
AcSegmentedControl
AcActionButton
AcSettingRow
AcPermissionRow
AcTrendChart
AcProgressRow
```

页面不得自行定义第二套颜色、圆角、字号和间距体系。

---

## 11. 数据模型建议

### 收集项

```swift
struct CollectedItem: Identifiable {
    let id: UUID
    var title: String?
    var content: CollectedContent
    var contentType: CollectedContentType
    var source: CollectionSource
    var sourceApplication: String?
    var sourceDevice: String?
    var createdAt: Date
    var updatedAt: Date
    var processingStatus: ProcessingStatus
    var isPinned: Bool
    var isFavorite: Bool
    var tags: [String]
    var projectID: UUID?
}
```

```swift
enum CollectionSource {
    case clipboard
    case mobileSync
    case voiceInput
    case screenshot
    case agent
    case manual
}
```

```swift
enum ProcessingStatus {
    case pending
    case distilled
    case archived
    case exported
}
```

---

## 12. 下一阶段设计顺序

严格按以下顺序推进：

1. 统一应用外壳
2. 工作台
3. 收集箱
4. Agent
5. 日程
6. 工具台
7. 灵动大陆
8. 说入法
9. 状态
10. 模型
11. 设置

先锁定外壳、工作台和收集箱，再扩展其余页面。
