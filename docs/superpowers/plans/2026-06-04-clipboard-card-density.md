# 剪贴板卡片密度实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 让 AcMind 的剪贴板更像一个成熟的内容工作台：图片项采用缩略图优先的卡片，文本项采用紧凑的双行卡片，并且让 pin / copy 的反馈自然、即时，而不是像外挂能力。

**架构：** 保持剪贴板页作为主要集成点，但把可复用的展示规则收敛成一个小的共享模型，让列表和网格卡片保持一致。图片卡负责缩略图加载和图片优先布局，文本卡负责两行预览和更轻量的元信息。操作层在列表、网格和详情面板里保持一致，这样 pin/copy 的入口和反馈不会散。

**技术栈：** SwiftUI、AppKit、`AcMindKit`、`XCTest`、`xcodebuild`

---

### 任务 1：添加共享的剪贴板展示层

**文件：**
- 新增：`AcMindKit/Models/ClipboardCardPresentation.swift`
- 修改：`AcMindKit/Models/RecordingStatus.swift`
- 测试：`AcMindKitTests/ClipboardPinLayoutTests.swift`

- [ ] **步骤 1：先写一个会失败的测试**

```swift
func testClipboardCardPresentationUsesThumbnailFirstRules() {
    let imageItem = ClipboardItem(
        type: .image,
        content: "asset-id",
        textContent: "图片说明",
        sourceApp: "Safari"
    )
    let textItem = ClipboardItem(
        type: .text,
        content: nil,
        textContent: "这是一段很长的文本内容，用来验证两行预览规则是否生效。",
        sourceApp: "Notes"
    )

    XCTAssertEqual(ClipboardCardPresentation.thumbnailHeight(for: imageItem), 160)
    XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: imageItem), 1)
    XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: textItem), 2)
    XCTAssertEqual(ClipboardCardPresentation.previewText(for: imageItem), "图片说明")
    XCTAssertEqual(ClipboardCardPresentation.previewText(for: textItem), "这是一段很长的文本内容，用来验证两行预览规则是否生效。")
    XCTAssertEqual(ClipboardCardPresentation.subtitleText(for: imageItem), "Safari · 图片")
    XCTAssertEqual(ClipboardCardPresentation.subtitleText(for: textItem), "Notes · 文本")
}
```

- [ ] **步骤 2：运行这个测试，确认它确实失败**

运行：`swift test --filter ClipboardPinLayoutTests/testClipboardCardPresentationUsesThumbnailFirstRules`

预期：失败，因为此时 `ClipboardCardPresentation` 还不存在。

- [ ] **步骤 3：实现最小可用的共享展示 API**

```swift
public enum ClipboardCardPresentation {
    public static func thumbnailHeight(for item: ClipboardItem) -> CGFloat {
        item.type == .image ? 160 : 0
    }

    public static func previewLineLimit(for item: ClipboardItem) -> Int {
        item.type == .image ? 1 : 2
    }

    public static func previewText(for item: ClipboardItem) -> String {
        item.textContent?.isEmpty == false ? (item.textContent ?? "") : (item.content ?? "无内容")
    }

    public static func subtitleText(for item: ClipboardItem) -> String {
        let source = item.sourceApp?.isEmpty == false ? item.sourceApp! : "未知来源"
        return "\(source) · \(item.type.displayName)"
    }
}
```

- [ ] **步骤 4：重新运行测试，直到通过**

运行：`swift test --filter ClipboardPinLayoutTests/testClipboardCardPresentationUsesThumbnailFirstRules`

预期：通过。

- [ ] **步骤 5：提交共享展示层**

```bash
git add AcMindKit/Models/ClipboardCardPresentation.swift AcMindKitTests/ClipboardPinLayoutTests.swift
git commit -m "feat: add shared clipboard card presentation rules"
```

### 任务 2：把剪贴板列表卡片改成缩略图优先的行卡

**文件：**
- 修改：`Features/Native/Clipboard/ClipboardView.swift`
- 新增：`Features/Native/Clipboard/ClipboardItemComponents.swift`
- 修改：`App/ViewModels/ClipboardViewModel.swift`
- 测试：通过 `xcodebuild` 验证 app 目标

- [ ] **步骤 1：写一个会失败的测试**

```swift
func testTextPreviewUsesTwoLineRulesAndImagePreviewStaysThumbnailFirst() {
    let textItem = ClipboardItem(
        type: .text,
        content: "第一行\n第二行\n第三行",
        textContent: "第一行\n第二行\n第三行",
        sourceApp: "Xcode"
    )
    let imageItem = ClipboardItem(
        type: .image,
        content: "asset-id",
        textContent: "图片内容",
        sourceApp: "Preview"
    )

    XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: textItem), 2)
    XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: imageItem), 1)
}
```

- [ ] **步骤 2：运行这个测试，确认它失败**

运行：`swift test --filter ClipboardPinLayoutTests/testTextPreviewUsesTwoLineRulesAndImagePreviewStaysThumbnailFirst`

预期：失败，直到行卡真正接入共享展示规则。

- [ ] **步骤 3：把列表行改成可复用的缩略图优先组件**

```swift
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPin: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ClipboardItemThumbnailView(item: item, height: 48, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(ClipboardCardPresentation.previewText(for: item))
                    .lineLimit(ClipboardCardPresentation.previewLineLimit(for: item))
                Text(ClipboardCardPresentation.subtitleText(for: item))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ClipboardItemActionBar(item: item, onPin: onPin, onCopy: onCopy)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
```

