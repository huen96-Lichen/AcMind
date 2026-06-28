import Foundation

public enum ToolStatusLabelFormatter {
    public static let clipboardLoadedText = "已读取剪贴板内容"
    public static let processingText = "处理中..."

    public static func fallbackText(value: String, fallback: String = "未设置") -> String {
        value.isEmpty ? fallback : value
    }

    public static func availabilityState(
        isAvailable: Bool,
        availableText: String = "可用",
        unavailableText: String = "待配置"
    ) -> String {
        isAvailable ? availableText : unavailableText
    }

    public static func waitingToInput(_ subject: String) -> String {
        "等待输入 \(subject)"
    }

    public static func promptToSelect(_ subject: String) -> String {
        "请选择\(subject)"
    }

    public static func waitingToImport(_ subject: String) -> String {
        "等待导入 \(subject)"
    }

    public static func waitingToLoad(_ subject: String) -> String {
        "等待加载\(subject)"
    }

    public static func loading(_ subject: String) -> String {
        "正在加载\(subject)..."
    }

    public static func running(_ action: String) -> String {
        "正在\(action)..."
    }

    public static func selectedWaiting(_ subject: String, waitingFor action: String) -> String {
        "已选择\(subject)，等待\(action)"
    }

    public static func selectedRunning(_ subject: String, action: String) -> String {
        "已选择\(subject)，正在\(action)"
    }

    public static func importedWaiting(_ subject: String, waitingFor action: String) -> String {
        "已导入\(subject)，等待\(action)"
    }

    public static func emptyState(_ subject: String) -> String {
        "\(subject)为空"
    }

    public static func conflictState(_ subject: String) -> String {
        "存在\(subject)冲突"
    }

    public static func savedTo(_ subject: String) -> String {
        "已保存到 \(subject)"
    }

    public static func copiedText() -> String {
        "已复制!"
    }

    public static func copied(_ subject: String) -> String {
        "\(subject)已复制"
    }

    public static func saved(_ subject: String) -> String {
        "\(subject)已保存"
    }

    public static func generated(_ subject: String) -> String {
        "\(subject)已生成"
    }

    public static func restored(_ subject: String) -> String {
        "\(subject)已恢复"
    }

    public static func deleted(_ subject: String) -> String {
        "\(subject)已删除"
    }

    public static func copiedToClipboard(_ subject: String) -> String {
        "\(subject)已复制到剪贴板"
    }

    public static func saveFailed(_ errorMessage: String) -> String {
        "保存失败: \(errorMessage)"
    }

    public static func noItemsAvailable(_ subject: String) -> String {
        "暂无可检查的\(subject)"
    }

    public static func invalidURL(_ subject: String) -> String {
        "\(subject) 无效"
    }

    public static func invalidInput(_ subject: String) -> String {
        "请输入有效的\(subject)"
    }

    public static func missingTool(_ toolName: String) -> String {
        "未找到 \(toolName)"
    }

    public static func noContentAvailable(_ subject: String) -> String {
        "没有提取到可用\(subject)"
    }

    public static func nothingToCopy(_ subject: String) -> String {
        "没有可复制的\(subject)"
    }

    public static func copiedMarkdown() -> String {
        "Markdown 已复制"
    }

    public static func convertedToMarkdown(_ subject: String) -> String {
        "\(subject)已转换为 Markdown"
    }

    public static func noClipboardImage() -> String {
        "剪贴板里没有图片"
    }

    public static func noClipboardText() -> String {
        "剪贴板里没有可用文本"
    }

    public static func clipboardEmpty() -> String {
        "剪贴板为空"
    }

    public static func chooseImage() -> String {
        "请选择图片"
    }

    public static func enterInput(_ subject: String) -> String {
        "请输入\(subject)"
    }

    public static func noContentToGenerate(_ subject: String) -> String {
        "没有可生成的\(subject)"
    }

    public static func noMatchFound(_ subject: String) -> String {
        "没有找到匹配的\(subject)"
    }

    public static func deletedSubtitleSummary(keyword: String, removed: Int) -> String {
        "已删除包含「\(keyword)」的 \(removed) 条字幕"
    }

    public static func deletedSubtitle(index: Int) -> String {
        "已删除第 \(index) 条字幕"
    }

    public static func generatedFCPXMLSummary(subtitleCount: Int) -> String {
        "已生成 FCPXML，包含 \(subtitleCount) 条字幕"
    }

    public static func decodeFailed() -> String {
        "解码失败"
    }

    public static func invalidBase64() -> String {
        "输入不是有效的 Base64 字符串"
    }

    public static func nonUTF8ShownAsHex() -> String {
        "内容不是 UTF-8，已显示十六进制"
    }

    public static func jsonFormatted(pretty: Bool) -> String {
        pretty ? "JSON 已美化" : "JSON 已压缩"
    }

    public static func base64Encoded() -> String {
        "已编码为 Base64"
    }

    public static func base64DecodedText() -> String {
        "已解码为文本"
    }

    public static func base64DecodedHex() -> String {
        "已解码为字节十六进制"
    }

    public static func markdownCleanedSummary(
        trimmedTrailingSpaces: Int,
        collapsedBlankLines: Int
    ) -> String {
        "已整理 Markdown，清理了 \(trimmedTrailingSpaces) 处尾随空格，压缩了 \(collapsedBlankLines) 处空行"
    }

    public static func noSubtitleMatch(_ subject: String) -> String {
        "没有找到包含「\(subject)」的字幕"
    }

    public static func ocrCompleted() -> String {
        "OCR 识别完成"
    }

    public static func noRecognizedResults() -> String {
        "没有可复制的识别结果"
    }

    public static func recognizedResultsCopied() -> String {
        "识别结果已复制"
    }

    public static func recognizedResultsSaved() -> String {
        "识别结果已保存"
    }

    public static func imageProcessed() -> String {
        "图片已处理"
    }

    public static func chooseFolder() -> String {
        "请选择文件夹"
    }

    public static func noRenamableItems() -> String {
        "没有可重命名的项目"
    }

    public static func duplicateTargetNames() -> String {
        "结果中存在重复目标名称"
    }

    public static func batchRenameCompleted() -> String {
        "批量重命名完成"
    }

    public static func downloadCompleted(_ subject: String) -> String {
        "\(subject)下载完成"
    }

    public static func loadedCount(_ count: Int, noun: String) -> String {
        "已加载 \(count) 个\(noun)"
    }

    public static func completedDownloadCount(_ count: Int, noun: String) -> String {
        "完成，下载了 \(count) 个\(noun)"
    }

    public static func completed(_ action: String) -> String {
        "\(action)完成"
    }

    public static func passed(_ action: String) -> String {
        "\(action)通过"
    }

    public static func fetched(_ subject: String) -> String {
        "\(subject)已获取"
    }

    public static func failed(_ action: String) -> String {
        "\(action)失败"
    }
}
