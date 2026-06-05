# AcMind P0 Voice and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the remaining P0 gaps in settings, voice capture, microphone preference wiring, and simplified voice-service paths so every surfaced control is either real, clearly read-only, or clearly a pure preference.

**Architecture:** Keep the existing separation between UI state, local preferences, and runtime services. Settings changes should flow through `SettingsViewModel` into the appropriate service or preference store, while voice capture should stop through a real event-driven control path instead of a fixed sleep. Update text in companion and notch surfaces only where it prevents a false impression of functionality.

**Tech Stack:** SwiftUI, AppKit, AVFoundation, Speech, existing AcMindKit services, XCTest.

---

### Task 1: Classify and fix remaining settings items

**Files:**
- Modify: `Features/Native/Settings/SettingsView.swift`
- Modify: `Features/Native/Settings/SettingsSuiteView.swift`
- Modify: `App/ViewModels/SettingsViewModel.swift`
- Test: `AcMindKitTests/SettingsLocalPreferencesTests.swift`
- Test: `AcMindKitTests/AppNotificationServiceTests.swift`

- [ ] **Step 1: Write/adjust tests for the settings semantics**

```swift
func testUpdateAvailableNotificationsArePurePreferenceOnly() async {
    let suiteName = "AcMind.SettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    SettingsLocalPreferences(updateAvailableNotificationsEnabled: false).save(to: defaults)
    XCTAssertFalse(SettingsLocalPreferences.loadOrDefault(from: defaults).updateAvailableNotificationsEnabled)
}
```

- [ ] **Step 2: Change UI labels so no control implies an unavailable runtime**

```swift
SettingsInfoRow(
    label: "更新可用时通知",
    value: "仅保留偏好，当前未接入实际更新检查"
)
```

- [ ] **Step 3: Keep real runtime-backed controls enabled and remove any stale faux controls**

```swift
Toggle("自动采集剪贴板", isOn: $viewModel.autoCaptureClipboard)
Toggle("仅在激活应用时采集", isOn: $viewModel.captureOnlyWhenAppActive)
Toggle("启用截图捕获", isOn: $viewModel.captureScreenshotEnabled)
```

- [ ] **Step 4: Run the focused tests**

Run: `swift test --parallel --filter SettingsLocalPreferencesTests`
Expected: passes

---

### Task 2: Wire microphone preference into the voice recording path

**Files:**
- Modify: `Features/Native/VoiceEntry/VoiceEntryView.swift`
- Modify: `AcMindKit/Services/Voice/VoiceMicrophonePreferenceStore.swift`
- Modify: `AcMindKit/Services/Voice/VoiceService.swift`
- Modify: `AcMindKit/Protocols/VoiceServiceProtocol.swift`
- Test: `AcMindKitTests/VoiceMicrophonePreferenceStoreTests.swift`

- [ ] **Step 1: Add a test that the selected microphone preference is consumed by the recorder**

```swift
func testPreferredMicrophoneNameIsLoadedAndSaved() {
    let suiteName = "AcMind.VoiceMicrophonePreferenceStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    VoiceMicrophonePreferenceStore.save("USB Mic", to: defaults)
    XCTAssertEqual(VoiceMicrophonePreferenceStore.load(from: defaults), "USB Mic")
}
```

- [ ] **Step 2: Extend the voice service to accept a microphone preference for recording setup**

```swift
public protocol VoiceServiceProtocol: Sendable {
    func setPreferredMicrophoneName(_ name: String)
    func startRecording() async throws
    func stopRecording() async throws -> String
}
```

- [ ] **Step 3: Thread the preference from `VoiceEntryView` into the live voice service and keep a clear fallback**

```swift
preferredMicrophoneName = VoiceMicrophonePreferenceStore.load()
voiceService.setPreferredMicrophoneName(preferredMicrophoneName)
```

- [ ] **Step 4: Run the focused tests**

Run: `swift test --parallel --filter VoiceMicrophonePreferenceStoreTests`
Expected: passes

---

### Task 3: Replace the fixed 5-second voice capture stop with an event-driven close

