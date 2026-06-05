# AcMind 交接文档

更新时间：2026-06-05

## 当前进度

当前这条主线已经推进到 **0.0.6 的接近完成态**，整体进度我会判断在 **85% - 90%**。

已经完成的部分，主要是把剪贴板和收集箱统一成更成熟的素材卡结构，并把 Pin 悬浮窗的窗口级行为、前置策略和回归测试都补齐了。当前剩下的重点，不是大功能架构，而是 **真实场景里 Pin 是否稳定压在最前** 这一个最后体验点。

## 已完成

### 1. 剪贴板 / 收集箱卡片统一

- 剪贴板和收集箱都接入了同一套 `MaterialCardShell`。
- 结构统一成 `header + preview + footer + actions`。
- 卡片不再保留重复的状态层，减少了内容重复和空间浪费。
- 图片预览不再把标签压在图上，避免内容被挤出卡面。
- 文本预览改成更紧凑的两行/多行控制，整体密度比之前更接近 PinStack 的素材卡。

相关文件：
- [Features/Native/Shared/MaterialCardShell.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Shared/MaterialCardShell.swift)
- [Features/Native/Clipboard/ClipboardView.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Clipboard/ClipboardView.swift)
- [Features/Native/Inbox/Components/InboxItemCard.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Inbox/Components/InboxItemCard.swift)
- [AcMindKit/Models/ClipboardCardPresentation.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Models/ClipboardCardPresentation.swift)
- [AcMindKit/Models/MaterialCardGridLayout.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Models/MaterialCardGridLayout.swift)

### 2. Pin 悬浮窗能力

- 已实现独立悬浮窗，不再只是列表里的置顶标记。
- Pin 窗口支持：
  - 置顶
  - 关闭
  - 隐藏 / 显示全部
  - 重新激活后再前置
  - 多次短延迟重申前置
- 当前窗口层级仍采用 `screenSaver`，并保留跨空间行为。
- Pin 窗口已调整为更接近“真正浮窗”的体验，不再依赖主窗口激活逻辑。

相关文件：
- [AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift)
- [AcMindKit/Models/ClipboardPinWindowSizing.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Models/ClipboardPinWindowSizing.swift)
- [AcMindKit/Models/ClipboardPinWindowSnapshot.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Models/ClipboardPinWindowSnapshot.swift)
- [AcMindKit/Models/ClipboardPinNotifications.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Models/ClipboardPinNotifications.swift)
- [App/AppDelegate.swift](/Volumes/White Atlas/03_Projects/AcMind/App/AppDelegate.swift)

### 3. 主界面交互与导航

- 左侧主导航已从容易吞点击的 `List(selection:)` 方向，改成更稳定的按钮式交互。
- 首页 / Agent / 收集箱等入口的切换问题已经修过一轮。
- 副屏场景也不再强依赖主窗口屏幕。

相关文件：
- [App/ContentView.swift](/Volumes/White Atlas/03_Projects/AcMind/App/ContentView.swift)
- [Features/Sidebar/SidebarView.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Sidebar/SidebarView.swift)
- [App/SidebarItem.swift](/Volumes/White Atlas/03_Projects/AcMind/App/SidebarItem.swift)

### 4. 版本与验证

- 版本已经推进到 `0.0.6`，构建号 `6`。
- 最新 Debug 包已经重启并确认在运行。
- 目前验证结果：
  - `swift test --filter ClipboardPinLayoutTests` 通过
  - `swift test` 通过，`240` 个测试全绿
  - `xcodebuild -derivedDataPath /private/tmp/AcMindDerivedData -project AcMind.xcodeproj -scheme AcMind -configuration Debug build` 通过，`BUILD SUCCEEDED`

当前运行进程：
- `/private/tmp/AcMindDerivedData/Build/Products/Debug/AcMind.app/Contents/MacOS/AcMind`

## 还没彻底收口的点

### 1. Pin 是否真的稳定压在最前

这是当前唯一还需要真实场景确认的点。

虽然代码里已经做了：
- `screenSaver` 层级
- `showInactive` / `makeKeyAndOrderFront`
- `NSApp.activate(ignoringOtherApps: true)`
- 短延迟重申
- 定时保活重拉前景
- 应用激活 / 失活 / 屏幕变化时的再前置

但最终还是需要在你真实的副屏场景里，看它是否在 Final Cut / After Effects 这类窗口前面始终压得住。

### 2. 卡片密度是否还要再压一点

目前已经比之前紧凑很多，但如果你下一轮还想更像 PinStack，可以继续在：
- 图片缩略图大小
- 文本行高
- footer 高度
- grid 最小列宽

这几个点上继续磨。

## 下一轮建议

如果你在新对话里继续，我建议按这个顺序推进：

1. 先做一次真实副屏场景确认，重点看 Pin 是否真的始终在最前。
2. 如果还是不稳，再只盯 PinWindowManager 的前置策略，不要扩散到别的模块。
3. 如果 Pin 体验已经稳了，再继续压剪贴板和收集箱的卡片密度，让它们更像 PinStack。

## 交接提醒

- 当前工作区有较多未提交改动，这是预期中的进行中状态。
- 不要回滚不相关文件。
- 如果新对话继续做 Pin 体验，优先看：
  - [AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift)
  - [Features/Native/Clipboard/ClipboardView.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Clipboard/ClipboardView.swift)
  - [Features/Native/Inbox/Components/InboxItemCard.swift](/Volumes/White Atlas/03_Projects/AcMind/Features/Native/Inbox/Components/InboxItemCard.swift)
  - [AcMindKitTests/ClipboardPinLayoutTests.swift](/Volumes/White Atlas/03_Projects/AcMind/AcMindKitTests/ClipboardPinLayoutTests.swift)

