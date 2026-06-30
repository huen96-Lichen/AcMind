# AcMind 构建与测试基线

日期：2026-06-24

本文记录 AcMind 当前已经验证过的构建与测试基线。它保持事实化、保守，并明确写出已知失败。

## 环境

| 项目 | 值 |
|---|---|
| macOS | 26.5.1 (25F80) |
| Xcode | 26.5 (17F42) |
| Swift | Apple Swift 6.3.2, swift-driver 1.148.6 |
| 架构 | arm64 |
| Xcode 命令行工具 | `/Applications/Xcode.app/Contents/Developer` |
| 仓库 SHA | `1109c5ebea12968aab2ce0334a44b7d9739e5ccd` |

这次干净验证是在一个从同一提交派生出来的、没有依赖既有 `.build` 或 DerivedData 状态的干净工作区里完成的。

## 支持的构建命令

| 命令 | 结果 | 备注 |
|---|---|---|
| `swift package reset` | 通过 | 在解析前清理 SwiftPM 状态。 |
| `swift package resolve` | 通过 | 成功解析依赖。 |
| `swift build` | 通过 | 成功构建 Swift package。 |
| `swift test` | 失败 | 在 `AcMindKitTests` 的 9 个 suite 中出现 63 个失败断言；其中 `ToolWorkspaceStateTests` 占 18 个。 |
| `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` | 通过 | 成功产出 macOS app bundle。 |
| `bash scripts/build.sh --clean` | 通过 | 清理 `build/`、`.build/` 和 `DerivedData/`。 |
| `bash scripts/build.sh` | 通过 | Debug 构建成功，并把 helper 注入到 app bundle。 |
| `bash scripts/build.sh --release` | 通过 | Release 构建成功，并把 helper 注入到 app bundle。 |
| `bash scripts/build.sh --release --package` | 在没有 Developer ID 证书的机器上失败 | 由于 `set -euo pipefail`，签名查找流程会提前退出。 |
| `DEVELOPER_ID=- bash scripts/build.sh --release --package` | 通过 | 以 ad-hoc 签名方式成功生成 DMG。 |
| `bash scripts/build.sh --release --notarize` | 未验证 | 需要 Apple ID、应用专用密码、Team ID，以及可用于公证的签名配置。 |

## 应用构建产物

已验证的直接 Xcode 构建命令如下：

