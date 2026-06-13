import XCTest

final class AppSurfaceDialogStyleTests: XCTestCase {
    func testSharedDialogFrameSupportsUnifiedActionRow() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")

        XCTAssertTrue(source.contains("struct AppSurfaceDialogActionRow"))
        XCTAssertTrue(source.contains("primaryDisabled: Bool"))
        XCTAssertTrue(source.contains("footerNote: String? = \"选完就会关闭窗口，不会再额外弹系统对话框。\""))
        XCTAssertTrue(source.contains("AppSurfaceDialogActionRow("))
    }

    func testCaptureDestinationChoiceUsesStandardConfirmationFootnote() throws {
        let source = try readSource("Features/Companion/CompanionCapturePanel.swift")

        XCTAssertTrue(source.contains("AppSurfaceConfirmationCard("))
        XCTAssertTrue(source.contains("footerNote: \"选完就会关闭窗口，不会再额外弹系统对话框。\""))
        XCTAssertFalse(source.contains("这类浮窗会保持在前台，选完即收起。"))
    }

    func testPromptCardUsesSharedActionRow() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")

        XCTAssertTrue(source.contains("struct AppSurfacePromptCard"))
        XCTAssertTrue(source.contains("AppSurfaceDialogActionRow("))
        XCTAssertTrue(source.contains("footerNote: String? = nil"))
        XCTAssertTrue(source.contains("primaryDisabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
