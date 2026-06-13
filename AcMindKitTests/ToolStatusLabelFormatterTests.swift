import XCTest
@testable import AcMindKit

final class ToolStatusLabelFormatterTests: XCTestCase {
    func testWaitingLabelsStayConsistentAcrossTools() {
        XCTAssertEqual(ToolStatusLabelFormatter.waitingToInput("JSON"), "等待输入 JSON")
        XCTAssertEqual(ToolStatusLabelFormatter.waitingToInput("文本"), "等待输入 文本")
        XCTAssertEqual(ToolStatusLabelFormatter.promptToSelect("文档"), "请选择文档")
        XCTAssertEqual(ToolStatusLabelFormatter.promptToSelect("图片或从剪贴板识别"), "请选择图片或从剪贴板识别")
        XCTAssertEqual(ToolStatusLabelFormatter.waitingToImport("SRT"), "等待导入 SRT")
        XCTAssertEqual(ToolStatusLabelFormatter.waitingToLoad(""), "等待加载")
        XCTAssertEqual(ToolStatusLabelFormatter.waitingToLoad("提供商"), "等待加载提供商")
    }

    func testClipboardAndProcessingLabelsAreShared() {
        XCTAssertEqual(ToolStatusLabelFormatter.clipboardLoadedText, "已读取剪贴板内容")
        XCTAssertEqual(ToolStatusLabelFormatter.processingText, "处理中...")
        XCTAssertEqual(ToolStatusLabelFormatter.noClipboardText(), "剪贴板里没有可用文本")
        XCTAssertEqual(ToolStatusLabelFormatter.clipboardEmpty(), "剪贴板为空")
    }

