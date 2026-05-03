# PinMind Settings 信息架构重编排核验报告

## 1. 核验结论

结论：整体重编排是成功的，Settings 页的三栏语义、全局右侧详情面板隐藏、导航分组收敛、Sidebar / BottomRuntimeBar 的状态降噪都已经落地，且 `tsc` 与生产构建均通过。

但目前仍有 1 个需要优先关注的功能风险：

- `logLevel` 在 Settings 页仍然通过 `settings.update` 写入配置，但主进程没有看到把这次变更同步到 `logger.setLevel` 的链路，因此“修改日志级别立即影响当前运行时”这一真实能力没有闭合。

结论等级：

- P0：未发现
- P1：发现 1 项
- P2：发现少量信息重复和深链同步风险
- P3：少量文案 / 占位表达问题

## 2. 通过项

- `AppShell` 已按 Settings 场景隐藏全局 `RightInspector`，条件为 `mode === 'large' && activeView !== 'settings'`，见 [`src/renderer/components/layout/AppShell.tsx`](../../src/renderer/components/layout/AppShell.tsx) 第 55-84 行。
- `activeView` 在路由层仍稳定保留 `settings`，`App.tsx` 的 `renderPage('settings')` 仍然渲染 `SettingsPage`，见 [`src/renderer/App.tsx`](../../src/renderer/App.tsx) 第 92-183 行。
- `SettingsPage` 仍保留真实接口调用：
  - `settings.get`
  - `settings.update`
  - `providers.list/add/update/delete/testConnection`
  - `app.openStorageRoot`
  - `vault.pickFolder`
  - `vault.validatePath`
  - `permissions.getStatus/refresh/openSettings`
  见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 135-299 行、387-410 行、727-752 行、902-910 行、929-933 行。
- Provider CRUD 没有被降级成本地假保存，新增 / 编辑 / 删除 / 测试连接仍然走真实 IPC 和持久化链路，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 277-299 行。
- `storageRoot` 仍可展示、打开、重新选择并写回，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 387-415 行 和第 650-670 行。
- Obsidian 配置仍保留真实写入路径、路径校验、默认文件夹、路径规则、冲突策略、frontmatter 开关，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 715-807 行。
- `Sidebar` 已移除底部 AI 状态卡片，只保留用户 / 空间入口，见 [`src/renderer/components/layout/Sidebar.tsx`](../../src/renderer/components/layout/Sidebar.tsx) 第 98-119 行。
- `BottomRuntimeBar` 已收敛为数据目录 + 本地数据保护提示，没有再重复 AI / Mock / 云端状态，见 [`src/renderer/components/layout/BottomRuntimeBar.tsx`](../../src/renderer/components/layout/BottomRuntimeBar.tsx) 第 8-35 行。
- `npx tsc --noEmit` 通过，`npm run build` 通过，说明这次重编排没有引入编译级回归。

## 3. 失败项

### P1

