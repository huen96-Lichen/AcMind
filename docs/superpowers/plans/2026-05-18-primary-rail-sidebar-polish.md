# Primary Rail Sidebar Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the primary rail feel more native on macOS, visually separate the brand header from navigation, and let users resize the rail by dragging its edge while preserving existing workspace window behavior.

**Architecture:** Keep the current custom SwiftUI rail in `App/ContentView.swift` and extend it instead of switching to `NavigationSplitView`. The rail remains the single source of truth for primary navigation state, while `AppState` and `AppDelegate` continue to coordinate collapsed/expanded workspace window sizing through the existing notification pipeline.

**Tech Stack:** SwiftUI, AppKit, existing `AppState`/`AppDelegate` notification bridge, existing design tokens in `Shared/DesignSystem/ACLayout.swift`.

---

### Task 1: Replace the custom traffic-light cluster with native macOS controls

**Files:**
- Modify: `App/ContentView.swift`

- [ ] **Step 1: Write the failing test**

```swift
// No new unit test is needed here because this is a view-only change.
// Verify by running the app and checking the top rail visually.
```

- [ ] **Step 2: Run a visual verification before the change**

Run: launch the app and inspect the top control cluster in the primary rail.
Expected: the current custom three-dot cluster is still visible.

- [ ] **Step 3: Write minimal implementation**

Replace the current `TrafficLightArea` dot buttons with an `HStack` of native-looking macOS window controls:

```swift
private var nativeTrafficLightArea: some View {
    HStack(spacing: 8) {
        Circle().fill(Color(acHex: "#FF5F57")).frame(width: 12, height: 12)
        Circle().fill(Color(acHex: "#FEBC2E")).frame(width: 12, height: 12)
        Circle().fill(Color(acHex: "#28C840")).frame(width: 12, height: 12)
    }
    .frame(height: 44)
    .frame(maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
}
```

- [ ] **Step 4: Run a visual verification after the change**

Run: launch the app and inspect the top control cluster.
Expected: the cluster looks native and no hover icons appear.

- [ ] **Step 5: Commit**

```bash
git add App/ContentView.swift
git commit -m "style: use native macOS window controls in primary rail"
```

### Task 2: Separate the brand header from the navigation list

**Files:**
- Modify: `App/ContentView.swift`
- Modify: `Shared/DesignSystem/ACLayout.swift`

- [ ] **Step 1: Write the failing test**

```swift
// No unit test is required; validate by checking the brand row spacing,
// divider placement, and larger brand treatment in the app window.
```

- [ ] **Step 2: Run a visual verification before the change**

Run: inspect the brand row and the first navigation item in the rail.
Expected: the brand and nav items currently sit too close together.

- [ ] **Step 3: Write minimal implementation**

Introduce a dedicated brand header layout with a larger icon, stronger title weight, extra vertical padding, and a divider below it. Add a layout token if needed:

```swift
static let primaryRailBrandHeight: CGFloat = 52
static let primaryRailDividerInset: CGFloat = 12
```

Update the rail body so the brand header is visually distinct from the navigation list:

```swift
private var appMark: some View {
    VStack(spacing: 0) {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ACColors.accentBlue)
                .frame(width: 28, height: 28)
            Text("AcMind")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

        Divider()
            .overlay(ACColors.border.opacity(0.75))
            .padding(.horizontal, 12)
    }
}
```

- [ ] **Step 4: Run a visual verification after the change**

Run: launch the app and inspect the brand row.
Expected: the logo reads as a brand header, not an interactive nav element, and the divider clearly separates it from the menu.

- [ ] **Step 5: Commit**

```bash
git add App/ContentView.swift Shared/DesignSystem/ACLayout.swift
git commit -m "style: separate primary rail branding from navigation"
```

### Task 3: Add a draggable rail edge and rename the bottom toggle semantics

**Files:**
- Modify: `App/ContentView.swift`
- Modify: `App/AppState.swift`
- Modify: `App/AppDelegate.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Add a small state unit test if needed for persistence, otherwise verify
// the drag behavior and rail width updates manually in the running app.
```

- [ ] **Step 2: Run a pre-change behavior check**

Run: interact with the bottom toggle and resize the main window.
Expected: the bottom button still says "收起/展开" and the rail width is fixed.

- [ ] **Step 3: Write minimal implementation**

Add a persisted `primaryRailWidth` value to `AppState`, clamp it to sensible bounds, and post the existing `AcMind.workspaceRailWidthChanged` notification when it changes while the workspace is collapsed.

Update `PrimaryRail` so the bottom button reads `二级界面打开` / `二级界面关闭` and toggles the second-level surface state, not the rail width.

Add a thin draggable handle on the rail's trailing edge:

```swift
DragGesture(minimumDistance: 0)
    .onChanged { value in
        let nextWidth = clamp(primaryRailWidth + value.translation.width)
        primaryRailWidth = nextWidth
    }
```

Keep the current `collapseWindowToPrimaryRail` and `updateWindowForRailWidth` notification flow so the main window continues to follow the rail width while collapsed.

- [ ] **Step 4: Run verification after the change**

Run: drag the rail edge, collapse the workspace, and toggle the bottom button.
Expected: the rail resizes smoothly, the main window follows the collapsed width, and the bottom control now reflects the secondary view state.

- [ ] **Step 5: Commit**

```bash
git add App/ContentView.swift App/AppState.swift App/AppDelegate.swift
git commit -m "feat: make primary rail resizable and clarify footer toggle"
```

