# AcWork 0.1.0 WorkbenchV2 Preparation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated `WorkbenchV2` static page architecture for the AcWork workspace without removing or rewriting `WorkspaceHomeView`, so the team can land the HTML visual prototype later on a clean, measurable scaffold.

**Architecture:** Keep the legacy home page intact and route to a new `HomeV2` module only when a debug/dev switch is enabled. The V2 surface will use a fixed 1500×888 content canvas, a small shared measurement layer, mock-only component models, and no root scroll view. The first milestone is a stable static skeleton with frames exported to JSON and debug screenshots captured at the target sizes.

**Tech Stack:** SwiftUI, AppKit, existing `LayoutDebugStore` / `LayoutDebugOverlay`, `GeometryReader`, `PreferenceKey`, `AppStorage`, `xcodebuild`.

---

### Task 1: Add WorkbenchV2 constants and feature switch

**Files:**
- Create: `../../../Features/Native/HomeV2/WorkbenchV2Tokens.swift`
- Modify: `../../../App/ContentView.swift`

- [ ] **Step 1: Define the frozen V2 layout constants**

```swift
enum WorkbenchV2Metrics {
    static let defaultWindowWidth: CGFloat = 1500
    static let defaultWindowHeight: CGFloat = 920
    static let defaultContentWidth: CGFloat = 1500
    static let defaultContentHeight: CGFloat = 888
    static let titleBarHeight: CGFloat = 32
    static let minimumWindowWidth: CGFloat = 1180
    static let minimumWindowHeight: CGFloat = 720
    static let sidebarWidth: CGFloat = 216
    static let separatorWidth: CGFloat = 1
}
```

- [ ] **Step 2: Add a debug/dev toggle that can route the home page to V2 without replacing the legacy implementation**

```swift
extension AppState {
    #if DEBUG
    static let defaultUseWorkbenchV2 = true
    #else
    static let defaultUseWorkbenchV2 = false
    #endif
}
```

- [ ] **Step 3: Update `MainContent` so `.home` chooses between `WorkspaceHomeView` and `WorkbenchV2View`**

```swift
case .home:
    if Self.defaultUseWorkbenchV2 {
        WorkbenchV2View(
            mockData: WorkbenchV2MockData.preview(),
            debugOverlayEnabled: true
        )
        .navigationTitle("工作台")
    } else {
        WorkspaceHomeView(...)
            .navigationTitle("工作台")
    }
```

- [ ] **Step 4: Verify the app still compiles with the legacy page untouched**

Run:

```bash
xcodebuild -project "../../../AcMind.xcodeproj" -scheme AcMind -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='-' build
```

Expected: build succeeds.

---

### Task 2: Create isolated V2 layout shell

**Files:**
- Create: `../../../Features/Native/HomeV2/WorkbenchV2View.swift`
- Create: `../../../Features/Native/HomeV2/WorkbenchV2Layout.swift`

- [ ] **Step 1: Implement a root `WorkbenchV2View` that uses a fixed 1500×888 content canvas and no root `ScrollView`**

```swift
struct WorkbenchV2View: View {
    let mockData: WorkbenchV2MockData
    let debugOverlayEnabled: Bool

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width, WorkbenchV2Metrics.defaultContentWidth)
            let contentHeight = min(proxy.size.height, WorkbenchV2Metrics.defaultContentHeight)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: WorkbenchV2Metrics.sidebarWidth)

                Rectangle()
                    .fill(WorkbenchV2Tokens.Color.separator)
                    .frame(width: WorkbenchV2Metrics.separatorWidth)

                WorkbenchV2Layout(mockData: mockData, debugOverlayEnabled: debugOverlayEnabled)
                    .frame(width: contentWidth - WorkbenchV2Metrics.sidebarWidth - WorkbenchV2Metrics.separatorWidth, height: contentHeight)
            }
            .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
        }
        .frame(minWidth: WorkbenchV2Metrics.minimumWindowWidth, minHeight: WorkbenchV2Metrics.minimumWindowHeight)
        .coordinateSpace(name: "AcWorkWindow")
    }
}
```

- [ ] **Step 2: Build the fixed-page geometry for the header, main dashboard grid, and device status bar**

```swift
enum WorkbenchV2Layout {
    static let pagePaddingTop: CGFloat = 20
    static let pagePaddingLeading: CGFloat = 24
    static let pagePaddingBottom: CGFloat = 20
    static let pagePaddingTrailing: CGFloat = 24
    static let headerHeight: CGFloat = 48
    static let headerTop: CGFloat = 20
    static let headerBottomGap: CGFloat = 16
    static let bodyTop: CGFloat = 84
    static let bodyHeight: CGFloat = 700
    static let footerTop: CGFloat = 800
    static let footerHeight: CGFloat = 68
    static let contentWidth: CGFloat = 1235
    static let mainColumnWidth: CGFloat = 927
    static let contextColumnWidth: CGFloat = 292
    static let gutter: CGFloat = 16
}
```

- [ ] **Step 3: Attach debug measurement tags to the major containers**

```swift
#if DEBUG
.layoutDebugRegion("WorkbenchV2View")
.layoutDebugRegion("WorkbenchHeader")
.layoutDebugRegion("MainDashboardGrid")
.layoutDebugRegion("MainColumn")
.layoutDebugRegion("ContextColumn")
.layoutDebugRegion("DeviceStatusBar")
#endif
```