    func testLoadingAndSelectionHelpersReadNaturally() {
        XCTAssertEqual(ToolStatusLabelFormatter.loading("模型数据"), "正在加载模型数据...")
        XCTAssertEqual(ToolStatusLabelFormatter.running("发送对话验证"), "正在发送对话验证...")
        XCTAssertEqual(ToolStatusLabelFormatter.enterInput("JSON"), "请输入JSON")
        XCTAssertEqual(ToolStatusLabelFormatter.noContentToGenerate("字幕"), "没有可生成的字幕")
        XCTAssertEqual(ToolStatusLabelFormatter.noMatchFound("字幕"), "没有找到匹配的字幕")
        XCTAssertEqual(
            ToolStatusLabelFormatter.selectedWaiting("图片", waitingFor: "识别"),
            "已选择图片，等待识别"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.selectedRunning("文件夹", action: "读取文件"),
            "已选择文件夹，正在读取文件"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.importedWaiting("剪贴板图片", waitingFor: "处理"),
            "已导入剪贴板图片，等待处理"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.emptyState("文件夹"), "文件夹为空")
        XCTAssertEqual(ToolStatusLabelFormatter.conflictState("命名"), "存在命名冲突")
        XCTAssertEqual(ToolStatusLabelFormatter.savedTo("report.md"), "已保存到 report.md")
        XCTAssertEqual(ToolStatusLabelFormatter.copiedText(), "已复制!")
        XCTAssertEqual(ToolStatusLabelFormatter.copied("结果"), "结果已复制")
        XCTAssertEqual(ToolStatusLabelFormatter.saved("结果"), "结果已保存")
        XCTAssertEqual(ToolStatusLabelFormatter.copiedToClipboard("FCPXML"), "FCPXML已复制到剪贴板")
        XCTAssertEqual(ToolStatusLabelFormatter.saveFailed("权限不足"), "保存失败: 权限不足")
        XCTAssertEqual(ToolStatusLabelFormatter.noItemsAvailable("提供商"), "暂无可检查的提供商")
        XCTAssertEqual(ToolStatusLabelFormatter.invalidURL("URL"), "URL 无效")
        XCTAssertEqual(
            ToolStatusLabelFormatter.invalidInput("网址"),
            "请输入有效的网址"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.jsonFormatted(pretty: true), "JSON 已美化")
        XCTAssertEqual(ToolStatusLabelFormatter.jsonFormatted(pretty: false), "JSON 已压缩")
        XCTAssertEqual(ToolStatusLabelFormatter.base64Encoded(), "已编码为 Base64")
        XCTAssertEqual(ToolStatusLabelFormatter.base64DecodedText(), "已解码为文本")
        XCTAssertEqual(ToolStatusLabelFormatter.base64DecodedHex(), "已解码为字节十六进制")
        XCTAssertEqual(ToolStatusLabelFormatter.missingTool("yt-dlp"), "未找到 yt-dlp")
        XCTAssertEqual(
            ToolStatusLabelFormatter.noContentAvailable("正文"),
            "没有提取到可用正文"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.nothingToCopy("Markdown"),
            "没有可复制的Markdown"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.copiedMarkdown(), "Markdown 已复制")
        XCTAssertEqual(
            ToolStatusLabelFormatter.convertedToMarkdown("网页"),
            "网页已转换为 Markdown"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.noClipboardImage(), "剪贴板里没有图片")
        XCTAssertEqual(ToolStatusLabelFormatter.chooseImage(), "请选择图片")
        XCTAssertEqual(ToolStatusLabelFormatter.ocrCompleted(), "OCR 识别完成")
        XCTAssertEqual(ToolStatusLabelFormatter.noRecognizedResults(), "没有可复制的识别结果")
        XCTAssertEqual(ToolStatusLabelFormatter.recognizedResultsCopied(), "识别结果已复制")
        XCTAssertEqual(ToolStatusLabelFormatter.recognizedResultsSaved(), "识别结果已保存")
        XCTAssertEqual(ToolStatusLabelFormatter.imageProcessed(), "图片已处理")
        XCTAssertEqual(ToolStatusLabelFormatter.chooseFolder(), "请选择文件夹")
        XCTAssertEqual(ToolStatusLabelFormatter.noRenamableItems(), "没有可重命名的项目")
        XCTAssertEqual(ToolStatusLabelFormatter.duplicateTargetNames(), "预览中存在重复目标名称")
        XCTAssertEqual(ToolStatusLabelFormatter.batchRenameCompleted(), "批量重命名完成")
        XCTAssertEqual(
            ToolStatusLabelFormatter.decodeFailed(),
            "解码失败"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.invalidBase64(),
            "输入不是有效的 Base64 字符串"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.nonUTF8ShownAsHex(),
            "内容不是 UTF-8，已显示十六进制"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.markdownCleanedSummary(
                trimmedTrailingSpaces: 3,
                collapsedBlankLines: 2
            ),
            "已整理 Markdown，清理了 3 处尾随空格，压缩了 2 处空行"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.noSubtitleMatch("字幕"),
            "没有找到包含「字幕」的字幕"
        )
        XCTAssertEqual(
            ToolStatusLabelFormatter.deletedSubtitleSummary(keyword: "hello", removed: 4),
            "已删除包含「hello」的 4 条字幕"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.deletedSubtitle(index: 7), "已删除第 7 条字幕")
        XCTAssertEqual(
            ToolStatusLabelFormatter.generatedFCPXMLSummary(subtitleCount: 12),
            "已生成 FCPXML，包含 12 条字幕"
        )
        XCTAssertEqual(ToolStatusLabelFormatter.generated("FCPXML"), "FCPXML已生成")
        XCTAssertEqual(ToolStatusLabelFormatter.restored("原始字幕"), "原始字幕已恢复")
        XCTAssertEqual(ToolStatusLabelFormatter.deleted("字幕"), "字幕已删除")
        XCTAssertEqual(ToolStatusLabelFormatter.downloadCompleted("视频"), "视频下载完成")
        XCTAssertEqual(ToolStatusLabelFormatter.loadedCount(3, noun: "条目"), "已加载 3 个条目")
        XCTAssertEqual(ToolStatusLabelFormatter.completedDownloadCount(2, noun: "资源"), "完成，下载了 2 个资源")
        XCTAssertEqual(ToolStatusLabelFormatter.completed("对话验证"), "对话验证完成")
        XCTAssertEqual(ToolStatusLabelFormatter.passed("连通检查"), "连通检查通过")
        XCTAssertEqual(ToolStatusLabelFormatter.fetched("模型列表"), "模型列表已获取")
        XCTAssertEqual(ToolStatusLabelFormatter.failed("加载"), "加载失败")
    }

    func testFallbackTextKeepsEmptyValuesReadable() {
        XCTAssertEqual(ToolStatusLabelFormatter.fallbackText(value: ""), "未设置")
        XCTAssertEqual(ToolStatusLabelFormatter.fallbackText(value: "", fallback: "未配置模型"), "未配置模型")
        XCTAssertEqual(ToolStatusLabelFormatter.fallbackText(value: "Qwen3-ASR"), "Qwen3-ASR")
    }

    func testAvailabilityStateUsesSharedCopy() {
        XCTAssertEqual(ToolStatusLabelFormatter.availabilityState(isAvailable: true), "可用")
        XCTAssertEqual(ToolStatusLabelFormatter.availabilityState(isAvailable: false), "待配置")
        XCTAssertEqual(
            ToolStatusLabelFormatter.availabilityState(
                isAvailable: false,
                availableText: "已启用",
                unavailableText: "未启用"
            ),
            "未启用"
        )
    }
}
