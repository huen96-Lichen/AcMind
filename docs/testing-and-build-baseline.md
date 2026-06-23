# AcMind Testing and Build Baseline

Date: 2026-06-24

This document records the currently verified build and test baseline for AcMind. It is intentionally factual, conservative, and explicit about known failures.

## Environment

| Item | Value |
|---|---|
| macOS | 26.5.1 (25F80) |
| Xcode | 26.5 (17F42) |
| Swift | Apple Swift 6.3.2, swift-driver 1.148.6 |
| Architecture | arm64 |
| Xcode command-line tools | `/Applications/Xcode.app/Contents/Developer` |
| Repository SHA | `1109c5ebea12968aab2ce0334a44b7d9739e5ccd` |

The clean validation pass was run from a detached clean worktree derived from the same commit, without relying on pre-existing `.build` or DerivedData state.

## Supported build commands

| Command | Result | Notes |
|---|---|---|
| `swift package reset` | Pass | Cleans SwiftPM state before resolution. |
| `swift package resolve` | Pass | Resolves dependencies successfully. |
| `swift build` | Pass | Builds the Swift package successfully. |
| `swift test` | Fail | Fails with 63 failed assertions across 9 suites in `AcMindKitTests`; `ToolWorkspaceStateTests` accounts for 18 of them. |
| `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` | Pass | Produces the macOS app bundle. |
| `bash scripts/build.sh --clean` | Pass | Removes `build/`, `.build/`, and `DerivedData/`. |
| `bash scripts/build.sh` | Pass | Debug build succeeds and injects the helper into the app bundle. |
| `bash scripts/build.sh --release` | Pass | Release build succeeds and injects the helper into the app bundle. |
| `bash scripts/build.sh --release --package` | Fail on machines without a Developer ID cert | The script currently aborts during signing lookup because of `set -euo pipefail`. |
| `DEVELOPER_ID=- bash scripts/build.sh --release --package` | Pass | Ad-hoc signing and DMG creation succeed. |
| `bash scripts/build.sh --release --notarize` | Not verified | Requires Apple ID, app-specific password, Team ID, and a notarization-ready signing setup. |

## Application build output

The verified direct Xcode build command is:

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

The portable way to derive the app path is to inspect build settings and combine:

- `TARGET_BUILD_DIR`
- `WRAPPER_NAME`
- `FULL_PRODUCT_NAME`
- `CONFIGURATION_BUILD_DIR`

The verified build settings in this environment reported:

- `TARGET_BUILD_DIR = .../Build/Products/Debug`
- `CONFIGURATION_BUILD_DIR = .../Build/Products/Debug`
- `WRAPPER_NAME = AcMind.app`
- `FULL_PRODUCT_NAME = AcMind.app`

A portable path expression is:

```bash
"$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
```

For this project, Xcode and the release script both produced an unsigned app bundle successfully. The build output is valid, and the bundle exists at the derived path, but this checkpoint did not perform an interactive GUI launch test.

The helper installation is part of the verified build path. The app build includes a helper target and a script phase that places the helper binary at:

```text
Contents/Library/LaunchServices/com.acmind.systemstatus.helper
```

## Test status

| Suite | Status | Classification | CI treatment |
|---|---|---|---|
| Swift package resolution | Passing | Stable | Required |
| Swift package build | Passing | Stable | Required |
| Core non-UI test suites | Passing | Stable | Required |
| `AcMindKitTests` known-failure suites | Mixed | Pending analysis | Keep the full suite blocking until the failures are fixed |

## Known failures

The full test target `AcMindKitTests` has 624 executed tests and 63 failed assertions. Those 63 failures are spread across 9 test suites and 39 failing test methods. They are not all attributable to `ToolWorkspaceStateTests`.

Suite-level breakdown:

