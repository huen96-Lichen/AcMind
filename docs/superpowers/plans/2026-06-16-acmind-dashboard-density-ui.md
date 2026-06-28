# AcMind Dashboard Density UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework AcMind's system status page into a denser dashboard-first layout that keeps the helper install, fan control, and system health surfaces visible without losing the existing real system-state functionality.

**Architecture:** Keep the current system status snapshot and helper transport untouched. Recompose `SystemStatusView` into a tighter three-zone hierarchy: a compact top summary, a dense central metrics/timeline body, and a right-side control/repair rail. Prefer reshaping the existing view tree and reusing the current card primitives instead of introducing new state containers.

**Tech Stack:** SwiftUI, AcMindKit system status snapshot/service layer, existing `AppSurfaceCard` and status badge components, Xcode/macOS build + `swift test`.

---

### Task 1: Map the current status-page surface area

**Files:**
- Modify: `../../../Features/Native/SystemStatus/SystemStatusView.swift`

- [ ] **Step 1: Identify the current sections that must survive the redesign**

```text
Retain these user-visible surfaces in the new layout:
- top summary / refresh state
- KPI row for CPU, memory, network, disk, battery or thermal state
- trend overview
- diagnostics list
- permissions / capability state
- helper install card
- fan manual control card
```

- [ ] **Step 2: Inspect the current view tree and note the blocks that can be reused**

```text
Run: rg -n "dashboardOverviewCard|dashboardUtilityGrid|dashboardBottomRow|dashboardPermissionStateStrip|dashboardHelperInstallerCard|dashboardFanControlPanel" "../../../Features/Native/SystemStatus/SystemStatusView.swift"
Expected: the current page already exposes reusable dashboard blocks that can be recomposed instead of rewritten.
```

- [ ] **Step 3: Verify the current view still builds before layout surgery**

```text
Run: xcodebuild -project "../../../AcMind.xcodeproj" -scheme AcMind -configuration Debug -destination 'platform=macOS' build
Expected: BUILD SUCCEEDED
```

- [ ] **Step 4: Commit the task boundary in your working notes**

```text
No code change for this step. Record that the redesign will stay inside SystemStatusView first, then only touch shared cards if density requires it.
```

### Task 2: Recompose the page into a dense dashboard layout

**Files:**
- Modify: `../../../Features/Native/SystemStatus/SystemStatusView.swift`
- Optional modify: `../../../Features/Native/Shared/AppSurfaceStyle.swift`

- [ ] **Step 1: Replace the current tall page flow with a denser two-level layout**

```swift
var body: some View {
    AcWorkShell(
        title: "状态",
        subtitle: "真实采样 · \(viewModel.lastUpdatedText) · \(viewModel.refreshHint)",
        headerActions: AnyView(dashboardHeaderActions),
        leadingRailWidth: AppSurfaceTokens.Layout.leadingRailWidth,
        trailingRailWidth: DashboardLayout.sideCardWidth,
        leadingRail: { dashboardLeadingRail },
        content: { dashboardContent },
        trailingRail: { dashboardTrailingRail }
    )
    .onAppear {
        viewModel.startMonitoring()
        helperInstaller.refreshStatus()
        Task {
            await fanControlService.refresh()
            syncFanControlDraftFromSnapshot()
        }
    }
    .onDisappear { viewModel.stopMonitoring() }
    .onChange(of: viewModel.snapshot.fanControlStates) { _ in
        syncFanControlDraftFromSnapshot()
    }
}
```

- [ ] **Step 2: Pull the core health KPIs into the upper-middle grid and keep them visually dominant**

