# AcMind 交接文档

更新时间：2026-06-06

这是一份给“换一台电脑后继续工作”的交接说明，目标是让你打开项目后能立刻知道：
- 当前做到哪一步了
- 哪些问题已经修掉
- 还剩哪些风险和待做项
- 重新开工时先跑什么、先看什么

## 当前结论

当前主线仍然围绕一个目标推进：把 AcMind 做成一套统一、克制、真实驱动的桌面工作台，尤其是主界面和各子界面的外壳必须一致，系统状态页必须单屏完整可见，且不能再出现启动卡死。

最近已经确认并修掉的关键问题：
- 启动阶段的系统状态采样会触发断言，导致应用看起来“卡死”
- 主界面和子界面曾经存在不同窗口壳层、宽度漂移、左侧菜单被裁切的问题
- `状态` 页曾经需要滚动才能看完，且右侧容易被裁切
- 系统状态里不能再假装支持温度、风扇、功耗控制；读不到就明确显示 `未知` 或 `不可用`

最近一次可用验证结果：
- `swift test --parallel` 通过
- `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -derivedDataPath /tmp/acmind-dd build` 通过
- 真实启动后的窗口检查中，`状态` 页可完整显示，左侧一级菜单没有再被切掉

## 已完成的核心工作

### 1. 系统状态采样的启动卡死已修复

之前的崩溃来自 `AcMindKit/Services/SystemStatus/SystemStatusReaders.swift`：
- `SMCReader` 里曾经尝试读取非法 key `FNumber`
- `FourCharCode(fromString:)` 以前对非 4 字符字符串使用 `precondition`，会直接触发断言

当前处理方式：
- 已删除非法的 `FNumber` 读取路径
- `FourCharCode(fromString:)` 已改为容错，不再因为非法 key 直接 trap
- 已补回归测试，避免以后再把采样路径炸掉

相关文件：
- [`/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Services/SystemStatus/SystemStatusReaders.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/AcMindKit/Services/SystemStatus/SystemStatusReaders.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/AcMindKitTests/SystemStatusServiceTests.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/AcMindKitTests/SystemStatusServiceTests.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Services/SystemStatus/SystemStatusService.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/AcMindKit/Services/SystemStatus/SystemStatusService.swift)

### 2. 主壳层已统一到固定轨道

当前主界面已经朝“所有子界面共用同一套固定外壳”收敛：
- 左侧一级菜单宽度已经统一收窄
- 页面壳层不再按可用宽度偷偷缩放
- 多数主页面都已经换到同一套 `WorkspacePageShell` 轨道

关键文件：
- [`/Volumes/White Atlas/03_Projects/AcMind/App/ContentView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/App/ContentView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Sidebar/SidebarView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Sidebar/SidebarView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Shared/AppSurfaceStyle.swift)

当前用于统一壳层的关键尺寸思路：
- 主侧栏：`208`
- 主页面内容宽度：`1040`
- 左/右轨道：`200` / `224`

### 3. `状态` 页已压缩到可单屏完整显示

`状态` 页的目标是“系统状态中心”，不是长列表。现在已经按这个方向持续压缩：
- `KPI` 区保留核心卡片
- `系统状态总览` 作为主视觉中心
- 右侧状态指示压缩成矩阵/短行
- 底部温度、风扇、快速操作维持同一排
- 没有可用数据的地方必须清楚写 `未知` / `不可用`

相关文件：
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/SystemStatus/SystemStatusView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/SystemStatus/SystemStatusView.swift)

### 4. 常用子页面也在统一视觉语言

已经被拉到统一壳层/统一尺度的一些页面和弹窗：
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Home/WorkspaceHomeView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Home/WorkspaceHomeView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/VoiceEntry/VoiceEntryView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/VoiceEntry/VoiceEntryView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/DynamicContinent/DynamicContinentConfigView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/DynamicContinent/DynamicContinentConfigView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Tools/ToolPanels.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Tools/ToolPanels.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Capsule/CapsulePanel.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Capsule/CapsulePanel.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Inbox/InboxView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Inbox/InboxView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Agent/AgentDashboardView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Agent/AgentDashboardView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Schedule/ScheduleDashboardView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Schedule/ScheduleDashboardView.swift)
- [`/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Settings/SettingsView.swift`](/Volumes/White%20Atlas/03%20Projects/AcMind/Features/Native/Settings/SettingsView.swift)

## 当前产品方向

已经确定的品牌/体验方向：
- `Apple` 式克制工具感
- 安静、清晰、可靠
- 统一壳层，所有子界面共享同一套固定外框和空间逻辑
- 真实优先，不做假温度、假风扇、假功耗、假控制
- 单屏优先，核心状态必须首屏完整可见
- 图形优先，少写长句，多用环、条、矩阵、chip、短状态

相关文档：
- [`/Volumes/White Atlas/03_Projects/AcMind/PRODUCT.md`](/Volumes/White%20Atlas/03%20Projects/AcMind/PRODUCT.md)
- [`/Volumes/White Atlas/03_Projects/AcMind/docs/acmind-handoff-2026-06-05.md`](/Volumes/White%20Atlas/03%20Projects/AcMind/docs/acmind-handoff-2026-06-05.md)
- [`/Volumes/White Atlas/03_Projects/AcMind/docs/superpowers/plans/2026-06-02-acmind-visual-polish.md`](/Volumes/White%20Atlas/03%20Projects/AcMind/docs/superpowers/plans/2026-06-02-acmind-visual-polish.md)
- [`/Volumes/White Atlas/03_Projects/AcMind/docs/superpowers/specs/2026-05-25-acmind-ui-stability-design.md`](/Volumes/White%20Atlas/03%20Projects/AcMind/docs/superpowers/specs/2026-05-25-acmind-ui-stability-design.md)

## 换机后先做什么

建议按这个顺序继续：

1. 打开项目后先跑一遍：
   ```bash
   swift test --parallel
   xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -derivedDataPath /tmp/acmind-dd build
   ```
2. 启动真实 App，先确认：
   - 是否还会出现启动卡死
   - 左侧一级菜单是否完整可读
   - `状态` 页是否仍然单屏可见
   - 右侧是否还会被裁切
3. 如果要继续视觉 polish，优先看：
   - `Features/Native/SystemStatus/SystemStatusView.swift`
   - `Features/Native/Shared/AppSurfaceStyle.swift`
   - `App/ContentView.swift`
   - `Features/Sidebar/SidebarView.swift`
4. 如果再出现启动崩溃，先查：
   - `AcMindKit/Services/SystemStatus/SystemStatusReaders.swift`
   - `AcMindKit/Services/SystemStatus/SystemStatusService.swift`

## 当前工作区状态

当前工作区是明显的进行中状态，存在大量修改和新增文件，这是正常的，不要误判成脏工作需要回滚。

特别注意：
- 不要回滚你没改的文件
- 不要为了“看起来干净”删除正在推进的新增模块
- 如果后续继续做布局收口，优先保持“所有子界面共用同一套固定外壳”这个原则，不要让个别页面重新长出独立壳层

## 最近验证记录

最后一次已知可用验证：
- `swift test --parallel`
- `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -derivedDataPath /tmp/acmind-dd build`

最近一次真实窗口检查：
- `状态` 窗口可正常打开
- 左侧菜单完整
- 右侧没有再明显裁切
- 底部内容在当前窗口尺寸下可见

如果你在新机器上继续推进，建议先重新跑一次构建和真实启动，再接着做细节 polish。
