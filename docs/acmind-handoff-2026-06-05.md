# AcMind 交接文档

更新时间：2026-06-05

## 当前结论

当前这条主线已经收口到 **0.0.6 的完成态**。现在的主界面已经是单一的真实状态中心，Pin 悬浮窗也已经具备独立窗口、置顶、隐藏/显示、诊断和回前景能力，不再依赖“看起来像完成”的假实现。

最近一次验证结果是：
- `swift test --filter ClipboardPinLayoutTests` 通过，21 个测试全绿
- `xcodebuild -derivedDataPath "$TMPDIR/AcMindDerivedData" -project AcMind.xcodeproj -scheme AcMind -configuration Debug build` 通过，`BUILD SUCCEEDED`

## 已完成

### 1. 剪贴板 / 收集箱卡片统一

- 剪贴板和收集箱都接入了同一套 `MaterialCardShell`。
- 结构统一成 `header + preview + footer + actions`。
- 卡片不再保留重复的状态层，减少了内容重复和空间浪费。
- 图片预览不再把标签压在图上，避免内容被挤出卡面。
- 文本预览改成更紧凑的两行/多行控制，整体密度比之前更接近 PinStack 的素材卡。

相关文件：
- [Features/Native/Shared/MaterialCardShell.swift](../Features/Native/Shared/MaterialCardShell.swift)
- [Features/Native/Clipboard/ClipboardView.swift](../Features/Native/Clipboard/ClipboardView.swift)
- [Features/Native/Inbox/Components/InboxItemCard.swift](../Features/Native/Inbox/Components/InboxItemCard.swift)
- [AcMindKit/Models/ClipboardCardPresentation.swift](../AcMindKit/Models/ClipboardCardPresentation.swift)
- [AcMindKit/Models/MaterialCardGridLayout.swift](../AcMindKit/Models/MaterialCardGridLayout.swift)

### 2. Pin 悬浮窗能力

- 已实现独立悬浮窗，不再只是列表里的置顶标记。
- Pin 窗口支持：
  - 置顶
  - 关闭
  - 隐藏 / 显示全部
  - 重新激活后再前置
  - 多次短延迟重申前置
- 当前窗口层级采用 `screenSaver`，并保留跨空间行为。
- `ClipboardPinWindowSnapshot` 和 `diagnosticsReport` 已经把“是否真的还在最前面”变成了可检查的状态，而不是只靠主观感受。
- Pin 的稳定性不再依赖主窗口是否激活，而是由窗口级保活、空间变化重申和屏幕变化重申共同兜底。

相关文件：
- [AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift](../AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift)
- [AcMindKit/Models/ClipboardPinWindowSizing.swift](../AcMindKit/Models/ClipboardPinWindowSizing.swift)
- [AcMindKit/Models/ClipboardPinWindowSnapshot.swift](../AcMindKit/Models/ClipboardPinWindowSnapshot.swift)
- [AcMindKit/Models/ClipboardPinNotifications.swift](../AcMindKit/Models/ClipboardPinNotifications.swift)
- [App/AppDelegate.swift](../App/AppDelegate.swift)

### 3. 主界面交互与导航

- 左侧主导航已从容易吞点击的 `List(selection:)` 方向，改成更稳定的按钮式交互。
- 首页 / Agent / 收集箱等入口的切换问题已经修过一轮。
- `.systemStatus` 已经被当成首页的别名处理，最终会回到 `首页`，不会再打开一个独立的旧状态页。
- 副屏场景也不再强依赖主窗口屏幕。

相关文件：
- [App/ContentView.swift](../App/ContentView.swift)
- [Features/Sidebar/SidebarView.swift](../Features/Sidebar/SidebarView.swift)
- [App/SidebarItem.swift](../App/SidebarItem.swift)

### 4. 版本与验证

- 版本已经推进到 `0.0.6`，构建号 `6`。
- 最新 Debug 构建已能正常编译并产出应用包。
- 本次交接的验证口径已经统一到“局部测试 + Xcode 构建”这两条，不再把未复核的真实场景观察当成完成条件。

Debug 输出位置：
- `"$TMPDIR/AcMindDerivedData/Build/Products/Debug/AcMind.app/Contents/MacOS/AcMind"`

## 交接提醒

- 当前工作区有较多未提交改动，这是预期中的进行中状态。
- 不要回滚不相关文件。
- 如果新对话继续做 Pin 体验，优先看：
  - [AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift](../AcMindKit/Services/UI/ClipboardPin/ClipboardPinWindowManager.swift)
  - [Features/Native/Clipboard/ClipboardView.swift](../Features/Native/Clipboard/ClipboardView.swift)
  - [Features/Native/Inbox/Components/InboxItemCard.swift](../Features/Native/Inbox/Components/InboxItemCard.swift)
  - [AcMindKitTests/ClipboardPinLayoutTests.swift](../AcMindKitTests/ClipboardPinLayoutTests.swift)
