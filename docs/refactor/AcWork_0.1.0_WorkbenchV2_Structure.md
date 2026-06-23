# AcWork 0.1.0 WorkbenchV2 Structure

## Scope

This document records the new static `WorkbenchV2` scaffold that sits alongside the legacy `WorkspaceHomeView`.

Design rules used for this phase:

- Default content canvas: `1500 × 888`
- Title bar is excluded from the canvas
- Sidebar width: `216`
- Separator width: `1`
- Minimum window: `1180 × 720`
- No root-level vertical `ScrollView`
- No negative spacing to compensate for padding
- No direct replacement of the legacy home view

## Source Map

| Component | Swift File | Parent | Notes |
| --- | --- | --- | --- |
| `WorkbenchV2View` | `Features/Native/HomeV2/WorkbenchV2View.swift` | `MainContent.home` | Root V2 scaffold |
| `WorkbenchHeader` | `Features/Native/HomeV2/Components/WorkbenchHeader.swift` | `WorkbenchV2View` | Header row, title + badges |
| `MainDashboardGrid` | `Features/Native/HomeV2/WorkbenchV2View.swift` | `WorkbenchV2View` | Two-column body wrapper |
| `MainColumn` | `Features/Native/HomeV2/WorkbenchV2View.swift` | `MainDashboardGrid` | Left content column |
| `ContextColumn` | `Features/Native/HomeV2/WorkbenchV2View.swift` | `MainDashboardGrid` | Right context column |
| `CurrentFocusCard` | `Features/Native/HomeV2/Components/CurrentFocusCard.swift` | `MainColumn` | Primary summary card |
| `PendingItemsCard` | `Features/Native/HomeV2/Components/PendingItemsCard.swift` | `MainColumn` | Left queue card |
| `RecentCollectionCard` | `Features/Native/HomeV2/Components/RecentCollectionCard.swift` | `MainColumn` | Left queue card |
| `ActivityTrendCard` | `Features/Native/HomeV2/Components/ActivityTrendCard.swift` | `MainColumn` | Trend/chart card |
| `TodayStatusPanel` | `Features/Native/HomeV2/Components/TodayStatusPanel.swift` | `ContextColumn` | Context overview |
| `QuickActionsCard` | `Features/Native/HomeV2/Components/QuickActionsCard.swift` | `ContextColumn` | Context actions |
| `DeviceStatusBar` | `Features/Native/HomeV2/Components/DeviceStatusBar.swift` | `WorkbenchV2View` | Bottom status strip |
| `WorkbenchV2Card` | `Features/Native/HomeV2/WorkbenchV2View.swift` | Shared base | Reusable card shell |
| `WorkbenchV2EmptyState` | `Features/Native/HomeV2/WorkbenchV2View.swift` | Shared base | Empty state block |
| `WorkbenchTrendChart` | `Features/Native/HomeV2/Components/ActivityTrendCard.swift` | `ActivityTrendCard` | Mock chart preview |

## Layout Skeleton

The V2 scaffold uses a static frame model with a debug-friendly coordinate space named `AcWorkWindow`.

### Default Canvas

- Content size: `1500 × 888`
- Page padding: `24 / 24 / 20 / 20`
- Header frame: `x: 24, y: 20, w: 1452, h: 48`
- Body frame: `x: 24, y: 84, w: 1235, h: 700`
- Footer frame: `x: 24, y: 784, w: 1452, h: 68`
- Main column: `927`
- Context column: `292`
- Gutter: `16`

### Compact Canvas

- Triggered at narrower width or shorter height
- Content size: `1180 × 720`
- Page padding: `16`
- Header frame: `x: 16, y: 16, w: 1148, h: 44`
- Body frame: `x: 16, y: 72, w: 1148, h: 520`
- Footer frame: `x: 16, y: 604, w: 1148, h: 52`
- Main column: `880`
- Context column: `252`
- Gutter: `16`

## Runtime Frame Snapshot

Captured export file:

- `docs/refactor/AcWork_0.1.0_WorkbenchV2_Frames.json`

### Default Export

| Component | X | Y | W | H |
| --- | ---: | ---: | ---: | ---: |
| `WorkbenchV2View` | 0 | 0 | 1500 | 888 |
| `WorkbenchHeader` | 24 | 20 | 1452 | 48 |
| `MainDashboardGrid` | 24 | 84 | 1235 | 700 |
| `MainColumn` | 24 | 84 | 927 | 696 |
| `CurrentFocus` | 24 | 84 | 927 | 214 |
| `待处理` | 24 | 310 | 457 | 208 |
| `最近收集` | 493 | 310 | 457 | 208 |
| `活动趋势` | 24 | 512 | 927 | 286 |
| `ContextColumn` | 967 | 84 | 292 | 604 |
| `今日状态` | 967 | 84 | 292 | 262 |
| `快捷动作` | 967 | 358 | 292 | 330 |
| `DeviceStatusBar` | 24 | 784 | 1452 | 68 |

### Compact Export

| Component | X | Y | W | H |
| --- | ---: | ---: | ---: | ---: |
| `WorkbenchV2View` | 0 | 0 | 1180 | 720 |
| `WorkbenchHeader` | 16 | 16 | 1148 | 44 |
| `MainDashboardGrid` | 16 | 72 | 1148 | 520 |
| `MainColumn` | 16 | 72 | 880 | 492 |
| `CurrentFocus` | 16 | 68 | 880 | 158 |
| `待处理` | 16 | 227 | 434 | 152 |
| `最近收集` | 462 | 212 | 434 | 182 |
| `活动趋势` | 16 | 351 | 880 | 246 |
| `ContextColumn` | 912 | 72 | 252 | 400 |
| `今日状态` | 912 | 72 | 252 | 200 |
| `快捷动作` | 912 | 251 | 252 | 254 |
| `DeviceStatusBar` | 16 | 604 | 1148 | 52 |

## Implementation Notes

- `WorkbenchV2View` uses `GeometryReader` only to resolve static frames and drive the debug overlay.
- `LayoutDebugOverlay` is compiled only in `DEBUG`.
- The legacy `WorkspaceHomeView` remains intact and is still the production fallback.
- The V2 page currently uses mock data only.
- The chart card uses `Charts` with `catmullRom` interpolation to avoid hard line joins.

