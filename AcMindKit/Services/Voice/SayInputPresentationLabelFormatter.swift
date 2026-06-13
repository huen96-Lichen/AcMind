import Foundation

public enum SayInputPresentationLabelFormatter {
    public static let preparingText = "正在准备说入法..."
    public static let loadingSettingsText = "正在加载设置..."
    public static let recordingText = "正在收音..."
    public static let processingText = "正在整理文稿..."
    public static let startFailedText = "启动失败"
    public static let processingFailedText = "处理失败"
    public static let openingText = "准备收音"
    public static let idleText = "等待输入"
    public static let finishedText = "已结束"
    public static let cancelledText = "已取消"
    public static let clipboardCopiedText = "已复制到剪贴板"

    public static func resultTitle(for state: SayInputDeliveryState) -> String {
        switch state {
        case .insertedIntoFocusedField:
            return "已写入当前光标"
        case .copiedAndSavedToInbox:
            return "已复制并保存到收集箱"
        case .copiedToClipboard:
            return "已复制到剪贴板"
        case .awaitingUserChoice:
            return "已准备好"
        }
    }

    public static func resultDetail(for state: SayInputDeliveryState) -> String {
        switch state {
        case .insertedIntoFocusedField:
            return "内容已直接写入"
        case .copiedAndSavedToInbox:
            return "已进入收集箱"
        case .copiedToClipboard:
            return "可直接粘贴使用"
        case .awaitingUserChoice:
            return "内容已复制，等待你决定下一步"
        }
    }

    public static func hudTitle(for state: NotchV2VoiceSurfaceState) -> String {
        state.displayTitle ?? "说入法"
    }

    public static func hudDetail(for state: NotchV2VoiceSurfaceState) -> String {
        state.displaySubtitle ?? idleText
    }
}