| Test target | Test suite | Failing test methods | Failed assertions | Classification |
|---|---|---:|---:|---|
| `AcMindKitTests` | `SystemStatusCleanupTests` | 21 | 36 | A, stale snapshot / expectation drift |
| `AcMindKitTests` | `ToolWorkspaceStateTests` | 10 | 18 | A, stale snapshot / expectation drift |
| `AcMindKitTests` | `MusicNowPlayingParserTests` | 1 | 2 | A, expectation drift |
| `AcMindKitTests` | `MusicSurfacePolishTests` | 2 | 2 | A, expectation drift |
| `AcMindKitTests` | `AppNotificationServiceTests` | 1 | 1 | A, expectation drift |
| `AcMindKitTests` | `ScreenshotProcessingTests` | 1 | 1 | A, expectation drift |
| `AcMindKitTests` | `SettingsMigrationServiceTests` | 1 | 1 | A, expectation drift |
| `AcMindKitTests` | `SettingsPluginCopyTests` | 1 | 1 | A, expectation drift |
| `AcMindKitTests` | `SystemHardwareAccessTests` | 1 | 1 | A, expectation drift |

The test-method breakdown for the failing suites is:

### `SystemStatusCleanupTests`

| Test method | Failed assertions | Classification | Evidence / suspected cause |
|---|---:|---|---|
| `testAgentDashboardUsesCollaborativeWorkspaceSections` | 1 | A, stale test expectation | Surface and layout strings differ from the current implementation. |
| `testAgentDashboardUsesSharedCardSurfaces` | 2 | A, stale test expectation | The expected card-surface strings no longer match current source. |
| `testAgentPageCenterCardUsesRemainingHeight` | 1 | A, stale test expectation | Snapshot expectation is older than the current page layout. |
| `testAgentPageRightColumnIsMoreCompact` | 2 | A, stale test expectation | The expected compact-column strings no longer match current source. |
| `testClipboardViewUsesSharedBackdropAndSidebarCards` | 1 | A, stale test expectation | Backdrop and sidebar surface strings have changed. |
| `testCompanionVoicePanelSupportsEditableDraftAndStageFlow` | 1 | A, stale test expectation | Voice-panel wording / stage flow snapshot is stale. |
| `testContentViewUsesSharedSidebarView` | 1 | A, stale test expectation | Sidebar view expectations no longer match the current implementation. |
| `testLightStatusStripUsesStrongerHighlightedFeedback` | 2 | A, stale test expectation | Highlighted-feedback strings have diverged. |
| `testMainContentRoutesHomeToTheWorkspaceDashboard` | 1 | A, stale test expectation | Current routing strings no longer match the test fixture. |
| `testMainWindowPrunesPlaceholderAcMindWindows` | 2 | A, stale test expectation | Placeholder-window pruning output differs from the snapshot. |
| `testNotchAgentPageUsesComposerStyleQuickAsk` | 4 | A, stale test expectation | Several composer / quick-ask strings are outdated. |
| `testNotchCardsUseSofterPanelShadowAndFill` | 4 | A, stale test expectation | Panel shadow / fill expectations are outdated. |
| `testNotchOverviewUsesAdaptiveActionTiles` | 1 | A, stale test expectation | Adaptive-action-tile strings have drifted. |
| `testNotchTopBarUsesUnifiedStatusPills` | 1 | A, stale test expectation | Top-bar pill strings are stale. |
| `testScheduleDashboardUsesSharedCardShells` | 1 | A, stale test expectation | Card-shell strings differ from current source. |
| `testSettingsViewUsesSharedWorkspaceComponents` | 3 | A, stale test expectation | Multiple workspace-component strings are outdated. |
| `testStatusPillSupportsSelectedFeedback` | 2 | A, stale test expectation | Selected-feedback strings have drifted. |
| `testSystemStatusPageUsesSixCoreTilesAndNarrowRails` | 2 | A, stale test expectation | Tile / rail strings no longer match current source. |
| `testSystemStatusViewDoesNotUseSystemStatusSingleton` | 2 | A, stale test expectation | Singleton-usage expectations are outdated. |
| `testTopBarStatusButtonPrefersSystemStatusPage` | 1 | A, stale test expectation | Status-button routing text no longer matches the snapshot. |
| `testWorkspaceSharedComponentsUseSharedBackdropAndCardSurfaces` | 1 | A, stale test expectation | Shared surface strings are stale. |

