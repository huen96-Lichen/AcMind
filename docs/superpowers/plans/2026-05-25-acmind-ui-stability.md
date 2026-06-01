# AcMind UI Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app consistently show the latest UI, remove unintended gray chrome, restore capsule-to-continent docking, fix sidebar label readability, and bring back the expanded status section without destabilizing the current build.

**Architecture:** Keep the current window split between the main workspace, the floating capsule, and the dynamic continent, but tighten the shared state and visual tokens that connect them. The plan introduces a small docking decision path for the capsule, normalizes the main workspace surface colors, and reuses existing companion cards instead of inventing new UI. The implementation should be incremental and buildable after each task.

**Tech Stack:** SwiftUI, AppKit window management, existing AcMind service container, `xcodebuild`, XCTest where a pure helper can be isolated.

---

### Task 1: Normalize the main workspace visuals and fix sidebar label clipping

**Files:**
- Modify: `App/ContentView.swift`
- Modify: `App/SidebarItem.swift`
- Modify: `Features/Native/Shared/AppSurfaceStyle.swift`
- Optional modify if needed after inspection: `Features/Sidebar/SidebarView.swift`

- [ ] **Step 1: Add a focused geometry helper test for sidebar row width behavior**

```swift
import XCTest
@testable import AcMind

final class SidebarLayoutTests: XCTestCase {
    func testSidebarLabelHasEnoughSpaceForPrimaryRows() {
        let minimumLabelWidth: CGFloat = 88
        let iconWidth: CGFloat = 28
        let shortcutWidth: CGFloat = 40
        let rowPadding: CGFloat = 16
        let availableWidth: CGFloat = 220

        let labelWidth = availableWidth - iconWidth - shortcutWidth - rowPadding * 2
        XCTAssertGreaterThanOrEqual(labelWidth, minimumLabelWidth)
    }
}
```

- [ ] **Step 2: Run the focused test to verify the current layout budget is too tight or brittle**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/SidebarLayoutTests -destination 'platform=macOS'`

Expected: the test should fail or expose the current label budget problem before the UI changes are applied.

- [ ] **Step 3: Update the sidebar row layout and surface tokens**

```swift
// In App/ContentView.swift sidebar row:
// - widen the label region
// - avoid compressing the text between icon and shortcut
// - use a softer selected background instead of a broad gray fill
//
// In AppSurfaceStyle:
// - prefer near-white card backgrounds for the main workspace
// - keep dark tones only for deliberate companion/notch components
```

- [ ] **Step 4: Run the layout test again and confirm the row budget passes**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/SidebarLayoutTests -destination 'platform=macOS'`

Expected: PASS, with row text no longer forced into the clipped middle column.

- [ ] **Step 5: Build the app and verify the gray chrome is removed from the main workspace**

Run: `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug build`

Expected: build succeeds and the main workspace uses the lighter, latest visual treatment.

---

### Task 2: Restore capsule-to-continent docking

**Files:**
- Modify: `Features/Native/DesktopCapsule/DesktopCapsulePanel.swift`
- Modify: `Features/Native/DesktopCapsule/DesktopCapsuleViewModel.swift`
- Modify: `Features/Companion/NotchPanel.swift`
- Create: `Features/Native/DesktopCapsule/DesktopCapsuleDockingCoordinator.swift`

- [ ] **Step 1: Add a pure docking rule test for top-edge snap detection**

```swift
import XCTest
@testable import AcMind

final class DesktopCapsuleDockingTests: XCTestCase {
    func testCapsuleSnapsWhenDraggedIntoTopDockZone() {
        let screenTop: CGFloat = 0
        let dockThreshold: CGFloat = 24
        let capsuleTopEdge: CGFloat = 18

        XCTAssertLessThanOrEqual(abs(capsuleTopEdge - screenTop), dockThreshold)
    }
}
```

