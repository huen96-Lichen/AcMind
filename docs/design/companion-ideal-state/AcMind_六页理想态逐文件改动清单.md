# AcMind 六页理想态逐文件改动清单

> 这是从实施任务单再压缩出来的工程版清单。  
> 目标是让 coding agent 可以直接按文件推进，不用再自行解释设计意图。
> 
> 所有展开态页面和所有导出参考图都以 880 × 300 作为最终容器，不允许再使用别的主画幅作为实现目标。

## 使用方式

按“壳层 → 共享组件 → 页面”顺序执行。  
如果某一步需要改动超出本文件列出的范围，先停下来回看上层规范，不要擅自扩展。

## 0. 先改共享壳层和全局 token

### 架构边界说明

- 折叠态是菜单栏上的最小状态条。
- 展开态是 880 × 300 的主面板。
- 这份清单里的尺寸、三列宽度和卡片尺寸，都是展开态主面板的目标。
- 如果某个页面同时有 `NotchV2*Page` 和 `DynamicContinent*Page`，优先把 `DynamicContinent*Page` 作为展开态对齐基线，`NotchV2*Page` 作为兼容实现或共享子视图承载。

### 0.1 `Features/Companion/NotchV2DesignTokens.swift`

目标：把视觉语义收敛到统一的暗色工具壳层。

要做的事：

- 保持 `rootBackground`、`panelBackground`、`innerCardBackground` 的暗色语义一致。
- 降低主容器边框与内层边框的存在感，避免“边框太像装饰”。
- 保持 `cardRadius`、`rightCardRadius`、`largeRadius` 的层级稳定。
- 不新增一组新的品牌色或新的背景体系。

验收：

- 顶层背景与所有页面的卡片背景互相兼容。
- 同一层级卡片不会出现明显不同的边框语气。

### 0.2 `Features/Companion/CompanionSharedLayout.swift`

目标：统一页面共用的面板、标题和卡片壳。

要做的事：

- 锁定 `CompanionLayoutTokens` 的核心尺寸，不要让不同页面各自漂移。
- 统一 `CompanionPanel` 和 `CompanionCard` 的背景、边框、阴影语气。
- 保持 `CompanionPanelHeader` 和 `CompanionSectionHeader` 的标题层级一致。
- 不给不同页面单独发明新的 panel 语法。

重点检查：

- `panelCornerRadius`
- `panelBorderWidth`
- `cardCornerRadius`
- `panelSpacing`
- `cardSpacing`
- `pageHorizontalPadding`
- `pageVerticalPadding`

验收：

- 所有页面里的主卡、次卡、行卡看起来像同一套组件家族。

### 0.3 `Features/Companion/NotchV2Card.swift`

目标：统一主卡和状态 pill 的外观。

要做的事：

- 统一 `NotchV2Card` 的背景填充与边框透明度。
- 降低 card shadow 的重量。
- 保持 `NotchV2Glyph` 的尺寸语义稳定。
- 不要让 card style 分支变成四套不同语法。
- 保留 `NotchV2CardStyle.music(Color)` 的关联值签名，不要为了统一而强行改成无参 case。

重点检查：

- `NotchV2CardStyle.default`
- `NotchV2CardStyle.music`
- `NotchV2CardStyle.agent`
- `NotchV2CardStyle.timeline`

验收：

- card 在不同页面里只表现为“内容不同”，不会表现为“控件系统不同”。

### 0.4 `Features/Companion/DynamicContinent/DynamicContinentTemplateV2.swift`

目标：固定整套 companion 的外壳节奏。

要做的事：

- 保持外层容器宽高和圆角一致。
- 统一 top bar、内容区、底部状态条的位置关系。
- 保持可折叠状态下的壳层不变形。
- 不要在这里引入新的页面级布局分支。
- 把展开态主面板的尺寸语义和最小状态条入口分开。

重点检查：

- `expandedWidth`
- `expandedOverviewHeight`
- `topBarHeight`
- `pageHorizontalPadding`
- `pageBottomPadding`
- `columnGap`
- `rowGap`
- `containerCornerRadius`

验收：

- 六个页面切换时，壳层没有跳变感。

### 0.5 `Features/Companion/NotchV2TopBar.swift`

目标：固定顶栏导航和状态区的视觉语气。

要做的事：

- 保持左侧页签和右侧状态胶囊的高度统一。
- 降低分隔线存在感。
- 保持选中态只作用于当前页，不要扩散。
- 不新增新的顶栏操作入口。

验收：

- 顶栏在六个页面之间完全一致。

### 0.6 `Features/Companion/NotchV2StatusStrip.swift`

目标：统一底部状态条的密度和卡片语义。

要做的事：

- 保持 `displayItems` 的最大展示数量上限。
- 让高亮态和普通态只在颜色和轻微层级上有差异。
- 不要把底栏变成第二个功能区。

验收：

- 底栏是状态信息，不是操作中心。

---

## 1. 本机页相关文件

### 1.1 `Features/Companion/NotchV2OverviewPage.swift`

目标：把首页收敛成“当前任务 + 快捷动作 + 系统快览”。

要做的事：

- 保留当前任务卡作为左侧主焦点。
- 保留快捷动作作为中间主焦点。
- 保留系统快览作为右侧主焦点。
- 删除或弱化任何重复解释句。
- 不恢复被删掉的多余按钮组。

关键检查：

- 当前任务是否仍然是一眼可见的 hero。
- 快捷动作是否控制在高频操作内。
- 系统快览是否只保留最关键状态。

验收：

- 首页不再像多功能控制面板，而是像总览仪表盘。

