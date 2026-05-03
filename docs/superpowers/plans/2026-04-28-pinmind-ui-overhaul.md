# PinMind 全应用 UI 重构实施计划

日期：2026-04-28  
范围：基于设计稿，对 PinMind 做一次全应用、分阶段、可验证的 UI 重构

## 0. 目标

把 PinMind 从“功能可用但视觉分散”的状态，推进到“统一、克制、Apple-ish、产品级可用”的桌面应用体验。

本次重构不是单页微调，而是一次“壳层 + token + 主工作台 + 六大页面”级别的统一改造。

## 1. 设计目标摘要

- 统一全局视觉 token：暖白底、轻玻璃、低噪声、橙色只用于主操作/选中态
- 统一字体层级：列表标题、表头、状态、来源都要明显轻于当前版本
- 统一 shell 结构：Sidebar + TopBar + Main Workspace + Right Inspector + Bottom Runtime Bar
- 修复今日工作台的功能链路：selected item 必须和 detail panel 绑定
- 统一六大页面的布局语言和响应式断点
- 保留真实功能，去掉“像能点、其实没闭环”的视觉错觉

## 2. 当前已确认的关键问题

### 2.1 今日工作台

- `selectedRecordId` 与详情面板存在联动缺口
- `compact` 断点未被工作台完整处理
- 筛选/删除后，选中项可能指向不存在的记录
- 列表字体偏重，行高偏大，视觉接近后台表格

### 2.2 全局壳层

- `AppShell` 已有三栏结构，但 token、间距、宽度还不贴近设计稿
- `Sidebar`、`TopBar`、`BottomRuntimeBar` 的视觉层级未统一

### 2.3 全局样式

- `src/renderer/styles.css` 已有变量，但字体栈、颜色、阴影、圆角仍需整体收口
- 当前 token 体系没有完整映射到设计稿规范

### 2.4 页面层

- 收集箱、二级整理页、快速捕获小窗口、设置页、AI 控制台、输出中心需要统一到同一套产品语言

## 3. 执行策略

采用“先全局，后页面；先功能链路，后视觉微调”的顺序。

推荐采用三条并行线：

1. 全局 token / shell / 响应式
2. 今日工作台功能链路 + 详情绑定
3. 六大页面的局部适配与统一组件化

如果需要加速，建议用子任务并行，但每条线的写入文件要严格隔离。

## 4. 分阶段实施计划

### Phase 1：建立全局视觉底座

目标：
- 把字体、颜色、圆角、阴影、间距、面板玻璃感统一到设计稿

涉及文件：
- `src/renderer/styles.css`
- `src/renderer/main.tsx` 或全局样式入口（如有）
- `src/renderer/components/layout/AppShell.tsx` 的基础 class 约定

要做的事：
- 替换字体栈为设计稿要求的 Apple-ish stack
- 增补/收敛 CSS variables
- 统一 `--app-bg`、`--main-bg`、`--panel-bg`、`--card-bg`、`--primary` 等 token
- 统一圆角和阴影命名
- 让按钮、badge、card、table header、empty state 使用同一套 token

验收：
- 全局页面基础视觉不再是“普通后台风”
- 主按钮、卡片、表头、徽章的层级关系一致

### Phase 2：修复今日工作台的状态链路

目标：
- 列表选中项与详情面板严格绑定
- 删除、筛选、首次进入都能正确兜底

涉及文件：
- `src/renderer/pages/dashboard/DashboardPage.tsx`
- `src/renderer/hooks/useLayoutMode.ts`
- `src/renderer/components/layout/RightInspector.tsx`（如果继续沿用右侧面板）

要做的事：
- 列表点击后设置 `selectedRecordId`
- `selectedRecord` 从可见列表中推导，避免筛选后悬空
- 删除当前项后自动选下一条可见记录
- 首次进入时默认选中第一条可见记录
- 在 `compact` / `small` 断点下，让详情以 drawer / modal 形式出现

验收：
- 点击任意列表项，右侧详情内容与列表行完全一致
- 选中项消失后不会出现空指针或错误详情
- 列表有数据时，不会显示错误空态

### Phase 3：重做今日工作台的列表区

目标：
- 从“表格”变成“内容处理队列”
- 列表主标题不再显示完整路径

涉及文件：
- `src/renderer/pages/dashboard/DashboardPage.tsx`
- 可能拆出：
  - `src/renderer/components/dashboard/DashboardQueueRow.tsx`
  - `src/renderer/components/dashboard/DashboardQueueHeader.tsx`

要做的事：
- 依据标题优先级生成语义标题
- 内容列增加摘要和最多 3 个标签
- 来源 / 状态 / 时间用更轻的字号与颜色
- 降低行高和标题字重
- 选中态改为橙色浅背景 + 左侧竖线
- 宽屏下保留 4 列，窄屏下折叠到 2 列或隐藏弱信息列

验收：
- 列表主标题稳定为 14px / 600 左右
- 完整路径不再出现在主标题位置
- 选中态、hover 态、状态 badge 一眼可分辨

### Phase 4：重做详情面板

