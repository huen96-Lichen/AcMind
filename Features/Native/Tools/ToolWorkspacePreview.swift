import SwiftUI
import AppKit

#if DEBUG
@MainActor
struct ToolWorkspacePreviewRoot: View {
    @StateObject private var toolsViewModel: ToolsViewModel
    @StateObject private var workbenchViewModel: WorkbenchViewModel

    init() {
        let toolsViewModel = ToolsViewModel()
        let workbenchViewModel = WorkbenchViewModel(shouldLoadData: false)

        Self.configureTools(viewModel: toolsViewModel)
        Self.configureWorkbench(viewModel: workbenchViewModel)

        _toolsViewModel = StateObject(wrappedValue: toolsViewModel)
        _workbenchViewModel = StateObject(wrappedValue: workbenchViewModel)
    }

    var body: some View {
        ZStack {
            AppSurfaceBackdrop()

            GeometryReader { proxy in
                let isNarrow = proxy.size.width < 1100

                VStack(alignment: .leading, spacing: 12) {
                    AppSurfaceCard(title: "工具台 / 工作台", subtitle: "真实页面在同一窗口中的组合视图", padding: 14) {
                        HStack(spacing: 12) {
                            StatusBadge(text: "工具台", tone: .info, compact: true)
                            StatusBadge(text: "工作台", tone: .success, compact: true)
                            StatusBadge(text: "三阶段", tone: .neutral, compact: true)
                        }
                    }

                    if isNarrow {
                        VStack(spacing: 12) {
                            ToolsView(viewModel: toolsViewModel)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(420, proxy.size.height * 0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            WorkbenchView(viewModel: workbenchViewModel)
                                .frame(maxWidth: .infinity)
                                .frame(height: max(420, proxy.size.height * 0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            ToolsView(viewModel: toolsViewModel)
                                .frame(width: proxy.size.width * 0.53)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            WorkbenchView(viewModel: workbenchViewModel)
                                .frame(width: proxy.size.width * 0.47)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
                .padding(16)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .environmentObject(AppState.shared)
    }

    private static func configureTools(viewModel: ToolsViewModel) {
        viewModel.tools = ToolRegistry.defaultTools
        viewModel.selectedCategory = .conversion
        viewModel.searchQuery = ""
        viewModel.activeToolRoute = nil

        let now = Date()
        viewModel.recentTools = [
            makeRecentTool(
                route: .documentConvert,
                name: "文档转换",
                description: "在 PDF、Word、文稿之间转换",
                icon: "doc.text",
                category: .conversion,
                lastUsedDate: now.addingTimeInterval(-300)
            ),
            makeRecentTool(
                route: .ocr,
                name: "文字识别",
                description: "从图片中提取文字",
                icon: "text.viewfinder",
                category: .conversion,
                lastUsedDate: now.addingTimeInterval(-1800)
            ),
            makeRecentTool(
                route: .webDigest,
                name: "网页精读",
                description: "输入网页地址，抓取正文并生成文稿",
                icon: "globe",
                category: .download,
                lastUsedDate: now.addingTimeInterval(-7200)
            )
        ]
    }

    private static func configureWorkbench(viewModel: WorkbenchViewModel) {
        let alphaID = UUID(uuidString: "A1111111-1111-4111-8111-111111111111")!
        let betaID = UUID(uuidString: "B2222222-2222-4222-8222-222222222222")!

        let now = Date()
        let recentNoteDate = now.addingTimeInterval(-3600)

        viewModel.projects = [
            Project(id: alphaID, name: "AcWork 重制", noteCount: 2, lastUpdated: now.addingTimeInterval(-900), sortOrder: 0),
            Project(id: betaID, name: "设计系统", noteCount: 1, lastUpdated: now.addingTimeInterval(-5400), sortOrder: 1)
        ]
        viewModel.notes = [
            WorkbenchNote(
                id: "note-alpha-1",
                projectID: alphaID,
                title: "工具台阶段拆分",
                content: "选择、配置、结果三段式工作流已经接入。",
                tags: ["workflow", "tools"],
                createdAt: recentNoteDate,
                updatedAt: recentNoteDate
            ),
            WorkbenchNote(
                id: "note-alpha-2",
                projectID: alphaID,
                title: "窗口约定",
                content: "默认版和窄宽版都走同一生成流程。",
                tags: ["preview", "release"],
                createdAt: now.addingTimeInterval(-5400),
                updatedAt: now.addingTimeInterval(-1800)
            ),
            WorkbenchNote(
                id: "note-beta-1",
                projectID: betaID,
                title: "共享层总览",
                content: "工作台总览卡和项目列表继续沿用产品页面语言。",
                tags: ["summary", "surface"],
                createdAt: now.addingTimeInterval(-10800),
                updatedAt: now.addingTimeInterval(-7200)
            )
        ]
        viewModel.selectedProject = viewModel.projects.first
        viewModel.searchQuery = ""
        viewModel.todayItems = [
            TodayItem(title: "整理工具输出", priority: .medium),
            TodayItem(title: "归档工作台笔记", priority: .low)
        ]
        viewModel.pendingArchiveCount = 3
        viewModel.pendingArchiveItems = [
            WorkbenchArchiveItem(id: "archive-1", title: "旧版工具记录", status: "inbox", createdAt: now.addingTimeInterval(-14400)),
            WorkbenchArchiveItem(id: "archive-2", title: "待处理内容", status: "inbox", createdAt: now.addingTimeInterval(-28800)),
            WorkbenchArchiveItem(id: "archive-3", title: "项目备忘", status: "inbox", createdAt: now.addingTimeInterval(-43200))
        ]
    }

    private static func makeRecentTool(
        route: ToolRoute,
        name: String,
        description: String,
        icon: String,
        category: ToolCategory,
        lastUsedDate: Date
    ) -> RecentTool {
        RecentTool(
            id: UUID(),
            toolId: UUID(),
            name: name,
            description: description,
            icon: icon,
            category: category,
            route: route,
            lastUsedDate: lastUsedDate
        )
    }
}
#endif