- `logLevel` 的 Settings 页控件仍只调用 `settings.update({ logLevel })`，但主进程侧没有看到从 settings 更新自动同步到 `logger.setLevel` 的链路，因此日志级别的修改目前更像“持久化配置”，不是“当前运行时立即生效”的真实能力。
  - 证据：[`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 929-933 行
  - 证据：[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 143-148 行只有独立的 `logger.setLevel`
  - 证据：[`src/main/settings.ts`](../../src/main/settings.ts) 第 68-88 行只负责持久化 settings，没有触发 logger 同步

### P2

- `storageRoot` 在 Settings 页里仍出现两处展示：
  - `general` 下的“存储路径”卡片，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 387-415 行
  - `path-storage` 下的“路径与存储”卡片，见同文件第 657-670 行
  这不影响功能，但仍有信息重复。
- `SettingsPage` 的 tab 同步逻辑只在挂载时读取一次 URL 参数，见同文件第 115-132 行；如果 Settings 页已经处于挂载状态，再通过顶部栏改 `tab`，页面内部分类未必会跟着 URL 变化即时切换。

### P3

- `appearance`、`advanced-data`、`advanced-dev` 中仍有明显“展示态 / 开发中”文案，属于可接受的占位表达，但建议后续统一语气。

## 4. 风险项

- 右侧详情面板虽然已在 Settings 页隐藏，但 `AppShell` 的判定依赖 `activeView !== 'settings'`，所以只要 Settings 路由命名不变就稳定；若后续改路由名，需要同步更新这个条件，见 [`src/renderer/components/layout/AppShell.tsx`](../../src/renderer/components/layout/AppShell.tsx) 第 55-83 行。
- `SettingsPage` 的 `tab` 兼容依赖 `ALL_CATEGORIES`，当前 `obsidian`、`path-storage`、`ai-models` 等新 key 都已纳入；如果后续 Trae 再改分类 key，要同时检查顶部栏与旧入口是否还写着旧参数，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 57-103 行、115-132 行。
- `BottomRuntimeBar` 现在只保留最少状态，如果后续需要调试 AI 运行态，应该把这类信息放回 AI 控制台或日志页，而不是再加回底部栏，见 [`src/renderer/components/layout/BottomRuntimeBar.tsx`](../../src/renderer/components/layout/BottomRuntimeBar.tsx) 第 20-34 行。

## 5. 真实接口回归结果

| 接口 | 结果 | 证据 |
|---|---|---|
| `settings.get` | real | [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 137-140 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 76-79 行 |
| `settings.update` | real | 同文件第 170-187 行、第 191-206 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 81-90 行；[`src/main/settings.ts`](../../src/main/settings.ts) 第 68-88 行 |
| `app.openStorageRoot` | real | 同文件第 397-410 行、第 663-669 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 109-124 行 |
| `vault.pickFolder` | real | 同文件第 407-410 行、第 737-741 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 804-816 行附近 |
| `vault.validatePath` | real | 同文件第 749-752 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 739-752 行附近 |
| `providers.list` | real | 同文件第 154-168 行、第 214-246 行、第 282-288 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 328-379 行附近 |
| `providers.add` | real | 同文件第 282-284 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 336-347 行附近 |
| `providers.update` | real | 同文件第 213-216 行、第 282-288 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 348-366 行附近 |
| `providers.delete` | real | 同文件第 245-248 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 367-379 行附近 |
| `providers.testConnection` | real | 同文件第 260-273 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 470 行附近 |
| `permissions.getStatus` | real | 同文件第 137-140 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 1269-1277 行附近 |
| `permissions.refresh` | real | 同文件第 907-910 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 1269-1277 行附近 |
| `permissions.openSettings` | real | 同文件第 902-905 行；[`src/main/ipc.ts`](../../src/main/ipc.ts) 第 1269-1277 行附近 |
| `logger.setLevel` | real IPC 存在，但 Settings 页未接入 | [`src/main/ipc.ts`](../../src/main/ipc.ts) 第 143-148 行；[`src/preload/index.ts`](../../src/preload/index.ts) 第 561-566 行 |

## 6. 路由与 tab 参数核验

- 顶层路由仍支持 `settings`，见 [`src/renderer/App.tsx`](../../src/renderer/App.tsx) 第 92-123 行、第 157-183 行。
- `onNavigate('settings', { tab: 'obsidian' })` 仍会把 `tab=obsidian` 写进 URL，见 [`src/renderer/components/layout/TopBar.tsx`](../../src/renderer/components/layout/TopBar.tsx) 第 95-114 行。
- `SettingsPage` 的新分类 key 中仍包含 `obsidian`，所以旧入口没有失效，见 [`src/renderer/pages/settings/SettingsPage.tsx`](../../src/renderer/pages/settings/SettingsPage.tsx) 第 27-39 行、第 57-103 行、第 115-132 行。
- 需要注意：当前 tab 同步只在首屏挂载时读取 URL，没有对后续 URL 改动做持续监听，所以“页面已停留在 Settings 内部时，再改 tab 参数”的场景不够稳。

## 7. 响应式布局核验

- `AppShell` 在 large / medium / small / compact 四档布局中仍按原规则排布，Settings 页面仅额外隐藏了全局 `RightInspector`，没有改动其余页面的布局骨架，见 [`src/renderer/components/layout/AppShell.tsx`](../../src/renderer/components/layout/AppShell.tsx) 第 41-85 行。
- `capture-inbox`、`export`、`ai-console`、`knowledge-graph` 等页面不受 `activeView === 'settings'` 条件影响，仍可在 large 模式下显示右侧信息区。
- `Sidebar` 只保留主导航 + 用户卡片，不再塞入 AI 状态模块，因此不会在中小屏引入额外高度压力，见 [`src/renderer/components/layout/Sidebar.tsx`](../../src/renderer/components/layout/Sidebar.tsx) 第 84-119 行。
- `BottomRuntimeBar` 高度固定为 44px，内容已经降到最少，布局塌陷风险低，见 [`src/renderer/components/layout/BottomRuntimeBar.tsx`](../../src/renderer/components/layout/BottomRuntimeBar.tsx) 第 12-35 行。

## 8. TypeScript / Build 结果

| 命令 | 结果 |
|---|---|
| `npx tsc --noEmit` | 通过 |
| `npm run build` | 通过 |

补充说明：

- `npm run build` 中 `vite build` 成功完成，只有常规的 chunk size warning，没有 `Exec format error`。

## 9. 必须修复项

1. 修复 `logLevel` 与 `logger.setLevel` 的运行时同步问题，避免 Settings 页看似可改、实际只写库不生效。
2. 如果希望顶部栏 Vault 快捷入口在 Settings 已打开时也能切换到 Obsidian 子页，需要补一个对 URL `tab` 变化的持续同步，而不只是 mount 时读取一次。

## 10. 建议下一步

1. 先让 Trae 补 `logLevel -> logger.setLevel` 的同步链路，这是唯一明确的 P1。
2. 顺手把 Settings 页的 `tab` 监听补成持续同步，避免顶部栏的 Obsidian 快捷入口在同页内失效。
3. 如果上面两点修完，就可以进入下一轮纯视觉 polish：
   - 进一步收敛重复的 `storageRoot` 展示
   - 统一占位文案语气
   - 继续压缩 Settings 页的辅助说明密度
4. 如果要继续核验，建议下一轮重点看：
   - `SettingsPage` 是否需要在 tab 切换时真正更新 URL 和内部状态
   - `logger.setLevel` 是否应该在 `settings.update` 后由主进程自动触发
   - `provider_configs` / `settings.providers` 双源数据是否仍保持一致