**Files:**
- Modify: `AcMindKit/Services/Input/Capture/CaptureService.swift`
- Modify: `App/AppDelegate.swift`
- Modify: `AcMindKit/Services/Voice/VoiceService.swift`
- Modify: `Features/Native/VoiceEntry/VoiceEntryView.swift`
- Test: `AcMindKitTests/SayInputCoordinatorTests.swift`

- [ ] **Step 1: Add a regression test for explicit voice stop instead of a sleep-based timeout**

```swift
func testVoiceCaptureStopsWhenFinishNotificationArrives() async throws {
    let captureService = CaptureService(voiceService: stubVoiceService)
    let task = Task { try await captureService.captureFromVoice() }
    NotificationCenter.default.post(name: .companionVoiceFinishRequested, object: nil)
    _ = try await task.value
}
```

- [ ] **Step 2: Teach the capture flow to wait on a finish signal instead of sleeping for a fixed duration**

```swift
let finishObserver = NotificationCenter.default.addObserver(
    forName: .companionVoiceFinishRequested,
    object: nil,
    queue: .main
) { _ in
    continuation.resume(returning: ())
}
```

- [ ] **Step 3: Keep the existing UI action that posts the finish signal**

```swift
NotificationCenter.default.post(name: .companionVoiceFinishRequested, object: nil)
```

- [ ] **Step 4: Run the focused tests**

Run: `swift test --parallel --filter SayInputCoordinatorTests`
Expected: passes

---

### Task 4: Replace simplified Whisper API and audio storage paths with real implementations

**Files:**
- Modify: `AcMindKit/Services/Voice/VoiceService.swift`
- Modify: `AcMindKit/Services/Input/Capture/CaptureService.swift`
- Modify: `AcMindKit/Services/Voice/STT/Cloud/OpenAIWhisperTranscriber.swift`
- Modify: `AcMindKit/Services/Voice/STT/STTRouter.swift`
- Test: `AcMindKitTests/AgentToolRouterTests.swift`
- Test: `AcMindKitTests/StorageTests.swift`

- [ ] **Step 1: Add tests that the API path and audio file path are real and deterministic**

```swift
func testOpenAIWhisperTranscriberBuildsMultipartRequest() async throws {
    let transcriber = OpenAIWhisperTranscriber(apiKey: "test")
    _ = try await transcriber.transcribe(audioFile: AudioFile(url: testAudioURL))
}
```

- [ ] **Step 2: Move audio persistence to the asset store directory that the rest of the app already uses**

```swift
let assetDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    .first!.appendingPathComponent("AcMind/Assets", isDirectory: true)
```

- [ ] **Step 3: Route Whisper API through the shared STT provider path instead of the ad hoc simplified body**

```swift
let transcriber = OpenAIWhisperTranscriber(apiKey: key)
return try await transcriber.transcribe(audioFile: audioFile)
```

- [ ] **Step 4: Run the focused tests**

Run: `swift test --parallel --filter StorageTests`
Expected: passes

---

### Task 5: Make Qwen3-ASR behavior explicit and clean up remaining voice copy

**Files:**
- Modify: `AcMindKit/Services/Voice/STT/Local/Qwen3ASRTranscriber.swift`
- Modify: `Features/Native/VoiceEntry/VoiceEntryView.swift`
- Modify: `Features/Companion/CompanionVoicePanel.swift`

- [ ] **Step 1: Replace “模拟流式” language with explicit segmented-result wording**

```swift
/// Qwen3-ASR 不支持真正的流式。
/// 这里发送起始状态和最终结果，让 UI 明确这是分段产物而不是实时流。
```

- [ ] **Step 2: Ensure the voice entry UI describes the selected provider truthfully**

```swift
Text("当前 ASR 引擎如果不支持实时流式，会以分段结果呈现。")
```

- [ ] **Step 3: Run the repo-wide verification commands**

Run:
```bash
swift test --parallel
xcodebuild -project AcMind.xcodeproj -scheme AcMind -quiet build
```
Expected: both pass.
