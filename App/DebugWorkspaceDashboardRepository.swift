#if DEBUG
import AcMindKit

@MainActor
struct PreviewWorkspaceDashboardRepository: WorkspaceDashboardRepositoryProtocol {
    let phase: WorkspaceDashboardPhase

    func loadSnapshot() async -> WorkspaceDashboardSnapshot {
        let preview = AcWorkPreviewData.homeSnapshot
        return WorkspaceDashboardSnapshot(
            phase: phase,
            nowLabel: preview.nowLabel,
            currentFocus: preview.currentFocus,
            nextStep: preview.nextStep,
            pendingItems: preview.pendingItems,
            recentItems: AcWorkPreviewData.populatedInboxItems.prefix(3).map {
                $0.title ?? $0.previewText ?? $0.type.displayName
            },
            recentScreenshotItems: AcWorkPreviewData.populatedInboxItems
                .filter { $0.source == .screenshot || $0.type == .screenshot }
                .prefix(3)
                .map { item in
                    let label = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "文字识别" : "截图"
                    return "\(label) · \(item.title ?? item.previewText ?? item.type.displayName)"
                },
            scheduleItems: preview.scheduleItems,
            systemMetrics: preview.systemMetrics,
            systemStatusSnapshot: preview.systemStatusSnapshot,
            currentPage: SidebarItem.home.displayName,
            permissionSummary: "已授权 3 · 未知 0 · 不可用 0",
            unavailableReasons: []
        )
    }
}
#endif
