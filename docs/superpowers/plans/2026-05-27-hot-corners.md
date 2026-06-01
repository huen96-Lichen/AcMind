# Hot Corners for Dynamic Continent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore four-corner hover triggers with 1.5 second dwell actions, persistent per-corner bindings, and an editable configuration page inside “灵动大陆 & 配置”.

**Architecture:** Keep the hot-corner runtime separate from the configuration UI. Store the bindings as a codable settings field on `AppSettings`, expose them through a narrow `HotCornerSettingsStore` that `SettingsService` conforms to, then let a dedicated `HotCornerManager` monitor mouse movement and dispatch actions without the UI owning any event monitoring. The Dynamic Continent config page becomes the editor for those bindings and remains the only place users manage them.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, existing `ServiceContainer`, existing `SettingsService`

---

### Task 1: Add hot-corner models and persist them through AppSettings

**Files:**
- Create: `AcMindKit/Models/HotCornerConfig.swift`
- Create: `AcMindKit/Protocols/HotCornerSettingsStore.swift`
- Modify: `AcMindKit/Models/AppSettings.swift:7-52`
- Modify: `AcMindKit/Services/Settings/SettingsService.swift:1-117`
- Test: `AcMindKitTests/HotCornerSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class HotCornerSettingsTests: XCTestCase {
    func testDefaultHotCornerSettingsUsesEmptyBindings() {
        let settings = AppSettings()

        XCTAssertEqual(settings.hotCornerSettings.bindings.count, 4)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.topLeft]?.action, .none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.topRight]?.action, .none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.bottomLeft]?.action, .none)
        XCTAssertEqual(settings.hotCornerSettings.bindings[.bottomRight]?.action, .none)
    }

    func testHotCornerSettingsRoundTripsThroughJSON() throws {
        let original = HotCornerSettings(
            bindings: [
                .topLeft: HotCornerBinding(action: .openApp(bundleIdentifier: "com.apple.Safari")),
                .topRight: HotCornerBinding(action: .toggleFeature(featureIdentifier: "dynamicContinent")),
                .bottomLeft: HotCornerBinding(action: .openURL(urlString: "https://example.com")),
                .bottomRight: HotCornerBinding(action: .none)
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotCornerSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HotCornerSettingsTests`
Expected: FAIL because `HotCornerSettings`, `HotCornerBinding`, and `AppSettings.hotCornerSettings` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
public enum HotCornerPosition: String, Codable, CaseIterable, Sendable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var id: String { rawValue }
}

public enum HotCornerAction: Codable, Equatable, Sendable {
    case none
    case openApp(bundleIdentifier: String)
    case openURL(urlString: String)
    case toggleFeature(featureIdentifier: String)
    case openInternalRoute(routeIdentifier: String)
    case showPanel(panelIdentifier: String)
}

public struct HotCornerBinding: Codable, Hashable, Sendable, Equatable {
    public var isEnabled: Bool
    public var hoverDelay: TimeInterval
    public var action: HotCornerAction
}

public struct HotCornerSettings: Codable, Hashable, Sendable, Equatable {
    public var bindings: [HotCornerPosition: HotCornerBinding]
}

public protocol HotCornerSettingsStore: Sendable {
    func getHotCornerSettings() async -> HotCornerSettings
    func updateHotCornerSettings(_ settings: HotCornerSettings) async throws
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HotCornerSettingsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AcMindKit/Models/HotCornerConfig.swift AcMindKit/Models/AppSettings.swift AcMindKit/Protocols/HotCornerSettingsStore.swift AcMindKit/Services/Settings/SettingsService.swift AcMindKitTests/HotCornerSettingsTests.swift
git commit -m "feat: add hot corner settings model"
```

### Task 2: Add the runtime hot-corner manager and wire it into app startup

**Files:**
- Create: `AcMindKit/Services/UI/HotCornerManager.swift`
- Modify: `App/ServiceContainer.swift:87-374`
- Modify: `App/AppDelegate.swift:1-700`
- Test: `AcMindKitTests/HotCornerManagerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class HotCornerManagerTests: XCTestCase {
    func testCornerHitTestingFindsTheCorrectScreenCorner() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let point = CGPoint(x: 5, y: 895)

        XCTAssertEqual(HotCornerGeometry.corner(at: point, in: screen), .topLeft)
    }

