# Companion Layout Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the companion notch pages by removing redundant sections so the overview, AI, music, and status pages feel denser and more balanced without changing navigation behavior.

**Architecture:** Keep the existing three-column dashboard structure and the current top bar. Refactor the page composition only: remove redundant cards, move the most important remaining content into the freed space, and preserve existing view-model actions. This keeps the change localized to the companion presentation layer while avoiding any new routing or adapter work.

**Tech Stack:** SwiftUI, AppKit, AcMindKit, Xcode build/test.

---

### Task 1: Trim the Overview Page

**Files:**
- Modify: `Features/Companion/NotchV2OverviewPage.swift`

- [ ] **Step 1: Remove the redundant shortcut-entry card and let the remaining cards own the page height**

```swift
private var rightColumn: some View {
    VStack(spacing: NotchV2DesignTokens.cardSpacing) {
        if let hint = viewModel.systemAttentionHint {
            NotchV2SystemAttentionHintCard(hint: hint) {
                viewModel.openSystemStatusPage()
            }
        }

        NotchV2Card(title: "系统快览", symbol: "cpu", fillHeight: true, cornerRadius: NotchV2DesignTokens.rightCardRadius) {
            VStack(alignment: .leading, spacing: 6) {
                systemStatusRow(
                    icon: batteryIconName,
                    title: "电池",
                    value: viewModel.batteryStateText,
                    accent: viewModel.batteryAccent
                )

                systemStatusRow(
                    icon: "mic.fill",
                    title: "麦克风",
                    value: viewModel.microphonePermissionStatus.displayName,
                    accent: viewModel.microphonePermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                )

                systemStatusRow(
                    icon: "display",
                    title: "录屏",
                    value: viewModel.screenRecordingPermissionStatus.displayName,
                    accent: viewModel.screenRecordingPermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                )

                systemStatusRow(
                    icon: "accessibility",
                    title: "辅助功能",
                    value: viewModel.accessibilityPermissionStatus.displayName,
                    accent: viewModel.accessibilityPermissionStatus == .authorized ? NotchV2DesignTokens.accentGreen : .orange
                )

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                Button {
                    viewModel.openSystemStatusPage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("进入状态页")
                    }
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NotchV2DesignTokens.accentBlue.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NotchV2DesignTokens.accentBlue.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 2: Keep the left task card and center runtime card as the only content anchors**

```swift
private var centerColumn: some View {
    VStack(spacing: NotchV2DesignTokens.cardSpacing) {
        NotchV2Card(title: "便捷动作", symbol: "bolt.fill", padding: 12, cardAccent: NotchV2DesignTokens.accentBlue) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(viewModel.quickActions) { action in
                        NotchV2ActionButton(
                            icon: action.icon,
                            title: action.title,
                            isSelected: false,
                            action: action.action
                        )
                    }
                }
            }
        }

        NotchV2Card(
            title: "运行中",
            symbol: "sparkles",
            padding: 12,
            cardAccent: viewModel.activeRuntimeSurface.accentColor
        ) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.activeRuntimeSurface.symbol)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(viewModel.activeRuntimeSurface.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.activeRuntimeSurface.title)
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Text(viewModel.activeRuntimeSurface.subtitle)
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                if viewModel.isVoicePriorityActive {
                    MiniVoiceWaveform(mode: viewModel.voiceWaveformMode, accent: viewModel.voiceDisplayAccent)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Verify the overview page still compiles and displays the current task, runtime summary, and system summary**

Run: `xcodebuild build -project AcMind.xcodeproj -scheme AcMind -destination 'platform=macOS'`
Expected: PASS

### Task 2: Trim the AI Page

**Files:**
- Modify: `Features/Companion/NotchV2AgentPage.swift`

- [ ] **Step 1: Remove the AI-status and shortcut cards from the right side, then move conversation history into the left column**

```swift
private var leftColumn: some View {
    NotchV2Card(title: "AI 状态", symbol: "sparkles") {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.activeRuntimeSurface.accentColor)
                    .frame(width: 7, height: 7)
                Text(viewModel.activeRuntimeSurface.title)
                    .font(NotchV2DesignTokens.Typography.title)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(viewModel.activeModelLabel)
                .font(NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(viewModel.activeProviderStatus)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Divider()
                .overlay(NotchV2DesignTokens.separator.opacity(0.45))

            VStack(alignment: .leading, spacing: 6) {
                Text("对话历史")
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)

                if viewModel.quickAskMessages.isEmpty {
                    Text("暂无对话记录")
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.quickAskMessages.suffix(4), id: \.id) { message in
                                historyRow(message: message)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Keep the center conversation card as the primary page body**

```swift
private var centerColumn: some View {
    NotchV2Card(title: "对话", symbol: "message", fillHeight: true, cardAccent: NotchV2DesignTokens.accentBlue) {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chatPreviewMessages, id: \.id) { message in
                    chatBubble(message)
                }

                if viewModel.quickAskIsSending {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在发送...")
                            .font(NotchV2DesignTokens.Typography.caption)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Divider()
                .overlay(NotchV2DesignTokens.separator.opacity(0.45))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("问一句...", text: $viewModel.quickAskDraft)
                        .textFieldStyle(.plain)
                        .font(NotchV2DesignTokens.Typography.body)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.90))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(NotchV2DesignTokens.separator.opacity(0.35), lineWidth: 1)
                        )
                        .submitLabel(.send)
                        .onSubmit {
                            Task { await viewModel.sendQuickAsk() }
                        }

                    Button {
                        Task { await viewModel.sendQuickAsk() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(NotchV2DesignTokens.accentBlue)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.quickAskDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.quickAskIsSending)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Verify the AI page still compiles and the conversation input still works**

Run: `xcodebuild build -project AcMind.xcodeproj -scheme AcMind -destination 'platform=macOS'`
Expected: PASS

### Task 3: Trim the Music Page

**Files:**
- Modify: `Features/Companion/NotchV2MusicPage.swift`

- [ ] **Step 1: Remove the source-and-queue card and the lyrics card, keeping only playback and controls**

```swift
var body: some View {
    NotchV2DashboardLayout(leftColumnWidth: 238, rightColumnWidth: 238) {
        emptyColumn
    } centerColumn: {
        centerColumn
    } rightColumn: {
        rightColumn
    }
}

private var emptyColumn: some View {
    EmptyView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private var rightColumn: some View {
    NotchV2Card(
        title: "播放控制",
        symbol: "slider.horizontal.3",
        fillHeight: true,
        cornerRadius: NotchV2DesignTokens.rightCardRadius
    ) {
        VStack(alignment: .leading, spacing: 8) {
            controlRow(
                icon: "shuffle",
                title: "随机播放",
                isActive: false
            )
            controlRow(
                icon: "repeat",
                title: "循环播放",
                isActive: false
            )
            controlRow(
                icon: "speaker.wave.2.fill",
                title: "音量",
                isActive: false
            )
        }
    }
}
```

- [ ] **Step 2: Keep the center playing card as the only music content block**

```swift
private var centerColumn: some View {
    NotchV2Card(
        title: "正在播放",
        symbol: "play.circle.fill",
        cardAccent: NotchV2DesignTokens.accentGreen
    ) {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.hasPlaybackContext == false {
                emptyState
            } else {
                HStack(alignment: .center, spacing: 12) {
                    AlbumArtworkHeroView(artworkData: viewModel.playbackState.artwork)
                        .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(titleText)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(trackSummaryText)
                            .font(NotchV2DesignTokens.Typography.body)
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        progressRow

                        HStack(spacing: 8) {
                            playbackButton(systemName: "backward.fill", size: 32) {
                                viewModel.previousTrack()
                            }

                            playbackButton(systemName: viewModel.playbackState.isPlaying ? "pause.fill" : "play.fill", size: 40, isPrimary: true) {
                                viewModel.playPause()
                            }

                            playbackButton(systemName: "forward.fill", size: 32) {
                                viewModel.nextTrack()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()
                .overlay(NotchV2DesignTokens.separator.opacity(0.45))

            HStack(spacing: 8) {
                NotchV2StatusPill(icon: "waveform", title: playbackStatusText, accent: NotchV2DesignTokens.cardBackgroundStrong)
                NotchV2StatusPill(icon: "timer", title: "\(currentTimeText) / \(durationText)", accent: NotchV2DesignTokens.innerCardBackground)
                NotchV2StatusPill(icon: "speaker.wave.2", title: volumeText, accent: NotchV2DesignTokens.innerCardBackground)
            }
        }
    }
}
```

- [ ] **Step 3: Verify music playback still compiles and still exposes transport controls**

Run: `xcodebuild build -project AcMind.xcodeproj -scheme AcMind -destination 'platform=macOS'`
Expected: PASS

### Task 4: Trim the System Status Page

**Files:**
- Modify: `Features/Companion/NotchV2OverviewPage.swift`
- Modify: `Features/Companion/NotchV2SystemStatusRail.swift`

- [ ] **Step 1: Remove the left-side key-metrics card and move the runtime summary into the left column**

```swift
private var leftColumn: some View {
    VStack(spacing: NotchV2DesignTokens.cardSpacing) {
        NotchV2Card(title: "运行摘要", symbol: "sparkles", fillHeight: true, cardAccent: viewModel.activeRuntimeSurface.accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.activeRuntimeSurface.accentColor)
                        .frame(width: 7, height: 7)
                    Text(viewModel.activeRuntimeSurface.title)
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(NotchV2DesignTokens.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(viewModel.activeRuntimeSurface.subtitle)
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)

                VStack(alignment: .leading, spacing: 6) {
                    compactRow(label: "焦点", value: currentFocusText)
                    compactRow(label: "最近输入", value: lastTaskText)
                }

                Divider()
                    .overlay(NotchV2DesignTokens.separator.opacity(0.45))

                VStack(alignment: .leading, spacing: 4) {
                    Text("模块状态")
                        .font(NotchV2DesignTokens.Typography.caption)
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    HStack(spacing: 6) {
                        moduleStatusDot(title: "音乐", enabled: viewModel.isModuleEnabled(.music), active: viewModel.playbackState.isPlaying)
                        moduleStatusDot(title: "AI", enabled: viewModel.isModuleEnabled(.agent), active: viewModel.status == .listening || viewModel.status == .transcribing)
                        moduleStatusDot(title: "日程", enabled: viewModel.isModuleEnabled(.schedule), active: false)
                    }
                }
            }
        }

        NotchV2Card(title: "跳转", symbol: "arrow.right.circle", fillHeight: false, cornerRadius: NotchV2DesignTokens.rightCardRadius) {
            VStack(alignment: .leading, spacing: 8) {
                Text("在主窗口查看完整运行状态、进程和问题排查。")
                    .font(NotchV2DesignTokens.Typography.body)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(2)

                Button("打开完整状态窗口") {
                    viewModel.openSystemStatusWindow()
                }
                .buttonStyle(.plain)
                .foregroundStyle(NotchV2DesignTokens.accentBlue)
            }
        }
    }
}
```

- [ ] **Step 2: Keep the right-side system-status rail unchanged except for consuming the freed width**

```swift
struct NotchV2SystemStatusRail: View {
    @ObservedObject var viewModel: SystemStatusViewModel

    var body: some View {
        VStack(spacing: NotchV2DesignTokens.cardSpacing) {
            NotchV2Card(title: "本机状态", symbol: "desktopcomputer", cornerRadius: NotchV2DesignTokens.rightCardRadius) {
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(title: "CPU", value: viewModel.cpuSummary, accent: .blue)
                    statusRow(title: "内存", value: viewModel.memorySummary, accent: .purple)
                    statusRow(title: "电池", value: viewModel.batterySummary, accent: .cyan)
                    statusRow(title: "网络", value: viewModel.networkSummary, accent: .green)

                    Button("查看状态") {
                        (NSApp.delegate as? AppDelegate)?.showSystemStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Verify the system-status page still compiles and the jump button still opens the full window**

Run: `xcodebuild build -project AcMind.xcodeproj -scheme AcMind -destination 'platform=macOS'`
Expected: PASS

### Task 5: Final Validation

**Files:**
- None

- [ ] **Step 1: Run a clean build to flush any stale incremental state**

Run: `xcodebuild clean -project AcMind.xcodeproj -scheme AcMind`
Expected: PASS

- [ ] **Step 2: Rebuild the app after the clean**

Run: `xcodebuild build -project AcMind.xcodeproj -scheme AcMind -destination 'platform=macOS'`
Expected: PASS

- [ ] **Step 3: Confirm the new compact pages still show music playback in collapsed and expanded states**

Run: launch the app and inspect the companion notch pages while music is playing.
Expected: The compact music chip still shows the current track, and the expanded music page still shows the playing card and controls.

