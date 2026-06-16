import XCTest
@testable import AcMindKit

final class AgentTraceRendererTests: XCTestCase {
    func testParsesStructuredBlocksAndCodeFences() throws {
        let segments = AgentTraceRenderer.parse("""
        执行完成

        provider: openai
        model: gpt-4.1

        - 已读取 2 条素材
        - 已生成草稿

        ```swift
        let config = loadConfig()
        guard config.isEnabled else { return }
        ```

        输出已写入草稿。
        """)

        XCTAssertEqual(segments.count, 5)

        guard case .paragraph(let first) = segments[0] else {
            return XCTFail("expected first paragraph")
        }
        XCTAssertEqual(first, "执行完成")

        guard case .metadata(let metadata) = segments[1] else {
            return XCTFail("expected metadata block")
        }
        XCTAssertEqual(metadata.map(\.key), ["provider", "model"])
        XCTAssertEqual(metadata.map(\.value), ["openai", "gpt-4.1"])

        guard case .bulletList(let bullets) = segments[2] else {
            return XCTFail("expected bullet list")
        }
        XCTAssertEqual(bullets, ["已读取 2 条素材", "已生成草稿"])

        guard case .code(let language, let code) = segments[3] else {
            return XCTFail("expected code block")
        }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(code, "let config = loadConfig()\nguard config.isEnabled else { return }")

        guard case .paragraph(let last) = segments[4] else {
            return XCTFail("expected trailing paragraph")
        }
        XCTAssertEqual(last, "输出已写入草稿。")
    }

    func testFallsBackToParagraphForPlainText() throws {
        let segments = AgentTraceRenderer.parse("只是普通输出")

        XCTAssertEqual(segments.count, 1)
        guard case .paragraph(let text) = segments[0] else {
            return XCTFail("expected paragraph fallback")
        }
        XCTAssertEqual(text, "只是普通输出")
    }
}
