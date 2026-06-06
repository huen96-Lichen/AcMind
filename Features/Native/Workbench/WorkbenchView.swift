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
                .frame(width: 184)
                .background(AppSurfaceTokens.secondarySidebarBackground)

            Divider()

            // 右侧内容
            content
        }
        .background(AppSurfaceTokens.background)
        .sheet(item: $viewModel.projectEditorDraft) { draft in
            WorkbenchProjectEditorSheet(
                draft: draft,
                onCancel: {
                    viewModel.projectEditorDraft = nil
                },
                onSave: { updatedDraft in
                    viewModel.saveProjectDraft(updatedDraft)
                }
            )
        }
        .sheet(item: $viewModel.noteEditorDraft) { draft in
            WorkbenchNoteEditorSheet(
                draft: draft,
                projects: viewModel.projects,
                onCancel: {
                    viewModel.noteEditorDraft = nil
                },
                onSave: { updatedDraft in
                    viewModel.saveNoteDraft(updatedDraft)
                }
            )
        }
        .sheet(isPresented: $viewModel.showPendingArchive) {
            WorkbenchArchiveSheet(
                items: viewModel.pendingArchiveItems,
                onClose: { viewModel.showPendingArchive = false }
            )
        }
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
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(4)
                    }

                    if viewModel.todayItems.isEmpty {
                        Text("今日暂无待整理内容")
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
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

                        Button(action: { viewModel.presentNewProjectEditor() }) {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(viewModel.projects) { project in
                        ProjectRow(project: project, isSelected: viewModel.selectedProject?.id == project.id, onEdit: {
                            viewModel.editProject(project)
                        }, onDelete: {
                            viewModel.deleteProject(project)
                        }) {
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
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .cornerRadius(4)
                    }

                    if viewModel.pendingArchiveCount > 0 {
                        Button("查看全部") {
                            viewModel.presentPendingArchive()
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
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .font(.caption)

                    TextField("搜索笔记...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 160)
                }
                .padding(6)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(6)

                Button(action: { viewModel.presentNewNoteEditor() }) {
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
                .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.3))

            Text(emptyStateTitle)
                .font(.title3)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            if viewModel.projects.isEmpty {
                Button("新建项目") {
                    viewModel.presentNewProjectEditor()
                }
                .buttonStyle(.borderedProminent)
            } else if viewModel.searchQuery.isEmpty {
                Button("创建第一篇笔记") {
                    viewModel.presentNewNoteEditor()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if viewModel.projects.isEmpty {
            return "还没有项目"
        }
        return viewModel.searchQuery.isEmpty ? "暂无笔记" : "未找到匹配内容"
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
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.background : AppSurfaceTokens.secondaryText)

                Text(project.name)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                Text("\(project.noteCount)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? AppSurfaceTokens.background.opacity(0.7) : AppSurfaceTokens.secondaryText)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
                .background(isSelected ? AppSurfaceTokens.accentBlue : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("编辑") {
                onEdit()
            }

            Button("删除", role: .destructive) {
                onDelete()
            }
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
                    .fill(AppSurfaceTokens.accentPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundStyle(AppSurfaceTokens.accentPrimary)
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
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
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
                    .foregroundStyle(AppSurfaceTokens.accentOrange)
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

struct Project: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var noteCount: Int
    var lastUpdated: Date
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, noteCount: Int = 0, lastUpdated: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.noteCount = noteCount
        self.lastUpdated = lastUpdated
        self.sortOrder = sortOrder
    }
}

extension Project {
    init(snapshot: WorkbenchProjectSnapshot) {
        self.init(
            id: UUID(uuidString: snapshot.id) ?? UUID(),
            name: snapshot.name,
            noteCount: snapshot.noteCount,
            lastUpdated: snapshot.lastUpdated,
            sortOrder: snapshot.sortOrder
        )
    }

    var snapshot: WorkbenchProjectSnapshot {
        WorkbenchProjectSnapshot(
            id: id.uuidString,
            name: name,
            noteCount: noteCount,
            lastUpdated: lastUpdated,
            sortOrder: sortOrder
        )
    }
}

struct WorkbenchNote: Identifiable, Equatable {
    let id: String
    let projectID: UUID
    var title: String
    var content: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct WorkbenchProjectDraft: Identifiable, Equatable {
    let id = UUID()
    var projectID: UUID?
    var name: String
}

struct WorkbenchNoteDraft: Identifiable, Equatable {
    let id = UUID()
    var noteID: String?
    var projectID: UUID
    var title: String
    var content: String
    var tags: String
    var createdAt: Date?
}

struct WorkbenchArchiveItem: Identifiable, Equatable {
    let id: String
    let title: String
    let status: String
    let createdAt: Date
}

// MARK: - View Model

@MainActor
class WorkbenchViewModel: ObservableObject {
    private let storage: StorageServiceProtocol

    @Published var todayItems: [TodayItem] = []
    @Published var projects: [Project] = []
    @Published var notes: [WorkbenchNote] = []
    @Published var selectedProject: Project?
    @Published var searchQuery = ""
    @Published var pendingArchiveCount = 0
    @Published var pendingArchiveItems: [WorkbenchArchiveItem] = []
    @Published var projectEditorDraft: WorkbenchProjectDraft?
    @Published var noteEditorDraft: WorkbenchNoteDraft?
    @Published var showPendingArchive = false

    var filteredNotes: [WorkbenchNote] {
        let projectNotes: [WorkbenchNote]
        if let selectedProject {
            projectNotes = notes.filter { $0.projectID == selectedProject.id }
        } else {
            projectNotes = notes
        }

        if searchQuery.isEmpty {
            return projectNotes
        }

        return projectNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.content.localizedCaseInsensitiveContains(searchQuery) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    init(storage: StorageServiceProtocol = StorageService()) {
        self.storage = storage
        loadData()
    }

    private func loadData() {
        Task {
            do {
                let loadedProjects = try await WorkbenchProjectStore.loadProjects(from: storage)
                projects = loadedProjects.map(Project.init(snapshot:))
                if let persistedID = try await WorkbenchProjectStore.loadSelectedProjectID(from: storage),
                   let project = projects.first(where: { $0.id.uuidString == persistedID }) {
                    selectedProject = project
                } else {
                    selectedProject = projects.first
                }

                let distilledNotes = try await storage.listDistilledNotes()
                notes = distilledNotes.map { note in
                    WorkbenchNote(
                        id: note.id,
                        projectID: UUID(uuidString: note.sourceItemId) ?? UUID(),
                        title: note.title ?? "无标题",
                        content: note.contentMarkdown ?? note.summary ?? "",
                        tags: note.tags,
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    )
                }

                reconcileNotesIntoProjects()

                let cal = Calendar.current
                let capturedItems = try await storage.listSourceItems(filter: SourceItemFilter(status: .captured))
                todayItems = capturedItems
                    .filter { cal.isDate($0.createdAt, inSameDayAs: Date()) }
                    .map { item in
                        TodayItem(
                            title: item.title ?? "未命名",
                            priority: .medium
                        )
                    }

                let inboxItems = try await storage.listSourceItems(filter: SourceItemFilter(status: .inbox))
                pendingArchiveCount = inboxItems.count
                pendingArchiveItems = inboxItems.prefix(20).map {
                    WorkbenchArchiveItem(
                        id: $0.id,
                        title: $0.title ?? "未命名",
                        status: $0.status.rawValue,
                        createdAt: $0.createdAt
                    )
                }

                reconcileNotesIntoProjects()
            } catch {
                print("⚠️ Workbench 数据加载失败: \(error.localizedDescription)")
            }
        }
    }

    func presentNewProjectEditor() {
        projectEditorDraft = WorkbenchProjectDraft(projectID: nil, name: "")
    }

    func editProject(_ project: Project) {
        projectEditorDraft = WorkbenchProjectDraft(projectID: project.id, name: project.name)
    }

    func saveProjectDraft(_ draft: WorkbenchProjectDraft) {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        if let projectID = draft.projectID, let index = projects.firstIndex(where: { $0.id == projectID }) {
            projects[index].name = trimmed
        } else {
            let sortOrder = (projects.map(\.sortOrder).max() ?? -1) + 1
            let newProject = Project(name: trimmed, sortOrder: sortOrder)
            projects.append(newProject)
            selectedProject = newProject
            Task {
                try? await WorkbenchProjectStore.saveSelectedProjectID(newProject.id.uuidString, to: storage)
            }
        }

        projects.sort { $0.sortOrder < $1.sortOrder }
        reconcileNotesIntoProjects()
        Task {
            try? await WorkbenchProjectStore.saveProjects(projects.map(\.snapshot), to: storage)
        }
        projectEditorDraft = nil
    }

    func deleteProject(_ project: Project) {
        guard projects.count > 1 else { return }

        let replacementProject = projects.first(where: { $0.id != project.id })
        let reassignedProjectID = replacementProject?.id
        let affectedNotes = notes.filter { $0.projectID == project.id }

        Task {
            for note in affectedNotes {
                let updated = DistilledNote(
                    id: note.id,
                    sourceItemId: reassignedProjectID?.uuidString ?? note.projectID.uuidString,
                    title: note.title,
                    summary: note.content,
                    category: "workbench",
                    tags: note.tags,
                    contentMarkdown: note.content,
                    createdAt: note.createdAt,
                    updatedAt: Date()
                )
                try? await storage.updateDistilledNote(updated)
            }
            await refreshNotesFromStorage()
            await MainActor.run {
                projects.removeAll { $0.id == project.id }
                if selectedProject?.id == project.id {
                    selectedProject = replacementProject
                    if let replacementProject {
                        Task {
                            try? await WorkbenchProjectStore.saveSelectedProjectID(replacementProject.id.uuidString, to: storage)
                        }
                    }
                }
                reconcileNotesIntoProjects()
            }
            try? await WorkbenchProjectStore.saveProjects(projects.map(\.snapshot), to: storage)
        }
    }

    func presentNewNoteEditor() {
        let project = selectedProject ?? projects.first
        guard let project else { return }
        noteEditorDraft = WorkbenchNoteDraft(noteID: nil, projectID: project.id, title: "", content: "", tags: "", createdAt: nil)
    }

    func editNote(_ note: WorkbenchNote) {
        noteEditorDraft = WorkbenchNoteDraft(
            noteID: note.id,
            projectID: note.projectID,
            title: note.title,
            content: note.content,
            tags: note.tags.joined(separator: ", "),
            createdAt: note.createdAt
        )
    }

    func saveNoteDraft(_ draft: WorkbenchNoteDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTags = draft.tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard trimmedTitle.isEmpty == false else { return }

        let sourceItemID = draft.projectID.uuidString
        let now = Date()
        let createdAt = draft.createdAt ?? now
        let note = DistilledNote(
            id: draft.noteID ?? UUID().uuidString,
            sourceItemId: sourceItemID,
            title: trimmedTitle,
            summary: trimmedContent,
            category: "workbench",
            tags: trimmedTags,
            contentMarkdown: trimmedContent,
            createdAt: createdAt,
            updatedAt: now
        )

        Task {
            do {
                if draft.noteID == nil {
                    try await storage.insertDistilledNote(note)
                } else {
                    try await storage.updateDistilledNote(note)
                }
                await refreshNotesFromStorage()
                await MainActor.run {
                    noteEditorDraft = nil
                    reconcileNotesIntoProjects()
                }
            } catch {
                print("⚠️ 保存笔记失败: \(error.localizedDescription)")
            }
        }
    }

    func deleteNote(_ note: WorkbenchNote) {
        Task {
            do {
                try await storage.deleteDistilledNote(id: note.id)
                await refreshNotesFromStorage()
                await MainActor.run {
                    reconcileNotesIntoProjects()
                }
            } catch {
                print("⚠️ 删除笔记失败: \(error.localizedDescription)")
            }
        }
    }

    func selectProject(_ project: Project) {
        selectedProject = project
        Task {
            try? await WorkbenchProjectStore.saveSelectedProjectID(project.id.uuidString, to: storage)
        }
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

    func exportNote(_ note: WorkbenchNote) {
        openMarkdownDraft(note, prefix: "export")
    }

    func presentPendingArchive() {
        showPendingArchive = true
    }

    private func refreshNotesFromStorage() async {
        do {
            let distilledNotes = try await storage.listDistilledNotes()
            let fallbackProjectID = projects.first?.id ?? UUID()
            notes = distilledNotes.map { note in
                WorkbenchNote(
                    id: note.id,
                    projectID: UUID(uuidString: note.sourceItemId) ?? fallbackProjectID,
                    title: note.title ?? "无标题",
                    content: note.contentMarkdown ?? note.summary ?? "",
                    tags: note.tags,
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt
                )
            }
        } catch {
            print("⚠️ 刷新笔记失败: \(error.localizedDescription)")
        }
    }

    private func reconcileNotesIntoProjects() {
        guard projects.isEmpty == false else { return }

        for index in projects.indices {
            let projectID = projects[index].id
            let projectNotes = notes.filter { $0.projectID == projectID }
            projects[index].noteCount = projectNotes.count
            projects[index].lastUpdated = projectNotes.map(\.updatedAt).max() ?? projects[index].lastUpdated
        }

        projects.sort { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.lastUpdated > rhs.lastUpdated
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        if let selectedID = selectedProject?.id,
           let updatedSelected = projects.first(where: { $0.id == selectedID }) {
            selectedProject = updatedSelected
        }

        Task {
            try? await WorkbenchProjectStore.saveProjects(projects.map(\.snapshot), to: storage)
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

// MARK: - Sheets

struct WorkbenchProjectEditorSheet: View {
    let draft: WorkbenchProjectDraft
    let onCancel: () -> Void
    let onSave: (WorkbenchProjectDraft) -> Void
    @State private var name: String

    init(draft: WorkbenchProjectDraft, onCancel: @escaping () -> Void, onSave: @escaping (WorkbenchProjectDraft) -> Void) {
        self.draft = draft
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: draft.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.projectID == nil ? "新建项目" : "编辑项目")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("项目名称", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Button("保存") {
                    var updated = draft
                    updated.name = name
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

struct WorkbenchNoteEditorSheet: View {
    let draft: WorkbenchNoteDraft
    let projects: [Project]
    let onCancel: () -> Void
    let onSave: (WorkbenchNoteDraft) -> Void
    @State private var projectID: UUID
    @State private var title: String
    @State private var content: String
    @State private var tags: String

    init(
        draft: WorkbenchNoteDraft,
        projects: [Project],
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkbenchNoteDraft) -> Void
    ) {
        self.draft = draft
        self.projects = projects
        self.onCancel = onCancel
        self.onSave = onSave
        _projectID = State(initialValue: draft.projectID)
        _title = State(initialValue: draft.title)
        _content = State(initialValue: draft.content)
        _tags = State(initialValue: draft.tags)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.noteID == nil ? "新建笔记" : "编辑笔记")
                .font(.title3)
                .fontWeight(.semibold)

            Picker("项目", selection: $projectID) {
                ForEach(projects) { project in
                    Text(project.name).tag(project.id)
                }
            }
            .pickerStyle(.menu)

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppSurfaceTokens.separator.opacity(0.2), lineWidth: 1)
                )

            TextField("标签，使用逗号分隔", text: $tags)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Button("保存") {
                    var updated = draft
                    updated.projectID = projectID
                    updated.title = title
                    updated.content = content
                    updated.tags = tags
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}

struct WorkbenchArchiveSheet: View {
    let items: [WorkbenchArchiveItem]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待归档")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("当前收集箱里尚未处理的条目。")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                Spacer()

                Button("关闭", action: onClose)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)
                                Text(item.status)
                                    .font(.caption)
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }

                            Spacer()

                            Text(RelativeDateTimeFormatter().localizedString(for: item.createdAt, relativeTo: Date()))
                                .font(.caption)
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                        .padding(12)
                        .background(AppSurfaceTokens.cardBackgroundSoft)
                        .cornerRadius(8)
                    }

                    if items.isEmpty {
                        Text("当前没有待归档条目。")
                            .font(.body)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .padding(.top, 12)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .background(AppSurfaceTokens.background)
    }
}