- [ ] **步骤 4：重新运行测试，直到通过**

运行：`swift test --filter ClipboardPinLayoutTests/testTextPreviewUsesTwoLineRulesAndImagePreviewStaysThumbnailFirst`

预期：通过。

- [ ] **步骤 5：验证 app 目标仍能构建**

运行：`xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' build`

预期：`BUILD SUCCEEDED`。

- [ ] **步骤 6：提交列表行重构**

```bash
git add Features/Native/Clipboard/ClipboardView.swift Features/Native/Clipboard/ClipboardItemComponents.swift App/ViewModels/ClipboardViewModel.swift
git commit -m "feat: make clipboard rows thumbnail-first"
```

### 任务 3：把网格卡改成更紧凑的素材卡

**文件：**
- 修改：`Features/Native/Clipboard/ClipboardView.swift`
- 修改：`Features/Native/Clipboard/ClipboardItemComponents.swift`
- 测试：通过 `xcodebuild` 验证 app 目标

- [ ] **步骤 1：写一个会失败的测试**

```swift
func testImageCardPrefersLargeThumbnailAndMinimalMetadata() {
    let imageItem = ClipboardItem(
        type: .image,
        content: "asset-id",
        textContent: "截图说明",
        sourceApp: "Safari"
    )

    XCTAssertEqual(ClipboardCardPresentation.thumbnailHeight(for: imageItem), 160)
    XCTAssertEqual(ClipboardCardPresentation.subtitleText(for: imageItem), "Safari · 图片")
}
```

- [ ] **步骤 2：运行这个测试，确认它失败**

运行：`swift test --filter ClipboardPinLayoutTests/testImageCardPrefersLargeThumbnailAndMinimalMetadata`

预期：失败，直到图片卡真正切到大缩略图和轻元信息结构。

- [ ] **步骤 3：把网格卡改成缩略图优先的图片卡**

```swift
struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.type == .image {
                ClipboardItemThumbnailView(item: item, height: 160, cornerRadius: 12, expandToWidth: true)
            }
            Text(ClipboardCardPresentation.previewText(for: item))
                .lineLimit(item.type == .image ? 1 : 2)
            Text(ClipboardCardPresentation.subtitleText(for: item))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            ClipboardItemActionBar(item: item, onPin: onPin, onCopy: onCopy)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
```

- [ ] **步骤 4：重新运行测试，直到通过**

运行：`swift test --filter ClipboardPinLayoutTests/testImageCardPrefersLargeThumbnailAndMinimalMetadata`

预期：通过。

- [ ] **步骤 5：再次执行 app 构建**

运行：`xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' build`

预期：`BUILD SUCCEEDED`。

- [ ] **步骤 6：提交网格卡重构**

```bash
git add Features/Native/Clipboard/ClipboardView.swift Features/Native/Clipboard/ClipboardItemComponents.swift
git commit -m "feat: densify clipboard image cards"
```

### 任务 4：收紧 pin 反馈并做回归验证

**文件：**
- 修改：`Features/Native/Clipboard/ClipboardView.swift`
- 修改：`App/AppDelegate.swift`
- 修改：`AcMindKitTests/ClipboardPinLayoutTests.swift`

- [ ] **步骤 1：写一个会失败的测试**

```swift
func testClipboardPinStateIsReflectedInTheBadgeAndActionSurface() {
    XCTAssertEqual(ClipboardCardPresentation.pinFeedbackTitle(isPinned: true), "已固定")
    XCTAssertEqual(ClipboardCardPresentation.pinFeedbackTitle(isPinned: false), "Pin")
}
```

- [ ] **步骤 2：运行这个测试，确认它失败**

运行：`swift test --filter ClipboardPinLayoutTests/testClipboardPinStateIsReflectedInTheBadgeAndActionSurface`

预期：失败，直到共享 pin 反馈文案被补齐。

- [ ] **步骤 3：把共享 pin 反馈接入列表、网格和详情操作**

```swift
Button(action: onPin) {
    Text(ClipboardCardPresentation.pinFeedbackTitle(isPinned: item.isPinned))
}
```

- [ ] **步骤 4：重新运行测试，直到通过**

运行：`swift test --filter ClipboardPinLayoutTests/testClipboardPinStateIsReflectedInTheBadgeAndActionSurface`

预期：通过。

- [ ] **步骤 5：运行全量测试和 app 构建**

运行：
`swift test`

运行：
`xcodebuild -project AcMind.xcodeproj -scheme AcMind -configuration Debug -destination 'platform=macOS' build`

预期：两者都成功，且没有测试失败。

- [ ] **步骤 6：做一次最终的人工检查**

在运行中的应用里确认：
- 图片项在列表和网格里都能明显看到缩略图
- 文本项是紧凑的双行卡片
- `Pin` 会立刻给出可见反馈
- 点击 pin 按钮不会再因为命中区域冲突而没有反应

- [ ] **步骤 7：提交最终版本**

```bash
git add AcMindKit/Models/ClipboardCardPresentation.swift AcMindKitTests/ClipboardPinLayoutTests.swift Features/Native/Clipboard/ClipboardView.swift Features/Native/Clipboard/ClipboardItemComponents.swift App/ViewModels/ClipboardViewModel.swift App/AppDelegate.swift
git commit -m "feat: mature clipboard card density and pin feedback"
```