### `ToolWorkspaceStateTests`

| Test method | Failed assertions | Classification | Evidence / suspected cause |
|---|---:|---|---|
| `testAdvancedToolPanelsUseSharedBackdropAndCards` | 1 | A, stale test expectation | The test expects `AppVisualBackdrop()`, but current source uses `AppSurfaceBackdrop()`. |
| `testCompletionToolPanelsUseSharedBackdropAndCards` | 2 | A, stale test expectation | The test expects `AppVisualBackdrop()` and `WorkspacePageShell(`, but current source no longer matches those strings. |
| `testCoreToolPanelsUseSharedBackdropAndCards` | 1 | A, stale test expectation | The test expects `AppVisualBackdrop()`, but current source uses `AppSurfaceBackdrop()`. |
| `testHomeAndSettingsUseSharedBackdropSurfaces` | 1 | A, stale test expectation | The test expects older home/settings backdrop wiring. |
| `testModelManagementPanelUsesDetailSurfaceCards` | 1 | A, stale test expectation | The test expects `WorkspacePageShell(`, but current source no longer contains that shell string. |
| `testSystemStatusViewKeepsBackdropVisible` | 2 | A, stale test expectation | The test expects `WorkspacePageShell(`, but the current source no longer contains that shell string. |
| `testToolsViewSurfacesTheThreeStageWorkflow` | 2 | A, stale test expectation | The test still looks for `工具工作流` and `ToolStageHeader`, but `Features/Native/Tools/ToolsView.swift` now uses `AcWorkShell` and `ToolWorkspaceStageRail`. |
| `testToolsViewUsesSharedBackdropAndCardSurfaces` | 6 | A, stale test expectation | The test expects `AppVisualBackdrop()`, but the current source uses `AppSurfaceBackdrop()` and `AcSection` / `AppSurfaceCard` combinations. |
| `testWebDigestPanelUsesSharedSurfaceCards` | 1 | A, stale test expectation | The test expects `AppVisualBackdrop()`, but `Features/Native/Tools/WebDigestPanel.swift` now uses `AppSurfaceBackdrop()`. |
| `testWorkbenchViewShowsProjectNoteArchiveWorkflow` | 1 | A, stale test expectation | The test expects `AppVisualBackdrop()`, but `Features/Native/Workbench/WorkbenchView.swift` now uses `AppSurfaceBackdrop()`. |

### Other failing suites

| Test method | Failed assertions | Classification | Evidence / suspected cause |
|---|---:|---|---|
| `MusicNowPlayingParserTests.testMusicPageEmptyStateDoesNotPresentAcMindAsPlaybackSource` | 2 | A, expectation drift | Empty-state copy / playback-source wording changed. |
| `MusicSurfacePolishTests.testMusicPageQueueEmptyStateUsesSharedContextText` | 1 | A, expectation drift | Shared context text has drifted. |
| `MusicSurfacePolishTests.testMusicPageUsesThreeColumnWorkspace` | 1 | A, expectation drift | Workspace layout text has drifted. |
| `AppNotificationServiceTests.testPlanPrefersInlineToastWhenAcMindIsFrontmostEvenIfDenied` | 1 | A, expectation drift | The expectation still prefers `inlineToast`, but the current implementation returns `appleScriptFallback`. |
| `ScreenshotProcessingTests.testScreenshotPostProcessorResizesAndRoundsCorners` | 1 | A, expectation drift | The expected rounded-corner pixel value no longer matches the current processor output. |
| `SettingsMigrationServiceTests.testRunIfNeededMigratesLegacyPreferencesHotkeysAndVoiceSettings` | 1 | A, expectation drift | The legacy-migration expectation for the voice setting no longer matches current behavior. |
| `SettingsPluginCopyTests.testSettingsViewContainsPluginOverviewCard` | 1 | A, expectation drift | The plugin-overview card string is stale. |
| `SystemHardwareAccessTests.testHelperTransportWinsWhenAvailable` | 1 | A, expectation drift | The helper-transport preference expectation no longer matches the current transport selection. |

