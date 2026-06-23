# AcMind Bento 视觉统一任务单

目标：

- 先统一整体视觉
- 再把适合的页面做完整 Bento 化
- 其余页面做局部 Bento 化
- 让整个项目更精致、更像一套完整产品

---

## P0 视觉统一底座

1. 统一全局视觉令牌，作为整个应用的唯一基础样式来源。  
   目标文件：[Features/Native/Shared/AppSurfaceStyle.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift)

2. 把页面里零散使用的圆角、阴影、边框、分隔线、间距收敛到统一 token。  
   目标结果：所有卡片、按钮、列表、面板都用同一套半径、阴影和边距规则。

3. 清理全局字体层级，统一标题、副标题、卡片标题、正文、注释的字号和字重。  
   目标结果：不要同一屏里出现太多“看起来像标题”的文字。

4. 统一颜色语义，明确区分：
   - 主内容色
   - 次级文本色
   - 说明文本色
   - 背景层级色
   - 强调色
   - 状态色  
   目标结果：不再到处直接写系统颜色或临时灰色值。

5. 统一卡片外观规则，明确所有卡片都遵守：
   - 统一内边距
   - 统一圆角
   - 统一边框透明度
   - 统一轻阴影或无阴影策略  
   目标结果：不同页面的卡片看起来像同一个系统。

6. 统一按钮和小控件风格。  
   目标文件：[Components/ShortcutRecorderView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Components/ShortcutRecorderView.swift)  
   目标结果：按钮、切换、标签、快捷键输入控件都不要各长各的。

---

## P1 完整 Bento 化页面

7. 把工作台首页作为第一主战场，做成完整 Bento 概览页。  
   目标文件：[Features/Native/Home/WorkspaceHomeView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Home/WorkspaceHomeView.swift)  
   要做的事：
   - 把当前内容拆成“主卡 + 侧卡 + 辅助卡”
   - 强化焦点区、趋势区、快捷操作区、摘要区
   - 让用户一眼看到“今天最重要的事”

8. 把 Workbench V2 做成第二个完整 Bento 样板页。  
   目标文件：[Features/Native/HomeV2/WorkbenchV2View.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/WorkbenchV2View.swift)  
   要做的事：
   - 保留它现在的结构优势
   - 进一步强化卡片尺寸层级
   - 让 hero 卡、趋势卡、快捷卡、状态卡形成真正的 Bento 网格

9. 把 Agent Dashboard 做成完整的“对话 + 任务 + 状态”工作台。  
   目标文件：[Features/Native/Agent/AgentDashboardView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Agent/AgentDashboardView.swift)  
   要做的事：
   - 让对话区和右侧任务区层次更明显
   - 对话记录、模型选择、任务面板做成不同权重的卡片
   - 把“运行状态”和“输入区”做得更轻、更统一

10. 把系统状态页做成完整的 Bento 仪表盘。  
    目标文件：[Features/Native/SystemStatus/SystemStatusView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/SystemStatus/SystemStatusView.swift)  
    要做的事：
    - 把 CPU、内存、电池、风扇、网络等拆成模块卡
    - 强化趋势图、环形图、关键数值卡
    - 做成“一屏扫完系统健康状况”的布局

---

## P1 局部 Bento 化页面

11. 把设置页改成“Bento 概览 + 线性设置内容”的混合布局。  
    目标文件：[Features/Native/Settings/SettingsView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Settings/SettingsView.swift)  
    要做的事：
    - 左侧分类继续保持清晰导航
    - 右侧内容顶部做摘要卡
    - 统计、插件、状态、搜索结果用 Bento 卡片
    - 表单区保持线性，不要强拆

12. 把收集箱做成“摘要卡 + 列表区”的混合布局。  
    目标文件：[Features/Native/Inbox/InboxView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Inbox/InboxView.swift)  
    要做的事：
    - 顶部做收集状态、待处理数量、最近项摘要
    - 主体列表保持高效浏览
    - 让卡片只负责概览，不打断浏览节奏

13. 把日程页改成“概览卡 + 传统日历”的混合布局。  
    目标文件：[Features/Native/Schedule/ScheduleDashboardView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Schedule/ScheduleDashboardView.swift)  
    要做的事：
    - 顶部放今日摘要、待办、冲突提醒、时间块概览
    - 月/周/年视图保持原生可读性
    - 不要把日历主体硬塞成卡片拼贴

