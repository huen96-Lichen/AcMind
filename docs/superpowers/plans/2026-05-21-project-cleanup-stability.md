# AcMind Project Cleanup and Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up repository structure and documentation, reduce startup/shutdown fragility, and finish the ongoing module split so the app builds and behaves more predictably.

**Architecture:** Keep the repo anchored around a single SwiftPM core (`AcMindKit`) plus the app shell under `App/`. Treat the current `Features/` split as the source of truth, remove legacy path references, and make startup/shutdown state flow explicit instead of relying on fatal crashes, polling, or fire-and-forget cleanup tasks.

**Tech Stack:** Swift 5.9, SwiftPM, Xcode project (`.pbxproj`), SwiftUI, AppKit, SQLite3.

---

### Task 1: Refresh repository docs and clean local noise

**Files:**
- Modify: `README.md`
- Modify: `docs/AcMind_Current_State.md`
- Modify: `docs/ui-shell-guideline.md`
- Modify: `docs/ui-shell-migration-compare.md`
- Modify: `.gitignore`
- Modify: `docs/superpowers/plans/2026-05-21-project-cleanup-stability.md`

- [ ] **Step 1: Rewrite the README to match the current implementation**

```markdown
# AcMind

Local-first AI 信息中枢，基于 SwiftUI + AppKit 构建。

## 当前结构

- `App/`：应用入口、状态和窗口编排
- `AcMindKit/`：模型、协议和服务层
- `Features/`：Native 与 Companion 视图
- `Shared/DesignSystem/`：共享设计系统
- `Resources/`：资源文件
- `scripts/`：构建与辅助脚本

## 构建

```bash
swift package resolve
swift build
swift test --parallel
```

## 备注

- 当前数据库层直接基于 SQLite3。
- 历史迁移残留路径不应再作为新代码入口。
```

- [ ] **Step 2: Rewrite the current-state doc so it describes the real structure**

```markdown
# AcMind 当前状态说明

## 结构现状

当前仓库的主入口是 `App/`，核心服务集中在 `AcMindKit/`，界面层集中在 `Features/`。

## 稳定性关注点

- 启动顺序必须保持可恢复
- 退出清理必须完成
- 文档中的路径必须和工程引用一致
```

- [ ] **Step 3: Tighten `.gitignore` for local noise and migration leftovers**

```gitignore
.DS_Store
**/.DS_Store
build/
.build/
dist/
.trae/
.acmind-tmp/
临时/
```

- [ ] **Step 4: Re-run repo scans to verify the old references are gone**

```bash
rg -n "legacy feature paths|GRDB.swift|docs/Design|TODO|FIXME" README.md docs .gitignore AcMind.xcodeproj Package.swift
find . -name '.DS_Store' | sed -n '1,40p'
```

- [ ] **Step 5: Commit the doc cleanup**

```bash
git add README.md docs/AcMind_Current_State.md docs/ui-shell-guideline.md docs/ui-shell-migration-compare.md .gitignore
git commit -m "docs: align repo docs with current structure"
```

### Task 2: Remove startup and shutdown fragility

**Files:**
- Modify: `App/ServiceContainer.swift`
- Modify: `App/AppDelegate.swift`
- Modify: `App/AppState.swift`
- Modify: `App/AcMindApp.swift`
- Modify: `App/ContentView.swift`
- Test: `AcMindKitTests/*` if new tests are needed for lifecycle behavior

- [ ] **Step 1: Replace `fatalError` access with a safer container accessor**

```swift
public static var shared: ServiceContainer? {
    _shared
}

public static func requireShared(file: StaticString = #fileID, line: UInt = #line) -> ServiceContainer {
    precondition(_shared != nil, "ServiceContainer must be initialized before use.", file: file, line: line)
    return _shared!
}
```

- [ ] **Step 2: Update call sites to guard initialization instead of assuming it**

```swift
guard ServiceContainer.isInitialized(), let container = ServiceContainer.shared else { return }
```

- [ ] **Step 3: Make application shutdown synchronous enough to finish**

