import Foundation
import AppKit
import SwiftUI
import AcMindKit

struct AgentWorkspaceView: View {
    @StateObject private var viewModel = AgentWorkspaceViewModel()
    @StateObject private var providerManagementViewModel = SettingsViewModel()
    @AppStorage(AgentWorkspacePreferences.managementRailWidthKey) private var managementRailWidth: Double = AgentWorkspacePreferences.defaultManagementRailWidth
    @AppStorage(AgentWorkspacePreferences.managementRailCollapsedKey) private var managementRailCollapsed: Bool = true
    @AppStorage(AgentWorkspacePreferences.managementRailVisibleKey) private var managementRailVisible: Bool = true
    @State private var showsQuickAsk = false
    @State private var showsProviderManager = false
    @State private var quickAskText = ""
    @State private var railDragBaseWidth: Double?
    @State private var folderRenameTarget: AgentProjectFolder?
    @State private var showsAuxiliaryDrawer = false

    var body: some View {
        GeometryReader { geometry in
            let isCompactLayout = geometry.size.width < AgentWorkspaceLayout.compactLayoutThreshold
            let auxiliaryDrawerWidth = min(max(320, geometry.size.width * 0.24), AgentWorkspaceLayout.auxiliaryDrawerMaxWidth)
            let stackedDrawerWidth = max(geometry.size.width - ACLayout.pagePaddingX * 2, 0)
            let stackedDrawerHeight = min(max(420, geometry.size.height * 0.42), 560)

            VStack(alignment: .leading, spacing: 0) {
                conversationHeader
                    .frame(height: ACLayout.pageHeaderHeight)
                    .padding(.horizontal, ACLayout.pagePaddingX)

                if showsAuxiliaryDrawer {
                    if isCompactLayout {
                        VStack(alignment: .leading, spacing: ACLayout.panelGap) {
                            mainConversationContent

                            auxiliaryDrawer(width: stackedDrawerWidth, isCompact: true)
                                .frame(height: stackedDrawerHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, ACLayout.pagePaddingX)
                        .padding(.vertical, ACLayout.pagePaddingY)
                        .padding(.bottom, ACLayout.pagePaddingBottom)
                    } else {
                        HStack(alignment: .top, spacing: ACLayout.panelGap) {
                            mainConversationContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                            auxiliaryDrawer(width: auxiliaryDrawerWidth, isCompact: false)
                                .frame(width: auxiliaryDrawerWidth)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, ACLayout.pagePaddingX)
                        .padding(.vertical, ACLayout.pagePaddingY)
                        .padding(.bottom, ACLayout.pagePaddingBottom)
                    }
                } else {
                    mainConversationContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, ACLayout.pagePaddingX)
                        .padding(.vertical, ACLayout.pagePaddingY)
                        .padding(.bottom, ACLayout.pagePaddingBottom)
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.88), value: showsAuxiliaryDrawer)
            }
            .sheet(item: $folderRenameTarget) { folder in
                FolderRenameSheet(
                    folderName: folder.name,
                    isSystemFolder: folder.isSystem,
                    onConfirm: { newName in
                        Task { await viewModel.renameFolder(folderID: folder.id, to: newName) }
                    }
                )
            }
            .sheet(isPresented: $showsProviderManager) {
                ProviderManagementSheet(viewModel: providerManagementViewModel)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .acmindProvidersDidChange)) { _ in
            Task { await viewModel.refreshProviders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionVoiceAgentDraft)) { notification in
            if let draft = notification.object as? String {
                viewModel.acceptVoiceDraft(draft)
            }
        }
        .alert("Agent 错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var conversationHeader: some View {
        ViewThatFits(in: .horizontal) {
            conversationHeaderWide
            conversationHeaderCompact
        }
    }

