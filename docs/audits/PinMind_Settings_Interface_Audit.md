# PinMind 设置页与接口盘点报告

## 1. 审计结论摘要

PinMind 当前的设置相关能力，绝大多数已经是真实可用的，但它们被拆散在多个层级里：

- 设置页本身是一个真实的配置入口，入口文件在 `src/renderer/pages/settings/SettingsPage.tsx:56`。
- 设置页二级导航是同一个文件里的 `SETTINGS_CATEGORIES`，不是独立路由。
- 配置和持久化的主存储是 SQLite，不是 `localStorage`、`electron-store` 或独立 JSON 文件。
- `AppSettings` 通过 `app_settings` 表保存，`vault_config` 和 `provider_configs` 还有各自独立表，形成了双源甚至三源配置结构。
- AI Provider / Vault / Workspace / Clipboard / Permission 的多数动作都是真接口。
- 但顶部栏、侧边栏底部卡片、底部状态栏里有大量固定文案和静态状态，容易把“展示”误当成“真实状态”。
- 全局右侧详情面板是按 `AppShell` 的大屏布局统一挂载的，Settings 页并不需要它，当前会显示无意义的空态。

最大风险不是“接口没有”，而是“接口太多，且同一含义被多处重复展示、重复维护”。后续 UI 重排应优先解决：

1. `settings.vault` 与 `vault_config` 的双来源；
2. `settings.providers` 与 `provider_configs` 的双来源；
3. 顶部栏 / 侧边栏 / 底部栏 / 个人空间面板对同一状态的重复展示；
4. Settings 页和全局右侧详情面板的布局冲突。

## 2. 当前设置页结构

### 2.1 入口与导航

- 设置页入口：`src/renderer/App.tsx:182`。
- 设置页页面组件：`src/renderer/pages/settings/SettingsPage.tsx:56`。
- 设置二级导航定义：`src/renderer/pages/settings/SettingsPage.tsx:39`。
- 设置页当前是“左侧分类列表 + 右侧详情面板”的两栏结构：`src/renderer/pages/settings/SettingsPage.tsx:263`。

### 2.2 设置页模块盘点

| 设置模块 | 文件路径 | 字段 / 按钮 | 当前状态 | 真实接口 | 备注 |
|---|---|---|---|---|---|
| 通用 | `src/renderer/pages/settings/SettingsPage.tsx:309` | `storageRoot`、`open`、`更改路径` | real | `app.openStorageRoot`、`settings.update`、`vault.pickFolder` | `storageRoot` 会写入 `app_settings`；“更改路径”实际选的是目录并写回 `settings.storageRoot`。 |
| 通用 | `src/renderer/pages/settings/SettingsPage.tsx:353` | `launchAtLogin`、`minimizeToTray`、`backgroundClipboard` | real | `settings.update` | 三个开关都是真配置项。 |
| 通用 | `src/renderer/pages/settings/SettingsPage.tsx:375` | `autoCapture`、`showCaptureToast`、`autoAiProcess` | real | `settings.update` | 都会直接写入 `AppSettings`。 |
| 通用 | `src/renderer/pages/settings/SettingsPage.tsx:397` | `autoExportObsidian`、说明文案 | mixed | `settings.update` | 开关真实；“默认输出位置已统一到捕获入口”是说明文案，不是当前页实际配置项。 |
| 通用 | `src/renderer/pages/settings/SettingsPage.tsx:417` | `storageRoot` 展示、`打开数据目录` | real | `app.openStorageRoot` | 这里和上方“存储路径”重复，属于同一能力的重复呈现。 |
| AI 模型 | `src/renderer/pages/settings/SettingsPage.tsx:444` | `新增模型来源` | real | `providers.add` | 打开真实 provider 对话框。 |
| AI 模型 | `src/renderer/pages/settings/SettingsPage.tsx:468` | `ProviderCard` 列表、启用/停用、编辑、删除、测试连接 | real | `providers.list`、`providers.update`、`providers.delete`、`providers.testConnection` | 这些按钮都是真动作，不是 placeholder。 |
| AI 模型 | `src/renderer/pages/settings/SettingsPage.tsx:502` | `defaultStrategy` 下拉 | real | `settings.update` | 写入的是 `defaultTier`，不是独立的 provider 选择器。 |
| 路径与存储 | `src/renderer/pages/settings/SettingsPage.tsx:561` | `storageRoot`、`pollIntervalMs`、`scopeMode`、`scopedApps` | real | `settings.update` | 这里的字段名称与需求里的 `scanInterval/scanScope/allowedApps` 不同，实际是 `pollIntervalMs/scopeMode/scopedApps`。 |
| Obsidian | `src/renderer/pages/settings/SettingsPage.tsx:625` | `vault.vaultPath`、`defaultFolder`、`pathRule`、`conflictStrategy`、`autoFrontmatter`、`校验`、`选择` | real | `settings.update`、`vault.validatePath`、`vault.pickFolder` | 这块是真实可写的，按钮有实际动作。 |
| 捕获入口 | `src/renderer/pages/settings/SettingsPage.tsx:723` | `capsule` 子面板全部字段 | real | `settings.update` | 这是一整套真实的 capsule 配置，字段来自 `src/shared/capsuleSettings.ts:128`。 |
| 外观 | `src/renderer/pages/settings/SettingsPage.tsx:726` | `主题模式`、`showFloatingButton` | mixed | `settings.update` | `showFloatingButton` 是真实；“主题模式”当前是静态 badge，不是实际可写主题切换。 |
| 隐私与本地优先 | `src/renderer/pages/settings/SettingsPage.tsx:753` | 权限卡片、`刷新`、`前往系统设置` | real | `permissions.getStatus`、`permissions.refresh`、`permissions.openSettings` | 这是运行时权限快照，不是持久化设置。 |
| 高级 | `src/renderer/pages/settings/SettingsPage.tsx:792` | `logLevel` | real | `logger.setLevel` / `settings.update` | 真实日志级别控制。 |
| 高级 | `src/renderer/pages/settings/SettingsPage.tsx:814` | `实时保存` | placeholder | 无 | 这是纯展示态，不是配置项。 |

