import Foundation
import AcMindKit

#if DEBUG
enum AcWorkPreviewData {
    static let fixedNow = Date(timeIntervalSince1970: 1_781_491_200)

    static var homeSnapshot: AcWorkHomePreviewSnapshot {
        AcWorkHomePreviewSnapshot(
            nowLabel: "2026-06-15 09:20",
            currentFocus: "AcWork Phase 1 UI 重制",
            nextStep: "确认收集箱统一模型与 Shell 响应式规则",
            pendingItems: [
                "3 条剪贴板内容待整理",
                "1 条会议语音待提炼",
                "2 张截图等待 OCR"
            ],
            scheduleItems: [
                "10:00 设计规范复盘",
                "14:30 收集箱 Repository 联调",
                "17:00 构建与截图验收"
            ],
            systemMetrics: [
                "CPU 28%",
                "内存 11.2 GB",
                "模型服务在线"
            ]
        )
    }

    static func inboxItems(for scenario: AcWorkPreviewScenario) -> [SourceItem] {
        switch scenario {
        case .populated:
            return populatedInboxItems
        case .loading, .empty, .error:
            return []
        }
    }

    static var populatedInboxItems: [SourceItem] {
        [
            SourceItem(
                id: "acwork-preview-voice-standup",
                type: .audio,
                source: .voice,
                status: .captured,
                title: "站会语音记录",
                previewText: "今天先完成导航迁移，再推进收集箱统一模型。",
                transcript: "今天先完成导航迁移，再推进收集箱统一模型。风险点是旧剪贴板数据必须保持可读。",
                sourceApp: "AcWork",
                tags: ["voice", "standup"],
                metadata: ["scenario": "populated", "duration": "00:42"],
                createdAt: fixedNow.addingTimeInterval(-600),
                updatedAt: fixedNow.addingTimeInterval(-540)
            ),
            SourceItem(
                id: "acwork-preview-clipboard-link",
                type: .webpage,
                source: .clipboard,
                status: .pending,
                title: "设计规范链接",
                previewText: "AcWork Focus Workspace 规范：Shell、Toolbar、Filter Rail、Inspector。",
                sourceApp: "Safari",
                originalUrl: "https://example.local/acwork/spec",
                tags: ["link", "design-system"],
                metadata: ["scenario": "populated", "contentKind": "link"],
                createdAt: fixedNow.addingTimeInterval(-1_800)
            ),
            SourceItem(
                id: "acwork-preview-phone-richtext",
                type: .text,
                source: .clipboard,
                status: .inbox,
                title: "手机同步富文本",
                previewText: "从 iPhone 同步的竞品笔记，包含标题、列表和行动项。",
                sourceApp: "iPhone",
                tags: ["phone-sync", "rich-text"],
                metadata: ["scenario": "populated", "sourceDevice": "iPhone", "contentKind": "richText"],
                createdAt: fixedNow.addingTimeInterval(-2_400)
            ),
            SourceItem(
                id: "acwork-preview-screenshot-ocr",
                type: .screenshot,
                source: .screenshot,
                status: .parsed,
                title: "设置页截图 OCR",
                previewText: "截图中识别到模型配置、权限状态、快捷键状态。",
                ocrText: "模型配置 / 权限状态 / 快捷键状态 / 本地优先",
                tags: ["screenshot", "ocr"],
                metadata: ["scenario": "populated", "contentKind": "image"],
                createdAt: fixedNow.addingTimeInterval(-3_600)
            ),
            SourceItem(
                id: "acwork-preview-agent-code",
                type: .text,
                source: .agent,
                status: .distilled,
                title: "Agent 生成代码片段",
                previewText: "func canonicalSidebarItem(for item: SidebarItem) -> SidebarItem { item == .clipboard ? .inbox : item }",
                tags: ["agent", "code"],
                metadata: ["scenario": "populated", "contentKind": "code", "language": "swift"],
                createdAt: fixedNow.addingTimeInterval(-5_400),
                updatedAt: fixedNow.addingTimeInterval(-5_100)
            ),
            SourceItem(
                id: "acwork-preview-manual-file",
                type: .pdf,
                source: .manual,
                status: .exported,
                title: "手动添加的需求 PDF",
                previewText: "Phase 1 范围、验收截图和风险清单。",
                tags: ["file", "requirements"],
                metadata: ["scenario": "populated", "contentKind": "file", "extension": "pdf"],
                createdAt: fixedNow.addingTimeInterval(-7_200),
                updatedAt: fixedNow.addingTimeInterval(-6_900)
            ),
            SourceItem(
                id: "acwork-preview-video-reference",
                type: .video,
                source: .file,
                status: .inbox,
                title: "交互动效参考视频",
                previewText: "用于比对工作台卡片进入动画和 Inspector 展开方式。",
                tags: ["video", "motion"],
                metadata: ["scenario": "populated", "contentKind": "video"],
                createdAt: fixedNow.addingTimeInterval(-9_000)
            )
        ]
    }
}
#endif
