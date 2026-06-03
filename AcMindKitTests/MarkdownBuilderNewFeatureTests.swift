import XCTest
@testable import AcMindKit

final class MarkdownBuilderNewFeatureTests: XCTestCase {

    let builder = MarkdownBuilder()

    // MARK: - TOC Tests

    func testBuildTOC() {
        let markdown = """
        # 标题一

        ## 第一章

        内容...

        ### 1.1 小节

        更多内容...

        ## 第二章

        结尾内容
        """

        let toc = builder.buildTOC(from: markdown)
        XCTAssertTrue(toc.contains("## 目录"))
        XCTAssertTrue(toc.contains("[第一章](#第一章)"))
        XCTAssertTrue(toc.contains("[第二章](#第二章)"))
        XCTAssertTrue(toc.contains("[1.1 小节](#11-小节)"))
    }

    func testBuildTOCEmptyForNoHeadings() {
        let markdown = "这是一段普通文本，没有标题。"
        let toc = builder.buildTOC(from: markdown)
        XCTAssertTrue(toc.isEmpty)
    }

    // MARK: - Code Block Enhancement Tests

    func testEnhanceCodeBlocks() {
        let markdown = """
        示例代码：

        ```
        func hello() {
            print("Hello")
        }
        ```
        """

        let enhanced = builder.enhanceCodeBlocks(in: markdown)
        XCTAssertTrue(enhanced.contains("```swift"))
    }

    func testEnhanceCodeBlocksDetectsPython() {
        let markdown = """
        ```python
        def hello():
            print("Hello")
        ```
        """

        let enhanced = builder.enhanceCodeBlocks(in: markdown)
        XCTAssertTrue(enhanced.contains("```python"))
    }

    // MARK: - Template Tests

    func testListTemplates() {
        let templates = builder.listTemplates()
        XCTAssertEqual(templates.count, 4)
        XCTAssertTrue(templates.contains { $0.id == "default" })
        XCTAssertTrue(templates.contains { $0.id == "meeting" })
        XCTAssertTrue(templates.contains { $0.id == "research" })
        XCTAssertTrue(templates.contains { $0.id == "daily" })
    }

    func testApplyTemplate() {
        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "测试笔记",
            summary: "这是摘要",
            category: "技术",
            tags: ["swift", "ios"],
            createdAt: Date(),
            updatedAt: Date()
        )

        let template = MarkdownTemplate(
            id: "custom",
            name: "自定义",
            contentPattern: "# {{title}}\n\n{{summary}}\n\n标签: {{tags}}",
            frontmatterDefaults: ["type": "custom-note"]
        )

        let result = builder.applyTemplate(template, to: note)

        XCTAssertTrue(result.contains("# 测试笔记"))
        XCTAssertTrue(result.contains("这是摘要"))
        XCTAssertTrue(result.contains("标签: swift, ios"))
        XCTAssertTrue(result.contains("---"))
        XCTAssertTrue(result.contains("type: custom-note"))
        XCTAssertTrue(result.contains("title: 测试笔记"))
    }

    func testApplyTemplateFrontmatterEscaping() {
        let note = DistilledNote(
            id: UUID().uuidString,
            sourceItemId: UUID().uuidString,
            title: "含\"引号\"的标题",
            createdAt: Date(),
            updatedAt: Date()
        )

        let template = MarkdownTemplate(
            id: "test",
            name: "测试",
            contentPattern: "{{title}}",
            frontmatterDefaults: [:]
        )

        let result = builder.applyTemplate(template, to: note)
        XCTAssertTrue(result.contains("title: \"含\\\"引号\\\"的标题\""))
    }
}
