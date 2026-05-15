import SwiftUI

struct WorkbenchView: View {
    @State private var selectedSection: WorkbenchSection = .knowledgeBase
    @State private var searchText: String = ""
    @State private var selectedNoteID: UUID = workbenchNotes.first?.id ?? UUID()

    private var filteredNotes: [WorkbenchNote] {
        let notes = workbenchNotes.filter { note in
            let sectionMatch: Bool
            switch selectedSection {
            case .knowledgeBase:
                sectionMatch = note.section == .knowledgeBase
            case .projectNotes:
                sectionMatch = note.section == .projectNotes
            case .archive:
                sectionMatch = note.section == .archive
            }

            let searchMatch = searchText.isEmpty || note.title.localizedCaseInsensitiveContains(searchText) || note.excerpt.localizedCaseInsensitiveContains(searchText)
            return sectionMatch && searchMatch
        }

        return notes
    }

    private var selectedNote: WorkbenchNote? {
        filteredNotes.first { $0.id == selectedNoteID } ?? filteredNotes.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ACPageHeader(
                title: "工作台",
                subtitle: "知识沉淀 · Markdown · 双链 · Obsidian",
                trailing: {
                    HStack(spacing: 12) {
                        ACSearchField("搜索笔记", text: $searchText, width: 260, height: 36)
                        ACButton("新建笔记", kind: .primary, minWidth: 92) {}
                    }
                }
            )
            .frame(height: 72)

            HStack(alignment: .top, spacing: ACLayout.gapL) {
                sidebar
                    .frame(width: 240)

                centerPanel
                    .frame(maxWidth: .infinity)

                detailPanel
                    .frame(width: 430)
            }
            .padding(.horizontal, ACLayout.pagePaddingX)
            .padding(.vertical, ACLayout.pagePaddingY)
            .padding(.bottom, ACLayout.pagePaddingBottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(ACColors.pageBackground)
    }

    private var sidebar: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text("知识入口")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(WorkbenchSection.allCases) { section in
                        WorkbenchSidebarRow(
                            section: section,
                            count: section.count,
                            selected: selectedSection == section
                        ) {
                            selectedSection = section
                            selectedNoteID = section.firstNoteID ?? selectedNoteID
                        }
                    }
                }

                Divider()
                    .overlay(ACColors.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Obsidian")
                        .font(ACTypography.panelTitle)
                        .foregroundStyle(ACColors.primaryText)

                    ACButton("打开 Obsidian", kind: .secondary, action: {})
                    ACButton("同步双链", kind: .ghost, action: {})
                }
            }
        }
    }

    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            topContextCard

            if filteredNotes.isEmpty {
                ACCard {
                    ACEmptyState(
                        icon: "text.book.closed",
                        title: "当前没有可显示的笔记",
                        subtitle: "试试切换知识库、项目笔记或待归档。"
                    )
                }
            } else {
                ACCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredNotes) { note in
                            WorkbenchNoteRow(
                                note: note,
                                selected: selectedNoteID == note.id
                            ) {
                                selectedNoteID = note.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var topContextCard: some View {
        ACCard(padding: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSection.title)
                        .font(ACTypography.sectionTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(selectedSection.subtitle)
                        .font(ACTypography.body)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ForEach(["Markdown", "双链", "Obsidian"], id: \.self) { tag in
                        ACBadge(tag, kind: .neutral)
                    }
                }
            }
        }
    }

    private var detailPanel: some View {
        ACDetailPanel(width: 430, padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                if let selectedNote {
                    WorkbenchDetailHeader(note: selectedNote)
                    WorkbenchExcerptCard(note: selectedNote)
                    WorkbenchBacklinksCard(note: selectedNote)
                    WorkbenchMetadataCard(note: selectedNote)
                } else {
                    ACEmptyState(
                        icon: "square.stack",
                        title: "选择一条笔记查看关联",
                        subtitle: "这里会展示摘要、标签、双链和元数据。"
                    )
                }
            }
        }
    }
}