### 2.3 结论

Settings 页的真实可用能力主要集中在：

- `storageRoot`
- `providers`
- `defaultTier`
- `vault`
- `capsule`
- `logLevel`
- `permissions`

其中最容易误判的是：

- `主题模式` 当前只是静态展示；
- `实时保存` 只是状态文案；
- “默认输出位置已统一到捕获入口” 是说明，不是本页真实字段；
- 数据目录 / 本地数据保护 / Mock 状态大量在别处重复展示。

## 3. IPC 接口清单

下面列的是和设置页、AI 控制台、权限、路径、存储、workspace 及相关状态最直接有关的接口。

| 接口名 | main 侧位置 | preload 暴露名 | renderer 调用位置 | 入参 | 出参 | 当前是否被使用 |
|---|---|---|---|---|---|---|
| `settings.get` | `src/main/ipc.ts:76` | `window.pinmind.settings.get` | `src/renderer/App.tsx:70`、`src/renderer/pages/settings/SettingsPage.tsx:87`、`src/renderer/hooks/useShellSnapshot.ts:40` | 无 | `AppSettings` | yes |
| `settings.update` | `src/main/ipc.ts:81` | `window.pinmind.settings.update` | `src/renderer/pages/settings/SettingsPage.tsx:125`、`src/renderer/components/layout/PersonalSpacePanel.tsx:68`、`src/renderer/pages/onboarding/OnboardingPage.tsx:132` | `Partial<AppSettings>` | `AppSettings` | yes |
| `settings.runtime.get` | `src/main/ipc.ts:1283` | `window.pinmind.settings.runtime.get` | `src/renderer/CaptureHub.tsx:332`、`src/renderer/CaptureHub.tsx:342` | 无 | `RuntimeSettings` | yes |
| `app.getVersion` | `src/main/ipc.ts:93` | `window.pinmind.app.getVersion` | 少量页面可能调用，未见设置页直接使用 | 无 | `string` | unclear |
| `app.openStorageRoot` | `src/main/ipc.ts:109` | `window.pinmind.app.openStorageRoot` | `SettingsPage.tsx:332`、`SettingsPage.tsx:426`、`PersonalSpacePanel.tsx:97` | 无 | `boolean` | yes |
| `storage.getStats` | `src/main/ipc.ts:126` | `window.pinmind.storage.getStats` | `src/renderer/hooks/useShellSnapshot.ts:41` | 无 | `StorageStats` | yes |
| `providers.list` | `src/main/ipc.ts:328` | `window.pinmind.providers.list` | `SettingsPage.tsx:107`、`AiConsolePage.tsx:587`、`OnboardingPage.tsx:67` | 无 | `ProviderConfig[]` | yes |
| `providers.add` | `src/main/ipc.ts:340` | `window.pinmind.providers.add` | `SettingsPage.tsx:233`、`AiConsolePage.tsx:617`、`OnboardingPage.tsx:130` | `ProviderConfig` | `ProviderConfig` | yes |
| `providers.update` | `src/main/ipc.ts:354` | `window.pinmind.providers.update` | `SettingsPage.tsx:162`、`SettingsPage.tsx:231`、`AiConsolePage.tsx:621` | `id`, `patch` | `ProviderConfig` | yes |
| `providers.delete` | `src/main/ipc.ts:373` | `window.pinmind.providers.delete` | `SettingsPage.tsx:194`、`AiConsolePage.tsx:626` | `id` | `void` | yes |
| `providers.scanLocal` | `src/main/ipc.ts:386` | `window.pinmind.providers.scanLocal` | `OnboardingPage.tsx:67` | 无 | `{ name, size, modifiedAt }[]` | yes |
| `providers.testConnection` | `src/main/ipc.ts:422` | `window.pinmind.providers.testConnection` | `SettingsPage.tsx:212`、`AiConsolePage.tsx:631` | `providerId` | `{ ok, latencyMs, error? }` | yes |
| `permissions.getStatus` | `src/main/ipc.ts:1269` | `window.pinmind.permissions.getStatus` | `SettingsPage.tsx:88`、`OnboardingPage.tsx:53`、`useShellSnapshot.ts:43` | `PermissionCheckSource` | `PermissionStatusSnapshot` | yes |
| `permissions.refresh` | `src/main/ipc.ts:1272` | `window.pinmind.permissions.refresh` | `SettingsPage.tsx:781`、`OnboardingPage.tsx:103` | `PermissionCheckSource`、`traceId?` | `PermissionStatusSnapshot` | yes |
| `permissions.openSettings` | `src/main/ipc.ts:1275` | `window.pinmind.permissions.openSettings` | `SettingsPage.tsx:776` | `target`、`traceId?` | `void` | yes |
| `vault.getConfig` | `src/main/ipc.ts:734` | `window.pinmind.vault.getConfig` | `useShellSnapshot.ts:44` | 无 | `VaultConfig` | yes |
| `vault.updateConfig` | `src/main/ipc.ts:746` | `window.pinmind.vault.updateConfig` | `PersonalSpacePanel.tsx:143`、`OnboardingPage.tsx:163` | `Partial<VaultConfig>` | `VaultConfig` | yes |
| `vault.validatePath` | `src/main/ipc.ts:759` | `window.pinmind.vault.validatePath` | `SettingsPage.tsx:661`、`OnboardingPage.tsx:158` | `vaultPath` | `{ valid, message }` | yes |
| `vault.pickFolder` | `src/main/ipc.ts:796` | `window.pinmind.vault.pickFolder` | `SettingsPage.tsx:341`、`SettingsPage.tsx:649`、`OnboardingPage.tsx:147`、`PersonalSpacePanel.tsx:140` | 无 | `string` | yes |
| `workspace.selectDirectory` | `src/main/ipc.ts:1776` | `window.pinmind.workspace.selectDirectory` | `PersonalSpacePanel.tsx:107` | 无 | `{ success, path? }` | yes |
| `workspace.openDirectory` | `src/main/ipc.ts:1798` | `window.pinmind.workspace.openDirectory` | `PersonalSpacePanel.tsx:125`、`PersonalSpacePanel.tsx:414` | `dirPath` | `{ success }` | yes |
| `workspace.testWrite` | `src/main/ipc.ts:1813` | `window.pinmind.workspace.testWrite` | `PersonalSpacePanel.tsx:162` | `dirPath` | `{ success, path?, error? }` | yes |
| `clipboard.getStatus` | `src/main/ipc.ts:299` | `window.pinmind.clipboard.getStatus` | `useShellSnapshot.ts:42` | 无 | `{ running, enabled }` | yes |
| `clipboard.toggle` | `src/main/ipc.ts:311` | `window.pinmind.clipboard.toggle` | 当前设置页未直接调用 | `enabled` | `boolean` | unclear |
| `logger.getLevel` | `src/main/ipc.ts:138` | `window.pinmind.logger.getLevel` | AI / 诊断页可能使用 | 无 | `LogLevel` | unclear |
| `logger.setLevel` | `src/main/ipc.ts:144` | `window.pinmind.logger.setLevel` | `SettingsPage.tsx:805` | `LogLevel` | `LogLevel` | yes |
| `logger.read` | `src/main/ipc.ts:605` | `window.pinmind.logger.read` | `AiLogPanel`、日志页相关 | `channel`, `limit?` | `string[]` | yes |
| `aiTasks.list` | `src/main/ipc.ts:477` | `window.pinmind.aiTasks.list` | `AiConsolePage.tsx`、`useAiTasks` | filter | `AiTask[]` | yes |
| `aiTasks.cancel` | `src/main/ipc.ts:489` | `window.pinmind.aiTasks.cancel` | `AiConsolePage.tsx:641` | `id` | `boolean` | yes |
| `aiTasks.retry` | `src/main/ipc.ts:506` | `window.pinmind.aiTasks.retry` | `AiConsolePage.tsx:650` | `id` | `AiTask \| null` | yes |
| `distill.run` | `src/main/ipc.ts:523` | `window.pinmind.distill.run` | `CaptureInboxPage.tsx:249`、多个蒸馏页面 | `sourceItemIds`, `operations`, `tier?` | `AiTask[]` | yes |
| `distill.runSingle` | `src/main/ipc.ts:536` | `window.pinmind.distill.runSingle` | 蒸馏工作台 | `sourceItemId`, `operation`, `tier?` | `AiTask` | yes |
| `distill.batch` | `src/main/ipc.ts:634` | `window.pinmind.distill.batch` | 批量蒸馏场景 | `sourceItemIds`, `operations`, `tier?` | `batchId` | yes |
| `distill.batchStatus` | `src/main/ipc.ts:648` | `window.pinmind.distill.batchStatus` | 批处理进度页 | `batchId` | `BatchProgress` | yes |
| `distill.batchCancel` | `src/main/ipc.ts:665` | `window.pinmind.distill.batchCancel` | 批处理进度页 | `batchId` | `boolean` | yes |
| `distilledOutputs.list` | `src/main/ipc.ts:678` | `window.pinmind.distilledOutputs.list` | export / review 页面 | filter | `DistilledOutput[]` | yes |
| `distilledOutputs.review` | `src/main/ipc.ts:690` | `window.pinmind.distilledOutputs.review` | review / export flow | `id`, `action`, `data?` | `DistilledOutput` | yes |
| `knowledgeCards.list/get/...` | `src/main/ipc.ts:946` | `window.pinmind.knowledgeCards.*` | 图谱 / 详情页 | various | various | yes |
| `graph.get` | `src/main/ipc.ts:994` | `window.pinmind.graph.get` | 图谱页 | filter | `{ cards, edges }` | yes |
| `datasets.*` | `src/main/ipc.ts:1005` 起 | `window.pinmind.datasets.*` | `AiConsolePage.tsx:599` 等 | various | various | yes |
| `trainingRuns.*` | `src/main/ipc.ts:1098` 起 | `window.pinmind.trainingRuns.*` | `AiConsolePage.tsx:600`、`601` | various | various | yes |
| `modelVersions.*` | `src/main/ipc.ts:1180` 起 | `window.pinmind.modelVersions.*` | `AiConsolePage.tsx:601`、`673`、`678` | various | various | yes |
| `captureItems.*` | `src/main/ipc.ts:1442` 起 | `window.pinmind.captureItems.*` | `CaptureInboxPage.tsx:230`、`OnboardingPage.tsx:183` | various | various | yes |
| `capture.*` stubs | `src/main/ipc.ts:1245` 起 | `window.pinmind.capture.*` | 录屏 / launcher 相关 | various | various | mostly stub |
| `workbench.saveMarkdown` | `src/main/ipc.ts:1677` | `window.pinmind.workbench.saveMarkdown` | 蒸馏工作台 | `content`, `filename?` | `{ success, filePath?, filename?, error? }` | yes |
| `workbench.revealInFinder` | `src/main/ipc.ts:1755` | `window.pinmind.workbench.revealInFinder` | 蒸馏工作台 | `filePath` | `boolean` | yes |