```swift
func applicationWillTerminate(_ notification: Notification) {
    isTerminating = true
    fnVoiceMonitor.stop()
    if ServiceContainer.isInitialized() {
        Task { @MainActor in
            await ServiceContainer.requireShared().shutdown()
        }
    }
    NotificationCenter.default.removeObserver(self)
}
```

- [ ] **Step 4: Remove `Timer.publish` polling from `AppState` and bind directly to container state updates**

```swift
@MainActor
public func sync(with container: ServiceContainer) {
    initializationPhase = container.currentPhase
    isInitializing = container.currentPhase != .idle && container.currentPhase != .completed && container.currentPhase != .failed
    initializationError = container.initializationError
    isAppReady = container.isInitialized
}
```

- [ ] **Step 5: Add or update tests covering init and shutdown paths**

```swift
func testServiceContainerCanBeAccessedOnlyAfterSetup() async throws
func testAppStateSyncCopiesContainerPhaseWithoutPolling() async throws
```

- [ ] **Step 6: Run lifecycle-related verification**

```bash
swift test --parallel
swift build
```

- [ ] **Step 7: Commit the lifecycle hardening**

```bash
git add App/ServiceContainer.swift App/AppDelegate.swift App/AppState.swift App/AcMindApp.swift App/ContentView.swift
git commit -m "fix: harden app lifecycle state flow"
```

### Task 3: Finish module split and align project references

**Files:**
- Modify: `AcMind.xcodeproj/project.pbxproj`
- Modify: `Features/Native/Tools/ToolAdvancedPanels.swift`
- Modify: `Features/Native/Tools/ToolPanels.swift`
- Modify: `Features/Native/Agent/AgentWorkspaceView.swift`
- Modify: `Features/Native/Settings/SettingsSuiteView.swift`
- Modify: `Features/Native/Workbench/WorkbenchView.swift`
- Modify: `AcMindKit/Services/Storage/Database.swift`
- Modify: `AcMindKit/Services/Storage/DatabaseRecords.swift`
- Modify: `AcMindKit/Services/Storage/DatabaseJobsAndAssets.swift`
- Modify: `AcMindKit/Services/Storage/SQLiteSupport.swift`

- [ ] **Step 1: Verify the split files already carry the intended responsibilities**

```swift
// DatabaseRecords.swift: record mapping only
// DatabaseJobsAndAssets.swift: job/asset CRUD only
// SQLiteSupport.swift: low-level sqlite wrapper only
```

- [ ] **Step 2: Move remaining logic out of the legacy mega-files into focused files where needed**

```swift
// ToolPanels.swift: entry shell and composition
// ToolPanelsTextUtilities.swift: text helpers
// ToolPanelsMarkdownCleaner.swift: markdown cleanup
// ToolAdvancedPanels.swift: advanced tool shell
```

- [ ] **Step 3: Clean `AcMind.xcodeproj` so only active source paths remain**

```text
Remove references to:
- 旧的 feature 路径
- orphaned recovered references
- duplicate source entries that already live under `Features/...`
```

- [ ] **Step 4: Rebuild and list tests to confirm the project graph is consistent**

```bash
swift test --list-tests
swift build
```

- [ ] **Step 5: Commit the module and project alignment**

```bash
git add AcMind.xcodeproj/project.pbxproj AcMindKit/Services/Storage/*.swift Features/Native/Tools/*.swift Features/Native/Agent/*.swift Features/Native/Settings/*.swift Features/Native/Workbench/*.swift
git commit -m "refactor: align module splits and project references"
```

### Task 4: Final verification and cleanup

**Files:**
- No new source files expected
- Modify only if verification finds a regression

- [ ] **Step 1: Run the full validation suite**

```bash
swift build
swift test --parallel
swift test --list-tests
git status --short
```

- [ ] **Step 2: Confirm there are no stray legacy path references**

```bash
rg -n "legacy feature paths|Recovered References|GRDB.swift|fatalError\\(\"ServiceContainer must be initialized before use" .
```

- [ ] **Step 3: Decide whether to remove any remaining local-only junk files**

```bash
find . -name '.DS_Store'
```

- [ ] **Step 4: Produce a concise handoff note with what changed and what remains**
```
