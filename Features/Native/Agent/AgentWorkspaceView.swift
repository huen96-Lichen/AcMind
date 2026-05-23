import Foundation
import AppKit
import SwiftUI
import AcMindKit

struct AgentWorkspaceView: View {
    @StateObject private var viewModel: AgentWorkspaceViewModel
    @StateObject private var providerManagementViewModel: SettingsViewModel
    @AppStorage(AgentWorkspacePreferences.managementRailWidthKey) private var managementRailWidth: Double = AgentWorkspacePreferences.defaultManagementRailWidth
    @AppStorage(AgentWorkspacePreferences.managementRailCollapsedKey) private var managementRailCollapsed: Bool = true
    @State private var showsQuickAsk = false
    @State private var showsProviderManager = false
    @State private var quickAskText = ""
    @State private var railDragBaseWidth: Double?
    @State private var folderRenameTarget: AgentProjectFolder?
    @State private var showsAuxiliaryDrawer = false
    @EnvironmentObject private var toastManager: ToastManager

    init(container: ServiceContainer) {
        self._viewModel = StateObject(wrappedValue: AgentWorkspaceViewModel(container: container))
        self._providerManagementViewModel = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompactLayout = geometry.size.width < AgentWorkspaceLayout.compactLayoutThreshold
            let auxiliaryDrawerWidth = min(max(320, geometry.size.width * 0.24), AgentWorkspaceLayout.auxiliaryDrawerMaxWidth)
            let stackedDrawerWidth = max(geometry.size.width - ACLayout.pagePaddingX * 2, 0)
            let stackedDrawerHeight = min(max(420, geometry.size.height * 0.42), 560)

            VStack(alignment: .leading, spacing: 0) {
                AgentWorkspaceHeaderView(
                    viewModel: viewModel,
                    showsQuickAsk: $showsQuickAsk,
                    showsProviderManager: $showsProviderManager,
                    showsAuxiliaryDrawer: $showsAuxiliaryDrawer
                )
                    .frame(height: ACLayout.headerHeightMedium)
                    .padding(.horizontal, AcMindSurfaceTokens.pagePadding)
                    .padding(.top, AcMindSurfaceTokens.pagePadding)
                    .padding(.bottom, 12)

                Group {
                    if showsAuxiliaryDrawer {
                        if isCompactLayout {
                            VStack(alignment: .leading, spacing: ACLayout.panelGap) {
                                mainConversationContent

                                auxiliaryDrawer(width: stackedDrawerWidth, isCompact: true)
                                    .frame(height: stackedDrawerHeight)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, AcMindSurfaceTokens.pagePadding)
                            .padding(.vertical, AcMindSurfaceTokens.pagePaddingY)
                            .padding(.bottom, AcMindSurfaceTokens.pagePaddingY)
                        } else {
                            HStack(alignment: .top, spacing: ACLayout.panelGap) {
                                mainConversationContent
                                    .frame(maxWidth: .infinity, alignment: .topLeading)

                                auxiliaryDrawer(width: auxiliaryDrawerWidth, isCompact: false)
                                    .frame(width: auxiliaryDrawerWidth)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, AcMindSurfaceTokens.pagePadding)
                            .padding(.vertical, AcMindSurfaceTokens.pagePaddingY)
                            .padding(.bottom, AcMindSurfaceTokens.pagePaddingY)
                        }
                    } else {
                        mainConversationContent
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, AcMindSurfaceTokens.pagePadding)
                            .padding(.vertical, AcMindSurfaceTokens.pagePaddingY)
                            .padding(.bottom, AcMindSurfaceTokens.pagePaddingY)
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.88), value: showsAuxiliaryDrawer)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.clear)
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

    private var mainConversationContent: some View {
        VStack(alignment: .leading, spacing: AcMindSurfaceTokens.sectionGap) {
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
                .frame(maxWidth: .infinity, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func auxiliaryDrawer(width: CGFloat, isCompact: Bool) -> some View {
        AgentWorkspaceManagementDrawerView(
            viewModel: viewModel,
            managementRailWidth: $managementRailWidth,
            managementRailCollapsed: $managementRailCollapsed,
            railDragBaseWidth: $railDragBaseWidth,
            folderRenameTarget: $folderRenameTarget,
            showsAuxiliaryDrawer: $showsAuxiliaryDrawer,
            width: width,
            isCompact: isCompact
        )
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

        toastManager.show(.success, "已附加 \(urls.count) 个文件")
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

    private var threadView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AcMindSurfaceTokens.panelCornerRadius, style: .continuous)
                .fill(AcMindSurfaceTokens.tertiarySurface)

            if viewModel.messages.isEmpty {
                emptyConversationState
                    .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.messages) { message in
                                AgentMessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 18)
                    }
                    .onChange(of: viewModel.messages.count) {
                        guard let lastID = viewModel.messages.last?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AcMindSurfaceTokens.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AcMindSurfaceTokens.panelCornerRadius, style: .continuous)
                .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
        )
    }

    private var emptyConversationState: some View {
        VStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ACColors.accentPurple, ACColors.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .center, spacing: 4) {
                Text("输入一句话，Agent 会直接执行")
                    .font(ACTypography.cardTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("记笔记、建任务、排日程，或先搜索再整理结论。")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                ForEach(AgentActionMode.quickActions.prefix(4)) { mode in
                    Button {
                        viewModel.selectedActionMode = mode
                        viewModel.inputText = mode.suggestedPrompt
                    } label: {
                        Text(mode.displayName)
                            .font(ACTypography.miniMedium)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AcMindSurfaceTokens.secondarySurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
    }

}
