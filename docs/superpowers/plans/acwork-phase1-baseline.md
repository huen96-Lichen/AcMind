# AcWork Phase 1 Baseline

> Captured: 2026-06-15 11:23 Asia/Shanghai

## Repository

- Branch: `codex/backup-2026-06-13`
- Worktree: contains extensive pre-existing modified and untracked files
- Policy: preserve all existing user changes; do not reset or revert them

## Project

- Xcode project: `AcMind.xcodeproj`
- App scheme: `AcMind`
- Library scheme: `AcMindKit`
- macOS deployment target: 14.0
- Debug app output: `build/Debug/AcMind.app`

## Build Baseline

Command:

```bash
bash scripts/build.sh
```

Result:

- Build succeeded.
- App bundle validation succeeded.
- App Intents metadata extraction completed with no relevant symbols.

## Test Baseline

Command:

```bash
swift test --parallel
```

Result:

- 577 tests discovered.
- 31 test cases failed before AcWork implementation changes.
- Failures include pre-existing behavior assertions and source-text UI assertions.

Known failing suites:

- `AppNotificationServiceTests`
- `MusicNowPlayingParserTests`
- `MusicSurfacePolishTests`
- `SettingsMigrationServiceTests`
- `SettingsPluginCopyTests`
- `SidebarItemTests`
- `ScreenshotProcessingTests`
- `SystemStatusCleanupTests`
- `ToolWorkspaceStateTests`

The AcWork work must not introduce failures outside the recorded baseline. Relevant tests will be updated when their asserted product behavior intentionally changes.

## Data Compatibility Baseline

Existing data directory:

```text
~/Library/Application Support/AcMind
```

Existing database:

```text
~/Library/Application Support/AcMind/acmind-swift.db
```

Observed database size:

```text
9,916,416 bytes
```

Relevant existing tables:

- `source_items`
- `clipboard_items`
- `clipboard_tags`
- `asset_files`
- `distilled_notes`
- `export_records`
- `knowledge_cards`
- `schedule_events`
- `app_settings`

Phase 1 must preserve this directory and database. The unified inbox will aggregate existing models rather than physically merging or renaming these tables.

## Window Baseline

Before AcWork migration:

- SwiftUI scene default: 1500 x 920
- AppKit main window default and minimum: 880 x 650
- Main window was normalized back to 880 x 650 whenever shown

AcWork target:

- Default: 1500 x 920
- Minimum: 1180 x 720
- Restored user sizes above the minimum remain intact