目标：
- 详情面板成为选中内容的操作中心
- 空状态只在没有选中项时出现

涉及文件：
- `src/renderer/pages/dashboard/DashboardPage.tsx`
- `src/renderer/components/layout/RightInspector.tsx`
- 如有需要，拆出：
  - `src/renderer/components/dashboard/DashboardDetailPanel.tsx`
  - `src/renderer/components/dashboard/DashboardDetailTabs.tsx`

要做的事：
- 详情标题、来源、状态、时间、摘要、路径与选中项同步
- 详情区增加 tabs：详情 / AI 处理结果 / 元数据 / 日志
- 详情卡片使用统一的 glass card 视觉
- 右侧面板宽度收敛到设计稿范围

验收：
- 有选中项时，不显示“选择一条内容查看详情”
- 右侧内容随左侧选中行同步变化
- 小窗口下详情可折叠或抽屉化，不遮挡主内容

### Phase 5：统一全局 chrome

目标：
- Sidebar、TopBar、BottomRuntimeBar 都回到设计稿的克制风格

涉及文件：
- `src/renderer/components/layout/Sidebar.tsx`
- `src/renderer/components/layout/TopBar.tsx`
- `src/renderer/components/layout/BottomRuntimeBar.tsx`
- `src/renderer/components/layout/AppShell.tsx`

要做的事：
- 统一左侧导航的字号、图标、分组间距
- 顶栏只保留必要的操作与状态，不再显得“后台管理”
- 底栏固定 44px，避免遮挡内容
- 统一三栏宽度和拖拽/滚动规则

验收：
- 视觉上像同一个产品系统，不像拼接出来的多个页面
- 底栏不会溢出或遮挡主内容

### Phase 6：六大页面统一风格

目标：
- 六大主页面共享同一套视觉语言，但保留各自的业务结构

涉及文件：
- `src/renderer/pages/capture-inbox/**/*`
- `src/renderer/pages/edit/**/*`
- `src/renderer/pages/settings/**/*`
- `src/renderer/pages/ai-console/**/*`
- `src/renderer/pages/export/**/*`
- `src/renderer/pages/capsule/**/*`（或对应快速捕获页面目录）

要做的事：
- 收集箱页：队列 + 详情联动，保留真实功能
- 二级整理页：三栏内容组织，视觉层级更克制
- 快速捕获小窗口：做成小胶囊式浮窗语言
- 设置页：左分类右卡片，卡片式设置组
- AI 控制台：统计卡、模型卡、任务表、右侧摘要卡统一
- 输出中心：表格 + 右侧详情 + 失败状态统一

验收：
- 六大页面都符合 warm focus 的整体语言
- 主操作按钮统一且单一

### Phase 7：响应式与窗口策略

目标：
- 大、中、小窗口都不裁切，不溢出，不失焦

涉及文件：
- `src/renderer/hooks/useLayoutMode.ts`
- `src/renderer/components/layout/AppShell.tsx`
- `src/renderer/pages/dashboard/DashboardPage.tsx`

要做的事：
- 明确 large / medium / compact / small 的职责
- `medium` 下详情可折叠
- `small` 下统计卡折叠为 2 列或自动换行
- 列表窄屏隐藏弱信息列，把来源/时间降级到摘要下

验收：
- 1280px 以上三栏稳定
- 960-1279px 下不挤压主内容
- 960px 以下不出现裁切和空白浪费

## 5. 文档更新要求

每完成一个阶段，需要同步更新：

- `WORKLOG.md`
- `CHANGELOG.md`
- `PinMind/交接文档.md`

说明：

- `docs/PROJECT_HANDOVER.md` 当前在仓库中不存在
- 如果需要一个英文路径的统一交接文档，可以后续再补，但本轮先以现有 `PinMind/交接文档.md` 为准

## 6. 主要验收标准

### 功能验收

- 点击列表项，详情面板正确同步
- 删除 / 筛选后，selected item 不会悬空
- 有数据时详情面板不会显示错误空态
- 完整路径不再作为列表主标题

### 视觉验收

- 列表标题降到 14px 左右
- 表头 / 来源 / 时间 / 状态不抢主标题层级
- 整体更像成熟桌面应用，不像后台表格
- 橙色只用于主操作、选中态、强调

### 布局验收

- 大屏三栏稳定
- 中屏详情可折叠
- 小屏不裁切、不溢出
- Sidebar / 列表 / 详情都支持独立滚动

## 7. 推荐实施顺序

1. 先改 `styles.css` 和 shell token
2. 再修 `DashboardPage.tsx` 的选中态与详情联动
3. 再重做列表行和详情面板
4. 再统一 `Sidebar` / `TopBar` / `BottomRuntimeBar`
5. 再批量收敛六大页面的视觉语言
6. 最后做响应式修补和文档同步

## 8. 风险点

- 如果先改页面细节、后改全局 token，会产生重复返工
- 如果先做视觉，不先修 selected item 绑定，会出现“看起来更漂亮但还是错链路”
- 如果六大页面不共享 token，最终会变成“每页都差不多，但并不统一”

