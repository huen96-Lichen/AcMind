# AcMind System Status Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified system-status foundation for AcMind that can collect local machine state through explicit reader boundaries and route privileged SMC fan read/write operations through a helper-capable abstraction.

**Architecture:** Keep `SystemStatusService` as the snapshot aggregator, but move hardware-specific behavior behind a focused bridge layer. The first pass adds a reusable helper/command abstraction plus fan-control state so the UI can show real fan RPM and adjust fan speed percentage through a single fan-control service instead of direct reader-only logic. Future phases can plug in more hardware domains without changing the dashboard surface.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, macOS IOKit/IOHID, `Process`, `osascript`, existing AcMindKit service model.

---

### Task 1: Add a fan-control bridge and SMC command model

**Files:**
- Create: `AcMindKit/Services/SystemStatus/SystemHardwareBridge.swift`
- Create: `AcMindKit/Services/SystemStatus/SystemSMCBridge.swift`
- Modify: `AcMindKit/Models/SystemStatusModels.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class SystemSMCBridgeTests: XCTestCase {
    func testFanPercentageMapsIntoRPMRange() {
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(0, minRPM: 1200, maxRPM: 4800), 1200)
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(50, minRPM: 1200, maxRPM: 4800), 3000)
        XCTAssertEqual(SystemSMCBridge.percentageToFanRPM(100, minRPM: 1200, maxRPM: 4800), 4800)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SystemSMCBridgeTests/testFanPercentageMapsIntoRPMRange -v`
Expected: fail because `SystemSMCBridge` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

```swift
public enum SystemSMCBridge {
    public static func percentageToFanRPM(_ percentage: Double, minRPM: Double, maxRPM: Double) -> Double {
        let clampedPercentage = min(max(percentage, 0), 100)
        guard maxRPM > minRPM else { return minRPM }
        return minRPM + ((maxRPM - minRPM) * clampedPercentage / 100.0)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter SystemSMCBridgeTests/testFanPercentageMapsIntoRPMRange -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add AcMindKit/Services/SystemStatus/SystemHardwareBridge.swift AcMindKit/Services/SystemStatus/SystemSMCBridge.swift AcMindKit/Models/SystemStatusModels.swift Package.swift AcMindKitTests/SystemSMCBridgeTests.swift
git commit -m "feat: add system smc fan control bridge"
```

### Task 2: Route fan reads and writes through the bridge

**Files:**
- Modify: `AcMindKit/Services/SystemStatus/SystemStatusReaders.swift`
- Modify: `AcMindKit/Services/SystemStatus/SystemStatusService.swift`
- Modify: `AcMindKit/Models/SystemStatusModels.swift`
- Create: `AcMindKit/Services/SystemStatus/SystemFanControlService.swift`
- Create: `AcMindKitTests/SystemFanControlServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class SystemFanControlServiceTests: XCTestCase {
    func testFanControlStateCarriesPercentAndMode() {
        let state = SystemFanControlState(
            fanID: 0,
            name: "Main Fan",
            rpm: 1400,
            minRPM: 1200,
            maxRPM: 4800,
            isAutomatic: false,
            controlPercent: 25
        )

        XCTAssertEqual(state.displayPercent, 25)
        XCTAssertEqual(state.displayRPM, 1400)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SystemFanControlServiceTests/testFanControlStateCarriesPercentAndMode -v`
Expected: fail because `SystemFanControlState` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

```swift
public struct SystemFanControlState: Identifiable, Equatable, Sendable {
    public var id: Int
    public var fanID: Int
    public var name: String
    public var rpm: Double?
    public var minRPM: Double?
    public var maxRPM: Double?
    public var isAutomatic: Bool
    public var controlPercent: Double?

    public var displayPercent: Double? { controlPercent }
    public var displayRPM: Double? { rpm }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter SystemFanControlServiceTests/testFanControlStateCarriesPercentAndMode -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add AcMindKit/Services/SystemStatus/SystemStatusReaders.swift AcMindKit/Services/SystemStatus/SystemStatusService.swift AcMindKit/Models/SystemStatusModels.swift AcMindKit/Services/SystemStatus/SystemFanControlService.swift AcMindKitTests/SystemFanControlServiceTests.swift
git commit -m "feat: route fan status through control service"
```

### Task 3: Add fan control UI for percentage and automatic mode

**Files:**
- Modify: `Features/Native/SystemStatus/SystemStatusView.swift`
- Modify: `App/ServiceContainer.swift`
- Create: `AcMindKit/Protocols/SystemFanControlServiceProtocol.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class SystemStatusViewModelFanTests: XCTestCase {
    func testFanSummaryShowsManualPercentageWhenAvailable() {
        // create a snapshot with one manual fan and assert the summary text
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SystemStatusViewModelFanTests -v`
Expected: fail because the view model has no fan control summary yet.

- [ ] **Step 3: Write the minimal implementation**

```swift
// Add a fan control section with:
// - current RPM
// - automatic/manual segmented control
// - percentage slider mapped to minRPM/maxRPM
// - reset button
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter SystemStatusViewModelFanTests -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Features/Native/SystemStatus/SystemStatusView.swift App/ServiceContainer.swift AcMindKit/Protocols/SystemFanControlServiceProtocol.swift
git commit -m "feat: add fan control ui"
```

### Task 4: Verify the foundation on the current machine

**Files:**
- None

- [ ] **Step 1: Run the package build**

Run: `swift build`
Expected: PASS

- [ ] **Step 2: Run the focused tests**

Run: `swift test --parallel --filter SystemSMCBridgeTests`
Run: `swift test --parallel --filter SystemFanControlServiceTests`
Expected: PASS for the new tests; any unrelated existing failures should be called out separately.

- [ ] **Step 3: Smoke-check the dashboard compile path**

Run: `xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' build`
Expected: PASS or, if an unrelated preexisting issue appears, record the exact failure and stop before broadening scope.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: establish system status phase 1 foundation"
```