### 3.1 需要特别注意的 stub / 占位接口

- `capture.takeFixedScreenshot`
- `capture.takeRegionScreenshot`
- `capture.takeRegionScreenshotCopy`
- `capture.takeRegionScreenshotSave`
- `capture.takeRegionScreenshotSaveAs`
- `capture.takeRegionScreenshotPin`
- `capture.cancelRegionScreenshot`
- `capture.getSelectionSession`
- `capture.getColorAtPosition`
- `capture.ignoreNextCopy`
- `capture.getRecordingState`
- `capture.requestRecordingStop`
- `capture.getLauncherVisualState`
- `capture.launcherDragStart`
- `capture.launcherDragMove`
- `capture.launcherDragEnd`
- `capture.toggleHub`
- `capture.hideHub`
- `capture.reportHubHeight`

这些接口在 preload 暴露了，但 main 侧基本是返回固定值或空实现，属于 placeholder 级能力，不应在 UI 中被包装成“已完整可用”。

## 4. 配置项与存储来源

### 4.1 存储结论

当前项目没有发现 `localStorage`、`electron-store` 或独立的 JSON 配置文件作为主配置源。真实持久化主要有三类：

- SQLite：`storageRoot/pinmind.db`
- 文件系统：`storageRoot/logs`、`storageRoot/sources`、`storageRoot/captures`、`storageRoot/outputs`
- 环境变量：`LOCAL_MODEL_ENABLED`、`LOCAL_MODEL_MODE`、`LOCAL_MODEL_NAME`、`OLLAMA_BASE_URL`