```bash
xcodebuild \
  -project AcMind.xcodeproj \
  -scheme AcMind \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

可移植的 app 路径应通过查看 build settings 并组合以下值来得到：

- `TARGET_BUILD_DIR`
- `WRAPPER_NAME`
- `FULL_PRODUCT_NAME`
- `CONFIGURATION_BUILD_DIR`

在当前环境里，已验证的 build settings 为：

- `TARGET_BUILD_DIR = .../Build/Products/Debug`
- `CONFIGURATION_BUILD_DIR = .../Build/Products/Debug`
- `WRAPPER_NAME = AcMind.app`
- `FULL_PRODUCT_NAME = AcMind.app`

可移植的路径表达式是：

```bash
"$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
```

对于这个项目，Xcode 和 release script 都成功产出了未签名的 app bundle。构建产物是有效的，bundle 也存在于推导出的路径上，但这个检查点没有执行交互式 GUI 启动测试。

helper 安装是已验证构建路径的一部分。应用构建会包含一个 helper target，以及一个脚本阶段，把 helper 二进制放到：

```text
Contents/Library/LaunchServices/com.acmind.systemstatus.helper
```

## 测试状态

| 套件 | 状态 | 分类 | CI 处理 |
|---|---|---|---|
| Swift package 解析 | 通过 | 稳定 | 必需 |
| Swift package 构建 | 通过 | 稳定 | 必需 |
| 核心非 UI 测试套件 | 通过 | 稳定 | 必需 |
| `AcMindKitTests` 已知失败套件 | 混合 | 待分析 | 在失败修复前，保持整个 suite 处于阻断状态 |

## 已知失败

完整的 `AcMindKitTests` 目标共有 624 个已执行测试和 63 个失败断言。这 63 个失败分布在 9 个 test suite 和 39 个失败的 test method 中，并不全都来自 `ToolWorkspaceStateTests`。

套件级别分布如下：

| Test target | Test suite | 失败方法数 | 失败断言数 | 分类 |
|---|---|---:|---:|---|
| `AcMindKitTests` | `SystemStatusCleanupTests` | 21 | 36 | A，过时的截图 / 期望漂移 |
| `AcMindKitTests` | `ToolWorkspaceStateTests` | 10 | 18 | A，过时的截图 / 期望漂移 |
| `AcMindKitTests` | `MusicNowPlayingParserTests` | 1 | 2 | A，期望漂移 |
| `AcMindKitTests` | `MusicSurfacePolishTests` | 2 | 2 | A，期望漂移 |
| `AcMindKitTests` | `AppNotificationServiceTests` | 1 | 1 | A，期望漂移 |
| `AcMindKitTests` | `ScreenshotProcessingTests` | 1 | 1 | A，期望漂移 |
| `AcMindKitTests` | `SettingsMigrationServiceTests` | 1 | 1 | A，期望漂移 |
| `AcMindKitTests` | `SettingsPluginCopyTests` | 1 | 1 | A，期望漂移 |
| `AcMindKitTests` | `SystemHardwareAccessTests` | 1 | 1 | A，期望漂移 |

失败 test method 的细分如下：

### `SystemStatusCleanupTests`

| Test method | 失败断言数 | 分类 | 证据 / 可能原因 |
|---|---:|---|---|
| `testAgentDashboardUsesCollaborativeWorkspaceSections` | 1 | A，过时的测试期望 | 表面和布局字符串与当前实现不同。 |
| `testAgentDashboardUsesSharedCardSurfaces` | 2 | A，过时的测试期望 | 期望的 card-surface 字符串已不再匹配当前源码。 |
| `testAgentPageCenterCardUsesRemainingHeight` | 1 | A，过时的测试期望 | 截图期望比当前页面布局更旧。 |
| `testAgentPageRightColumnIsMoreCompact` | 2 | A，过时的测试期望 | 期望的紧凑列字符串与当前源码不同。 |
| `testClipboardViewUsesSharedBackdropAndSidebarCards` | 1 | A，过时的测试期望 | 背景层和侧边栏 surface 字符串已变化。 |
| `testCompanionVoicePanelSupportsEditableDraftAndStageFlow` | 1 | A，过时的测试期望 | 语音面板文案 / stage flow 截图已经过时。 |
| `testContentViewUsesSharedSidebarView` | 1 | A，过时的测试期望 | 侧边栏视图期望已不再匹配当前实现。 |
| `testLightStatusStripUsesStrongerHighlightedFeedback` | 2 | A，过时的测试期望 | 高亮反馈字符串已漂移。 |
| `testMainContentRoutesHomeToTheWorkspaceDashboard` | 1 | A，过时的测试期望 | 当前路由字符串与测试夹具不再一致。 |
| `testMainWindowPrunesPlaceholderAcMindWindows` | 2 | A，过时的测试期望 | 占位窗口清理输出与快照不同。 |
| `testNotchAgentPageUsesComposerStyleQuickAsk` | 4 | A，过时的测试期望 | 多个 composer / quick-ask 字符串已经过时。 |
| `testNotchCardsUseSofterPanelShadowAndFill` | 4 | A，过时的测试期望 | 面板阴影 / 填充期望已经过时。 |
| `testNotchOverviewUsesAdaptiveActionTiles` | 1 | A，过时的测试期望 | 自适应 action tile 字符串已经漂移。 |
| `testNotchTopBarUsesUnifiedStatusPills` | 1 | A，过时的测试期望 | 顶栏 pill 字符串已过时。 |
| `testScheduleDashboardUsesSharedCardShells` | 1 | A，过时的测试期望 | card-shell 字符串与当前源码不同。 |
| `testSettingsViewUsesSharedWorkspaceComponents` | 3 | A，过时的测试期望 | 多个 workspace component 字符串已过时。 |
| `testStatusPillSupportsSelectedFeedback` | 2 | A，过时的测试期望 | 选中反馈字符串已漂移。 |
| `testSystemStatusPageUsesSixCoreTilesAndNarrowRails` | 2 | A，过时的测试期望 | tile / rail 字符串与当前源码不一致。 |
| `testSystemStatusViewDoesNotUseSystemStatusSingleton` | 2 | A，过时的测试期望 | 单例使用期望已过时。 |
| `testTopBarStatusButtonPrefersSystemStatusPage` | 1 | A，过时的测试期望 | 状态按钮路由文本与快照不同。 |
| `testWorkspaceSharedComponentsUseSharedBackdropAndCardSurfaces` | 1 | A，过时的测试期望 | 共享 surface 字符串已过时。 |

### `ToolWorkspaceStateTests`

| Test method | 失败断言数 | 分类 | 证据 / 可能原因 |
|---|---:|---|---|
| `testAdvancedToolPanelsUseSharedBackdropAndCards` | 1 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()`，但当前源码使用的是 `AppSurfaceBackdrop()`。 |
| `testCompletionToolPanelsUseSharedBackdropAndCards` | 2 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()` 和 `WorkspacePageShell(`，但当前源码已不再匹配这些字符串。 |
| `testCoreToolPanelsUseSharedBackdropAndCards` | 1 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()`，但当前源码使用的是 `AppSurfaceBackdrop()`。 |
| `testHomeAndSettingsUseSharedBackdropSurfaces` | 1 | A，过时的测试期望 | 测试期待的是旧版 home/settings 背景层连接方式。 |
| `testModelManagementPanelUsesDetailSurfaceCards` | 1 | A，过时的测试期望 | 测试期待 `WorkspacePageShell(`，但当前源码中已经没有这个 shell 字符串。 |
| `testSystemStatusViewKeepsBackdropVisible` | 2 | A，过时的测试期望 | 测试期待 `WorkspacePageShell(`，但当前源码中没有这个 shell 字符串。 |
| `testToolsViewSurfacesTheThreeStageWorkflow` | 2 | A，过时的测试期望 | 测试仍在找 `工具工作流` 和 `ToolStageHeader`，但 `Features/Native/Tools/ToolsView.swift` 现在使用的是 `AcWorkShell` 和 `ToolWorkspaceStageRail`。 |
| `testToolsViewUsesSharedBackdropAndCardSurfaces` | 6 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()`，但当前源码使用的是 `AppSurfaceBackdrop()` 和 `AcSection` / `AppSurfaceCard` 的组合。 |
| `testWebDigestPanelUsesSharedSurfaceCards` | 1 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()`，但 `Features/Native/Tools/WebDigestPanel.swift` 现在使用的是 `AppSurfaceBackdrop()`。 |
| `testWorkbenchViewShowsProjectNoteArchiveWorkflow` | 1 | A，过时的测试期望 | 测试期待 `AppVisualBackdrop()`，但 `Features/Native/Workbench/WorkbenchView.swift` 现在使用的是 `AppSurfaceBackdrop()`。 |

### 其他失败的 suite

| Test method | 失败断言数 | 分类 | 证据 / 可能原因 |
|---|---:|---|---|
| `MusicNowPlayingParserTests.testMusicPageEmptyStateDoesNotPresentAcMindAsPlaybackSource` | 2 | A，期望漂移 | 空状态文案 / 播放源表述已经变化。 |
| `MusicSurfacePolishTests.testMusicPageQueueEmptyStateUsesSharedContextText` | 1 | A，期望漂移 | 共享上下文文案已漂移。 |
| `MusicSurfacePolishTests.testMusicPageUsesThreeColumnWorkspace` | 1 | A，期望漂移 | 工作区布局文案已漂移。 |
| `AppNotificationServiceTests.testPlanPrefersInlineToastWhenAcMindIsFrontmostEvenIfDenied` | 1 | A，期望漂移 | 测试仍然偏向 `inlineToast`，但当前实现返回的是 `appleScriptFallback`。 |
| `ScreenshotProcessingTests.testScreenshotPostProcessorResizesAndRoundsCorners` | 1 | A，期望漂移 | 预期的圆角像素值已不再匹配当前处理器输出。 |
| `SettingsMigrationServiceTests.testRunIfNeededMigratesLegacyPreferencesHotkeysAndVoiceSettings` | 1 | A，期望漂移 | 对旧偏好迁移中语音设置的期望已不匹配当前行为。 |
| `SettingsPluginCopyTests.testSettingsViewContainsPluginOverviewCard` | 1 | A，期望漂移 | 插件概览卡片字符串已过时。 |
| `SystemHardwareAccessTests.testHelperTransportWinsWhenAvailable` | 1 | A，期望漂移 | helper transport 优先级期望已不再匹配当前 transport 选择。 |

这些失败在当前 checkpoint 中的每次运行都会稳定复现：

- 第 1 次运行，完整 `swift test`：624 个测试，63 个失败
- 第 2 次运行，`swift test --filter ToolWorkspaceStateTests`：12 个测试，18 个失败
- 第 3 次运行，`swift test --filter ToolWorkspaceStateTests`：12 个测试，18 个失败
- 第 4 次运行，干净克隆环境下的 `swift test`：624 个测试，63 个失败

这 63 个失败是 63 个失败断言，不是 63 个独立失败的 test method。完整运行里有 39 个失败的 test method，分布在 9 个 suite 中，而 `ToolWorkspaceStateTests` 里的 18 个失败只是一部分。

## 可重复性结果

- 同样的 39 个失败 test method 每次都会出现。
- 实际结果对这些 `contains(...)` 断言来说都稳定为 `false`。
- 失败集合看起来不依赖执行顺序。
- 单独运行某个 suite 并不会让失败消失。
- 这些失败不像是时序敏感问题。

## CI 策略建议

建议的临时策略是：让完整 `swift test` 继续阻断，并保持 GitHub Actions 处于红色，直到文档化的基线被修复。

这个策略最诚实，因为当前还有 63 个失败断言分布在 9 个 suite 中。它也避免了假装只有 `ToolWorkspaceStateTests` 一个未解决问题。

CI 策略不应：

- 吞掉退出码；
- 使用 `swift test || true`；
- 禁用整个 test target；
- 删除断言；
- 排除所有 UI 或布局测试；
- 在文档化失败仍然存在时，把基线当成绿色。

## 构建脚本验证

已验证：

- `bash scripts/build.sh`
- `bash scripts/build.sh --release`
- `bash scripts/build.sh --release --package`（使用 `DEVELOPER_ID=-`）
- `bash scripts/build.sh --clean`

尚未验证：

- `bash scripts/build.sh --release --notarize`

重要行为说明：

- `bash scripts/build.sh --release --package` 在没有 Developer ID 证书的机器上会失败，因为 `set -euo pipefail` 会让签名查找流程提前退出。
- 传入 `DEVELOPER_ID=-` 后，同一个模式可以通过 ad-hoc 签名和 DMG 生成完成。

## issue 草稿

如果这些项没有在本 checkpoint 中修复，就应明确跟踪它们：

1. 已知失败 suite 基线对齐
   - 复现：运行 `swift test`
   - 实际：624 个测试，63 个失败
   - 期望：本文中的完整失败清单应保持准确且可归因
   - 分类：多个 suite 上的过时测试期望
