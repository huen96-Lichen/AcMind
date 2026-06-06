import XCTest
@testable import AcMindKit

@MainActor
final class ContextCaptureServiceTests: XCTestCase {

    // MARK: - ContextSnapshot.formattedContext

    func testFormattedContextIncludesAllFields() {
        let snapshot = ContextSnapshot(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "MyProject",
            selectedText: "let x = 1",
            surroundingText: "func foo() {\n  let x = 1\n}",
            timestamp: Date()
        )

        let formatted = snapshot.formattedContext()
        XCTAssertTrue(formatted.contains("当前窗口: MyProject"))
        XCTAssertTrue(formatted.contains("选中文本: let x = 1"))
        XCTAssertTrue(formatted.contains("上下文: func foo()"))
    }

    func testFormattedContextOmitsNilFields() {
        let snapshot = ContextSnapshot(
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            windowTitle: nil,
            selectedText: "hello",
            surroundingText: nil,
            timestamp: Date()
        )

        let formatted = snapshot.formattedContext()
        XCTAssertTrue(formatted.contains("选中文本: hello"))
        XCTAssertFalse(formatted.contains("当前窗口"))
        XCTAssertFalse(formatted.contains("上下文"))
    }

    func testFormattedContextReturnsEmptyWhenAllNil() {
        let snapshot = ContextSnapshot(
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            windowTitle: nil,
            selectedText: nil,
            surroundingText: nil,
            timestamp: Date()
        )

        XCTAssertEqual(snapshot.formattedContext(), "")
    }

    func testFormattedContextOmitsEmptyStrings() {
        let snapshot = ContextSnapshot(
            appName: "Test",
            bundleIdentifier: "com.test",
            windowTitle: "",
            selectedText: "  ",
            surroundingText: "context",
            timestamp: Date()
        )

        let formatted = snapshot.formattedContext()
        XCTAssertFalse(formatted.contains("当前窗口"))
        XCTAssertTrue(formatted.contains("上下文: context"))
    }

    // MARK: - ContextSnapshot.hasContext

    func testHasContextTrueWhenWindowPresent() {
        let snapshot = ContextSnapshot(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: "Project",
            selectedText: nil,
            surroundingText: nil,
            timestamp: Date()
        )

        XCTAssertTrue(snapshot.hasContext)
    }

    func testHasContextTrueWhenSelectedTextPresent() {
        let snapshot = ContextSnapshot(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: nil,
            selectedText: "some text",
            surroundingText: nil,
            timestamp: Date()
        )

        XCTAssertTrue(snapshot.hasContext)
    }

    func testHasContextTrueWhenSurroundingTextPresent() {
        let snapshot = ContextSnapshot(
            appName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            windowTitle: nil,
            selectedText: nil,
            surroundingText: "surrounding",
            timestamp: Date()
        )

        XCTAssertTrue(snapshot.hasContext)
    }

    func testHasContextFalseWhenAllNil() {
        let snapshot = ContextSnapshot(
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            windowTitle: nil,
            selectedText: nil,
            surroundingText: nil,
            timestamp: Date()
        )

        XCTAssertFalse(snapshot.hasContext)
    }

    // MARK: - AppType Detection

    func testAppTypeEmailFromMailBundle() {
        XCTAssertEqual(detectAppType(from: "com.apple.mail"), .email)
        XCTAssertEqual(detectAppType(from: "com.microsoft.outlook"), .email)
        XCTAssertEqual(detectAppType(from: "org.mozilla.thunderbird"), .email)
    }

    func testAppTypeMessagingFromChatBundles() {
        XCTAssertEqual(detectAppType(from: "com.apple.messages"), .messaging)
        XCTAssertEqual(detectAppType(from: "com.tencent.xinwechat"), .messaging)
        XCTAssertEqual(detectAppType(from: "com.tinyspeck.slackmacgap"), .messaging)
        XCTAssertEqual(detectAppType(from: "org.telegram.desktop"), .messaging)
        XCTAssertEqual(detectAppType(from: "net.whatsapp.whatsapp"), .messaging)
    }

    func testAppTypeCodeEditorFromDevBundles() {
        XCTAssertEqual(detectAppType(from: "com.apple.dt.xcode"), .codeEditor)
        XCTAssertEqual(detectAppType(from: "com.microsoft.vscode"), .codeEditor)
        XCTAssertEqual(detectAppType(from: "com.sublimetext.4"), .codeEditor)
        XCTAssertEqual(detectAppType(from: "com.github.atom"), .codeEditor)
        XCTAssertEqual(detectAppType(from: "org.vim.macvim"), .codeEditor)
    }