The failures are reproducible on every run captured in this checkpoint:

- Run 1, full `swift test`: 624 tests, 63 failures
- Run 2, `swift test --filter ToolWorkspaceStateTests`: 12 tests, 18 failures
- Run 3, `swift test --filter ToolWorkspaceStateTests`: 12 tests, 18 failures
- Run 4, clean-clone `swift test`: 624 tests, 63 failures

The 63 failures are 63 failed assertions, not 63 distinct failing test methods. The full run has 39 failing test methods across 9 suites, and the 18 `ToolWorkspaceStateTests` failures are only part of the total.

## Repeatability results

- The same 39 failing test methods appear every time.
- The actual result is consistently `false` for the failing `contains(...)` assertions.
- The failure set does not appear order-dependent.
- Running the suite individually does not make the failures disappear.
- The failures do not look timing-sensitive.

## CI policy recommendation

Recommended temporary policy: keep the full `swift test` run blocking and let GitHub Actions stay red until the documented baseline is fixed.

This policy is the most honest because 63 failed assertions remain across 9 suites. It also avoids pretending that `ToolWorkspaceStateTests` is the only open issue.

The CI policy should not:

- swallow exit codes;
- use `swift test || true`;
- disable the entire test target;
- delete assertions;
- exclude all UI or layout tests;
- treat the baseline as green while the documented failures still exist.

## Build script validation

Verified:

- `bash scripts/build.sh`
- `bash scripts/build.sh --release`
- `bash scripts/build.sh --release --package` with `DEVELOPER_ID=-`
- `bash scripts/build.sh --clean`

Not yet verified:

- `bash scripts/build.sh --release --notarize`

Important behavior note:

- `bash scripts/build.sh --release --package` currently fails on a machine without a Developer ID certificate because the signing lookup pipeline exits early under `set -euo pipefail`.
- Supplying `DEVELOPER_ID=-` makes the same mode complete with ad-hoc signing and DMG generation.

## Issue drafts

These items remain open and should be tracked explicitly if they are not fixed in this checkpoint:

1. Known-failure suite baseline reconciliation
   - Reproduction: run `swift test`
   - Actual: 624 tests, 63 failures
   - Expected: the full failure map in this document should remain accurate and attributable
   - Classification: stale test expectations across multiple suites
   - Acceptance: refresh or replace the snapshots only after a current source of truth is confirmed
   - Relevant files: `AcMindKitTests/AppNotificationServiceTests.swift`, `AcMindKitTests/MusicNowPlayingParserTests.swift`, `AcMindKitTests/MusicSurfacePolishTests.swift`, `AcMindKitTests/ScreenshotProcessingTests.swift`, `AcMindKitTests/SettingsMigrationServiceTests.swift`, `AcMindKitTests/SettingsPluginCopyTests.swift`, `AcMindKitTests/SystemHardwareAccessTests.swift`, `AcMindKitTests/SystemStatusCleanupTests.swift`, `AcMindKitTests/ToolWorkspaceStateTests.swift`

2. Supported macOS and architecture matrix
   - Reproduction: run the verified build commands on a non-arm64 host or different macOS version
   - Actual: this checkpoint only validated macOS 26.5.1 on arm64
   - Expected: documented minimums and supported host architectures
   - Classification: incomplete documentation
   - Acceptance: README and community docs should list the supported matrix and any unsupported combinations
   - Relevant files: `README.md`, `README.zh-CN.md`, `docs/testing-and-build-baseline.md`

3. Helper installation and signing behavior
   - Reproduction: run `bash scripts/build.sh --release --package` on a machine without a Developer ID cert
   - Actual: the script aborts during signing lookup unless `DEVELOPER_ID=-` is supplied
   - Expected: documented credential requirements and a predictable failure mode
   - Classification: incomplete scripting and documentation contract
   - Acceptance: the script should either handle missing certificates gracefully or document the requirement clearly
   - Relevant files: `scripts/build.sh`, `AcMind.xcodeproj/project.pbxproj`, `Config/Entitlements/*.entitlements`