14. 把工具台改成“功能入口矩阵 + 具体功能区”的局部 Bento。  
    目标文件：[Features/Native/Tools/ToolsView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Tools/ToolsView.swift)  
    要做的事：
    - 把工具入口做成清晰卡片网格
    - 把高频工具做大，低频工具做小
    - 保留工具详情页的线性结构

15. 把灵动大陆配置页改成“概览 + 配置”的分区式 Bento。  
    目标文件：[Features/Native/DynamicContinent/DynamicContinentConfigView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/DynamicContinent/DynamicContinentConfigView.swift)  
    要做的事：
    - 顶部总结当前状态
    - 中间展示关键开关和当前配置
    - 底部继续保留详细设置表单

16. 把语音入口页改成“状态卡 + 操作卡”的局部 Bento。  
    目标文件：[Features/Native/VoiceEntry/VoiceEntryView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/VoiceEntry/VoiceEntryView.swift)  
    要做的事：
    - 识别状态、输入状态、快捷操作分区展示
    - 波形、录音、转写、语言状态都做成统一卡片
    - 减少过多堆叠式布局

---

## P2 面板和浮层统一

17. 统一所有浮层和面板的卡片语言。  
    目标文件：
    - [Features/Companion/CompanionVoicePanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/CompanionVoicePanel.swift)
    - [Features/Companion/CompanionCapturePanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/CompanionCapturePanel.swift)
    - [Features/Companion/QuickNotePanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/QuickNotePanel.swift)
    - [Features/Companion/ScreenshotPreviewWindow.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/ScreenshotPreviewWindow.swift)  
    要做的事：
    - 统一毛玻璃、圆角、标题层、分割线
    - 统一按钮和状态标签
    - 让这些窗口看起来来自同一个设计系统

18. 统一 Notch / Capsule / Companion 相关界面的视觉节奏。  
    目标文件：
    - [Features/Companion/NotchV2RootView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/NotchV2RootView.swift)
    - [Features/Companion/NotchV2OverviewPage.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/NotchV2OverviewPage.swift)
    - [Features/Companion/NotchV2AgentPage.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/NotchV2AgentPage.swift)
    - [Features/Companion/NotchV2SystemStatusRail.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/NotchV2SystemStatusRail.swift)  
    要做的事：
    - 统一卡片半径和底板层
    - 统一状态条、标签、信息密度
    - 保持“小面积高信息量”的设计方向

19. 统一所有预览窗口和弹出层的容器风格。  
    目标文件：
    - [Features/Native/Capsule/CapsulePanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Capsule/CapsulePanel.swift)
    - [Features/Native/DesktopCapsule/DesktopCapsulePanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/DesktopCapsule/DesktopCapsulePanel.swift)
    - [Features/Companion/SystemEventHUD.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/SystemEventHUD.swift)  
    要做的事：
    - 保持统一边距、统一浮层边界、统一按钮形态
    - 让所有“临时出现的 UI”也像一个系统，而不是临时拼出来的

---

## P2 列表和编辑器的轻量统一

20. 把长列表页面做成“统一卡片列表”，不要硬 Bento 化。  
    目标文件：
    - [Features/Native/Clipboard/ClipboardView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Clipboard/ClipboardView.swift)
    - [Features/Native/Inbox/InboxView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Inbox/InboxView.swift)
    - [Features/Native/Schedule/WeekCalendarView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Schedule/WeekCalendarView.swift)
    - [Features/Native/Schedule/MonthCalendarView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Schedule/MonthCalendarView.swift)
    - [Features/Native/Schedule/YearCalendarView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Schedule/YearCalendarView.swift)  
    要做的事：
    - 统一卡片边框、行高、分隔线、hover 状态
    - 保持浏览效率
    - 不把列表拆碎

21. 把编辑器保持原生线性，但统一“编辑区外壳”。  
    目标文件：[Features/Native/Schedule/EventEditorView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Schedule/EventEditorView.swift)  
    要做的事：
    - 保持表单逻辑清晰
    - 统一输入框、分组标题、辅助说明
    - 让编辑器视觉和卡片系统一致，但不强改布局