    func testHoverDelayTriggersOnlyAfterDwell() async {
        var triggered = false
        let manager = HotCornerManager(actionExecutor: { _ in triggered = true })
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        manager.update(mouseLocation: CGPoint(x: 5, y: 895), screenFrames: [screen])

        try? await Task.sleep(for: .milliseconds(1600))

        XCTAssertTrue(triggered)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HotCornerManagerTests`
Expected: FAIL because `HotCornerManager` and `HotCornerGeometry` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
@MainActor
public final class HotCornerManager {
    public init(actionExecutor: @escaping (HotCornerAction) -> Void = { _ in })
    public func start()
    public func stop()
    public func update(settings: HotCornerSettings)
    public func update(mouseLocation: CGPoint, screenFrames: [CGRect])
}

public enum HotCornerGeometry {
    public static func corner(at point: CGPoint, in screenFrame: CGRect) -> HotCornerPosition?
}
```

The manager should install a global mouse-moved monitor, keep a pending dwell timer per active corner, cancel when the pointer leaves the corner, and execute the bound action after the configured delay.

- [ ] **Step 4: Wire startup**

Update `ServiceContainer` and `AppDelegate` so the manager is created once after settings load, receives the persisted `HotCornerSettings`, and is stopped during shutdown.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter HotCornerManagerTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add AcMindKit/Services/UI/HotCornerManager.swift App/ServiceContainer.swift App/AppDelegate.swift AcMindKitTests/HotCornerManagerTests.swift
git commit -m "feat: restore hot corner runtime"
```

### Task 3: Turn the Dynamic Continent hot-zone section into an editor

**Files:**
- Modify: `Features/Native/DynamicContinent/DynamicContinentConfigView.swift:1-420`
- Create: `Features/Native/DynamicContinent/HotCornerEditorSheet.swift`
- Create: `Features/Native/DynamicContinent/HotCornerBindingRow.swift`
- Test: `AcMindKitTests/DynamicContinentHotCornerViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AcMindKit

final class DynamicContinentHotCornerViewModelTests: XCTestCase {
    func testViewModelLoadsHotCornerBindingsFromSettings() async {
        let service = HotCornerStoreStub(
            settings: HotCornerSettings(
                bindings: [
                    .topRight: HotCornerBinding(
                        isEnabled: true,
                        hoverDelay: 1.5,
                        action: .openApp(bundleIdentifier: "com.apple.Safari")
                    )
                ]
            )
        )
        let viewModel = DynamicContinentConfigViewModel(settings: service)

        await viewModel.loadHotCornerSettings()

        XCTAssertEqual(viewModel.hotCornerBindings[.topRight]?.action, .openApp(bundleIdentifier: "com.apple.Safari"))
    }
}

final class HotCornerStoreStub: HotCornerSettingsStore {
    var settings: HotCornerSettings

    init(settings: HotCornerSettings) {
        self.settings = settings
    }

    func getHotCornerSettings() async -> HotCornerSettings {
        settings
    }

    func updateHotCornerSettings(_ settings: HotCornerSettings) async throws {
        self.settings = settings
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DynamicContinentHotCornerViewModelTests`
Expected: FAIL because the view model does not yet load or save hot-corner bindings.

- [ ] **Step 3: Write minimal implementation**

Add a dedicated hot-corner editor UI inside the “热区配置” section, with:

```swift
HotCornerBindingRow(position: .topLeft, binding: ...)
HotCornerEditorSheet(binding: ...)
```

The view model should load `HotCornerSettings` from a narrow `HotCornerSettingsStore`, expose bindings keyed by `HotCornerPosition`, and save them back through `updateHotCornerSettings(_:)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DynamicContinentHotCornerViewModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Features/Native/DynamicContinent/DynamicContinentConfigView.swift Features/Native/DynamicContinent/HotCornerEditorSheet.swift Features/Native/DynamicContinent/HotCornerBindingRow.swift AcMindKitTests/DynamicContinentHotCornerViewModelTests.swift
git commit -m "feat: add hot corner editor to dynamic continent"
```

### Task 4: Verify the end-to-end build and behavior

**Files:**
- Modify: any files touched above
- Test: `AcMindKitTests/HotCornerSettingsTests.swift`, `AcMindKitTests/HotCornerManagerTests.swift`, `AcMindKitTests/DynamicContinentHotCornerViewModelTests.swift`

- [ ] **Step 1: Run focused tests**

Run:

```bash
swift test --filter HotCornerSettingsTests
swift test --filter HotCornerManagerTests
swift test --filter DynamicContinentHotCornerViewModelTests
```

Expected: all three test targets pass.

- [ ] **Step 2: Build the app**

Run:

```bash
xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Manual sanity check**

Launch the app and confirm:

- “灵动大陆 & 配置” contains an editable “热区配置” section.
- Each corner can be assigned a distinct action.
- Hovering a corner for 1.5 seconds triggers the bound action.
- Turning the feature off stops the hover triggers.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: restore hot corners end to end"
```