### 4.2 关键配置项

| 配置项 | 默认值 | 存储位置 | 读取位置 | 写入位置 | 是否持久化 | 备注 |
|---|---|---|---|---|---|---|
| `storageRoot` | `~/PinMind` | `app_settings.value` JSON | `settings.load()`、`settings.getStorageRoot()` | `settings.update()`、`PersonalSpacePanel`、`OnboardingPage` | yes | 实际会被 `resolveStorageRoot()` 规范化。 |
| `pollIntervalMs` | `500` | `app_settings.value` JSON | `settings.load()`、`captureService.init()` | `settings.update()` | yes | 对应需求里的 `scanInterval`。 |
| `autoCapture` | `true` | `app_settings.value` JSON | `captureService.init()` | `settings.update()` | yes | 控制剪贴板监听是否启用。 |
| `hasCompletedOnboarding` | `false` | `app_settings.value` JSON | `App.tsx:70` | `settings.update()` | yes | 控制是否进入 onboarding。 |
| `screenshotShortcut` | `Cmd+Shift+1` | `app_settings.value` JSON | `shortcutManager` | 未在当前设置页直接写 | yes | 目前不在 Settings 页展示。 |
| `dashboardShortcut` | `Cmd+Shift+Space` | `app_settings.value` JSON | `shortcutManager` | 未在当前设置页直接写 | yes | 目前不在 Settings 页展示。 |
| `launchAtLogin` | `false` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | Settings 页真实可写。 |
| `providers` | `[]` | `app_settings.value` JSON | `settings.load()`、`SettingsPage`、`AiConsolePage`、`OnboardingPage` | `settings.update()`、`providers.*` 之后同步写回 | yes | 同时还有独立 `provider_configs` 表，属于双源风险点。 |
| `defaultTier` | `local_light` | `app_settings.value` JSON | `settings.load()`、`Sidebar`、`BottomRuntimeBar`、`AiConsolePage` | `settings.update()` | yes | 不是 `aiProvider`，而是任务默认层级。 |
| `vault.vaultPath` | `''` | `app_settings.value` JSON | `settings.load()`、`TopBar` | `settings.update()` | yes | 同时还有独立 `vault_config.vault_path`，双源。 |
| `vault.defaultFolder` | `''`（默认配置） | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | `vault_config` 的默认值是 `Inbox`，这里与独立表不完全一致。 |
| `vault.pathRule` | `category_date` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 对应需求里的 `pathRule`，名字相同。 |
| `vault.conflictStrategy` | `rename` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 对应 Obsidian 冲突处理。 |
| `vault.autoFrontmatter` | `true` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 同时独立 `vault_config.auto_frontmatter` 也存在。 |
| `vault.frontmatterTemplate` | `{}` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 与独立表同名字段。 |
| `logLevel` | `info` | `app_settings.value` JSON | `logger.getLevel()`、Settings 页 | `logger.setLevel()`、`settings.update()` | yes | 实际日志输出控制。 |
| `scopeMode` | `all` | `app_settings.value` JSON | `CaptureHub`、`settings.runtime.get()` | `settings.update()` | yes | 对应需求里的 `scanScope`。 |
| `scopedApps` | `[]` | `app_settings.value` JSON | `settings.runtime.get()` | `settings.update()` | yes | 对应需求里的 `allowedApps`。 |
| `showFloatingButton` | `true` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 设置页“桌面灵感胶囊”开关。 |
| `capsule` | `DEFAULT_CAPSULE_SETTINGS` | `app_settings.value` JSON | `settings.load()`、`capsuleController` | `settings.update()` | yes | 一整套真实配置。 |
| `minimizeToTray` | `false` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 真实设置。 |
| `backgroundClipboard` | `true` | `app_settings.value` JSON | `captureService.init()` | `settings.update()` | yes | 控制后台剪贴板监听。 |
| `showCaptureToast` | `true` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 真实设置。 |
| `autoAiProcess` | `false` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 真实设置。 |
| `autoExportObsidian` | `false` | `app_settings.value` JSON | `settings.load()` | `settings.update()` | yes | 真实设置，但导出路径与 `vault_config` 存在分流。 |
| `profile` | `DEFAULT_USER_PROFILE` | `app_settings.value` JSON | `Sidebar`、`TopBar`、`PersonalSpacePanel` | `settings.update()` | yes | 用于用户头像和空间信息。 |
| `preferences` | `DEFAULT_USER_PREFERENCES` | `app_settings.value` JSON | `PersonalSpacePanel` | `settings.update()` | yes | 主题、密度、默认起始页、状态栏显示。 |
| `provider_configs` | 无独立默认值 | SQLite `provider_configs` 表 | `providers.list`、`tierRouter`、`realDistiller` | `providers.add/update/delete` | yes | 这是 AI provider 的真实运行时来源。 |
| `vault_config` | `vault_path=''`, `default_folder='Inbox'` | SQLite `vault_config` 表 | `vault.getConfig`、`obsidianExporter`、`TopBar`（优先） | `vault.updateConfig` | yes | 与 `settings.vault` 双写，需谨慎。 |
| `app_settings` | 多字段默认见 `DEFAULT_SETTINGS` | SQLite `app_settings` 表 | `settings.get`、`settings.load` | `settings.update`、`settings.load` 首次创建 | yes | 主设置 JSON 存储。 |
| `LOCAL_MODEL_ENABLED` | `true` | 环境变量 | `localModelService.resolveConfig()` | 启动参数 | no | 不属于持久化设置。 |
| `LOCAL_MODEL_MODE` | `real` | 环境变量 | `localModelService.resolveConfig()` | 启动参数 | no | 影响 mock / real provider。 |
| `LOCAL_MODEL_NAME` | `gemma4:e4b` | 环境变量 | `localModelService.resolveConfig()` | 启动参数 | no | 不是 UI 设置。 |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | 环境变量 | `localModelService.resolveConfig()` | 启动参数 | no | 不是 UI 设置。 |

