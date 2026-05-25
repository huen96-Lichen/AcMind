import AppKit
import SwiftUI
import AcMindKit

// MARK: - Workbench View
// 工作台 - Obsidian / 项目 / 知识沉淀空间

struct WorkbenchView: View {
    @StateObject private var viewModel = WorkbenchViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航
            sidebar
                .frame(width: 220)
                .background(AppSurfaceTokens.secondarySidebarBackground)

            Divider()

            // 右侧内容
            content
        }
        .background(AppSurfaceTokens.background)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 今日整理
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("今日整理")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.todayItems.count)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(4)
                    }

                    if viewModel.todayItems.isEmpty {
                        Text("今日暂无待整理内容")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    } else {
                        ForEach(viewModel.todayItems) { item in
                            WorkbenchSidebarItemRow(item: item)
                        }
                    }
                }

                Divider()

                // 项目笔记
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("项目笔记")
                            .font(.headline)

                        Spacer()

                        Button(action: { viewModel.showNewProjectSheet = true }) {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(viewModel.projects) { project in
                        ProjectRow(project: project, isSelected: viewModel.selectedProject?.id == project.id) {
                            viewModel.selectProject(project)
                        }
                    }
                }

                Divider()

                // Obsidian 入口
                VStack(alignment: .leading, spacing: 12) {
                    Text("Obsidian")
                        .font(.headline)

                    Button(action: { viewModel.openObsidian() }) {
                        HStack {
                            Image(systemName: "book.closed")
                            Text("打开 Obsidian")
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.syncWithObsidian() }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("同步")
                        }
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // 待归档
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("待归档")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.pendingArchiveCount)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(4)
                    }

                    if viewModel.pendingArchiveCount > 0 {
                        Button("查看全部") {
                            viewModel.showPendingArchive = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                if let project = viewModel.selectedProject {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("\(project.noteCount) 笔记 • 最后更新 \(formatTime(project.lastUpdated))")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                } else {
                    Text("工作台")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                // 搜索
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)
                        .font(.caption)

                    TextField("搜索笔记...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 200)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)

                Button(action: { viewModel.showNewNoteSheet = true }) {
                    Label("新建笔记", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // 笔记列表
            if viewModel.filteredNotes.isEmpty {
                emptyState
            } else {
                noteList
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundStyle(Color.secondary.opacity(0.3))

            Text(viewModel.searchQuery.isEmpty ? "暂无笔记" : "未找到匹配内容")
                .font(.title3)
                .foregroundStyle(Color.secondary)

            if viewModel.searchQuery.isEmpty {
                Button("创建第一篇笔记") {
                    viewModel.showNewNoteSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Note List

    private var noteList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredNotes) { note in
                    NoteRow(note: note, viewModel: viewModel)

                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sidebar Item Row

struct WorkbenchSidebarItemRow: View {
    let item: TodayItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.priorityColor)
                .frame(width: 6, height: 6)

            Text(item.title)
                .font(.body)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(project.name)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                Text("\(project.noteCount)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
                .background(isSelected ? Color.accentColor : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: WorkbenchNote
    @ObservedObject var viewModel: WorkbenchViewModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppSurfaceTokens.accentPurple.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundStyle(AppSurfaceTokens.accentPurple)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(note.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(AppSurfaceTokens.cardBackgroundSoft)
                                    .cornerRadius(3)
                            }
                        }
                    }

                    Text(formatTime(note.updatedAt))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            // 操作按钮
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: { viewModel.editNote(note) }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("编辑")

                    Button(action: { viewModel.exportNote(note) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .help("导出")

                    Button(action: { viewModel.deleteNote(note) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
                    .help("删除")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? AppSurfaceTokens.cardBackgroundSoft : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Data Types

struct TodayItem: Identifiable {
    let id = UUID()
    let title: String
    let priority: Priority

    var priorityColor: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

enum Priority {
    case high
    case medium
    case low
}

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let noteCount: Int
    let lastUpdated: Date
}

struct WorkbenchNote: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - View Model

@MainActor
class WorkbenchViewModel: ObservableObject {
    // MARK: - Dependencies

    private let storage: StorageServiceProtocol

    @Published var todayItems: [TodayItem] = []
    @Published var projects: [Project] = []
    @Published var notes: [WorkbenchNote] = []
    @Published var selectedProject: Project?
    @Published var searchQuery = ""
    @Published var showNewProjectSheet = false
    @Published var showNewNoteSheet = false
    @Published var showPendingArchive = false
    @Published var pendingArchiveCount = 0

    var filteredNotes: [WorkbenchNote] {
        let projectNotes = selectedProject == nil ? notes : notes.filter { _ in true }

        if searchQuery.isEmpty {
            return projectNotes
        }

        return projectNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.content.localizedCaseInsensitiveContains(searchQuery) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    init() {
        self.storage = ServiceContainer.shared.storageService
        loadData()
    }

    // MARK: - Data Loading

    private func loadData() {
        Task {
            do {
                // 加载蒸馏笔记
                let distilledNotes = try await storage.listDistilledNotes()
                notes = distilledNotes.map { note in
                    WorkbenchNote(
                        title: note.title ?? "无标题",
                        content: note.contentMarkdown ?? note.summary ?? "",
                        tags: note.tags,
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    )
                }

                // 加载今日待整理条目（status == .captured）
                let capturedItems = try await storage.listSourceItems(
                    filter: SourceItemFilter(status: .captured)
                )
                let cal = Calendar.current
                todayItems = capturedItems
                    .filter { cal.isDate($0.createdAt, inSameDayAs: Date()) }
                    .map { item in
                        TodayItem(
                            title: item.title ?? "未命名",
                            priority: .medium
                        )
                    }

                // 当前先使用静态列表，后续再接入 Project 服务数据源
                projects = [
                    Project(name: "AcMind 开发", noteCount: notes.count, lastUpdated: Date()),
                    Project(name: "个人知识库", noteCount: 0, lastUpdated: Date().addingTimeInterval(-86400)),
                ]

                // 计算待归档数量
                let inboxItems = try await storage.listSourceItems(
                    filter: SourceItemFilter(status: .inbox)
                )
                pendingArchiveCount = inboxItems.count

            } catch {
                print("⚠️ Workbench 数据加载失败: \(error.localizedDescription)")
            }
        }
    }

    func selectProject(_ project: Project) {
        selectedProject = project
    }

    func openObsidian() {
        let appURL = URL(fileURLWithPath: "/Applications/Obsidian.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func syncWithObsidian() {
        openObsidian()
    }

    func editNote(_ note: WorkbenchNote) {
        openMarkdownDraft(note, prefix: "edit")
    }

    func exportNote(_ note: WorkbenchNote) {
        openMarkdownDraft(note, prefix: "export")
    }

    func deleteNote(_ note: WorkbenchNote) {
        Task {
            do {
                // 笔记作为 SourceItem 存储，通过 ID 删除
                try await storage.deleteSourceItem(id: note.id.uuidString)
                notes.removeAll { $0.id == note.id }
            } catch {
                print("⚠️ 删除笔记失败: \(error.localizedDescription)")
            }
        }
    }

    private func openMarkdownDraft(_ note: WorkbenchNote, prefix: String) {
        let filename = "\(prefix)-\(note.title.replacingOccurrences(of: "/", with: "_")).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let text = """
        # \(note.title)

        \(note.content)
        """
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            print("⚠️ 写入临时 Markdown 失败: \(error.localizedDescription)")
        }
    }
}