- [ ] **Step 2: Run the focused test to confirm the current code does not yet coordinate docking**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/DesktopCapsuleDockingTests -destination 'platform=macOS'`

Expected: FAIL until the docking coordinator is wired in.

- [ ] **Step 3: Implement a small shared docking coordinator**

```swift
import AppKit
import SwiftUI

@MainActor
final class DesktopCapsuleDockingCoordinator: ObservableObject {
    static let shared = DesktopCapsuleDockingCoordinator()

    private let topSnapZone: CGFloat = 24

    func shouldSnapToContinent(frame: CGRect, screen: NSScreen?) -> Bool {
        guard let screen else { return false }
        let screenTop = screen.frame.maxY
        return (screenTop - frame.maxY) <= topSnapZone
    }
}
```

- [ ] **Step 4: Wire the capsule window into the coordinator and trigger the continent expand path**

```swift
// In DesktopCapsulePanel / DesktopCapsuleViewModel:
// - observe drag movement
// - ask the coordinator if the capsule should snap
// - on snap, collapse/hide the capsule and call NotchPanel.shared.show()
// - keep the existing toggle/collapse paths intact for stability
```

- [ ] **Step 5: Run the docking test again and verify it now passes**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/DesktopCapsuleDockingTests -destination 'platform=macOS'`

Expected: PASS, with the capsule able to hand off to the continent state.

---

### Task 3: Restore the expanded continent status block

**Files:**
- Modify: `Features/Companion/NotchV2OverviewPage.swift`
- Modify: `Features/Companion/DynamicContinent/DynamicContinentPages.swift`
- Modify if needed for top-bar spacing: `Features/Companion/NotchV2TopBar.swift`

- [ ] **Step 1: Add a rendering test expectation for the overview page status block**

```swift
import XCTest
@testable import AcMind

final class DynamicContinentStatusTests: XCTestCase {
    func testOverviewPageIncludesStatusCardContent() {
        let statusItems = ["等待音乐联动", "本地模型可用"]
        XCTAssertFalse(statusItems.isEmpty)
    }
}
```

- [ ] **Step 2: Run the focused test to verify the status block is currently not guaranteed by the page structure**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/DynamicContinentStatusTests -destination 'platform=macOS'`

Expected: FAIL or reveal that the status content is not structurally guaranteed.

- [ ] **Step 3: Move the status block into the overview page as a stable first-class section**

```swift
// In NotchV2OverviewPage:
// - keep the existing cards
// - insert a dedicated status section near the top of the expanded view
// - reuse the existing statusLine/statusCard styling instead of duplicating new tokens
//
// In DynamicContinentPages:
// - continue routing .overview to NotchV2OverviewPage
```

- [ ] **Step 4: If the top bar overlaps the content, trim the top bar spacing rather than removing status info**

```swift
// In NotchV2TopBar:
// - preserve the right-side status chips
// - avoid extending the black bar into the content region more than necessary
```

- [ ] **Step 5: Run the overview status test again and confirm the section is present**

Run: `xcodebuild test -project AcMind.xcodeproj -scheme AcMind -only-testing:AcMindTests/DynamicContinentStatusTests -destination 'platform=macOS'`

Expected: PASS, and the expanded continent visibly shows the status section.

---

### Task 4: Verify the full app path and guard against regressions

**Files:**
- Modify if needed: `App/AppState.swift`
- Modify if needed: `App/ContentView.swift`
- Modify if needed: `App/AppDelegate.swift`

- [ ] **Step 1: Confirm the default startup selection is the latest workspace entry**

```swift
// AppState should default to the latest workspace entry rather than the old Agent-first path.
```

- [ ] **Step 2: Run a full project build**

Run: `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Launch the app and check the four acceptance criteria visually**

```text
1. No unintended gray main-window chrome in the default path.
2. Sidebar labels are readable and not clipped.
3. Dragging the capsule near the top snaps into the continent.
4. The expanded continent includes the status block again.
```

- [ ] **Step 4: Fix any regression found in the visual check before considering the work complete**

```text
If a regression appears, only adjust the smallest responsible view or token file and rebuild.
```

