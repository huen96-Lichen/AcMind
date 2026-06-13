import XCTest
@testable import AcMindKit

final class SayInputPresentationLabelFormatterTests: XCTestCase {
    func testPanelStatusLabelsCoverCoreVoiceFlow() {
        XCTAssertEqual(SayInputPresentationLabelFormatter.preparingText, "正在准备说入法...")
        XCTAssertEqual(SayInputPresentationLabelFormatter.loadingSettingsText, "正在加载设置...")
        XCTAssertEqual(SayInputPresentationLabelFormatter.recordingText, "正在收音...")
        XCTAssertEqual(SayInputPresentationLabelFormatter.processingText, "正在整理文稿...")
        XCTAssertEqual(SayInputPresentationLabelFormatter.startFailedText, "启动失败")
        XCTAssertEqual(SayInputPresentationLabelFormatter.processingFailedText, "处理失败")
        XCTAssertEqual(SayInputPresentationLabelFormatter.openingText, "准备收音")
        XCTAssertEqual(SayInputPresentationLabelFormatter.hudTitle(for: .idle), "说入法")
        XCTAssertEqual(SayInputPresentationLabelFormatter.hudDetail(for: .idle), "等待输入")
    }

    func testPanelResultLabelsMatchDeliveryState() {
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultTitle(for: .insertedIntoFocusedField),
            "已写入当前光标"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultDetail(for: .insertedIntoFocusedField),
            "内容已直接写入"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultTitle(for: .copiedAndSavedToInbox),
            "已复制并保存到收集箱"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultDetail(for: .copiedAndSavedToInbox),
            "已进入收集箱"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultTitle(for: .copiedToClipboard),
            "已复制到剪贴板"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultDetail(for: .copiedToClipboard),
            "可直接粘贴使用"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultTitle(for: .awaitingUserChoice),
            "已准备好"
        )
        XCTAssertEqual(
            SayInputPresentationLabelFormatter.resultDetail(for: .awaitingUserChoice),
            "内容已复制，等待你决定下一步"
        )
    }
}