- [ ] **Step 4: Run the build again and check that the new files are included**

Run:

```bash
xcodebuild -project "../../../AcMind.xcodeproj" -scheme AcMind -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='-' build
```

Expected: build succeeds with `WorkbenchV2View` compiled into the app.

---

### Task 3: Create mock-only component files

**Files:**
- Create: `../../../Features/Native/HomeV2/Components/WorkbenchHeader.swift`
- Create: `../../../Features/Native/HomeV2/Components/CurrentFocusCard.swift`
- Create: `../../../Features/Native/HomeV2/Components/PendingItemsCard.swift`
- Create: `../../../Features/Native/HomeV2/Components/RecentCollectionCard.swift`
- Create: `../../../Features/Native/HomeV2/Components/TodayStatusPanel.swift`
- Create: `../../../Features/Native/HomeV2/Components/ActivityTrendCard.swift`
- Create: `../../../Features/Native/HomeV2/Components/QuickActionsCard.swift`
- Create: `../../../Features/Native/HomeV2/Components/DeviceStatusBar.swift`
- Create: `../../../Features/Native/HomeV2/Preview/WorkbenchV2MockData.swift`

- [ ] **Step 1: Define one mock data struct that can initialize every V2 component without global singletons**

```swift
struct WorkbenchV2MockData {
    let header: Header
    let currentFocus: CurrentFocus
    let pendingItems: PendingItems
    let recentCollection: RecentCollection
    let todayStatus: TodayStatus
    let activityTrend: ActivityTrend
    let quickActions: QuickActions
    let deviceStatus: DeviceStatus
}
```

- [ ] **Step 2: Give each component a single responsibility and an isolated preview**

```swift
struct CurrentFocusCard: View {
    let model: WorkbenchV2MockData.CurrentFocus
    var body: some View { EmptyView() }
}
```

- [ ] **Step 3: Keep empty, normal, and warning states explicit in the mock models**

```swift
enum WorkbenchV2State {
    case empty
    case normal
    case warning
}
```

- [ ] **Step 4: Ensure no component imports app state or service singletons**

Run:

```bash
rg -n "AppState.shared|ServiceContainer.shared|EnvironmentObject|@EnvironmentObject" "../../../Features/Native/HomeV2"
```

Expected: no matches for global singletons in V2 component files.

---

### Task 4: Add static charts and measurement export for V2

**Files:**
- Create: `../../../Features/Native/HomeV2/WorkbenchV2Chart.swift`
- Modify: `../../../App/AppDelegate.swift`

- [ ] **Step 1: Define the chart point type for V2 mock trend data**

```swift
struct WorkbenchTrendPoint: Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
}
```

- [ ] **Step 2: Implement a static chart surface that prefers Catmull-Rom smoothing**

```swift
Chart(points) { point in
    LineMark(...)
        .interpolationMethod(.catmullRom)
}
```

- [ ] **Step 3: Fall back to an explicit empty-data state when the mock series is empty**

```swift
if points.isEmpty {
    EmptyTrendStateView()
} else {
    WorkbenchTrendChart(...)
}
```

- [ ] **Step 4: Extend the audit exporter to emit V2 frames and screenshots**

```swift
try exportContentViewScreenshot(
    serviceContainer: serviceContainer,
    outputURL: screenshotsDir.appendingPathComponent("workbench-v2-default-debug.png"),
    contentSize: CGSize(width: 1500, height: 888),
    showLayoutDebugOverlay: true,
    rootViewBuilder: {
        WorkbenchV2View(mockData: .preview(), debugOverlayEnabled: true)
    }
)
```

- [ ] **Step 5: Write the V2 frame JSON beside the screenshot exports**

```swift
let frames = AuditRuntimeFrames(
    window: AuditWindowFrame(width: 1500, height: 888),
    components: [...]
)
```

---

### Task 5: Document the V2 structure and verify the build

**Files:**
- Create: `../../refactor/AcWork_0.1.0_WorkbenchV2_Structure.md`
- Create: `../../refactor/AcWork_0.1.0_WorkbenchV2_Frames.json`

- [ ] **Step 1: Write the structure doc with the fixed canvas, component tree, and responsive rules**

```markdown
# AcWork 0.1.0 WorkbenchV2 Structure
```

- [ ] **Step 2: Emit the V2 runtime frame JSON from the exporter**

```json
{
  "window": { "width": 1500, "height": 888 },
  "components": [
    { "name": "WorkbenchHeader", "x": 241, "y": 20, "width": 1235, "height": 48 }
  ]
}
```

- [ ] **Step 3: Capture the debug screenshots for default and compact sizes**

Run:

```bash
xcodebuild -project "../../../AcMind.xcodeproj" -scheme AcMind -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='-' build
```

Then export:

```bash
"DerivedData/AcMind-aollzkokwuzgdvhjedyzodikxjdb/Build/Products/Debug/AcMind.app/Contents/MacOS/AcMind" --acwork-layout-audit
```

Expected output files:

- `../../refactor/screenshots/workbench-v2-default-debug.png`
- `../../refactor/screenshots/workbench-v2-compact-debug.png`

- [ ] **Step 4: Verify the new V2 files build cleanly and the legacy home page still exists**

Run:

```bash
rg -n "struct WorkspaceHomeView|struct WorkbenchV2View" "../../../Features/Native/Home" "../../../Features/Native/HomeV2"
```

Expected: both implementations are present.

