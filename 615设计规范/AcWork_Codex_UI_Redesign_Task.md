# AcWork UI 重制任务单

## 0. 任务目标

将现有 AcMind UI 重构为 **AcWork**，并按照已经确认的视觉方向完成第一阶段界面重制。

正式风格名称：

```text
AcWork Focus Workspace
```

中文定义：

> 克制、沉浸、内容优先的个人 AI 工作台。

本任务不是简单改名，也不是对现有页面做局部美化，而是需要统一：

- 产品命名
- 一级导航
- 页面职责
- 应用外壳
- 视觉 Token
- 通用组件
- 收集箱与剪贴板的数据结构
- 页面状态与响应式规则

---

# 1. 第一阶段交付范围

本轮只完成以下 3 个核心部分：

1. 统一应用外壳
2. 工作台
3. 合并后的收集箱

收集箱需要同时支持：

- 列表视图
- 网格视图
- 详情 Inspector
- 批量操作
- 剪贴板来源
- 手机同步来源
- Pin
- 收藏
- 粘贴队列

其他页面暂时只完成导航占位，不进行完整 UI 重构。

---

# 2. 品牌迁移

## 2.1 用户可见名称

所有用户可见位置统一使用：

```text
AcWork
```

需要检查并替换：

- 应用标题
- 主侧边栏品牌
- 欢迎语
- 设置页
- 关于页
- 菜单栏
- 通知标题
- Agent 自我介绍
- Mock 数据
- 空状态文案
- 调试页面标题

## 2.2 内部代码命名

新建组件和新代码统一使用 `AcWork` 前缀。

推荐迁移：

```text
AcMindApp       → AcWorkApp
AcMindAgent     → AcWorkAgent
AcMindSettings  → AcWorkSettings
```

旧代码可分阶段迁移，不要求一次性重命名全部类型。

## 2.3 数据兼容

禁止直接删除或改名旧数据目录。

必须：

- 保留旧数据读取
- 新增迁移层
- 确认迁移成功后再切换新目录
- 迁移失败时回退到旧数据

---

# 3. 一级导航

统一导航固定为：

```text
AcWork

工作
- 工作台
- Agent
- 收集箱
- 日程

处理
- 工具台

随身能力
- 灵动大陆
- 说入法

系统
- 状态
- 模型
- 设置
```

## 3.1 导航调整

必须删除：

```text
剪贴板
```

作为一级页面。

剪贴板能力合并进收集箱。

## 3.2 路由建议

```swift
enum AcWorkRoute: String, CaseIterable, Identifiable {
    case workspace
    case agent
    case inbox
    case calendar
    case toolbench
    case dynamicIsland
    case voiceInput
    case status
    case models
    case settings
}
```

---

# 4. 统一应用外壳

## 4.1 基准尺寸

```text
设计基准：1500 × 920 pt
最小窗口：1180 × 720 pt
```

## 4.2 固定布局尺寸

| 区域 | 尺寸 |
|---|---:|
| 主侧边栏 | 216 pt |
| 顶部工具栏 | 60 pt |
| 页面边距 | 20 pt |
| 区块间距 | 16 pt |
| 筛选栏 | 220 pt |
| Inspector | 304 pt |

## 4.3 应用结构

```text
RootWindow
├── AcSidebar
└── Workspace
    ├── AcPageToolbar
    └── PageBody
        ├── Optional FilterRail
        ├── MainContent
        └── Optional Inspector
```

## 4.4 响应式规则

```text
宽度 ≥ 1320
允许三栏布局

宽度 1180–1319
自动隐藏 Inspector
详情使用 Sheet 或右侧 Overlay

宽度 < 1180
禁止继续缩小
```

## 4.5 侧边栏

规格：

- 宽度 216 pt
- 品牌区高度 72 pt
- 导航项高度 38 pt
- 导航项圆角 10 pt
- 图标 16–18 pt
- 分组标题 11 pt semibold
- 选中状态使用浅蓝背景
- Hover 使用浅灰背景
- 不永久显示快捷键提示

