import SwiftUI
import AcMindKit

struct ProviderManagementSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderID: String?
    @State private var searchText: String = ""
    @State private var isCreatingNewDraft = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overviewCard
                    HStack(alignment: .top, spacing: 14) {
                        providerListCard
                            .frame(width: 360)

                        editorCard
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(20)
            }
            .background(ACColors.pageBackground)
            .navigationTitle("Provider 管理")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 760)
        .task {
            await viewModel.loadProviders()
            syncSelectionAfterReload()
        }
        .onChange(of: viewModel.providers) {
            syncSelectionAfterReload()
        }
        .onChange(of: selectedProviderID) {
            guard let selectedProviderID,
                  let provider = viewModel.providers.first(where: { $0.id == selectedProviderID }) else {
                return
            }
            viewModel.beginEditingProvider(provider)
        }
    }

    private var overviewCard: some View {
        ACCard(padding: 16) {
            HStack(alignment: .center, spacing: 16) {
                ACTypeIcon("server.rack", tint: ACColors.accentPurple, background: ACColors.selectedFill, size: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Provider 中枢")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        ACBadge("\(viewModel.providers.count) 个", kind: .neutral)
                    }
                    Text("统一管理云端、OpenAI 兼容、本地 Ollama / 小模型 provider。")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                    Text("编辑、启停、健康检查、API Key 都在这个页面完成。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ACBadge("\(viewModel.providers.filter { $0.enabled }.count) 启用", kind: .green)
                    ACBadge("\(viewModel.providers.filter { viewModel.providerHasKey($0.id) }.count) Key", kind: .orange)
                    ACBadge("\(viewModel.providers.filter { $0.providerType == .ollama || $0.providerType == .local }.count) 本地", kind: .blue)
                }
            }
        }
    }

    private var providerListCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider 列表")
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text("点击任一项进入编辑，启停和健康检查可在列表里直接操作。")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                ACSearchField("搜索 Provider", text: $searchText, width: nil, height: 36)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredProviders, id: \.id) { provider in
                            providerRow(provider)
                        }

                        if filteredProviders.isEmpty {
                            ACEmptyState(
                                icon: "server.rack",
                                title: "没有匹配的 Provider",
                                subtitle: "尝试清空搜索词，或直接创建一个新的 Provider。"
                            )
                            .padding(.top, 8)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        selectedProviderID = nil
                        isCreatingNewDraft = true
                        viewModel.resetProviderDraft()
                    } label: {
                        Label("新建空白", systemImage: "plus.circle")
                            .font(ACTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 0)

                    Button {
                        Task {
                            await viewModel.loadProviders()
                            syncSelectionAfterReload()
                        }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                            .font(ACTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func providerRow(_ provider: ProviderConfig) -> some View {
        let isSelected = selectedProviderID == provider.id
        let healthState = viewModel.providerHealthState(for: provider.id)

        return HStack(alignment: .top, spacing: 10) {
            Button {
                selectedProviderID = provider.id
                isCreatingNewDraft = false
                viewModel.beginEditingProvider(provider)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name.isEmpty ? provider.id : provider.name)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                    Text(provider.modelId)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 8) {
                ACBadge(provider.enabled ? "启用" : "停用", kind: provider.enabled ? .green : .neutral)

                HStack(spacing: 6) {
                    ACBadge(provider.providerType.displayName, kind: .blue)
                    ACBadge(provider.tier.displayName, kind: .neutral)
                    ACBadge(viewModel.providerHasKey(provider.id) ? "Key 已配" : "无 Key", kind: viewModel.providerHasKey(provider.id) ? .orange : .neutral)
                    providerHealthBadge(healthState)
                }

                HStack(spacing: 6) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { provider.enabled },
                            set: { newValue in
                                Task { await viewModel.setProviderEnabled(provider.id, enabled: newValue) }
                            }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(provider.enabled ? "点击停用" : "点击启用")

                    Button {
                        Task { await viewModel.checkProviderHealth(provider.id) }
                    } label: {
                        Image(systemName: "heart.text.square")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        selectedProviderID = provider.id
                        isCreatingNewDraft = false
                        viewModel.beginEditingProvider(provider)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        Task { await viewModel.deleteProvider(id: provider.id) }
                        if selectedProviderID == provider.id {
                            selectedProviderID = nil
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? ACColors.selectedFill : ACColors.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? ACColors.accentPurple.opacity(0.45) : ACColors.border.opacity(0.55), lineWidth: 1)
        )
    }

    private var editorCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(editorTitle)
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        ACBadge(viewModel.providerEditingID == nil ? "新建" : "编辑", kind: .purple)
                    }

                    Text("这里是完整编辑页。若留空 API Key，编辑已有 provider 时会保留原来的钥匙串内容。")
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        presetStrip
                        editorFields
                    }
                }
            }
        }
    }

    private var editorTitle: String {
        if let selectedProviderID,
           let provider = viewModel.providers.first(where: { $0.id == selectedProviderID }) {
            return provider.name.isEmpty ? provider.id : provider.name
        }
        return viewModel.providerEditingID == nil ? "新建 Provider" : "Provider 编辑"
    }

    private var presetStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快速套用预设")
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProviderPreset.quickAddPresets) { preset in
                        Button {
                            selectedProviderID = nil
                            isCreatingNewDraft = true
                            viewModel.applyProviderPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(ACTypography.captionMedium)
                                    .foregroundStyle(ACColors.primaryText)
                                Text(preset.providerType.displayName)
                                    .font(ACTypography.mini)
                                    .foregroundStyle(ACColors.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(ACColors.softFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ACColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var editorFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField("名称", text: $viewModel.providerDraftName)
                    .textFieldStyle(.roundedBorder)
                Picker("类型", selection: $viewModel.providerDraftProviderType) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .frame(maxWidth: 180, alignment: .leading)
            }

            HStack(spacing: 10) {
                TextField("Base URL", text: $viewModel.providerDraftBaseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model ID", text: $viewModel.providerDraftModelId)
                    .textFieldStyle(.roundedBorder)
            }

            SecureField(apiKeyPlaceholder, text: $viewModel.providerDraftAPIKey)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Picker("层级", selection: $viewModel.providerDraftTier) {
                    ForEach(ProviderTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .frame(maxWidth: 180, alignment: .leading)

                Toggle("启用", isOn: $viewModel.providerDraftEnabled)
                    .toggleStyle(.switch)

                Spacer(minLength: 0)
            }

            capabilityStrip

            if let provider = currentSelectedProvider {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前状态")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)

                    HStack(spacing: 6) {
                        ACBadge(provider.enabled ? "启用" : "停用", kind: provider.enabled ? .green : .neutral)
                        ACBadge(viewModel.providerHasKey(provider.id) ? "Key 已配" : "无 Key", kind: viewModel.providerHasKey(provider.id) ? .orange : .neutral)
                        providerHealthBadge(viewModel.providerHealthState(for: provider.id))
                    }

                    if let detail = viewModel.providerHealthState(for: provider.id).detail {
                        Text(detail)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(2)
                    }
                }
            }

            if let editingID = viewModel.providerEditingID {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.checkProviderHealth(editingID) }
                    } label: {
                        Label("检查健康", systemImage: "heart.text.square")
                            .font(ACTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)

                    if viewModel.providerHasKey(editingID) {
                        Button {
                            Task { await viewModel.clearProviderAPIKey(for: editingID) }
                        } label: {
                            Label("清空 Key", systemImage: "key.slash")
                                .font(ACTypography.captionMedium)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.saveDraftProvider() }
                } label: {
                    Label(viewModel.providerEditingID == nil ? "创建 Provider" : "保存修改", systemImage: "checkmark.circle.fill")
                        .font(ACTypography.captionMedium)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedProviderID = nil
                    viewModel.resetProviderDraft()
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .font(ACTypography.captionMedium)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                if let editingID = viewModel.providerEditingID {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteProvider(id: editingID) }
                        selectedProviderID = nil
                    } label: {
                        Label("删除 Provider", systemImage: "trash")
                            .font(ACTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var capabilityStrip: some View {
        let tags = capabilityTags(for: viewModel.providerDraftProviderType)
        return VStack(alignment: .leading, spacing: 8) {
            Text("能力标签")
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.secondaryText)

            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ACColors.softFill)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(ACColors.border.opacity(0.7), lineWidth: 1)
                        )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var apiKeyPlaceholder: String {
        if let editingID = viewModel.providerEditingID,
           viewModel.providerHasKey(editingID) {
            return "API Key（留空保留现有 Key）"
        }
        if viewModel.providerDraftProviderType == .ollama || viewModel.providerDraftProviderType == .local {
            return "API Key（本地模型通常不需要）"
        }
        if viewModel.providerDraftProviderType == .openAICompatible {
            return "API Key（兼容接口可选，留空则按无密钥处理）"
        }
        return "API Key（云端模型需要）"
    }

    private var filteredProviders: [ProviderConfig] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.providers
        }
        return viewModel.providers.filter { provider in
            provider.name.localizedCaseInsensitiveContains(query) ||
            provider.modelId.localizedCaseInsensitiveContains(query) ||
            provider.providerType.displayName.localizedCaseInsensitiveContains(query) ||
            provider.tier.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private func providerHealthBadge(_ state: ProviderHealthState) -> some View {
        let kind: ACBadge.Kind
        switch state {
        case .healthy:
            kind = .green
        case .checking:
            kind = .blue
        case .unhealthy:
            kind = .red
        case .disabled:
            kind = .neutral
        case .unknown:
            kind = .neutral
        }

        return ACBadge(state.label, kind: kind)
    }

    private func capabilityTags(for type: ProviderType) -> [String] {
        switch type {
        case .ollama:
            return ["chat", "stream", "local", "ollama"]
        case .local:
            return ["chat", "stream", "local"]
        case .openAICompatible:
            return ["chat", "stream", "compatible"]
        case .openAI:
            return ["chat", "stream", "cloud", "openai"]
        case .anthropic:
            return ["chat", "stream", "cloud", "anthropic"]
        case .google:
            return ["chat", "stream", "cloud", "google"]
        }
    }

    private var currentSelectedProvider: ProviderConfig? {
        guard let selectedProviderID else { return nil }
        return viewModel.providers.first(where: { $0.id == selectedProviderID })
    }

    private func syncSelectionAfterReload() {
        if let selectedProviderID,
           viewModel.providers.contains(where: { $0.id == selectedProviderID }) {
            return
        }

        if let editingID = viewModel.providerEditingID,
           viewModel.providers.contains(where: { $0.id == editingID }) {
            selectedProviderID = editingID
            isCreatingNewDraft = false
            return
        }

        if isCreatingNewDraft {
            return
        }

        if let first = viewModel.providers.first {
            selectedProviderID = first.id
            isCreatingNewDraft = false
        } else if selectedProviderID != nil {
            selectedProviderID = nil
        }
    }
}

extension Notification.Name {
    static let acmindProvidersDidChange = Notification.Name("acmind.providersDidChange")
}