    private var conversationHeaderWide: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.activeSessionTitle)
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)

                Text(viewModel.activeSessionSubtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ACBadge(viewModel.connectionStatusLabel, kind: viewModel.connectionStatusKind)
                ACBadge(viewModel.activeActionMode.displayName, kind: .blue)
                ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)

                actionButtonRow
            }
        }
    }

    private var conversationHeaderCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.activeSessionTitle)
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)

                Text(viewModel.activeSessionSubtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ACBadge(viewModel.connectionStatusLabel, kind: viewModel.connectionStatusKind)
                    ACBadge(viewModel.activeActionMode.displayName, kind: .blue)
                    ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)

                    actionButtonRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionButtonRow: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    showsQuickAsk.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Quick Ask")
                        .font(ACTypography.mini)
                }
                .foregroundStyle(ACColors.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(showsQuickAsk ? ACColors.selectedFill.opacity(0.8) : ACColors.softFill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(showsQuickAsk ? ACColors.accentPurple.opacity(0.35) : ACColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showsProviderManager = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Provider 管理")
                        .font(ACTypography.mini)
                }
                .foregroundStyle(ACColors.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(ACColors.softFill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ACColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showsAuxiliaryDrawer.toggle()
            } label: {
                Image(systemName: showsAuxiliaryDrawer ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ACColors.primaryText)
                    .frame(width: 32, height: 32)
                    .background(ACColors.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ACColors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var mainConversationContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsQuickAsk {
                AgentQuickAskStrip(
                    draft: $quickAskText,
                    title: "Quick Ask",
                    subtitle: "轻量提问，直接走现有 Agent 路由",
                    primaryActionTitle: "发送并新建会话",
                    secondaryActionTitle: "收起",
                    suggestions: Array(AgentActionMode.quickActions.prefix(3)),
                    onSend: {
                        Task { await sendQuickAsk() }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            showsQuickAsk = false
                        }
                    }
                )
            }

            threadView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)

            AgentInputComposer(
                inputText: $viewModel.inputText,
                selectedActionMode: $viewModel.selectedActionMode,
                selectedProviderID: $viewModel.selectedProviderID,
                providers: viewModel.enabledProviders,
                onProviderSelect: { providerID in
                    Task { await viewModel.selectProvider(providerID) }
                },
                onSend: {
                    Task { await viewModel.sendCurrentInput() }
                },
                onVoiceInput: {
                    NotificationCenter.default.post(name: .companionShowVoicePanel, object: nil)
                },
                onAttachFile: {
                    attachFilesToComposer()
                },
                onTools: {
                    showsAuxiliaryDrawer = true
                },
                onNewConversation: {
                    Task { await viewModel.createNewChat() }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func auxiliaryDrawer(width: CGFloat, isCompact: Bool) -> some View {
        managementRail(width: width, collapsed: false)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 18 : 20, style: .continuous)
                    .stroke(ACColors.border.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private func attachFilesToComposer() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = []
        panel.title = "选择要引用的文件"

        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard !urls.isEmpty else { return }

        let snippets = urls.map { "附件：\($0.lastPathComponent)" }.joined(separator: "\n")
        if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.inputText = "请结合这些附件一起处理：\n\(snippets)"
        } else {
            viewModel.inputText += "\n\n\(snippets)"
        }

        ToastManager.shared.show(.success, "已附加 \(urls.count) 个文件")
    }

    private func sendQuickAsk() async {
        let content = quickAskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let previousSessionID = viewModel.selectedSessionID
        quickAskText = ""
        showsQuickAsk = false

        await viewModel.createNewChat()
        viewModel.selectedActionMode = .auto
        viewModel.inputText = content
        await viewModel.sendCurrentInput()

        if let previousSessionID {
            await viewModel.selectSession(previousSessionID)
        }
    }

    private func managementRail(width: CGFloat, collapsed: Bool) -> some View {
        return ZStack(alignment: .leading) {
            if collapsed {
                collapsedManagementRail
            } else {
                expandedManagementRail
            }

            railResizeHandle
        }
        .frame(width: width, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Group {
                if collapsed {
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
                if collapsed {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ACColors.border.opacity(0.42), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ACColors.border.opacity(0.72), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(collapsed ? 0.01 : 0.025), radius: collapsed ? 2 : 5, x: 0, y: collapsed ? 1 : 2)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: managementRailCollapsed)
    }

    private var expandedManagementRail: some View {
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

    private var collapsedManagementRail: some View {
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

    private var managementRailHeader: some View {
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

    private var managementQuickActions: some View {
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

    private var managementHistorySection: some View {
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

    private var managementFolderSection: some View {
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

    private var managementStatusSection: some View {
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

    private var quickNavigatorCard: some View {
        EmptyView()
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.activeSessionTitle)
                        .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ACColors.primaryText)
                    Text(viewModel.activeSessionSubtitle)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    ACBadge(viewModel.selectedFolderName, kind: .neutral)
                    ACBadge(viewModel.activeActionMode.displayName, kind: .blue)
                    ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)
                }
            }

            HStack(spacing: 8) {
                Picker(
                    "模型",
                    selection: Binding(
                        get: { viewModel.selectedProviderID },
                        set: { providerID in
                            Task { await viewModel.selectProvider(providerID) }
                        }
                    )
                ) {
                    ForEach(viewModel.enabledProviders) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240, alignment: .leading)

                Picker("模式", selection: $viewModel.selectedActionMode) {
                    ForEach(AgentActionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 168, alignment: .leading)

                Spacer(minLength: 0)

                ACButton("继续当前会话", kind: .ghost, minWidth: 0) {
                    Task { await viewModel.reloadCurrentSession() }
                }

                railVisibilityToggleButton
            }
        }
    }

    private var threadView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 5) {
                    if viewModel.messages.isEmpty {
                        welcomeCard
                    } else {
                        ForEach(viewModel.messages) { message in
                            AgentMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 108)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: viewModel.messages.count) {
                guard let lastID = viewModel.messages.last?.id else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ACColors.accentPurple, ACColors.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("输入一句话，Agent 会直接执行。")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.primaryText)
                    Text("记笔记、建任务、排日程，或先搜索再整理结论。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }

            HStack(spacing: 4) {
                ForEach(AgentActionMode.quickActions) { mode in
                    Button {
                        viewModel.selectedActionMode = mode
                        viewModel.inputText = mode.suggestedPrompt
                    } label: {
                        Text(mode.displayName)
                            .font(ACTypography.mini)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ACColors.softFill.opacity(0.68))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 0)
    }

    private var executionSummaryCard: some View {
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

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("输入")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.primaryText)

                Spacer(minLength: 0)

                Text(viewModel.hintText)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            ZStack(alignment: .topLeading) {
                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("对 Agent 说：帮我了解这件事、创建待办、安排本周日程，或者把这段话整理成笔记。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }

                TextEditor(text: $viewModel.inputText)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 78)
                    .padding(3)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ACColors.softFill.opacity(0.16))
            )

            HStack(spacing: 4) {
                ForEach(AgentActionMode.quickActions) { mode in
                    Button {
                        viewModel.selectedActionMode = mode
                        if viewModel.inputText.isEmpty {
                            viewModel.inputText = mode.suggestedPrompt
                        }
                    } label: {
                        Text(mode.displayName)
                            .font(ACTypography.mini)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(viewModel.selectedActionMode == mode ? ACColors.selectedFill.opacity(0.72) : ACColors.softFill.opacity(0.55))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(viewModel.selectedActionMode == mode ? ACColors.accentBlue.opacity(0.75) : ACColors.border.opacity(0.6), lineWidth: 1)
                    )
                }

                Spacer(minLength: 0)

                ACButton("发送", kind: .primary, minWidth: 72) {
                    Task { await viewModel.sendCurrentInput() }
                }

                ACButton("新建对话", kind: .secondary, minWidth: 82) {
                    Task { await viewModel.createNewChat() }
                }
            }
        }
        .padding(6)
    }

    private var railResizeHandle: some View {
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

    private func railIconButton(title: String, icon: String, badge: String? = nil, showsLabel: Bool = true, action: @escaping () -> Void) -> some View {
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

    private func railChipButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(ACTypography.captionMedium)
                Spacer(minLength: 0)
            }
            .foregroundStyle(ACColors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(ACColors.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func railLineButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
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

    private func managementRailPresentation(for totalWidth: CGFloat) -> AgentRailPresentation {
        guard managementRailVisible else {
            return AgentRailPresentation(width: 0, collapsed: false, visible: false)
        }

        let baseWidth = clampManagementRailWidth(CGFloat(managementRailWidth))
        let maxAllowedWidth = max(
            totalWidth - ACLayout.pagePaddingX * 2 - ACLayout.panelGap - AgentWorkspaceLayout.centerMinWidth,
            AgentWorkspaceLayout.managementRailCollapsedWidth
        )

        let forcedCollapsed = totalWidth < AgentWorkspaceLayout.autoCollapseThreshold
        let collapsed = managementRailCollapsed || forcedCollapsed
        let width = collapsed
            ? AgentWorkspaceLayout.managementRailCollapsedWidth
            : min(baseWidth, maxAllowedWidth)

        return AgentRailPresentation(width: width, collapsed: collapsed, visible: true)
    }

    private func clampManagementRailWidth(_ width: CGFloat) -> CGFloat {
        min(
            max(width, AgentWorkspaceLayout.managementRailMinWidth),
            AgentWorkspaceLayout.managementRailMaxWidth
        )
    }

    private func openFolderRenameSheet(_ folder: AgentProjectFolder) {
        folderRenameTarget = folder
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(ACTypography.mini)
            .foregroundStyle(ACColors.secondaryText)
            .textCase(.uppercase)
            .tracking(0.3)
    }

    private func sidebarFolderRow(_ folder: AgentProjectFolder) -> some View {
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

    private var railVisibilityToggleButton: some View {
        Button {
            managementRailVisible.toggle()
        } label: {
            Image(systemName: managementRailVisible ? "sidebar.right" : "sidebar.left")
                .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ACColors.primaryText)
            .frame(width: 32, height: 32)
            .background(ACColors.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ACColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func folderActionsMenu(_ folder: AgentProjectFolder) -> some View {
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

    private func nestedSessionRow(_ session: AgentSessionSummary, selected: Bool) -> some View {
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

    private func historySessionRow(_ session: AgentSessionSummary) -> some View {
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

    private func historySectionHeader(_ section: AgentRecentSessionSection) -> some View {
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
}

@MainActor
final class AgentWorkspaceViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var inputText: String = ""
    @Published var selectedFolderID: String = AgentProjectFolder.systemFolders.first?.id ?? "all"
    @Published var selectedSessionID: String?
    @Published var selectedActionMode: AgentActionMode = .auto
    @Published var sessions: [AgentSessionSummary] = []
    @Published var messages: [ChatMessage] = []
    @Published var executionEntries: [AgentExecutionEntry] = []
    @Published var summaryItems: [AgentResultSummaryItem] = []
    @Published var toolChain: [AgentToolChainStep] = []
    @Published var enabledProviders: [ProviderConfig] = []
    @Published var selectedProviderID: String = ""
    @Published var expandedFolderIDs: Set<String> = Set(AgentProjectFolder.systemFolders.map(\.id).filter { $0 != "all" })
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hintText: String = "Enter 发送，Shift+Enter 换行"
    @Published var statusLabel: String = "待命"
    @Published var statusKind: ACBadge.Kind = .green
    @Published var lastActionTitle: String = "等待指令"

    private let storage: StorageServiceProtocol
    private let aiRuntime: AIRuntimeProtocol
    private let knowledgeService: KnowledgeServiceProtocol
    private let scheduleViewModel = ScheduleViewModel()
    private var didLoad = false
    private var projectFolders: [AgentProjectFolder] = AgentProjectFolder.systemFolders

    init() {
        let container = ServiceContainer.isInitialized() ? ServiceContainer.shared : nil
        let resolvedStorage = container?.storageService ?? StorageService()
        let resolvedAIRuntime = container?.aiRuntime ?? AIRuntimeService(storage: resolvedStorage)
        let resolvedKnowledge = container?.knowledgeService ?? KnowledgeService(storage: resolvedStorage)
        self.storage = resolvedStorage
        self.aiRuntime = resolvedAIRuntime
        self.knowledgeService = resolvedKnowledge
    }

    var sidebarFolders: [AgentProjectFolder] { visibleFolders }

    var historySessions: [AgentSessionSummary] {
        let query = trimmedSearchText
        return sessions
            .filter { matchesSearch($0, query: query) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8)
            .map { $0 }
    }

    var recentSessionSections: [AgentRecentSessionSection] {
        let query = trimmedSearchText
        let matchingSessions = sessions
            .filter { matchesSearch($0, query: query) }
            .sorted { $0.updatedAt > $1.updatedAt }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matchingSessions) { session in
            sectionKind(for: session.updatedAt, calendar: calendar)
        }

        return AgentRecentSessionSection.Kind.displayOrder.compactMap { kind -> AgentRecentSessionSection? in
            guard let sessions = grouped[kind], !sessions.isEmpty else { return nil }
            return AgentRecentSessionSection(
                kind: kind,
                sessions: sessions
            )
        }
    }

    var visibleFolders: [AgentProjectFolder] {
        let query = trimmedSearchText
        let folderCounts = Dictionary(uniqueKeysWithValues: projectFolders.map { folder in
            let count = sessions(in: folder.id, query: query).count
            return (folder.id, count)
        })

        return projectFolders
            .sorted { $0.order < $1.order }
            .filter { folder in
                guard folder.id != "all" else { return true }
                return query.isEmpty || matchesFolder(folder, query: query) || (folderCounts[folder.id] ?? 0) > 0
            }
            .map { folder in
                var copy = folder
                copy.sessionCount = folder.id == "all" ? filteredSessionCount(query: query) : (folderCounts[folder.id] ?? 0)
                return copy
            }
    }

    var visibleSessions: [AgentSessionSummary] {
        sessions(in: selectedFolderID)
    }

    var selectedFolderName: String {
        folder(for: selectedFolderID)?.name ?? "全部"
    }

    var activeSessionTitle: String {
        selectedSessionSummary?.title ?? "新建对话"
    }

    var activeSessionSubtitle: String {
        if let session = selectedSessionSummary {
            return "\(session.folderName) · \(session.messageCount) 条消息 · \(session.updatedAt.formattedAgentTime)"
        }
        return "选择一个历史对话，或者直接新建会话开始。"
    }

    var currentModelLabel: String {
        selectedProvider?.modelId ?? "本地回退"
    }

    var connectionStatusLabel: String {
        selectedProvider == nil ? "本地回退" : "在线"
    }

    var connectionStatusKind: ACBadge.Kind {
        selectedProvider == nil ? .neutral : .green
    }

    var routeSummary: String {
        selectedActionMode == .auto ? "智能判断" : selectedActionMode.displayName
    }

    var toolChainSummary: String {
        if toolChain.isEmpty {
            return "等待输入"
        }
        return "\(toolChain.filter { $0.state == .done }.count)/\(toolChain.count)"
    }

    var lastExecutionTitle: String {
        executionEntries.first?.title ?? "暂无执行"
    }

    var activeActionMode: AgentActionMode {
        selectedActionMode == .auto ? detectedActionMode(for: inputText) : selectedActionMode
    }

    var selectedSessionSummary: AgentSessionSummary? {
        sessions.first(where: { $0.id == selectedSessionID })
    }

    var selectedProvider: ProviderConfig? {
        enabledProviders.first(where: { $0.id == selectedProviderID }) ?? enabledProviders.first
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reloadWorkspace(selectNewestIfNeeded: true)
    }

    func refreshProviders() async {
        await reloadWorkspace(selectNewestIfNeeded: false)
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func acceptVoiceDraft(_ draft: String) {
        inputText = draft
        if selectedSessionID == nil {
            Task { await createNewChat() }
        }
        statusLabel = "已接收语音草稿"
        statusKind = .blue
    }

    func selectFolder(_ folderID: String) {
        selectedFolderID = folderID
        if folderID != "all" {
            expandedFolderIDs.insert(folderID)
        }
        if let first = visibleSessions.first {
            Task { await selectSession(first.id) }
        } else {
            selectedSessionID = nil
            messages = []
            toolChain = []
            summaryItems = []
        }
    }

    func createProjectFolder() async {
        let index = projectFolders.filter { !$0.isSystem }.count + 1
        let newFolder = AgentProjectFolder(
            id: "project-\(UUID().uuidString)",
            name: "项目 \(index)",
            subtitle: "新建项目文件夹",
            icon: "folder.fill",
            tint: ACColors.accentPurple,
            order: 100 + index,
            isSystem: false
        )
        projectFolders.append(newFolder)
        selectedFolderID = newFolder.id
        expandedFolderIDs.insert(newFolder.id)
        await createNewChat()
    }

    func moveSession(_ sessionID: String, to folderID: String) async {
        guard let folder = folder(for: folderID) else { return }

        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            session.metadata["folderId"] = folder.id
            session.metadata["folderName"] = folder.name
            session.metadata["folderIcon"] = folder.icon
            session.updatedAt = Date()
            try await storage.updateChatSession(session)

            selectedFolderID = folder.id
            selectedSessionID = sessionID
            statusLabel = "已归入文件夹"
            statusKind = .green

            await reloadWorkspace(selectNewestIfNeeded: false)
            await selectSession(sessionID)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func renameFolder(folderID: String, to newName: String) async {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let folder = folder(for: folderID), !folder.isSystem else { return }

        do {
            let folderSessionIDs = sessions
                .filter { $0.folderID == folderID }
                .map(\.id)

            for sessionID in folderSessionIDs {
                guard var session = try await storage.getChatSession(id: sessionID) else { continue }
                session.metadata["folderName"] = trimmedName
                session.updatedAt = Date()
                try await storage.updateChatSession(session)
            }

            selectedFolderID = folderID
            statusLabel = "文件夹已重命名"
            statusKind = .green
            await reloadWorkspace(selectNewestIfNeeded: false)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func createNewChat() async {
        let folder = folder(for: selectedFolderID) ?? AgentProjectFolder.systemFolders[0]
        let session = ChatSession(
            title: "新对话",
            providerId: selectedProvider?.id,
            modelId: selectedProvider?.modelId,
            status: .active,
            metadata: [
                "folderId": folder.id,
                "folderName": folder.name,
                "folderIcon": folder.icon,
                "actionMode": selectedActionMode.rawValue
            ]
        )

        do {
            try await storage.insertChatSession(session)
            selectedSessionID = session.id
            messages = []
            toolChain = []
            summaryItems = []
            lastActionTitle = "新会话"
            await reloadWorkspace(selectNewestIfNeeded: false)
            await selectSession(session.id)
            statusLabel = "新对话已创建"
            statusKind = .green
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func selectSession(_ sessionID: String) async {
        selectedSessionID = sessionID
        if let session = sessions.first(where: { $0.id == sessionID }) {
            selectedFolderID = session.folderID
            if session.folderID != "all" {
                expandedFolderIDs.insert(session.folderID)
            }
        }

        if let storedSession = try? await storage.getChatSession(id: sessionID) {
            if let providerId = storedSession.providerId,
               enabledProviders.contains(where: { $0.id == providerId }) {
                selectedProviderID = providerId
            } else if selectedProviderID.isEmpty {
                selectedProviderID = enabledProviders.first?.id ?? ""
            }

            if let rawMode = storedSession.metadata["actionMode"] {
                selectedActionMode = AgentActionMode(rawValue: rawMode) ?? selectedActionMode
            }
        }

        await reloadMessages(for: sessionID)
    }

    func selectProvider(_ providerID: String) async {
        guard enabledProviders.contains(where: { $0.id == providerID }) else { return }
        selectedProviderID = providerID
        await lockCurrentSessionProvider()
    }

    func reloadCurrentSession() async {
        guard let sessionID = selectedSessionID else { return }
        await reloadMessages(for: sessionID)
    }

    func sendCurrentInput() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            presentError("输入不能为空")
            return
        }

        if selectedSessionID == nil {
            await createNewChat()
        }

        guard let sessionID = selectedSessionID else { return }

        let userMessage = ChatMessage(
            sessionId: sessionID,
            role: .user,
            content: content,
            status: .completed
        )

        do {
            try await storage.insertChatMessage(userMessage)
            await updateSessionTitleIfNeeded(sessionID: sessionID, content: content)
        } catch {
            presentError(error.localizedDescription)
            return
        }

        messages.append(userMessage)
        inputText = ""
        isLoading = true
        statusLabel = "正在处理"
        statusKind = .blue
        toolChain = [AgentToolChainStep(title: "解析指令", detail: "判断输入是聊天、待办、搜索还是日程", state: .running, accent: ACColors.accentBlue)]

        let mode = selectedActionMode == .auto ? detectedActionMode(for: content) : selectedActionMode
        if selectedActionMode == .auto {
            selectedActionMode = mode
        }
        await updateSessionActionMode(sessionID: sessionID, mode: mode)
        await updateSessionProvider(sessionID: sessionID)

        do {
            let result = try await execute(content: content, sessionID: sessionID)
            toolChain = result.toolChain
            summaryItems = result.summaryItems
            lastActionTitle = result.title
            statusLabel = result.statusLabel
            statusKind = result.statusKind
            executionEntries.insert(
                AgentExecutionEntry(
                    title: result.title,
                    detail: result.detail,
                    state: result.executionState,
                    accent: result.statusKind == .green ? ACColors.accentGreen : ACColors.accentBlue,
                    timestamp: Date()
                ),
                at: 0
            )

            let assistantMessage = ChatMessage(
                sessionId: sessionID,
                role: .assistant,
                content: result.reply,
                status: .completed,
                modelId: selectedProvider?.modelId,
                providerId: selectedProvider?.id
            )
            messages.append(assistantMessage)
            try await storage.insertChatMessage(assistantMessage)
            await reloadWorkspace(selectNewestIfNeeded: false)
            await reloadMessages(for: sessionID)
        } catch {
            let fallback = ChatMessage(
                sessionId: sessionID,
                role: .assistant,
                content: "这条指令我已经接住了，但执行过程中遇到错误：\(error.localizedDescription)",
                status: .failed
            )
            messages.append(fallback)
            try? await storage.insertChatMessage(fallback)
            presentError(error.localizedDescription)
        }

        isLoading = false
    }

    func deleteSession(_ sessionID: String) async {
        do {
            try await storage.deleteChatSession(id: sessionID)
            if selectedSessionID == sessionID {
                selectedSessionID = nil
                messages = []
                executionEntries = []
                summaryItems = []
                toolChain = []
            }
            statusLabel = "会话已删除"
            statusKind = .neutral
            await reloadWorkspace(selectNewestIfNeeded: true)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func reloadWorkspace(selectNewestIfNeeded: Bool) async {
        do {
            enabledProviders = (await aiRuntime.listProviders()).filter { $0.enabled }
            if selectedProviderID.isEmpty {
                selectedProviderID = enabledProviders.first?.id ?? ""
            } else if !enabledProviders.contains(where: { $0.id == selectedProviderID }) {
                selectedProviderID = enabledProviders.first?.id ?? ""
            }

            let loadedSessions = try await storage.listChatSessions(status: nil)
            let summaries = await buildSessionSummaries(from: loadedSessions)
            sessions = summaries.sorted { $0.updatedAt > $1.updatedAt }

            projectFolders = AgentProjectFolder.systemFolders
            let dynamicFolders = summaries
                .map { $0.folder }
                .reduce(into: [String: AgentProjectFolder]()) { partialResult, folder in
                    partialResult[folder.id] = folder
                }
                .values
                .sorted { $0.order < $1.order }
            projectFolders.append(contentsOf: dynamicFolders.filter { folder in
                !AgentProjectFolder.systemFolders.contains(where: { $0.id == folder.id })
            })

            if selectNewestIfNeeded && selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
                if let sessionID = selectedSessionID {
                    selectedFolderID = sessions.first?.folderID ?? selectedFolderID
                    await reloadMessages(for: sessionID)
                }
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func reloadMessages(for sessionID: String) async {
        do {
            messages = try await storage.listChatMessages(sessionId: sessionID)
            await rebuildExecutionState(from: messages)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func updateSessionTitleIfNeeded(sessionID: String, content: String) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedTitle.isEmpty || trimmedTitle == "新对话" else { return }

            session.title = conciseTitle(from: content, fallback: "新对话")
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func updateSessionActionMode(sessionID: String, mode: AgentActionMode) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            session.metadata["actionMode"] = mode.rawValue
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            // 不中断主流程；这里仅用于记住会话偏好
        }
    }

    private func updateSessionProvider(sessionID: String) async {
        do {
            guard var session = try await storage.getChatSession(id: sessionID) else { return }
            guard let provider = selectedProvider else { return }
            session.providerId = provider.id
            session.modelId = provider.modelId
            session.metadata["providerId"] = provider.id
            session.metadata["providerName"] = provider.name
            session.metadata["providerType"] = provider.providerType.storageValue
            session.metadata["providerTier"] = provider.tier.storageValue
            session.metadata["modelId"] = provider.modelId
            session.updatedAt = Date()
            try await storage.updateChatSession(session)
        } catch {
            // 继续执行，不阻断主流程
        }
    }

    private func lockCurrentSessionProvider() async {
        guard let sessionID = selectedSessionID else { return }
        await updateSessionProvider(sessionID: sessionID)
    }

    private func rebuildExecutionState(from messages: [ChatMessage]) async {
        guard let latestUser = messages.last(where: { $0.role == .user }) else {
            toolChain = []
            summaryItems = []
            return
        }

        let mode = selectedActionMode == .auto ? detectedActionMode(for: latestUser.content) : selectedActionMode
        toolChain = buildToolChain(for: mode, content: latestUser.content)
        summaryItems = buildSummaryItems(for: mode, content: latestUser.content)
    }

    private func execute(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let mode = selectedActionMode == .auto ? detectedActionMode(for: content) : selectedActionMode

        switch mode {
        case .chat:
            return try await executeChat(content: content, sessionID: sessionID)
        case .task:
            return try await executeTask(content: content, sessionID: sessionID)
        case .search:
            return try await executeSearch(content: content, sessionID: sessionID)
        case .schedule:
            return try await executeSchedule(content: content, sessionID: sessionID)
        case .note:
            return try await executeNote(content: content, sessionID: sessionID)
        case .auto:
            return try await executeChat(content: content, sessionID: sessionID)
        }
    }

    private func executeChat(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let history = try await storage.listChatMessages(sessionId: sessionID)
        let systemPrompt = """
        你是 AcMind 的原生聊天式 Agent。
        你需要简洁、可执行地回应用户，并优先给出下一步动作。
        当用户提到待办、日程、资料搜索、记笔记时，请输出清晰结果，不要写空话。
        """

        let promptMessages = [ChatMessage(sessionId: sessionID, role: .system, content: systemPrompt, status: .completed)] + history

        do {
            if let provider = selectedProvider {
                let response = try await aiRuntime.chat(messages: promptMessages, providerId: provider.id, model: provider.modelId)
                return AgentExecutionResult(
                    title: "对话已完成",
                    detail: "通过 \(provider.name) / \(provider.modelId) 生成回复",
                    reply: response.content,
                    toolChain: buildToolChain(for: .chat, content: content),
                    summaryItems: buildSummaryItems(for: .chat, content: content),
                    statusLabel: "已回复",
                    statusKind: .green,
                    executionState: .done
                )
            }

            let fallback = buildLocalReply(for: content)
            return AgentExecutionResult(
                title: "本地回复",
                detail: "没有可用模型配置，已使用本地回退策略",
                reply: fallback,
                toolChain: buildToolChain(for: .chat, content: content),
                summaryItems: buildSummaryItems(for: .chat, content: content),
                statusLabel: "本地回退",
                statusKind: .neutral,
                executionState: .done
            )
        } catch {
            let fallback = buildLocalReply(for: content)
            return AgentExecutionResult(
                title: "对话失败后回退",
                detail: error.localizedDescription,
                reply: fallback,
                toolChain: buildToolChain(for: .chat, content: content),
                summaryItems: buildSummaryItems(for: .chat, content: content),
                statusLabel: "回退完成",
                statusKind: .orange,
                executionState: .failed
            )
        }
    }

    private func executeTask(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let title = conciseTitle(from: content, fallback: "新待办")
        let steps = [
            TaskStep(title: "整理需求", description: content, status: .completed, order: 1),
            TaskStep(title: "拆解步骤", description: "已形成 3-5 个可执行动作", status: .completed, order: 2),
            TaskStep(title: "写入任务看板", description: "已转入任务管理", status: .completed, order: 3),
            TaskStep(title: "等待执行", description: "后续可继续追问或接着执行", status: .pending, order: 4)
        ]
        let task = AgentTask(
            title: title,
            description: content,
            status: .running,
            priority: .medium,
            steps: steps,
            currentStepIndex: 0,
            sourceMessageId: sessionID
        )

        let createdTask = try await persistTask(task)

        return AgentExecutionResult(
            title: "已创建任务",
            detail: "任务《\(createdTask.title)》已写入任务看板",
            reply: "我已经把这条内容整理成待办《\(createdTask.title)》，并放入任务看板。你可以继续让我拆解步骤、补充优先级，或者直接开始执行。",
            toolChain: buildToolChain(for: .task, content: content),
            summaryItems: [
                AgentResultSummaryItem(title: "任务标题", value: createdTask.title, tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "状态", value: createdTask.status.displayName, tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "优先级", value: createdTask.priority.displayName, tint: ACColors.accentPurple)
            ],
            statusLabel: "任务已建",
            statusKind: .green,
            executionState: .done
        )
    }

    private func executeSearch(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let query = searchQuery(from: content)
        let cardResults = try await knowledgeService.searchCards(query: query)
        let vaultResults = (try? await knowledgeService.searchVault(query: query)) ?? []
        let webResults = try? await performWebSearch(query: query)

        var replyParts: [String] = []
        if !cardResults.isEmpty {
            replyParts.append("知识库结果：")
            replyParts.append(contentsOf: cardResults.prefix(3).map { "• \($0.canonicalTitle) · \($0.summary ?? "无摘要")" })
        }
        if !vaultResults.isEmpty {
            replyParts.append("Vault 结果：")
            replyParts.append(contentsOf: vaultResults.prefix(3).map { "• \($0.title) · \($0.excerpt)" })
        }
        if let webResults, !webResults.isEmpty {
            replyParts.append("联网搜索：")
            replyParts.append(contentsOf: webResults.prefix(3).map { "• \($0.title)\n  \($0.url)" })
        }
        if replyParts.isEmpty {
            replyParts.append("没有搜到直接命中的资料，但我已经把这条问题转成可继续追问的搜索请求。")
        }

        return AgentExecutionResult(
            title: "搜索完成",
            detail: "查询「\(query)」已完成",
            reply: replyParts.joined(separator: "\n\n"),
            toolChain: [
                AgentToolChainStep(title: "搜索知识库", detail: "调用 `searchCards`", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "搜索 Vault", detail: "调用 `searchVault`", state: .done, accent: ACColors.accentPurple),
                AgentToolChainStep(title: "联网搜索", detail: "通过 DuckDuckGo HTML 接口检索", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "知识卡片", value: "\(cardResults.count) 条", tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "Vault 结果", value: "\(vaultResults.count) 条", tint: ACColors.accentPurple),
                AgentResultSummaryItem(title: "联网结果", value: "\(webResults?.count ?? 0) 条", tint: ACColors.accentGreen)
            ],
            statusLabel: "搜索完成",
            statusKind: .green,
            executionState: .done
        )
    }

    private func executeSchedule(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let parsed = parseScheduleIntent(from: content)
        let title = parsed.title
        let categoryId = scheduleViewModel.categories.first?.id ?? "default"

        scheduleViewModel.openCreateEvent(on: parsed.date, hour: parsed.hour, minute: parsed.minute)
        scheduleViewModel.createEvent(
            title: title,
            categoryId: categoryId,
            startHour: parsed.hour,
            startMinute: parsed.minute,
            durationMinutes: parsed.duration,
            isAllDay: false
        )

        let timeLabel = parsed.date.formatted(date: .abbreviated, time: .shortened)
        return AgentExecutionResult(
            title: "已安排日程",
            detail: "日程《\(title)》已写入系统日历",
            reply: "我已经把这条内容安排成日程《\(title)》，时间是 \(timeLabel)。如果你愿意，我还可以继续帮你补参会人、拆成待办，或者改成全天事件。",
            toolChain: [
                AgentToolChainStep(title: "解析时间", detail: "提取日期和时刻", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "创建日程", detail: "已写入系统日历", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "标题", value: title, tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "时间", value: timeLabel, tint: ACColors.accentBlue),
                AgentResultSummaryItem(title: "时长", value: "\(parsed.duration) 分钟", tint: ACColors.accentPurple)
            ],
            statusLabel: "日程已写入",
            statusKind: .green,
            executionState: .done
        )
    }

    private func persistTask(_ task: AgentTask) async throws -> AgentTask {
        let encoded = String(data: try JSONEncoder().encode(task), encoding: .utf8) ?? ""
        try await storage.setSetting(key: "agent_task_\(task.id)", value: encoded)

        let existingIndex = (try await storage.getSetting(key: "agent_task_index")) ?? "[]"
        if let data = existingIndex.data(using: .utf8),
           var ids = try? JSONDecoder().decode([String].self, from: data),
           !ids.contains(task.id) {
            ids.insert(task.id, at: 0)
            let encodedIDs = String(data: try JSONEncoder().encode(ids), encoding: .utf8) ?? "[]"
            try await storage.setSetting(key: "agent_task_index", value: encodedIDs)
        } else {
            let encodedIDs = String(data: try JSONEncoder().encode([task.id]), encoding: .utf8) ?? "[]"
            try await storage.setSetting(key: "agent_task_index", value: encodedIDs)
        }

        return task
    }

    private func executeNote(content: String, sessionID: String) async throws -> AgentExecutionResult {
        let item = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: conciseTitle(from: content, fallback: "语音笔记"),
            previewText: content
        )
        try await storage.insertSourceItem(item)

        return AgentExecutionResult(
            title: "已保存笔记",
            detail: "内容已写入收集箱",
            reply: "我已经把这段内容保存为笔记《\(item.title ?? "语音笔记")》，后续可以继续帮你蒸馏、归类或者转成任务。",
            toolChain: [
                AgentToolChainStep(title: "整理笔记", detail: "提取语音内容", state: .done, accent: ACColors.accentBlue),
                AgentToolChainStep(title: "写入收集箱", detail: "已保存原文", state: .done, accent: ACColors.accentGreen)
            ],
            summaryItems: [
                AgentResultSummaryItem(title: "笔记标题", value: item.title ?? "语音笔记", tint: ACColors.accentGreen),
                AgentResultSummaryItem(title: "状态", value: "已保存", tint: ACColors.accentBlue)
            ],
            statusLabel: "笔记已存",
            statusKind: .green,
            executionState: .done
        )
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
        statusLabel = "出错"
        statusKind = .orange
    }

    private func buildSessionSummaries(from sessions: [ChatSession]) async -> [AgentSessionSummary] {
        var summaries: [AgentSessionSummary] = []

        for session in sessions {
            let folderID = session.metadata["folderId"] ?? "all"
            let folder = folder(for: folderID) ?? AgentProjectFolder(
                id: folderID,
                name: session.metadata["folderName"] ?? "未分类",
                subtitle: "历史归档",
                icon: "folder",
                tint: ACColors.accentBlue,
                order: 200,
                isSystem: false
            )
            let messages = (try? await storage.listChatMessages(sessionId: session.id)) ?? []
            let preview = messages.last(where: { $0.role != .system })?.content ?? "暂无消息"
            let icon = session.metadata["folderIcon"] ?? folder.icon
            let tint = folder.tint
            summaries.append(
                AgentSessionSummary(
                    id: session.id,
                    title: session.title,
                    folderID: folderID,
                    folderName: folder.name,
                    folder: folder,
                    preview: preview,
                    messageCount: messages.count,
                    createdAt: session.createdAt,
                    updatedAt: session.updatedAt,
                    timeLabel: session.updatedAt.formattedAgentTime,
                    icon: icon,
                    tint: tint
                )
            )
        }

        return summaries
    }

    private func folder(for id: String) -> AgentProjectFolder? {
        projectFolders.first(where: { $0.id == id }) ?? AgentProjectFolder.systemFolders.first(where: { $0.id == id })
    }

    func sessions(in folderID: String, query: String? = nil) -> [AgentSessionSummary] {
        let trimmedQuery = (query ?? trimmedSearchText)
        let base = folderID == "all"
            ? sessions
            : sessions.filter { $0.folderID == folderID }

        let filtered: [AgentSessionSummary]
        if trimmedQuery.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { matchesSearch($0, query: trimmedQuery) }
        }

        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    func isFolderExpanded(_ folderID: String) -> Bool {
        folderID == "all" ? false : expandedFolderIDs.contains(folderID)
    }

    func toggleFolderExpansion(_ folderID: String) {
        guard folderID != "all" else { return }
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func filteredSessionCount(query: String) -> Int {
        query.isEmpty ? sessions.count : sessions.filter { matchesSearch($0, query: query) }.count
    }

    private func matchesFolder(_ folder: AgentProjectFolder, query: String) -> Bool {
        folder.name.localizedCaseInsensitiveContains(query) ||
        folder.subtitle.localizedCaseInsensitiveContains(query)
    }

    private func matchesSearch(_ session: AgentSessionSummary, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return session.title.localizedCaseInsensitiveContains(query) ||
        session.preview.localizedCaseInsensitiveContains(query) ||
        session.folderName.localizedCaseInsensitiveContains(query)
    }

    private func sectionKind(for date: Date, calendar: Calendar) -> AgentRecentSessionSection.Kind {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }

        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()),
           weekInterval.contains(date) {
            return .thisWeek
        }

        if let monthInterval = calendar.dateInterval(of: .month, for: Date()),
           monthInterval.contains(date) {
            return .thisMonth
        }

        return .earlier
    }

    private func buildToolChain(for mode: AgentActionMode, content: String) -> [AgentToolChainStep] {
        switch mode {
        case .chat:
            return [
                .init(title: "解析上下文", detail: "识别对话目标", state: .done, accent: ACColors.accentBlue),
                .init(title: "生成回复", detail: "使用当前模型输出", state: .done, accent: ACColors.accentGreen),
                .init(title: "保存会话", detail: "写入本地历史", state: .done, accent: ACColors.accentPurple)
            ]
        case .task:
            return [
                .init(title: "解析任务", detail: "转成待办", state: .done, accent: ACColors.accentBlue),
                .init(title: "拆解步骤", detail: "整理为 3-5 个动作", state: .done, accent: ACColors.accentPurple),
                .init(title: "写入任务看板", detail: "创建 AgentTask", state: .done, accent: ACColors.accentGreen),
                .init(title: "生成回顾", detail: "输出下一步建议", state: .done, accent: ACColors.accentOrange)
            ]
        case .search:
            return [
                .init(title: "搜索知识库", detail: "searchCards", state: .done, accent: ACColors.accentBlue),
                .init(title: "搜索 Vault", detail: "searchVault", state: .done, accent: ACColors.accentPurple),
                .init(title: "联网检索", detail: "DuckDuckGo HTML", state: .done, accent: ACColors.accentGreen),
                .init(title: "汇总结论", detail: "生成可追问答案", state: .done, accent: ACColors.accentOrange)
            ]
        case .schedule:
            return [
                .init(title: "解析日期", detail: "自然语言时间解析", state: .done, accent: ACColors.accentBlue),
                .init(title: "创建日程", detail: "写入系统日历", state: .done, accent: ACColors.accentGreen),
                .init(title: "回写摘要", detail: "告诉你已安排的时间", state: .done, accent: ACColors.accentPurple)
            ]
        case .note:
            return [
                .init(title: "整理笔记", detail: "记录到收集箱", state: .done, accent: ACColors.accentBlue),
                .init(title: "生成摘要", detail: "准备后续蒸馏", state: .done, accent: ACColors.accentGreen),
                .init(title: "保存到收集箱", detail: "形成可追踪记录", state: .done, accent: ACColors.accentPurple)
            ]
        case .auto:
            return buildToolChain(for: detectedActionMode(for: content), content: content)
        }
    }

    private func buildSummaryItems(for mode: AgentActionMode, content: String) -> [AgentResultSummaryItem] {
        switch mode {
        case .chat:
            return []
        case .task:
            return [
                .init(title: "目标", value: conciseTitle(from: content), tint: ACColors.accentGreen),
                .init(title: "类型", value: "任务", tint: ACColors.accentBlue)
            ]
        case .search:
            return [
                .init(title: "查询", value: searchQuery(from: content), tint: ACColors.accentBlue)
            ]
        case .schedule:
            let parsed = parseScheduleIntent(from: content)
            return [
                .init(title: "标题", value: parsed.title, tint: ACColors.accentGreen),
                .init(title: "时间", value: parsed.date.formattedAgentTime, tint: ACColors.accentBlue)
            ]
        case .note:
            return [
                .init(title: "笔记", value: conciseTitle(from: content), tint: ACColors.accentPurple)
            ]
        case .auto:
            return buildSummaryItems(for: detectedActionMode(for: content), content: content)
        }
    }

    private func detectedActionMode(for content: String) -> AgentActionMode {
        let normalized = content.lowercased()
        if normalized.contains("日程") || normalized.contains("安排") || normalized.contains("提醒") || normalized.contains("会议") {
            return .schedule
        }
        if normalized.contains("待办") || normalized.contains("任务") || normalized.contains("todo") || normalized.contains("办") {
            return .task
        }
        if normalized.contains("笔记") || normalized.contains("记录") || normalized.contains("保存") || normalized.contains("记一下") {
            return .note
        }
        if normalized.contains("搜索") || normalized.contains("查一下") || normalized.contains("了解") || normalized.contains("联网") || normalized.contains("信息") {
            return .search
        }
        return .chat
    }

    private func buildLocalReply(for content: String) -> String {
        let mode = detectedActionMode(for: content)
        switch mode {
        case .task:
            return "我已经把这句话整理成可执行待办，你也可以继续让我拆成 3 到 5 步。"
        case .search:
            return "我正在帮你搜资料，并会把要点整理成可直接继续追问的结论。"
        case .schedule:
            return "我已经把这句话理解成日程请求，接下来会帮你落到具体时间。"
        case .note:
            return "我会把这段内容当成笔记收进收集箱。"
        case .chat, .auto:
            return "我已经收到这条消息。你可以继续让我把它变成待办、日程、笔记，或者先搜索信息。"
        }
    }

    private func conciseTitle(from text: String, fallback: String = "新任务") -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(18))
        return prefix.isEmpty ? fallback : prefix
    }

    private func searchQuery(from text: String) -> String {
        let keywords = [
            "搜索", "查一下", "了解", "联网", "信息", "资料", "关于", "帮我找", "帮我看看"
        ]
        var cleaned = text
        for keyword in keywords {
            cleaned = cleaned.replacingOccurrences(of: keyword, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseScheduleIntent(from text: String) -> ScheduleDraft {
        let calendar = Calendar.current
        let now = Date()
        var targetDate = now
        var hour = max(calendar.component(.hour, from: now) + 1, 8)
        var minute = 0
        var duration = 60

        if text.contains("明天"), let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            targetDate = tomorrow
        } else if text.contains("后天"), let dayAfter = calendar.date(byAdding: .day, value: 2, to: now) {
            targetDate = dayAfter
        } else {
            targetDate = now
        }

        if let match = text.firstMatch(of: /(\d{1,2})[:点](\d{1,2})?/) {
            hour = Int(match.1) ?? hour
            minute = Int(match.2 ?? Substring("0")) ?? 0
        } else if text.contains("下午") || text.contains("晚上") {
            hour = min(hour + 6, 22)
        } else if text.contains("上午") {
            hour = min(hour, 11)
        }

        if text.contains("半小时") {
            duration = 30
        } else if text.contains("两小时") {
            duration = 120
        } else if text.contains("一小时") {
            duration = 60
        }

        let title = conciseTitle(from: text, fallback: "新日程")
        return ScheduleDraft(title: title, date: targetDate, hour: hour, minute: minute, duration: duration)
    }

    private func performWebSearch(query: String) async throws -> [WebSearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://duckduckgo.com/html/?q=\(encoded)") else {
            return []
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let pattern = #"<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        return matches.prefix(5).compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { return nil }
            let urlString = String(html[urlRange]).replacingOccurrences(of: "&amp;", with: "&")
            let rawTitle = String(html[titleRange])
            let title = rawTitle
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return WebSearchResult(title: title, url: urlString)
        }
    }
}

enum AgentActionMode: String, CaseIterable, Identifiable {
    case auto
    case chat
    case task
    case search
    case schedule
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "智能判断"
        case .chat: return "普通对话"
        case .task: return "创建任务"
        case .search: return "搜索信息"
        case .schedule: return "安排日程"
        case .note: return "记笔记"
        }
    }

    var suggestedPrompt: String {
        switch self {
        case .auto, .chat:
            return "帮我把这段内容整理成可执行的回复。"
        case .task:
            return "把这段话转成待办任务，并拆成步骤。"
        case .search:
            return "帮我搜索相关信息，并提炼成要点。"
        case .schedule:
            return "帮我把这段话安排成日程。"
        case .note:
            return "把这段内容记成一条笔记。"
        }
    }

    static var quickActions: [AgentActionMode] {
        [.task, .search, .schedule, .note]
    }
}

struct AgentProjectFolder: Identifiable {
    let id: String
    var name: String
    var subtitle: String
    var icon: String
    var tint: Color
    var order: Int
    var isSystem: Bool
    var sessionCount: Int = 0

    static let systemFolders: [AgentProjectFolder] = [
        .init(id: "all", name: "全部", subtitle: "所有对话", icon: "tray.full", tint: ACColors.accentBlue, order: 0, isSystem: true),
        .init(id: "task", name: "任务", subtitle: "待办与执行", icon: "checklist", tint: ACColors.accentGreen, order: 1, isSystem: true),
        .init(id: "research", name: "研究", subtitle: "搜索与分析", icon: "magnifyingglass", tint: ACColors.accentPurple, order: 2, isSystem: true),
        .init(id: "schedule", name: "日程", subtitle: "时间安排", icon: "calendar", tint: ACColors.accentOrange, order: 3, isSystem: true),
        .init(id: "notes", name: "笔记", subtitle: "记录与蒸馏", icon: "note.text", tint: ACColors.accentBlue, order: 4, isSystem: true)
    ]
}

struct AgentSessionSummary: Identifiable {
    let id: String
    let title: String
    let folderID: String
    let folderName: String
    let folder: AgentProjectFolder
    let preview: String
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
    let timeLabel: String
    let icon: String
    let tint: Color
}

struct AgentRecentSessionSection: Identifiable {
    enum Kind: String, CaseIterable {
        case today
        case yesterday
        case thisWeek
        case thisMonth
        case earlier

        static var displayOrder: [Kind] { [.today, .yesterday, .thisWeek, .thisMonth, .earlier] }

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .yesterday: return "moon.stars.fill"
            case .thisWeek: return "calendar"
            case .thisMonth: return "calendar.badge.clock"
            case .earlier: return "clock.arrow.circlepath"
            }
        }

        var tint: Color {
            switch self {
            case .today: return ACColors.accentBlue
            case .yesterday: return ACColors.accentPurple
            case .thisWeek: return ACColors.accentGreen
            case .thisMonth: return ACColors.accentOrange
            case .earlier: return ACColors.secondaryText
            }
        }

        var title: String {
            switch self {
            case .today: return "今天"
            case .yesterday: return "昨天"
            case .thisWeek: return "本周"
            case .thisMonth: return "本月"
            case .earlier: return "更早"
            }
        }

        var subtitle: String {
            switch self {
            case .today: return "最近更新"
            case .yesterday: return "昨天的对话"
            case .thisWeek: return "本周内的对话"
            case .thisMonth: return "这个月的对话"
            case .earlier: return "更早之前"
            }
        }
    }

    let kind: Kind
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
    let sessions: [AgentSessionSummary]

    var id: String { kind.rawValue }
}

struct AgentRailPresentation {
    let width: CGFloat
    let collapsed: Bool
    let visible: Bool
}

private enum AgentWorkspacePreferences {
    static let managementRailWidthKey = "AgentWorkspace.managementRailWidth"
    static let managementRailCollapsedKey = "AgentWorkspace.managementRailCollapsed"
    static let managementRailVisibleKey = "AgentWorkspace.managementRailVisible"
    static let defaultManagementRailWidth: Double = 232
}

private enum AgentWorkspaceLayout {
    static let centerMinWidth: CGFloat = 540
    static let managementRailMinWidth: CGFloat = 204
    static let managementRailMaxWidth: CGFloat = 260
    static let managementRailCollapsedWidth: CGFloat = 50
    static let managementRailCollapsedTrigger: CGFloat = 84
    static let defaultManagementRailWidth: CGFloat = 232
    static let auxiliaryDrawerMaxWidth: CGFloat = 388
    static let compactLayoutThreshold: CGFloat = 1180
    static let autoCollapseThreshold: CGFloat = 1100
}

private struct FolderRenameSheet: View {
    let folderName: String
    let isSystemFolder: Bool
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String

    init(folderName: String, isSystemFolder: Bool, onConfirm: @escaping (String) -> Void) {
        self.folderName = folderName
        self.isSystemFolder = isSystemFolder
        self.onConfirm = onConfirm
        self._draftName = State(initialValue: folderName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("重命名文件夹")
                .font(ACTypography.cardTitle)
                .foregroundStyle(ACColors.primaryText)

            Text(isSystemFolder ? "系统文件夹不可重命名。" : "输入新名称后保存，会同步到该文件夹下的所有会话。")
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
                .lineSpacing(2)

            TextField("文件夹名称", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .disabled(isSystemFolder)

            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer(minLength: 0)

                Button("保存") {
                    onConfirm(draftName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSystemFolder || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

struct AgentToolChainStep: Identifiable {
    enum State: String, Hashable {
        case done
        case running
        case waiting
        case failed
    }

    let id = UUID()
    let title: String
    let detail: String
    let state: State
    let accent: Color
}

struct AgentResultSummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

struct AgentExecutionEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: AgentToolChainStep.State
    let accent: Color
    let timestamp: Date
}

struct AgentExecutionResult {
    let title: String
    let detail: String
    let reply: String
    let toolChain: [AgentToolChainStep]
    let summaryItems: [AgentResultSummaryItem]
    let statusLabel: String
    let statusKind: ACBadge.Kind
    let executionState: AgentToolChainStep.State
}

struct ScheduleDraft {
    let title: String
    let date: Date
    let hour: Int
    let minute: Int
    let duration: Int
}

struct WebSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
}

struct AgentQuickAskStrip: View {
    @Binding var draft: String
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let suggestions: [AgentActionMode]
    let onSend: () -> Void
    let onDismiss: () -> Void

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)

                Button(secondaryActionTitle, action: onDismiss)
                    .buttonStyle(.plain)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            HStack(spacing: 5) {
                ForEach(suggestions) { mode in
                    Button {
                        draft = mode.suggestedPrompt
                    } label: {
                        Text(mode.displayName)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.primaryText)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ACColors.softFill.opacity(0.68))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ACColors.border.opacity(0.6), lineWidth: 1)
                    )
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)

                    TextField("输入一句话，直接进入现有 Agent 路由", text: $draft)
                        .font(ACTypography.caption)
                        .textFieldStyle(.plain)
                        .foregroundStyle(ACColors.primaryText)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(ACColors.softFill.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ACColors.border.opacity(0.75), lineWidth: 1)
                )

                Button(action: onSend) {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(primaryActionTitle)
                            .font(ACTypography.mini)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(ACColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(SendButtonHoverStyle())
                .disabled(trimmedDraft.isEmpty)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ACColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

struct AgentMessageRow: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }
    private var isSystem: Bool { message.role == .system }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 0) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isUser ? ACColors.accentPurple : (isSystem ? ACColors.secondaryText : ACColors.accentBlue))
                        .frame(width: 4, height: 4)
                    Text(roleLabel)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    Text(message.createdAt.formattedAgentTime)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Text(message.content)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.primaryText)
                    .lineSpacing(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: 500, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isUser ? ACColors.selectedFill.opacity(0.32) : ACColors.softFill.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isUser ? ACColors.accentPurple.opacity(0.08) : ACColors.border.opacity(0.32), lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 0) }
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .system: return "系统"
        case .user: return "你"
        case .assistant: return "Agent"
        case .tool: return "工具"
        }
    }
}

struct ToolChainRow: View {
    let step: AgentToolChainStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(step.accent)
                .frame(width: 7, height: 7)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(step.title)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.primaryText)
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }
                Text(step.detail)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var statusText: String {
        switch step.state {
        case .done: return "完成"
        case .running: return "进行中"
        case .waiting: return "等待"
        case .failed: return "失败"
        }
    }
}

struct ResultSummaryRow: View {
    let item: AgentResultSummaryItem

    var body: some View {
        HStack {
            Text(item.title)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(item.value)
                .font(ACTypography.caption)
                .foregroundStyle(item.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private extension Date {
    var formattedAgentTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}
