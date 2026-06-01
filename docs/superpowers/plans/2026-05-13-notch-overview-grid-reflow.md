# AcMind 今日页三栏等高重排 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the “今日” overview page into a strict three-column equal-height grid, with a compressed music summary, a single-row quick action strip, a compact task strip, and a matched-height Agent summary card.

**Architecture:** Keep the outer notch window unchanged and do all work inside `NotchV2OverviewPage.swift`, with only minimal supporting tweaks in shared card sizing if needed. The overview body should become one fixed-height row of three equal-height modules, and the center module should become a vertically stacked composition with explicit heights so it no longer grows like a dashboard. Preserve the existing music playback bridge and the music/AI tabs as separate pages.

**Tech Stack:** SwiftUI, AppKit-hosted `NSPanel`, existing `MusicService` playback state, existing `NotchV2` design tokens.

---

### Task 1: Lock the overview page to a fixed equal-height grid

**Files:**
- Modify: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2OverviewPage.swift`

- [ ] **Step 1: Rework the overview root layout to use one fixed-height row**

```swift
let overviewContentHeight: CGFloat = 310

HStack(alignment: .top, spacing: 20) {
    scheduleCard
        .frame(width: 247, height: overviewContentHeight, alignment: .top)

    centerColumn
        .frame(width: 350, height: overviewContentHeight, alignment: .top)

    agentCard
        .frame(width: 194, height: overviewContentHeight, alignment: .top)
}
.padding(.horizontal, 28)
.padding(.top, 14)
.padding(.bottom, 12)
```

- [ ] **Step 2: Verify the compiled body still keeps the overview page as a single row**

Run:
```bash
xcodebuild -scheme AcMind -project "/Volumes/White Atlas/03_Projects/AcMind_V2.0/AcMind.xcodeproj" -configuration Debug build
```
Expected: the build reaches SwiftUI compilation for `NotchV2OverviewPage.swift` without layout-related compile errors.

- [ ] **Step 3: Commit the fixed grid shell before touching internal card contents**

```bash
git add Features/Companion/NotchV2OverviewPage.swift
git commit -m "feat: lock overview page to equal-height three-column grid"
```

### Task 2: Compress the left and right summary cards to match the shared baseline

**Files:**
- Modify: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2OverviewPage.swift`
- Modify: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2Card.swift` if the default card padding or header spacing needs to be tightened further

- [ ] **Step 1: Make the schedule card a full-height summary module with bottom-aligned “查看全部”**

```swift
NotchV2Card(title: "日程", subtitle: "今天", symbol: "calendar", padding: 18) {
    VStack(alignment: .leading, spacing: 12) {
        // three schedule rows
        Spacer(minLength: 0)
        Text("查看全部 →")
    }
}
```

- [ ] **Step 2: Make the Agent card a summary module with bottom-aligned waveform**

```swift
NotchV2Card(title: "Agent", subtitle: "在线", symbol: "bubble.left.and.bubble.right", padding: 16) {
    VStack(alignment: .leading, spacing: 10) {
        // status rows
        Spacer(minLength: 0)
        waveformRow
    }
}
```

- [ ] **Step 3: Re-run the build to ensure the fixed-height cards still compile**

Run:
```bash
xcodebuild -scheme AcMind -project "/Volumes/White Atlas/03_Projects/AcMind_V2.0/AcMind.xcodeproj" -configuration Debug build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit the summary-card compression**

```bash
git add Features/Companion/NotchV2OverviewPage.swift Features/Companion/NotchV2Card.swift
git commit -m "feat: tighten overview summary cards"
```

### Task 3: Rebuild the center column as a compact three-part stack

**Files:**
- Modify: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2OverviewPage.swift`

- [ ] **Step 1: Replace the center column with an explicit three-part stack**

```swift
VStack(spacing: 14) {
    musicSummaryCard
        .frame(height: 108)

    quickToolsCard
        .frame(height: 88)

    currentTaskCard
        .frame(height: 60)
}
.frame(width: 350, height: overviewContentHeight, alignment: .top)
```

- [ ] **Step 2: Compress the music summary into a true overview summary card**

```swift
HStack(spacing: 12) {
    AlbumArtworkView(artworkData: viewModel.playbackState.artwork, size: 56)

    VStack(alignment: .leading, spacing: 5) {
        Text(title)
        Text("\(artistLabel) · \(albumLabel)")
        ProgressView(value: progressValue)
    }

    Spacer(minLength: 8)
    playbackControls
}
```

The target is a card that reads as a compact summary, not a full player. Keep the large music page untouched in `NotchV2MusicPage.swift`.

- [ ] **Step 3: Keep the quick actions to a single row of four equal buttons**

```swift
HStack(spacing: 12) {
    ForEach(viewModel.quickActions) { action in
        NotchV2ActionButton(icon: action.icon, title: action.title, isSelected: false, action: action.action)
            .frame(width: 76, height: 84)
    }
}
```

- [ ] **Step 4: Keep the task strip inside the center column and aligned to its width**

```swift
NotchV2Card(title: nil, subtitle: nil, symbol: nil, padding: 14) {
    HStack(spacing: 8) {
        Text("任务 · 3")
        Text("16:30")
        Text("音乐联动评估")
        Spacer()
    }
}
```

- [ ] **Step 5: Build after the center-column rewrite**

Run:
```bash
xcodebuild -scheme AcMind -project "/Volumes/White Atlas/03_Projects/AcMind_V2.0/AcMind.xcodeproj" -configuration Debug build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit the center-column reflow**

```bash
git add Features/Companion/NotchV2OverviewPage.swift
git commit -m "feat: compress overview center column"
```

### Task 4: Verify the tabs and playback bridge stay independent

**Files:**
- Inspect only: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2MusicPage.swift`
- Inspect only: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2AgentPage.swift`
- Inspect only: `/Volumes/White Atlas/03_Projects/AcMind_V2.0/Features/Companion/NotchV2ViewModel.swift`

- [ ] **Step 1: Confirm the music tab still uses the dedicated music page**

```swift
case .music:
    NotchV2MusicPage(viewModel: viewModel)
```

- [ ] **Step 2: Confirm the AI tab still uses the dedicated Agent page**

```swift
case .agent:
    NotchV2AgentPage(viewModel: viewModel)
```

- [ ] **Step 3: Confirm playback control still routes through the existing bridge**

```swift
func playPause() {
    MusicService.shared.togglePlay()
}
```

- [ ] **Step 4: Run a final build to verify the overview rewrite did not disturb the other tabs**

Run:
```bash
xcodebuild -scheme AcMind -project "/Volumes/White Atlas/03_Projects/AcMind_V2.0/AcMind.xcodeproj" -configuration Debug build
```
Expected: `BUILD SUCCEEDED`.

---

### Coverage Check

- Equal-height three-column overview grid: Task 1
- Left summary card compression: Task 2
- Right summary card compression: Task 2
- Center column compact three-part stack: Task 3
- Music page isolation: Task 4
- AI page isolation: Task 4
- Playback bridge preservation: Task 4
- Build verification: Tasks 1, 2, 3, 4