### 1.2 `Features/Companion/DynamicContinent/DynamicContinentPages.swift`

目标：保持本机页的页面组合和系统状态页的结构收敛。

要做的事：

- `DynamicContinentTodayPage` 作为展开态本机页的对齐基线，`NotchV2OverviewPage` 作为兼容版本同步更新。
- `DynamicContinentSystemStatusPage` 保持“先结论、后细项”。
- 系统状态页的中心指标区最多展示 4 到 6 个核心指标。
- 不增加新的状态来源。
- `Schedule` 页不在六页主图里单独重做，但必须继承同一套壳层 token。

关键检查：

- 运行摘要是否还在左列。
- 核心摘要是否还在中列第一屏。
- 本机状态和权限状态是否仍在右列。

验收：

- 本机页与系统状态页的视觉语言一致，不会互相打架。

---

## 2. 启动器页相关文件

### 2.1 `Features/Companion/NotchV2LauncherPage.swift`

目标：把启动器页固定成“先搜，再点”的工具界面。

要做的事：

- 保持搜索框在视觉中心偏上。
- 保持常用应用区优先于全部应用区。
- 保持所有应用区作为结果列表，不要再扩成第二个主区。
- 删除与搜索无关的冗余控制。
- 保留自动聚焦和清空搜索行为。

重点检查：

- `toolbarRow`
- `searchField`
- `favoriteSection`
- `allAppsSection`
- `moreMenu`

验收：

- 启动器页看起来像高效搜索工具，不像 App Store 或分类目录。

---

## 3. 音乐页相关文件

### 3.1 `Features/Companion/NotchV2MusicPage.swift`

目标：把音乐页固定成安静的播放器控制台。

要做的事：

- 保留左列队列 / 来源上下文。
- 保留中列正在播放与空态。
- 保留右列播放控制与状态。
- 去掉多余解释句和重复说明。
- 保持空态和播放态都足够完整。

重点检查：

- 左列是否仍然承担上下文职责。
- 中列是否仍然是主内容区。
- 右列控制是否没有抢走中列注意力。

验收：

- 没有播放内容时，页面仍然安静且完整。

---

## 4. AI 页相关文件

### 4.1 `Features/Companion/NotchV2AgentPage.swift`

目标：把 AI 页固定成对话工作台。

要做的事：

- 保留对话历史。
- 保留对话主体与输入区。
- 保留少量快速提问。
- 收窄状态卡和次级操作。
- 不把右侧做成第二个主视觉。

重点检查：

- 左列是不是历史。
- 中列是不是对话和输入。
- 右列是不是轻状态确认。

验收：

- 用户一眼知道这是一个“马上开始干活”的页面。

---

## 5. 系统状态页相关文件

### 5.1 `Features/Companion/DynamicContinent/DynamicContinentPages.swift`

目标：把系统状态页固定成监控面板。

要做的事：

- 左列保留运行摘要。
- 中列先放健康结论，再放关键指标。
- 右列保留本机状态和权限状态。
- 收紧 metric tile 数量，不要为了热闹继续加块。
- 页面必须和 `Features/Companion/NotchV2SystemStatusRail.swift` 的状态语义保持一致。

重点检查：

- 健康结论是否先于数值出现。
- 关键指标是否保持简短。
- 权限状态是否还是辅助信息。

验收：

- 页面像系统健康总览，不像详细性能报表。

---

## 6. 设置页相关文件

### 6.1 `Features/Companion/NotchV2SettingsPage.swift`

目标：把设置页固定成专业配置台。

要做的事：

- 保留展开与行为。
- 保留页面布局。
- 保留子模块管理。
- 收紧每行辅助说明。
- 保持 toggle、slider、menu 的控件语气一致。
- 不要让模块行看起来像另一套组件系统。

重点检查：

- `behaviorCard`
- `layoutCard`
- `moduleCard`
- `moduleRow`
- `runtimeContentSection`

验收：

- 设置页仍然密，但更整齐，更像系统偏好面板。

---

## 7. 建议提交顺序

按下面顺序做 commit 或阶段性提交：

1. `NotchV2DesignTokens.swift`
2. `CompanionSharedLayout.swift`
3. `NotchV2Card.swift`
4. `DynamicContinentTemplateV2.swift`
5. `NotchV2TopBar.swift`
6. `NotchV2StatusStrip.swift`
7. `NotchV2OverviewPage.swift`
8. `NotchV2LauncherPage.swift`
9. `NotchV2MusicPage.swift`
10. `NotchV2AgentPage.swift`
11. `DynamicContinentPages.swift`
12. `NotchV2SettingsPage.swift`

如果必须压缩成更少批次，建议按：

- 批次 1：共享壳层
- 批次 2：本机页 + 状态页
- 批次 3：启动器页 + 音乐页
- 批次 4：AI 页 + 设置页

---

## 8. 代码级验收条件

每一批改完后，至少要满足下面两个条件：

- `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' build` 通过
- 视觉上没有出现新的容器语法分叉

最终验收必须满足：

- 六个页面共享同一套壳层
- 顶栏和底栏一致
- 主卡与次卡层级统一
- 不需要滚动就能看到页面结论
- 参考图和实现结果没有明显冲突

---

## 9. 如果执行者卡住，先回看的东西

优先回看这三个文件：

1. `docs/design/companion-ideal-state/AcMind_六页理想态设计稿.md`
2. `docs/design/companion-ideal-state/AcMind_六页理想态实施任务单.md`
3. `docs/design/companion-ideal-state/assets/*.png`

如果实现和设计冲突，先修实现，不要先改设计。
