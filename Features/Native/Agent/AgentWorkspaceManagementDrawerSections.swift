import AppKit
import SwiftUI
import AcMindKit

extension AgentWorkspaceManagementDrawerView {
    var managementRailShell: some View {
        ZStack(alignment: .leading) {
            if managementRailCollapsed {
                collapsedManagementRail
            } else {
                expandedManagementRail
            }

            railResizeHandle
        }
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            Group {
                if managementRailCollapsed {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                }
            }
        )
        .overlay(
            Group {
                if managementRailCollapsed {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ACColors.border.opacity(0.42), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ACColors.border.opacity(0.72), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(managementRailCollapsed ? 0.01 : 0.025), radius: managementRailCollapsed ? 2 : 5, x: 0, y: managementRailCollapsed ? 1 : 2)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: managementRailCollapsed)
    }

    var expandedManagementRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                managementRailHeader
                managementQuickActions
                ACSearchField("搜索对话 / 文件夹", text: $viewModel.searchText, width: nil, height: ACLayout.controlHeight)

                managementHistorySection
                managementFolderSection
                managementStatusSection
            }
            .padding(12)
        }
    }

    var collapsedManagementRail: some View {
        VStack(spacing: 5) {
            VStack(spacing: 5) {
                railIconButton(title: "新建", icon: "square.and.pencil", showsLabel: false, action: {
                    Task { await viewModel.createNewChat() }
                })
                railIconButton(title: "项目", icon: "folder.badge.plus", showsLabel: false, action: {
                    Task { await viewModel.createProjectFolder() }
                })
                railIconButton(title: "历史", icon: "clock.arrow.circlepath", badge: "\(viewModel.historySessions.count)", showsLabel: false, action: {
                    managementRailCollapsed = false
                })
                railIconButton(title: "文件夹", icon: "folder", badge: "\(viewModel.sidebarFolders.count)", showsLabel: false, action: {
                    managementRailCollapsed = false
                })
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
    }

    var managementRailHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("管理栏")
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text("新建、历史、归类与文件夹管理。")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    ACBadge("\(viewModel.historySessions.count)", kind: .neutral)
                    ACBadge("\(viewModel.sidebarFolders.count)", kind: .neutral)
                }
                Text("\(Int(managementRailWidth.rounded())) px")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
            }
        }
    }

    var managementQuickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            railLineButton(title: "新建对话", icon: "square.and.pencil") {
                Task { await viewModel.createNewChat() }
            }

            railLineButton(title: "新建项目", icon: "folder.badge.plus") {
                Task { await viewModel.createProjectFolder() }
            }

            railLineButton(title: "新建文件夹", icon: "folder.badge.plus") {
                Task { await viewModel.createProjectFolder() }
            }

            railLineButton(title: "当前会话", icon: "bubble.left.and.bubble.right") {
                managementRailCollapsed = false
                if let session = viewModel.selectedSessionSummary {
                    Task { await viewModel.selectSession(session.id) }
                }
            }

            Text("右键或菜单可进行重命名与归类。")
                .font(ACTypography.mini)
                .foregroundStyle(ACColors.tertiaryText)
        }
    }

    var managementHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("历史对话")
                Spacer(minLength: 0)
                Text("\(viewModel.historySessions.count)")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
            }

            VStack(spacing: 8) {
                if viewModel.recentSessionSections.isEmpty {
                    Text("没有找到符合条件的历史对话。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                        .padding(.vertical, 6)
                } else {
                    ForEach(viewModel.recentSessionSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            historySectionHeader(section)

                            VStack(spacing: 6) {
                                ForEach(section.sessions) { session in
                                    Button {
                                        Task { await viewModel.selectSession(session.id) }
                                    } label: {
                                        historySessionRow(session)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("删除对话", role: .destructive) {
                                            Task { await viewModel.deleteSession(session.id) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(9)
                        .background(section.kind.tint.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(section.kind.tint.opacity(0.10), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    var managementFolderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("项目文件夹")
                Spacer(minLength: 0)
                Text("\(viewModel.sidebarFolders.count)")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
            }

            VStack(spacing: 7) {
                ForEach(viewModel.sidebarFolders) { folder in
                    sidebarFolderRow(folder)
                }
            }
        }
    }

    var managementStatusSection: some View {
        ACCard(padding: 11) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("当前状态")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)

                    Button {
                        showsAuxiliaryDrawer = false
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ACColors.secondaryText)
                            .frame(width: 22, height: 22)
                            .background(ACColors.softFill)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ACColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                ACInfoTable([
                    .init("当前文件夹", value: viewModel.selectedFolderName),
                    .init("当前模型", value: viewModel.currentModelLabel),
                    .init("输出模式", value: viewModel.selectedActionMode.displayName),
                    .init("会话", value: viewModel.activeSessionTitle)
                ])

                if !viewModel.executionEntries.isEmpty {
                    Divider().overlay(ACColors.divider)
                    executionSummaryCard
                }
            }
        }
    }

    var executionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近执行")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.primaryText)
                Spacer(minLength: 0)
                Text(viewModel.lastExecutionTitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            VStack(spacing: 4) {
                ForEach(viewModel.executionEntries.prefix(4)) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(entry.accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.title)
                                    .font(ACTypography.mini)
                                    .foregroundStyle(ACColors.primaryText)
                                Spacer(minLength: 0)
                                Text(entry.timestamp.formattedAgentTime)
                                    .font(ACTypography.mini)
                                    .foregroundStyle(ACColors.tertiaryText)
                            }
                            Text(entry.detail)
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    if entry.id != viewModel.executionEntries.prefix(4).last?.id {
                        Divider().overlay(ACColors.border.opacity(0.55))
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ACColors.softFill.opacity(0.18))
        )
    }

    var railResizeHandle: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ACColors.border.opacity(0.35))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            Capsule()
                .fill(ACColors.softFill)
                .overlay(
                    Capsule().stroke(ACColors.border, lineWidth: 1)
                )
                .frame(width: 24, height: 32)
                .overlay(
                    VStack(spacing: 3) {
                        Capsule().fill(ACColors.tertiaryText.opacity(0.55)).frame(width: 8, height: 1.5)
                        Capsule().fill(ACColors.tertiaryText.opacity(0.55)).frame(width: 8, height: 1.5)
                        Capsule().fill(ACColors.tertiaryText.opacity(0.55)).frame(width: 8, height: 1.5)
                    }
                )
                .offset(x: -12, y: 24)
        }
        .frame(width: 12)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !managementRailCollapsed else { return }
                    if railDragBaseWidth == nil {
                        railDragBaseWidth = managementRailWidth
                    }

                    let baseWidth = railDragBaseWidth ?? managementRailWidth
                    let proposedWidth = baseWidth - value.translation.width
                    managementRailWidth = Double(clampManagementRailWidth(CGFloat(proposedWidth)))
                }
                .onEnded { _ in
                    defer { railDragBaseWidth = nil }
                    let currentWidth = clampManagementRailWidth(CGFloat(managementRailWidth))
                    managementRailWidth = Double(currentWidth)

                    if currentWidth <= AgentWorkspaceLayout.managementRailCollapsedTrigger {
                        managementRailCollapsed = true
                        managementRailWidth = Double(AgentWorkspaceLayout.defaultManagementRailWidth)
                    }
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    func railIconButton(title: String, icon: String, badge: String? = nil, showsLabel: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: showsLabel ? 4 : 0) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)
                        .frame(width: showsLabel ? 34 : 30, height: showsLabel ? 34 : 30)
                        .background(ACColors.softFill.opacity(showsLabel ? 1.0 : 0.75))
                        .clipShape(RoundedRectangle(cornerRadius: showsLabel ? 12 : 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: showsLabel ? 12 : 9, style: .continuous)
                                .stroke(ACColors.border.opacity(showsLabel ? 1 : 0.6), lineWidth: 1)
                        )

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ACColors.accentBlue)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }

                if showsLabel {
                    Text(title)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    func railLineButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ACColors.primaryText)
                    .frame(width: 28, height: 28)
                    .background(ACColors.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(ACColors.border, lineWidth: 1)
                    )

                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(ACColors.softFill.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func openFolderRenameSheet(_ folder: AgentProjectFolder) {
        folderRenameTarget = folder
    }

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(ACTypography.mini)
            .foregroundStyle(ACColors.secondaryText)
            .textCase(.uppercase)
            .tracking(0.3)
    }

    func sidebarFolderRow(_ folder: AgentProjectFolder) -> some View {
        let selected = folder.id == viewModel.selectedFolderID
        let expanded = viewModel.isFolderExpanded(folder.id)
        let nestedSessions = viewModel.sessions(in: folder.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Button {
                    viewModel.toggleFolderExpansion(folder.id)
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ACColors.tertiaryText)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(folder.id == "all")

                Button {
                    viewModel.selectFolder(folder.id)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selected ? folder.tint.opacity(0.18) : ACColors.softFill)
                                .frame(width: 32, height: 32)
                            Image(systemName: folder.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? folder.tint : ACColors.secondaryText)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(ACTypography.captionMedium)
                                .foregroundStyle(ACColors.primaryText)
                                .lineLimit(1)
                            Text(folder.subtitle)
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(folder.sessionCount)")
                                .font(ACTypography.mini)
                                .foregroundStyle(selected ? folder.tint : ACColors.tertiaryText)
                            if folder.id == "all" {
                                Text("全部会话")
                                    .font(ACTypography.mini)
                                    .foregroundStyle(ACColors.tertiaryText)
                            }
                        }

                        folderActionsMenu(folder)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(selected ? folder.tint.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? folder.tint.opacity(0.24) : ACColors.border, lineWidth: 1)
            )

            if folder.id != "all" && expanded {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(folder.tint.opacity(0.45))
                            .frame(width: 2, height: 16)
                        Text("会话")
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.tertiaryText)
                        Spacer(minLength: 0)
                        Text("\(nestedSessions.count)")
                            .font(ACTypography.mini)
                            .foregroundStyle(folder.tint)
                    }
                    .padding(.leading, 10)

                    if nestedSessions.isEmpty {
                        Text("暂无会话")
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 28)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(nestedSessions) { session in
                            Button {
                                Task { await viewModel.selectSession(session.id) }
                            } label: {
                                nestedSessionRow(session, selected: session.id == viewModel.selectedSessionID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
    }

    func folderActionsMenu(_ folder: AgentProjectFolder) -> some View {
        Menu {
            Button("切换到此文件夹") {
                viewModel.selectFolder(folder.id)
            }

            Button("将当前会话归入此文件夹") {
                if let session = viewModel.selectedSessionSummary {
                    Task { await viewModel.moveSession(session.id, to: folder.id) }
                }
            }

            if !folder.isSystem {
                Button("重命名") {
                    openFolderRenameSheet(folder)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ACColors.tertiaryText)
                .frame(width: 22, height: 22)
                .background(ACColors.softFill)
                .clipShape(Circle())
                .overlay(Circle().stroke(ACColors.border, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    func nestedSessionRow(_ session: AgentSessionSummary, selected: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Rectangle()
                .fill(selected ? session.tint : ACColors.border)
                .frame(width: 2, height: 34)
                .cornerRadius(1)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.title)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(session.timeLabel)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }
                Text(session.preview)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(selected ? session.tint.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    func historySessionRow(_ session: AgentSessionSummary) -> some View {
        let selected = session.id == viewModel.selectedSessionID

        return HStack(alignment: .top, spacing: 9) {
            ACTypeIcon(
                session.icon,
                tint: selected ? session.tint : ACColors.secondaryText,
                background: selected ? session.tint.opacity(0.12) : ACColors.softFill,
                size: 34
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(session.timeLabel)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(session.preview)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(selected ? ACColors.selectedFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(selected ? ACColors.accentBlue.opacity(0.28) : ACColors.border, lineWidth: 1)
        )
    }

    func historySectionHeader(_ section: AgentRecentSessionSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(section.kind.tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: section.kind.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(section.kind.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text(section.subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
            }

            Spacer(minLength: 0)

            Text("\(section.sessions.count)")
                .font(ACTypography.mini)
                .foregroundStyle(section.kind.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(section.kind.tint.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    func clampManagementRailWidth(_ width: CGFloat) -> CGFloat {
        min(
            max(width, AgentWorkspaceLayout.managementRailMinWidth),
            AgentWorkspaceLayout.managementRailMaxWidth
        )
    }
}
