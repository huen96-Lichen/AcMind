import Foundation

public enum AIUsageBurnLabelFormatter {
    public static func statusText(for snapshot: UsageBurnSnapshot) -> String {
        switch snapshot.severity {
        case .none: return "正常"
        case .info: return "关注"
        case .warning: return "预警"
        case .critical: return "危险"
        }
    }

    public static func summaryText(for snapshot: UsageBurnSnapshot) -> String {
        guard snapshot.windows.isEmpty == false else { return snapshot.note }
        let topWindow = snapshot.windows.max(by: { $0.burnRatio < $1.burnRatio }) ?? snapshot.windows[0]
        return "\(statusText(for: snapshot)) · \(topWindow.name) \(String(format: "%.2fx", topWindow.burnRatio))"
    }

    public static func detailText(for snapshot: UsageBurnSnapshot) -> String {
        guard snapshot.windows.isEmpty == false else {
            return snapshot.note
        }

        let totalCost = String(format: "¥%.2f", snapshot.totalCostCNY)
        let totalTokens = "\(snapshot.totalTokens) tokens"
        let averageLatency = snapshot.totalRequests > 0 ? "\(snapshot.averageLatencyMs)ms 平均" : "无延迟样本"
        return "\(totalTokens) · \(totalCost) · \(averageLatency) · \(snapshot.note)"
    }

    public static func windowText(for window: UsageBurnWindowSnapshot) -> String {
        let usage = String(format: "%.0f%%", window.usagePercent * 100)
        let elapsed = String(format: "%.0f%%", window.elapsedPercent * 100)
        return "\(window.name) \(usage) / \(elapsed) · \(String(format: "%.2fx", window.burnRatio))"
    }

    public static func thresholdHintText() -> String {
        "阈值：1.3x 关注 · 2.0x 预警 · 3.0x 危险"
    }
}