底部显示：

```text
● 本地服务正常
Qwen 9B · 本地
```

正常状态不要使用大面积绿色。

## 4.6 顶部工具栏

左侧：

- 页面标题
- 当前项目、筛选条件或日期范围

右侧：

- 当前页面主要操作
- 全局搜索
- 快速记录
- 必要状态

规则：

- 页面标题只出现一次
- 正文禁止重复页面标题
- Toolbar 高度固定 60 pt

---

# 5. 视觉设计规范

## 5.1 风格方向

保留：

- Apple 原生感
- 内容优先
- 中等偏高信息密度
- 浅色冷灰体系
- 专业工具感
- 轻量沉浸

禁止：

- 风景大图
- 大面积毛玻璃
- 高饱和渐变
- 装饰性 3D 插画
- 重阴影
- 所有内容都做成卡片
- 网页后台模板感
- 营销页布局
- 重复标题
- 无功能大留白

## 5.2 基础颜色

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

SwiftUI 实现优先使用系统语义色。

## 5.3 圆角

| 组件 | 圆角 |
|---|---:|
| 主容器 | 16 |
| 普通卡片 | 12 |
| 输入框 | 10 |
| 按钮 | 9 |
| 弹窗 | 18 |
| 状态标签 | 胶囊 |

## 5.4 阴影

常规卡片：

- 不使用明显阴影
- 使用 1 pt 浅描边

允许使用阴影：

- Popover
- Sheet
- Context Menu
- Floating Input
- 灵动大陆
- HUD

---

# 6. 通用组件

第一阶段必须先实现以下组件：

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

## 6.1 组件要求

所有页面必须复用统一组件。

禁止：

- 每个页面单独定义颜色
- 每个页面单独定义圆角
- 每个页面单独定义字号
- 每个页面单独实现搜索框
- 每个页面单独实现 Inspector
- 每个页面单独实现卡片风格

---

# 7. 工作台页面

## 7.1 页面定位

工作台需要回答：

1. 当前正在做什么
2. 接下来应该做什么
3. 哪些内容等待处理
4. AcWork 是否正常运行

工作台不是：

- 功能入口集合
- 系统监控首页
- 营销首页
- 大图看板

## 7.2 页面结构

```text
Workspace
├── FocusHeader
├── SummaryRow
├── MainWorkArea
│   ├── RecentActivity
│   └── TodayPlan
└── SystemStatusStrip
```

## 7.3 FocusHeader

尺寸：

```text
高度 140 pt
横向满宽
```

左侧：

- 问候语
- 当前项目
- 当前重点
- 状态摘要

右侧：

- 快速记录
- 说入法
- 全局搜索

规则：

- 不使用图片背景
- 不使用渐变
- 使用极浅蓝灰背景
- 只有“快速记录”使用主要按钮

## 7.4 核心摘要

必须包含 4 个模块：

### Agent 当前任务

- 任务名称
- 当前步骤
- 进度
- 打开任务

### 下一日程

- 时间
- 事件名
- 距离开始时间
- 打开日程

### 待整理内容

- 待整理数量
- 来源分布
- 打开收集箱

### 最近剪贴板与 Pin

- 最近 3 条内容
- Pin 数量
- 打开收集箱剪贴板筛选

要求：

- 4 个模块不能做成完全相同的数字卡片
- 1500 宽度下 4 列
- 窄宽度下自动变为 2 × 2

## 7.5 主要工作区

布局：

```text
左侧 RecentActivity：1fr
右侧 TodayPlan：320 pt
```

RecentActivity：

- Agent 结果
- 收集箱处理
- 日程变更
- 工具执行
- 最多 6 条
- 行高 56–64 pt

TodayPlan：

- 今日事件
- 今日待办
- 快速操作
- 不使用卡片套卡片

## 7.6 系统状态条

固定在页面底部：