```swift
private var dashboardHealthSection: some View {
    VStack(alignment: .leading, spacing: 10) {
        SectionHeader(
            title: "健康摘要",
            description: "CPU、内存、网络、磁盘和电源的当前状态。",
            status: viewModel.healthSectionStatus,
            actions: [SectionHeaderAction(title: "刷新", icon: "arrow.clockwise") { viewModel.refresh() }]
        )

        GeometryReader { proxy in
            let columns = proxy.size.width < 560 ? 1 : 2

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: columns), spacing: 8) {
                MetricCard(label: "CPU", primaryValue: viewModel.cpuSummary, unit: "%", trend: viewModel.loadAverageSummary, state: viewModel.cpuStateSummary, lastUpdated: viewModel.lastUpdatedText, tint: .blue) {
                    DashboardSparklineChart(values: viewModel.cpuHistory, tint: .blue, lineWidth: 2.4).frame(width: 52, height: 52)
                }
                MetricCard(label: "内存", primaryValue: viewModel.memorySummary, unit: "GB", trend: viewModel.memoryPressureSummary == "—" ? viewModel.memoryUsagePercentSummary : viewModel.memoryPressureSummary, state: viewModel.memoryStateSummary, lastUpdated: viewModel.lastUpdatedText, tint: .purple) {
                    DashboardRingGauge(progress: viewModel.snapshot.memoryUsagePercent, tint: .purple, label: viewModel.memoryUsagePercentSummary).frame(width: 52, height: 52)
                }
                MetricCard(label: "网络", primaryValue: viewModel.networkSummary, trend: viewModel.networkInterfaceSummary, state: viewModel.networkStateSummary, lastUpdated: viewModel.lastUpdatedText, tint: .green) {
                    DashboardSparklineChart(values: viewModel.networkHistory, tint: .green, lineWidth: 2.2).frame(width: 52, height: 52)
                }
                MetricCard(label: "磁盘", primaryValue: viewModel.diskSummary, unit: "%", trend: viewModel.diskTrendSummary, state: viewModel.diskStateSummary, lastUpdated: viewModel.lastUpdatedText, tint: .orange) {
                    DashboardRingGauge(progress: viewModel.snapshot.diskUsagePercent, tint: .orange, label: viewModel.diskSummary).frame(width: 52, height: 52)
                }
            }
        }
        .frame(height: viewModel.hasBattery ? 340 : 280)
    }
}
```

- [ ] **Step 3: Compress the remaining content into short diagnostic blocks instead of tall narrative cards**

```swift
private var dashboardDiagnosticsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
        SectionHeader(
            title: "诊断区",
            description: "进程、传感器、接口和功率来源。",
            status: viewModel.diagnosticSectionStatus
        )

        dashboardUtilityGrid
        dashboardBottomRow
    }
}
```

- [ ] **Step 4: Keep the helper installer and fan control visible in the right rail, not buried below the fold**

```swift
private var dashboardCapabilitySection: some View {
    VStack(alignment: .leading, spacing: 10) {
        SectionHeader(
            title: "权限与能力",
            description: "哪些数据因硬件、系统或授权不可用。",
            status: viewModel.capabilitySectionStatus
        )

        StateContainer(phase: viewModel.capabilityContainerPhase(refreshAction: { viewModel.refresh() })) {
            VStack(alignment: .leading, spacing: 10) {
                dashboardPermissionStateStrip
                ForEach(viewModel.snapshot.permissions.filter { $0.isAvailable == false }.prefix(3)) { permission in
                    PermissionStatusCard(permission: permission) {
                        openPermissionSettings(for: permission)
                    }
                }
                dashboardHelperInstallerCard
                dashboardCapabilityReasonList
            }
        }
    }
}
```

- [ ] **Step 5: If the dense layout feels visually loose, tighten shared spacing tokens instead of changing every card**

```swift
// Only touch if needed for density:
// - AppSurfaceTokens.Layout.pagePadding
// - AppSurfaceTokens.Layout.sectionSpacing
// - AppSurfaceTokens.Layout.cardSpacing
// Keep the values small and consistent so all pages remain coherent.
```

### Task 3: Rebalance the top summary and side rails

**Files:**
- Modify: `../../../Features/Native/SystemStatus/SystemStatusView.swift`

- [ ] **Step 1: Turn the left rail into a compact operational summary**