private struct WorkbenchSidebarRow: View {
    let section: WorkbenchSection
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ACTypeIcon(section.icon, tint: selected ? ACColors.accentBlue : ACColors.secondaryText, background: selected ? ACColors.selectedFill : ACColors.softFill, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("\(count) 条")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(selected ? ACColors.selectedFill : ACColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(selected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WorkbenchNoteRow: View {
    let note: WorkbenchNote
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ACListRow(
                title: note.title,
                subtitle: note.excerpt,
                symbol: "doc.text",
                selected: selected,
                tint: note.tint,
                meta: note.updated,
                trailing: note.section.title
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WorkbenchDetailHeader: View {
    let note: WorkbenchNote

    var body: some View {
        HStack(spacing: 12) {
            ACTypeIcon("doc.text", tint: note.tint, background: note.tint.opacity(0.12), size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(note.updated)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WorkbenchExcerptCard: View {
    let note: WorkbenchNote

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("摘要")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(note.excerpt)
                    .font(ACTypography.body)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineSpacing(4)
            }
        }
    }
}

private struct WorkbenchBacklinksCard: View {
    let note: WorkbenchNote

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("双链与关联")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                VStack(spacing: 8) {
                    ForEach(note.backlinks, id: \.self) { link in
                        HStack(spacing: 10) {
                            ACTypeIcon("arrow.triangle.branch", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 32)
                            Text(link)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(ACColors.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(ACColors.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct WorkbenchMetadataCard: View {
    let note: WorkbenchNote

    var body: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("元数据")
                    .font(ACTypography.panelTitle)
                    .foregroundStyle(ACColors.primaryText)

                ACInfoTable([
                    .init("分类", value: note.section.title),
                    .init("标签", value: note.tags.joined(separator: " · ")),
                    .init("字数", value: note.wordCount),
                    .init("路径", value: note.path)
                ])
            }
        }
    }
}

private struct WorkbenchNote: Identifiable {
    let id = UUID()
    let title: String
    let excerpt: String
    let updated: String
    let section: WorkbenchSection
    let tags: [String]
    let backlinks: [String]
    let path: String
    let wordCount: String
    let tint: Color
}

private enum WorkbenchSection: String, CaseIterable, Identifiable {
    case knowledgeBase
    case projectNotes
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knowledgeBase: return "知识库"
        case .projectNotes: return "项目笔记"
        case .archive: return "待归档"
        }
    }

    var subtitle: String {
        switch self {
        case .knowledgeBase: return "长期沉淀与结构化知识"
        case .projectNotes: return "项目推进与临时整理"
        case .archive: return "待清理和待整理内容"
        }
    }

    var icon: String {
        switch self {
        case .knowledgeBase: return "books.vertical"
        case .projectNotes: return "note.text"
        case .archive: return "archivebox"
        }
    }

    var count: Int {
        switch self {
        case .knowledgeBase: return workbenchNotes.filter { $0.section == .knowledgeBase }.count
        case .projectNotes: return workbenchNotes.filter { $0.section == .projectNotes }.count
        case .archive: return workbenchNotes.filter { $0.section == .archive }.count
        }
    }

    var firstNoteID: UUID? {
        workbenchNotes.first { $0.section == self }?.id
    }
}

private let workbenchNotes: [WorkbenchNote] = [
    .init(
        title: "AcMind 2.0 UI 设计系统",
        excerpt: "统一颜色、字号、间距、圆角与基础组件，并逐页替换旧 NotchV2 风格卡片。",
        updated: "今天 09:20",
        section: .knowledgeBase,
        tags: ["DesignSystem", "macOS", "UI"],
        backlinks: ["灵动胶囊 / 大陆", "设置中心"],
        path: "Knowledge/Design/AcMind-UI.md",
        wordCount: "1,284 字",
        tint: ACColors.accentBlue
    ),
    .init(
        title: "Agent 工作台交互草案",
        excerpt: "左栏对话列表，中栏对话流和执行计划，右栏任务 Inspector。",
        updated: "今天 08:56",
        section: .projectNotes,
        tags: ["Agent", "Workflow", "Mock"],
        backlinks: ["工作台 / 知识整理"],
        path: "Projects/Agent/Workspace.md",
        wordCount: "862 字",
        tint: ACColors.accentPurple
    ),
    .init(
        title: "快速整理记录",
        excerpt: "整理收集箱、剪贴板与归档内容的迁移清单。",
        updated: "昨天 18:10",
        section: .archive,
        tags: ["Archive", "Cleanup"],
        backlinks: ["收集箱", "剪贴板"],
        path: "Archive/2026-05-14.md",
        wordCount: "436 字",
        tint: ACColors.accentOrange
    ),
    .init(
        title: "Obsidian 同步规范",
        excerpt: "需要确保双链、标签和目录结构在本地与 Obsidian 中一致。",
        updated: "昨天 11:20",
        section: .knowledgeBase,
        tags: ["Obsidian", "Sync"],
        backlinks: ["知识库总览"],
        path: "Knowledge/Obsidian/Sync.md",
        wordCount: "706 字",
        tint: ACColors.accentGreen
    ),
    .init(
        title: "待归档的会议纪要",
        excerpt: "会议纪要、临时想法和未整理的参考链接。",
        updated: "昨天 09:40",
        section: .archive,
        tags: ["Minutes", "Inbox"],
        backlinks: ["收集箱 / 今日"],
        path: "Archive/Meetings.md",
        wordCount: "391 字",
        tint: ACColors.accentRed
    )
]