```text
CPU 23% · 内存 38% · 网络 ↑12 KB/s · 电池 82% · 温度 45°C
```

规格：

- 高度 44 pt
- 正常状态使用中性色
- 只有异常项显示语义色
- 点击进入状态页

---

# 8. 收集箱页面

## 8.1 页面定位

收集箱统一承载：

- 剪贴板
- 手机同步
- 说入法
- 截图与 OCR
- Agent
- 手动添加
- 后续浏览器扩展
- 后续文件夹监听

## 8.2 三栏结构

```text
FilterRail 220
ContentArea 1fr
Inspector 304
```

## 8.3 左侧筛选

### 快捷视图

- 全部内容
- 待整理
- 已 Pin
- 已收藏
- 最近使用

### 来源

- 剪贴板
- 手机同步
- 说入法
- 截图与 OCR
- Agent
- 手动添加

### 类型

- 文本
- 链接
- 图片
- 文件
- 代码
- 富文本
- 视频

### 状态

- 待整理
- 已提炼
- 已归档
- 已导出

要求：

- 支持组合筛选
- 支持数量
- 当前筛选显示为 Filter Chips
- 筛选项高度 34 pt

## 8.4 中间内容区

顶部操作：

- 当前筛选摘要
- 搜索
- 排序
- 列表 / 网格切换
- 批量选择
- 添加内容

## 8.5 列表视图

每行包含：

- 类型图标
- 标题
- 两行预览
- 来源应用或设备
- 创建时间
- 状态
- 标签
- Pin
- 收藏
- 更多

规格：

```text
标准行高 84 pt
紧凑行高 64 pt
```

状态：

- Hover
- Selected
- Disabled
- Loading

## 8.6 网格视图

卡片尺寸：

```text
宽度 240–300 pt
高度 168–196 pt
```

内容类型：

- 图片：图片预览
- 链接：站点图标 + 标题 + 摘要
- 代码：等宽字体 + 语言
- 文件：文件图标 + 名称 + 大小
- 文本：最多 5 行

卡片规则：

- 内容本体优先
- 不显示重复的大标题
- 底部固定显示来源、时间和操作

## 8.7 Inspector

无选中项：

- 总数量
- 待整理数量
- Pin 数量
- 手机同步状态
- 粘贴队列数量

有选中项：

- 完整内容
- 来源
- 来源应用 / 设备
- 创建时间
- 类型
- 标签
- 关联项目

AI 操作：

- 自动标题
- 摘要
- 提取待办
- 提取日程
- 润色
- 发送给 Agent

内容去向：

- 转任务
- 添加到日程
- 保存到知识库
- 导出 Markdown
- 归档
- 删除

底部主要操作固定。

## 8.8 剪贴板专项能力

当来源筛选为“剪贴板”时：

- 显示监听状态
- 支持暂停监听
- 显示来源应用
- 支持复制
- 支持加入粘贴队列

## 8.9 Pin

Pin 是所有收集项的通用能力。

支持：

- 显示全部
- 隐藏全部
- 关闭全部
- 调整顺序

## 8.10 粘贴队列

仅在队列不为空时显示。

支持：

- 拖动排序
- 单项移除
- 清空
- 开始连续粘贴

## 8.11 批量操作

- 添加标签
- 发送给 Agent
- 转任务
- 转日程
- 归档
- 导出
- 删除

---

# 9. 数据模型重构

禁止继续维护：

```text
InboxItem
ClipboardItem
PinItem
```

三套重复模型。

统一为：

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

## 9.1 Repository

建议：

```swift
protocol CollectedItemRepository {
    func fetchItems(filter: CollectionFilter) async throws -> [CollectedItem]
    func update(_ item: CollectedItem) async throws
    func delete(ids: [UUID]) async throws
    func addToPasteQueue(ids: [UUID]) async throws
}
```

View 中禁止写死业务数据。

未完成接口使用：

```text
MockCollectedItemRepository
```

---