### 4.3 额外说明

- `storageRoot` 不是数据库内的独立配置文件，而是 SQLite 数据库文件所在根目录。
- `settings.vault` 与 `vault_config` 同时存在，属于重复持久化结构。
- `settings.providers` 与 `provider_configs` 同时存在，属于重复持久化结构。
- `localModel` / `mockEnabled` / `localFirstEnabled` 并不是当前设置页中的持久化字段，它们更多是运行时策略或状态推导。

## 5. 顶部栏 / 底部栏 / 状态卡片信息来源

| 状态信息 | 展示位置 | 组件文件 | 数据来源 | 是否重复 | 建议保留位置 |
|---|---|---|---|---|---|
| 本地优先 | 顶部栏左侧 chip | `src/renderer/components/layout/TopBar.tsx:55` | 固定文案 | 是 | 只保留一个全局位置；如果要更真实，应改为运行时状态而不是静态文案。 |
| Obsidian 已连接 / Obsidian | 顶部栏左侧 chip | `src/renderer/components/layout/TopBar.tsx:76` | `snapshot.vault?.vaultPath ?? snapshot.settings?.vault?.vaultPath` | 是 | 顶部可以保留，因它是全局连接状态。 |
| Vault 选择 | 顶部栏按钮 | `src/renderer/components/layout/TopBar.tsx:94` | `snapshot.vault` / `snapshot.settings.vault` | 是 | 顶部保留即可，点击进入 Obsidian 设置。 |
| AI 服务 | 左侧 Sidebar 底部状态卡 | `src/renderer/components/layout/Sidebar.tsx:121` | 固定值 `"正常"` | 是 | 如果保留，建议只在 AI Console 或调试区保留，不要与底部栏重复。 |
| 本地模型 | 左侧 Sidebar 底部状态卡 | `src/renderer/components/layout/Sidebar.tsx:123` | `settings.defaultTier` 经过 `formatTier()` | 是 | 可保留在 Sidebar 或 AI Console，但不要在多个位置重复硬编码。 |
| 云端模型 | 左侧 Sidebar 底部状态卡 | `src/renderer/components/layout/Sidebar.tsx:125` | 固定值 `"可用"` | 是 | 目前属于静态展示，不足以代表真实云端可用性。 |
| Mock | 左侧 Sidebar 底部状态卡 | `src/renderer/components/layout/Sidebar.tsx:126` | 固定值 `"关闭"` | 是 | 建议移入 AI Console / 开发模式。 |
| AI 服务 | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:21` | 固定值 `"正常"` | 是 | 与 Sidebar 重复，建议只保留一处。 |
| 本地模型 | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:22` | `settings.defaultTier` | 是 | 可保留为轻量运行态摘要。 |
| 云端模型 | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:23` | 固定值 `"可用"` | 是 | 静态信息，建议降级到 AI Console。 |
| Mock | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:24` | 固定值 `"关闭"` | 是 | 建议移出常规 UI。 |
| 数据目录 | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:35` | `settings.storageRoot` | 是 | 这是有用的全局信息，但不应在多个地方重复出现。 |
| 本地数据已保护 | 底部状态栏 | `src/renderer/components/layout/BottomRuntimeBar.tsx:37` | 固定文案 | 是 | 更像隐私宣言，适合放在设置页或帮助页，不必常驻。 |
| 模型状态：Template-based / provider 名称 | 蒸馏工作台状态栏 | `src/renderer/pages/distillation-workbench/components/DistillationStatusBar.tsx:19` | `getCurrentProviderName()` 的当前 provider 名称 | 否 | 仅保留在蒸馏工作台。 |
| 数据目录 | Personal Space 面板 | `src/renderer/components/layout/PersonalSpacePanel.tsx:357` | `settings.storageRoot` | 是 | 这是个人空间里的工作目录信息，不适合在设置页再强调一次。 |
| Obsidian Vault | Personal Space 面板 | `src/renderer/components/layout/PersonalSpacePanel.tsx:394` | `settings.vault.vaultPath` | 是 | 同上。 |
| 默认 AI 层级 | Personal Space 面板 | `src/renderer/components/layout/PersonalSpacePanel.tsx:422` | `settings.defaultTier` | 是 | 同上。 |

### 5.1 建议

1. 顶部栏保留“Obsidian 连接”和“Vault 入口”，这是全局导航里最有价值的信息。
2. 底部栏只保留“数据目录”或“本地保护”其中一个摘要，不要把 AI 状态和 Sidebar 再重复一遍。
3. AI 模型 / Mock / 云端可用性应以 AI Console 为主展示位置。
4. Settings 页中不应该再次铺一层全局状态摘要。

## 6. 右侧详情面板逻辑

| 文件 | 当前行为 | 依赖数据 | 设置页是否需要 | 修改风险 |
|---|---|---|---|---|
| `src/renderer/components/layout/RightInspector.tsx:25` | 全局右侧详情面板，依赖 `selectedItem`；无选中时显示空态 | `SelectedItemContext`、`snapshot.settings.profile.workspaceName` | 不需要 | 如果不加条件，Settings 页会白白占 380px。 |
| `src/renderer/components/layout/AppShell.tsx:55` | 仅在 `large` 模式下渲染 RightInspector | `layoutMode` | 不需要 | 目前 Settings 页在大屏也会带上右侧空面板。 |
| `src/renderer/pages/export/ExportPage.tsx:1204` | 页面内自己的右侧详情面板 | `selectedRow` | 设置页不需要 | 不要和全局 RightInspector 混为一谈。 |

### 6.1 判断

- Settings 页当前不需要全局右侧详情面板。
- 如果隐藏，最佳位置是 `src/renderer/components/layout/AppShell.tsx:80` 左右，增加 `activeView !== 'settings'` 的条件。
- 右侧详情面板应该保留给：
  - `capture-inbox`
  - 可能的内容详情页
  - 未来的 AI 结果 / 项目详情页

### 6.2 推荐改法

- 保留 `RightInspector` 组件本身，不删除。
- 仅在 `AppShell` 中决定是否挂载：
  - `activeView === 'settings'` 时隐藏；
  - `activeView === 'capture-inbox'` 时保留；
  - 其他页面按需再开放。

## 7. Mock / Placeholder / Real 能力区分

### 7.1 Real

这些能力是真实可用的，且会写入 SQLite 或触发真实系统动作：

- `settings.get` / `settings.update`
- `providers.add` / `providers.update` / `providers.delete` / `providers.list` / `providers.testConnection`
- `vault.getConfig` / `vault.updateConfig` / `vault.validatePath` / `vault.pickFolder`
- `workspace.selectDirectory` / `workspace.openDirectory` / `workspace.testWrite`
- `logger.setLevel` / `logger.read`
- `permissions.getStatus` / `permissions.refresh` / `permissions.openSettings`
- `clipboard.getStatus` / `clipboard.toggle`
- `distill.run` / `distill.runSingle` / `distill.batch` / `distilledOutputs.review`
- `captureItems.create/update/delete/list/readImage`
- `export.single` / `export.batch` / `export.retry` / `export.revealInVault`
- `modelVersions.activate` / `rollback`

### 7.2 Mock / Fallback

这些能力不是 UI 假装，而是运行时真实存在的 fallback 策略：

- `src/main/services/distiller/tierRouter.ts:52` 里，当找不到 provider 时会 `useMock: true`。
- `src/main/services/distiller/distillPipeline.ts:176` / `286` 里，`useMock` 时会走 `mockDistiller`。
- `src/main/services/localModel/localModelService.ts:47` 起，`LOCAL_MODEL_MODE=mock` 或 preflight 失败时会降级到 mock provider。
- `src/renderer/pages/distillation-workbench/services/distillationService.ts:48` 默认 provider 名称是 `Template-based`，本质也是 fallback。

### 7.3 Placeholder / Stub

这些是目前最应该在 UI 中降级处理的内容：

- `capture.*` 的一批扩展接口在 preload 暴露，但 main 侧多数是空实现或固定值。
- `settings.runtime.get` 目前只回了少量字段，不是完整运行时配置。
- `Sidebar` / `BottomRuntimeBar` 里的 `AI 服务正常`、`云端模型可用`、`Mock 关闭` 都是固定文案。
- `RightInspector` 的 `LogsTab` 当前只是“暂无日志记录”。
- `SettingsPage` 的 `主题模式` 和 `实时保存` 是展示态，不是完整配置功能。

### 7.4 UI 上应特别标记的项

- Mock 状态
- provider 调试信息
- raw logs
- 没有真实写入能力的按钮
- 仅用于开发或兜底的文案

## 8. UI 重编排前的风险点

1. `AppShell` 统一挂载的 RightInspector 会让 Settings 页在大屏下白白损失一列。
2. `settings.vault` 与 `vault_config` 是双源，重排 UI 时如果只改其中一个，会出现“设置页改了但导出没变”。
3. `settings.providers` 与 `provider_configs` 也是双源，AI 页和 Settings 页需要同步，不然会出现列表状态不一致。
4. Sidebar 和 BottomRuntimeBar 都在展示 AI / Mock / 数据目录，极易造成“看上去很多状态，实际上只是重复”的错觉。
5. `PersonalSpacePanel` 也在改 `storageRoot` 和 `vaultPath`，这是和 Settings 页并行的另一组入口，不能误删。
6. `localModelService` 的真实开关主要来自环境变量，不是 Settings 页，因此不要把 UI 重排理解成“把 mock 开关搬进设置就能控制一切”。
7. `captureItems.exportMarkdown` 明确禁止直接导出，不能因为按钮存在就认为导出入口可用。

## 9. 推荐的新设置页信息架构

### 9.1 建议结构

Settings 页建议改成真正的三层信息架构：

- 左侧主导航：全局产品导航
- 中间设置导航：设置分类
- 右侧主内容：当前设置项详情

同时在 Settings 场景下隐藏全局右侧详情面板。

### 9.2 分组建议

#### 基础设置

- 通用
- 外观
- 隐私与本地优先

当前支撑情况：

- 通用：已支持
- 外观：部分支持
- 隐私与本地优先：已支持

#### 知识库

- Obsidian
- 路径与存储
- 导出规则

当前支撑情况：

- Obsidian：已支持
- 路径与存储：已支持
- 导出规则：部分支持，和 `vault_config` / `autoExportObsidian` 有交叉

#### AI

- 模型管理
- Provider 配置
- 默认层级 / 回退策略
- Mock / 调试

当前支撑情况：

- 模型管理：已支持
- Provider 配置：已支持
- 默认层级 / 回退策略：已支持
- Mock / 调试：只应在 AI Console / 开发者模式展示，不建议常驻在 Settings

#### 捕获

- 剪贴板监听
- 快捷键
- 指定应用
- 捕获入口

当前支撑情况：

- 剪贴板监听：已支持
- 快捷键：部分支持，当前 Settings 页没完整入口
- 指定应用：已支持
- 捕获入口：已支持

#### 高级

- 日志
- 数据维护
- 开发者选项

当前支撑情况：

- 日志：已支持
- 数据维护：部分支持
- 开发者选项：未来规划

### 9.3 应暂时隐藏或降级的内容

- Mock 状态
- provider 原始诊断信息
- raw logs
- 纯展示态的“实时保存”
- 没有真实写入能力的按钮
- 数据目录在多个面板里的重复展示
- 与当前页面无关的全局 AI 状态摘要

## 10. 给 Trae 的后续执行建议

Trae 后续重排 UI 时，建议按下面顺序做：

1. 先把 Settings 页和全局 `AppShell` 解耦，确保 Settings 场景不再挂载全局右侧详情面板。
2. 再收敛状态展示，只保留每类信息的一个主展示位置。
3. 然后统一整理 `settings.vault` / `vault_config` 和 `settings.providers` / `provider_configs` 的来源说明。
4. 最后再做视觉重排和分组优化，不要先画版式再回头修数据源。

Trae 应该基于这份审计报告执行，而不是把界面元素当成可以随便移动的装饰块。

## 11. Codex 核验清单

- [ ] 再确认 `AppShell` 在 `activeView === 'settings'` 时是否隐藏 `RightInspector`
- [ ] 再确认 `settings.vault` 与 `vault_config` 是否需要统一口径
- [ ] 再确认 `settings.providers` 与 `provider_configs` 是否需要统一口径
- [ ] 再确认 `Sidebar` / `BottomRuntimeBar` 中的 AI 状态是否要改成真实运行时状态
- [ ] 再确认 `SettingsPage` 里的 `主题模式` 和 `实时保存` 是否只保留为说明
- [ ] 再确认 `capture.*` stub 是否需要在 UI 中标明为“未实现”
- [ ] 再确认 `PersonalSpacePanel` 是否继续保留数据目录 / Vault / 默认层级入口
- [ ] 再确认 `OnboardingPage` 是否仍是 `providers` 和 `vault` 的第二入口
- [ ] 再确认 `settings.runtime.get` 是否需要从 stub 升级为完整 runtime 配置

---

### 本次盘点的关键文件

- `src/renderer/App.tsx`
- `src/renderer/pages/settings/SettingsPage.tsx`
- `src/renderer/components/layout/AppShell.tsx`
- `src/renderer/components/layout/TopBar.tsx`
- `src/renderer/components/layout/Sidebar.tsx`
- `src/renderer/components/layout/BottomRuntimeBar.tsx`
- `src/renderer/components/layout/RightInspector.tsx`
- `src/renderer/components/layout/PersonalSpacePanel.tsx`
- `src/renderer/pages/ai-console/AiConsolePage.tsx`
- `src/main/ipc.ts`
- `src/preload/index.ts`
- `src/main/settings.ts`
- `src/main/storage.ts`
- `src/shared/types.ts`
- `src/shared/defaultSettings.ts`
- `src/shared/capsuleSettings.ts`
- `src/shared/ai/modelRegistry.ts`
- `src/main/services/distiller/tierRouter.ts`
- `src/main/services/distiller/distillPipeline.ts`
- `src/main/services/localModel/localModelService.ts`
- `src/renderer/pages/distillation-workbench/services/distillationService.ts`