```swift
private var dashboardLeadingRail: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            AppSurfaceCard(title: "系统摘要", subtitle: "轻量概览", padding: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    dashboardMiniLine(title: "CPU", value: viewModel.cpuSummary)
                    dashboardMiniLine(title: "内存", value: viewModel.memorySummary)
                    dashboardMiniLine(title: "网络", value: viewModel.networkSummary)
                    if viewModel.hasBattery { dashboardMiniLine(title: "电池", value: viewModel.batterySummary) }
                    dashboardMiniLine(title: "磁盘", value: viewModel.diskSummary)
                }
            }
            AppSurfaceCard(title: "硬件传感器", subtitle: "SMC 实时", padding: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.hasTemperatureData, let sensor = viewModel.snapshot.temperatureSensors.first(where: { $0.isAvailable && $0.value != nil }) {
                        let color = temperatureColor(sensor.value ?? 0)
                        dashboardMiniLineColored(title: "温度", value: viewModel.temperaturePrimaryValue, tint: color)
                    } else {
                        dashboardMiniLine(title: "温度", value: "采样中")
                    }
                    if viewModel.hasFanData {
                        dashboardMiniLine(title: "风扇", value: viewModel.fanPrimaryValue)
                    } else {
                        dashboardMiniLine(title: "风扇", value: "采样中")
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Keep the right rail focused on repair, helper, and control rather than raw telemetry**

```swift
private var dashboardTrailingRail: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            AppSurfaceCard(title: "状态指示", subtitle: "图标化状态矩阵", padding: 5) {
                VStack(alignment: .leading, spacing: 4) {
                    dashboardStatusMatrix.frame(height: DashboardLayout.statusMatrixHeight, alignment: .topLeading)
                    dashboardPermissionStateStrip.frame(height: DashboardLayout.permissionStripHeight, alignment: .topLeading)
                }
            }
        }
        .padding(16)
    }
}
```

- [ ] **Step 3: Make the fan control card feel like a first-class action surface**

```swift
private var dashboardFanControlPanel: some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("手动调速")
            Spacer(minLength: 0)
            Text(fanControlSummary)
        }
        Picker("风扇", selection: Binding(get: { selectedFanIndex }, set: { newValue in selectedFanIndex = newValue; syncFanControlDraftFromSnapshot() })) {
            ForEach(fanControlCandidates, id: \.fanIndex) { fan in
                Text(fan.name).tag(fan.fanIndex)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        Slider(value: Binding(get: { fanPercentDraft }, set: { newValue in fanPercentDraft = newValue }), in: 0...100, step: 1)
        HStack(alignment: .center, spacing: 6) {
            Button("自动") { Task { _ = await fanControlService.setFanAutomatic(fanIndex: selectedFanIndex) } }
            Button("应用") { Task { _ = await fanControlService.setFanPercentage(fanIndex: selectedFanIndex, percentage: fanPercentDraft) } }
            Button("重置") { Task { _ = await fanControlService.resetFanControl() } }
        }
    }
}
```

### Task 4: Verify the redesign without regressing helper or status behavior

**Files:**
- Modify: `../../../Features/Native/SystemStatus/SystemStatusView.swift`
- Modify if needed: `../../../Features/Native/Shared/AppSurfaceStyle.swift`

- [ ] **Step 1: Build the app after the layout rewrite**

```text
Run: xcodebuild -project "../../../AcMind.xcodeproj" -scheme AcMind -configuration Debug -destination 'platform=macOS' build
Expected: BUILD SUCCEEDED
```

- [ ] **Step 2: Run the helper transport tests again**

```text
Run: swift test --filter SystemHardwareAccessTests -v
Expected: The helper transport tests pass with 0 failures.
```

- [ ] **Step 3: Run a focused sanity check on the system status reader suite**

```text
Run: swift test --filter NetworkStatusReaderTests -v
Expected: Bluetooth parsing and reader availability checks still pass.
```

- [ ] **Step 4: Capture a screenshot of the page if the browser tooling is available**

```text
Open the AcMind system status page in the local browser, confirm the dashboard-density layout reads clearly, and check that the helper card and fan control remain visible in the right rail.
```

- [ ] **Step 5: Commit the final UI refinement**

```bash
git add ../../../Features/Native/SystemStatus/SystemStatusView.swift
git add ../../../Features/Native/Shared/AppSurfaceStyle.swift
git commit -m "feat: tighten system status into denser dashboard layout"
```