# 10. 页面状态

工作台和收集箱必须覆盖：

- Loading
- Empty
- Error
- Disabled
- Hover
- Selected
- Keyboard Focus
- Permission Required
- Sync Offline

## 10.1 Empty State

必须包含：

- 标题
- 一句说明
- 一个主要操作
- 可选一个次级操作

禁止放大型装饰插画。

## 10.2 Error State

必须包含：

- 错误原因
- 重试
- 查看详情
- 不丢失当前筛选条件

---

# 11. 实施顺序

## Phase 1：基础层

1. 建立 Design Tokens
2. 实现 AcWorkShell
3. 实现 AcSidebar
4. 实现 AcPageToolbar
5. 实现 Inspector 响应式
6. 实现统一卡片、列表和按钮

## Phase 2：品牌和导航

1. 用户可见名称改为 AcWork
2. 更新一级导航
3. 删除剪贴板一级入口
4. 保留旧路由兼容
5. 更新窗口标题和菜单

## Phase 3：工作台

1. FocusHeader
2. SummaryRow
3. RecentActivity
4. TodayPlan
5. SystemStatusStrip
6. 接入 ViewModel
7. 完成所有状态

## Phase 4：收集箱数据层

1. 定义 CollectedItem
2. 合并 Inbox / Clipboard / Pin
3. 建立 Repository
4. 建立筛选模型
5. 建立粘贴队列模型
6. 完成旧数据迁移

## Phase 5：收集箱 UI

1. FilterRail
2. Toolbar
3. List View
4. Grid View
5. Inspector
6. 批量操作
7. Pin 管理
8. 粘贴队列
9. 手机同步状态

## Phase 6：回归

1. 1500 × 920
2. 1320 宽度临界值
3. 1180 × 720
4. 键盘导航
5. VoiceOver
6. 深色模式兼容检查
7. 性能和滚动测试

---

# 12. 必须输出的截图

Codex 完成后必须输出：

## 工作台

- 1500 × 920 正常状态
- 1180 × 720 正常状态
- Empty
- Loading
- Error

## 收集箱

- 1500 × 920 列表视图
- 1500 × 920 网格视图
- 1180 × 720 列表视图
- Inspector 有选中项
- Inspector 无选中项
- 批量选择
- 剪贴板筛选
- 手机同步离线
- 粘贴队列展开
- Empty
- Loading
- Error

---

# 13. 验收标准

## 应用外壳

- Sidebar 宽度固定
- Toolbar 高度固定
- 页面标题只出现一次
- 1180 × 720 无裁切
- Inspector 响应式正确

## 工作台

- 首屏无需滚动
- 四层结构完整
- 系统状态不是核心模块
- 无大面积背景图
- 四个摘要模块结构不完全相同

## 收集箱

- 剪贴板不再是一级页面
- 所有来源使用同一数据模型
- 列表和网格都可用
- 组合筛选可用
- 批量操作可用
- Pin 可用于所有来源
- 粘贴队列可用
- 手机同步状态可用

## 工程质量

- SwiftUI 原生
- 无 WebView
- 无 HTML UI
- 无重复 Token
- 无大量写死数据
- ViewModel 与 Repository 分离
- 组件具备可复用性
- 支持键盘和辅助功能

---

# 14. 禁止事项

Codex 不得：

- 擅自新增一级页面
- 恢复剪贴板一级入口
- 使用大面积渐变
- 使用风景图
- 使用重阴影
- 把所有内容都做成卡片
- 使用网页后台模板
- 使用 WebView
- 在 View 中写死业务数据
- 为单个页面建立独立设计体系
- 重复页面标题
- 删除旧数据而不迁移
- 为了适配窄宽度直接缩放整个界面

---

# 15. 参考文件

本任务应同时参考：

```text
AcWork_UI_Architecture_v1
AcWork_Phase1_Core_Screens_v1
最新确认的 AcWork 设计参考图
```

实现时以本任务单为最高优先级。