    func testAppTypeDocumentEditorFromDocBundles() {
        XCTAssertEqual(detectAppType(from: "com.apple.iwork.pages"), .documentEditor)
        XCTAssertEqual(detectAppType(from: "com.microsoft.word"), .documentEditor)
        XCTAssertEqual(detectAppType(from: "notion.id"), .documentEditor)
        XCTAssertEqual(detectAppType(from: "md.obsidian"), .documentEditor)
    }

    func testAppTypeBrowserFromBrowserBundles() {
        XCTAssertEqual(detectAppType(from: "com.apple.safari"), .browser)
        XCTAssertEqual(detectAppType(from: "com.google.chrome"), .browser)
        XCTAssertEqual(detectAppType(from: "org.mozilla.firefox"), .browser)
        XCTAssertEqual(detectAppType(from: "com.microsoft.edgemac"), .browser)
    }

    func testAppTypeOtherForUnknownBundle() {
        XCTAssertEqual(detectAppType(from: "com.apple.finder"), .other)
        XCTAssertEqual(detectAppType(from: "com.spotify.client"), .other)
    }

    // MARK: - Surrounding Text

    func testSurroundingTextClampsOutOfBoundsSelectionWithoutCrashing() {
        let result = ContextCaptureService.surroundingText(
            from: "",
            selectedRange: CFRange(location: 3_254, length: 50)
        )

        XCTAssertNil(result)
    }

    func testSurroundingTextClampsSelectionAtEndOfText() {
        let result = ContextCaptureService.surroundingText(
            from: "Hello world",
            selectedRange: CFRange(location: 99, length: 10)
        )

        XCTAssertEqual(result, "Hello world[光标]")
    }

    // MARK: - AppType Properties

    func testAppTypeRecommendedPolishModes() {
        XCTAssertEqual(AppType.email.recommendedPolishMode, .formal)
        XCTAssertEqual(AppType.messaging.recommendedPolishMode, .light)
        XCTAssertEqual(AppType.codeEditor.recommendedPolishMode, .raw)
        XCTAssertEqual(AppType.documentEditor.recommendedPolishMode, .structured)
        XCTAssertEqual(AppType.browser.recommendedPolishMode, .light)
        XCTAssertEqual(AppType.other.recommendedPolishMode, .light)
    }

    func testAppTypeDisplayNames() {
        XCTAssertEqual(AppType.email.displayName, "邮件")
        XCTAssertEqual(AppType.messaging.displayName, "即时通讯")
        XCTAssertEqual(AppType.codeEditor.displayName, "代码编辑器")
        XCTAssertEqual(AppType.documentEditor.displayName, "文档编辑器")
        XCTAssertEqual(AppType.browser.displayName, "浏览器")
        XCTAssertEqual(AppType.other.displayName, "其他")
    }

    // MARK: - Helper

    private func detectAppType(from bundleIdentifier: String) -> AppType {
        if bundleIdentifier.contains("mail") ||
           bundleIdentifier.contains("outlook") ||
           bundleIdentifier.contains("thunderbird") {
            return .email
        }
        if bundleIdentifier.contains("messages") ||
           bundleIdentifier.contains("wechat") ||
           bundleIdentifier.contains("slack") ||
           bundleIdentifier.contains("telegram") ||
           bundleIdentifier.contains("whatsapp") {
            return .messaging
        }
        if bundleIdentifier.contains("xcode") ||
           bundleIdentifier.contains("code") ||
           bundleIdentifier.contains("sublime") ||
           bundleIdentifier.contains("atom") ||
           bundleIdentifier.contains("vim") {
            return .codeEditor
        }
        if bundleIdentifier.contains("pages") ||
           bundleIdentifier.contains("word") ||
           bundleIdentifier.contains("docs") ||
           bundleIdentifier.contains("notion") ||
           bundleIdentifier.contains("obsidian") {
            return .documentEditor
        }
        if bundleIdentifier.contains("safari") ||
           bundleIdentifier.contains("chrome") ||
           bundleIdentifier.contains("firefox") ||
           bundleIdentifier.contains("edge") {
            return .browser
        }
        return .other
    }
}