---

## P2 统一图表和数据展示

22. 统一所有小图表、环图、趋势图的风格。  
    目标文件：
    - [Features/Native/Home/WorkspaceHomeView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Home/WorkspaceHomeView.swift)
    - [Features/Native/HomeV2/Components/ActivityTrendCard.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/Components/ActivityTrendCard.swift)
    - [Features/Native/HomeV2/Components/TodayStatusPanel.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/Components/TodayStatusPanel.swift)
    - [Features/Companion/Components/SystemStatusComponents.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Companion/Components/SystemStatusComponents.swift)  
    要做的事：
    - 统一曲线粗细、填充透明度、轴线、网格线
    - 统一环图颜色逻辑
    - 统一数值字号和单位显示

23. 统一所有 metric 卡、统计卡、状态卡。  
    目标文件：
    - [Features/Native/Shared/AppSurfaceStyle.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift)
    - [Features/Native/HomeV2/Components/CurrentFocusCard.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/Components/CurrentFocusCard.swift)
    - [Features/Native/HomeV2/Components/PendingItemsCard.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/Components/PendingItemsCard.swift)
    - [Features/Native/HomeV2/Components/RecentCollectionCard.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/Components/RecentCollectionCard.swift)  
    要做的事：
    - 卡片标题、数值、说明、状态统一化
    - 不同模块用同一种视觉语法说话

---

## P3 结构和导航统一

24. 统一侧边栏、二级栏、rail 的视觉和节奏。  
    目标文件：
    - [Features/Sidebar/SidebarView.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Sidebar/SidebarView.swift)
    - [Components/SecondarySidebar.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Components/SecondarySidebar.swift)
    - [Features/Native/Shared/WorkspaceSharedComponents.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/WorkspaceSharedComponents.swift)  
    要做的事：
    - 统一导航条目的高度、图标尺寸、选中态
    - 统一 badge、subtitle、group label
    - 让主导航和副导航看起来像一套系统

25. 统一窗口和页面的内容最大宽度、边距和响应式断点。  
    目标文件：
    - [Features/Native/Shared/AppSurfaceStyle.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift)
    - [Features/Native/HomeV2/WorkbenchV2Layout.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/HomeV2/WorkbenchV2Layout.swift)
    - [App/AcMindApp.swift](/Volumes/White%20Atlas/03_Projects/AcMind/App/AcMindApp.swift)  
    要做的事：
    - 统一最小窗口尺寸和页面安全边距
    - 统一窄窗口时的降级策略
    - 避免某些页面宽松、某些页面紧凑得像两个 App

---

## P3 组件复用与整理

26. 把现有重复的卡片 / 标题 / 状态展示抽成稳定的共享组件。  
    目标文件：
    - [Features/Native/Shared/AppSurfaceStyle.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift)
    - [Features/Native/Shared/WorkspaceSharedComponents.swift](/Volumes/White%20Atlas/03_Projects/AcMind/Features/Native/Shared/WorkspaceSharedComponents.swift)  
    要做的事：
    - 把 SectionHeader、Card、MetricTile、ListRow 这些通用结构稳定下来
    - 避免每个页面都自己重新定义一套

27. 给 Bento 化页面制定统一的“卡片尺寸语言”。  
    目标结果：
    - large card
    - medium card
    - small card
    - wide card
    - rail card  
    这样以后所有新页面都能快速接入同样的视觉系统。

---

## 建议执行顺序

1. 先做 P0，统一全局底座
2. 再做 P1 的三个主页面：
   - 工作台
   - Workbench V2
   - Agent Dashboard
3. 然后做 P1 的局部 Bento：
   - 设置
   - 收集箱
   - 日程
4. 再统一浮层、面板、Notch、Capsule
5. 最后做 P2 / P3 的细节统一

---

## 完成标准

当这套任务做完，应该达到这些效果：

- 打开任意主页面，能明显看出是同一个产品
- 所有卡片、按钮、标签、标题都像一个设计系统出来的
- 工作台和仪表盘看起来更高级
- 设置页和列表页不乱，但也不单调
- Bento 负责“组织感”，线性布局负责“效率感”
- 整个项目更精致，但仍然保持原生 macOS 的清晰和克制

