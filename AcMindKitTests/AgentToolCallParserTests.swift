import XCTest
@testable import AcMindKit

final class AgentToolCallParserTests: XCTestCase {
    func testParseWebDigestPromptExtractsURL() {
        let request = AgentToolCallParser.parse(prompt: "帮我做网页精读 https://example.com/article")

        XCTAssertEqual(request?.toolType, .tools)
        XCTAssertEqual(request?.action, "webDigest")
        XCTAssertEqual(request?.parameters["url"], "https://example.com/article")
    }

    func testParseChineseToolPrompts() {
        let batch = AgentToolCallParser.parse(prompt: "批量下载 https://example.com 预览")
        XCTAssertEqual(batch?.toolType, .tools)
        XCTAssertEqual(batch?.action, "batchDownload")
        XCTAssertEqual(batch?.parameters["url"], "https://example.com")
        XCTAssertEqual(batch?.parameters["previewOnly"], "true")

        let video = AgentToolCallParser.parse(prompt: "下载视频 https://example.com/watch?v=1")
        XCTAssertEqual(video?.toolType, .tools)
        XCTAssertEqual(video?.action, "videoDownload")
        XCTAssertEqual(video?.parameters["url"], "https://example.com/watch?v=1")

        let export = AgentToolCallParser.parse(prompt: "导出 note-123 source-456")
        XCTAssertEqual(export?.toolType, .export)
        XCTAssertEqual(export?.action, "toObsidian")
        XCTAssertEqual(export?.parameters["noteId"], "note-123")
        XCTAssertEqual(export?.parameters["sourceItemId"], "source-456")
    }

    func testParseDocumentConvertPromptExtractsFilePath() {
        let request = AgentToolCallParser.parse(prompt: "document convert /tmp/demo.txt")

        XCTAssertEqual(request?.toolType, .tools)
        XCTAssertEqual(request?.action, "documentConvert")
        XCTAssertEqual(request?.parameters["path"], "/tmp/demo.txt")
    }

    func testParseModelManagementPromptReturnsManagementAction() {
        let request = AgentToolCallParser.parse(prompt: "模型管理 provider-1")

        XCTAssertEqual(request?.toolType, .tools)
        XCTAssertEqual(request?.action, "modelManagement")
        XCTAssertEqual(request?.parameters["providerId"], "provider-1")
    }

    func testParseFileOperationPrompts() {
        let rename = AgentToolCallParser.parse(prompt: "rename /tmp/old.txt to new.txt")
        XCTAssertEqual(rename?.toolType, .file)
        XCTAssertEqual(rename?.action, "rename")
        XCTAssertEqual(rename?.parameters["path"], "/tmp/old.txt")
        XCTAssertEqual(rename?.parameters["newName"], "new.txt")

        let copy = AgentToolCallParser.parse(prompt: "copy /tmp/old.txt to /tmp/new.txt")
        XCTAssertEqual(copy?.toolType, .file)
        XCTAssertEqual(copy?.action, "copy")
        XCTAssertEqual(copy?.parameters["path"], "/tmp/old.txt")
        XCTAssertEqual(copy?.parameters["destinationPath"], "/tmp/new.txt")

        let info = AgentToolCallParser.parse(prompt: "file info /tmp/demo.txt")
        XCTAssertEqual(info?.toolType, .file)
        XCTAssertEqual(info?.action, "info")
        XCTAssertEqual(info?.parameters["path"], "/tmp/demo.txt")

        let renameZh = AgentToolCallParser.parse(prompt: "重命名 /tmp/old.txt 为 new-name.txt")
        XCTAssertEqual(renameZh?.toolType, .file)
        XCTAssertEqual(renameZh?.action, "rename")
        XCTAssertEqual(renameZh?.parameters["path"], "/tmp/old.txt")
        XCTAssertEqual(renameZh?.parameters["newName"], "new-name.txt")

        let revealZh = AgentToolCallParser.parse(prompt: "在访达中显示 /tmp/demo.txt")
        XCTAssertEqual(revealZh?.toolType, .file)
        XCTAssertEqual(revealZh?.action, "reveal")
        XCTAssertEqual(revealZh?.parameters["path"], "/tmp/demo.txt")

        let infoZh = AgentToolCallParser.parse(prompt: "查看 /tmp/demo.txt 详情")
        XCTAssertEqual(infoZh?.toolType, .file)
        XCTAssertEqual(infoZh?.action, "info")
        XCTAssertEqual(infoZh?.parameters["path"], "/tmp/demo.txt")

        let copyZh = AgentToolCallParser.parse(prompt: "复制 /tmp/old.txt 到 /tmp/new.txt")
        XCTAssertEqual(copyZh?.toolType, .file)
        XCTAssertEqual(copyZh?.action, "copy")
        XCTAssertEqual(copyZh?.parameters["path"], "/tmp/old.txt")
        XCTAssertEqual(copyZh?.parameters["destinationPath"], "/tmp/new.txt")

        let openZh = AgentToolCallParser.parse(prompt: "打开 /tmp/demo.txt")
        XCTAssertEqual(openZh?.toolType, .file)
        XCTAssertEqual(openZh?.action, "open")
        XCTAssertEqual(openZh?.parameters["path"], "/tmp/demo.txt")
    }

    func testParseExportPromptExtractsNoteIdentifier() {
        let request = AgentToolCallParser.parse(prompt: "export note-123 source-456")

        XCTAssertEqual(request?.toolType, .export)
        XCTAssertEqual(request?.action, "toObsidian")
        XCTAssertEqual(request?.parameters["noteId"], "note-123")
        XCTAssertEqual(request?.parameters["sourceItemId"], "source-456")
    }

    func testParseBatchDownloadAndVideoDownloadPrompts() {
        let batch = AgentToolCallParser.parse(prompt: "batch download https://example.com/article preview")
        XCTAssertEqual(batch?.toolType, .tools)
        XCTAssertEqual(batch?.action, "batchDownload")
        XCTAssertEqual(batch?.parameters["url"], "https://example.com/article")
        XCTAssertEqual(batch?.parameters["previewOnly"], "true")

        let video = AgentToolCallParser.parse(prompt: "video download https://example.com/watch?v=1")
        XCTAssertEqual(video?.toolType, .tools)
        XCTAssertEqual(video?.action, "videoDownload")
        XCTAssertEqual(video?.parameters["url"], "https://example.com/watch?v=1")
    }

    func testParseApiTestPromptRequiresProviderId() {
        let noProvider = AgentToolCallParser.parse(prompt: "api test")
        XCTAssertNil(noProvider)

        let withProvider = AgentToolCallParser.parse(prompt: "api test provider-1")
        XCTAssertEqual(withProvider?.action, "apiTest")
        XCTAssertEqual(withProvider?.parameters["providerId"], "provider-1")
    }

    func testParseAutomationPromptRoutesToAutomationDraft() {
        let request = AgentToolCallParser.parse(prompt: "请把今天的待办自动化整理成步骤")

        XCTAssertEqual(request?.toolType, .ai)
        XCTAssertEqual(request?.action, "automationDraft")
        XCTAssertTrue(request?.parameters["goal"]?.contains("今天的待办自动化整理成步骤") == true)
    }
}
