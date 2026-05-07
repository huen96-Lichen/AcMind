import SwiftUI
import AcMindKit

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器
            Picker("设置", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsSection(viewModel: viewModel)
                    case .ai:
                        AISettingsSection(viewModel: viewModel)
                    case .vault:
                        VaultSettingsSection(viewModel: viewModel)
                    case .permissions:
                        PermissionsSection(viewModel: viewModel)
                    case .shortcuts:
                        ShortcutsSection(viewModel: viewModel)
                    }
                }
                .padding()
            }

            // 保存按钮
            HStack {
                Spacer()
                Button("保存") {
                    Task {
                        await viewModel.saveSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case ai
    case vault
    case permissions
    case shortcuts

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "通用"
        case .ai: return "AI"
        case .vault: return "Vault"
        case .permissions: return "权限"
        case .shortcuts: return "快捷键"
        }
    }
}

// MARK: - General Settings Section

struct GeneralSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("通用设置")
                .font(.title2)
                .fontWeight(.semibold)

            // 主题
            VStack(alignment: .leading, spacing: 8) {
                Text("外观")
                    .font(.headline)

                Picker("主题", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 语言
            VStack(alignment: .leading, spacing: 8) {
                Text("语言")
                    .font(.headline)

                Picker("语言", selection: $viewModel.language) {
                    Text("简体中文").tag("zh-CN")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            // 剪贴板自动采集
            VStack(alignment: .leading, spacing: 8) {
                Text("采集")
                    .font(.headline)

                Toggle("自动采集剪贴板", isOn: $viewModel.autoCaptureClipboard)
            }

            Divider()

            // 导出设置
            VStack(alignment: .leading, spacing: 8) {
                Text("导出")
                    .font(.headline)

                Picker("默认导出目标", selection: $viewModel.defaultExportTarget) {
                    ForEach(ExportTarget.allCases, id: \.self) { target in
                        Text(target.displayName).tag(target)
                    }
                }

                Toggle("自动添加 Frontmatter", isOn: $viewModel.autoFrontmatter)
            }
        }
    }
}

// MARK: - AI Settings Section

struct AISettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddProvider = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI 设置")
                .font(.title2)
                .fontWeight(.semibold)

            // 默认 Provider
            VStack(alignment: .leading, spacing: 8) {
                Text("默认 Provider")
                    .font(.headline)

                if viewModel.providers.isEmpty {
                    Text("暂无 Provider，请添加")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Provider", selection: $viewModel.defaultProviderId) {
                        Text("请选择").tag("")
                        ForEach(viewModel.providers) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                }
            }

            // Provider 列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("AI Providers")
                        .font(.headline)

                    Spacer()

                    Button("添加") {
                        showingAddProvider = true
                    }
                }

                if viewModel.providers.isEmpty {
                    Text("暂无 Provider")
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    ForEach(viewModel.providers) { provider in
                        ProviderRow(
                            provider: provider,
                            onEdit: {
                                // 编辑 Provider
                            },
                            onDelete: {
                                Task {
                                    await viewModel.removeProvider(id: provider.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Vault Settings Section

struct VaultSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vault 设置")
                .font(.title2)
                .fontWeight(.semibold)

            // Vault 路径
            VStack(alignment: .leading, spacing: 8) {
                Text("Vault 路径")
                    .font(.headline)

                HStack {
                    TextField("选择 Vault 文件夹", text: $viewModel.vaultPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button("选择...") {
                        Task {
                            await viewModel.selectVaultPath()
                        }
                    }
                }

                if !viewModel.vaultPath.isEmpty {
                    HStack {
                        Image(systemName: viewModel.validateVaultPath() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(viewModel.validateVaultPath() ? .green : .red)

                        Text(viewModel.validateVaultPath() ? "路径有效" : "路径无效")
                            .font(.caption)
                            .foregroundStyle(viewModel.validateVaultPath() ? .green : .red)
                    }
                }
            }

            // 默认文件夹
            VStack(alignment: .leading, spacing: 8) {
                Text("默认文件夹")
                    .font(.headline)

                TextField("默认文件夹名称", text: $viewModel.vaultDefaultFolder)
                    .textFieldStyle(.roundedBorder)
            }

            // 路径规则
            VStack(alignment: .leading, spacing: 8) {
                Text("路径规则")
                    .font(.headline)

                Picker("规则", selection: $viewModel.vaultPathRule) {
                    ForEach(VaultConfig.VaultPathRule.allCases, id: \.self) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 冲突策略
            VStack(alignment: .leading, spacing: 8) {
                Text("冲突策略")
                    .font(.headline)

                Picker("策略", selection: $viewModel.vaultConflictStrategy) {
                    ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("权限设置")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AcMind 需要以下权限才能正常工作")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                PermissionRow(
                    title: "麦克风",
                    description: "用于语音输入",
                    status: viewModel.microphoneStatus,
                    onRequest: {
                        Task {
                            await viewModel.requestPermission(.microphone)
                        }
                    },
                    onOpenSettings: {
                        Task {
                            await viewModel.openSystemPreferences(for: .microphone)
                        }
                    }
                )

                PermissionRow(
                    title: "屏幕录制",
                    description: "用于截图功能",
                    status: viewModel.screenRecordingStatus,
                    onRequest: {
                        Task {
                            await viewModel.requestPermission(.screenRecording)
                        }
                    },
                    onOpenSettings: {
                        Task {
                            await viewModel.openSystemPreferences(for: .screenRecording)
                        }
                    }
                )

                PermissionRow(
                    title: "辅助功能",
                    description: "用于全局快捷键",
                    status: viewModel.accessibilityStatus,
                    onRequest: {
                        Task {
                            await viewModel.requestPermission(.accessibility)
                        }
                    },
                    onOpenSettings: {
                        Task {
                            await viewModel.openSystemPreferences(for: .accessibility)
                        }
                    }
                )

                PermissionRow(
                    title: "完全磁盘访问",
                    description: "用于访问 Vault 文件夹",
                    status: viewModel.fullDiskAccessStatus,
                    onRequest: {
                        Task {
                            await viewModel.requestPermission(.fullDiskAccess)
                        }
                    },
                    onOpenSettings: {
                        Task {
                            await viewModel.openSystemPreferences(for: .fullDiskAccess)
                        }
                    }
                )

                PermissionRow(
                    title: "通知",
                    description: "用于任务完成提醒",
                    status: viewModel.notificationsStatus,
                    onRequest: {
                        Task {
                            await viewModel.requestPermission(.notifications)
                        }
                    },
                    onOpenSettings: {
                        Task {
                            await viewModel.openSystemPreferences(for: .notifications)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Shortcuts Section

struct ShortcutsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("快捷键设置")
                .font(.title2)
                .fontWeight(.semibold)

            Text("全局快捷键可以在任何应用中使用")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 截图快捷键
            VStack(alignment: .leading, spacing: 8) {
                Text("截图")
                    .font(.headline)

                HStack {
                    TextField("快捷键", text: $viewModel.captureScreenshotHotkey)
                        .textFieldStyle(.roundedBorder)

                    Button("录制") {
                        // 开始录制快捷键
                    }
                }
            }

            Divider()

            // 其他快捷键列表
            VStack(alignment: .leading, spacing: 8) {
                Text("应用内快捷键")
                    .font(.headline)

                ShortcutRow(action: "显示主窗口", shortcut: "⌘0")
                ShortcutRow(action: "显示胶囊", shortcut: "⌘⇧Space")
                ShortcutRow(action: "Agent", shortcut: "⌘1")
                ShortcutRow(action: "收集箱", shortcut: "⌘2")
                ShortcutRow(action: "日程", shortcut: "⌘3")
                ShortcutRow(action: "工作台", shortcut: "⌘4")
                ShortcutRow(action: "工具", shortcut: "⌘5")
                ShortcutRow(action: "设置", shortcut: "⌘,")
            }
        }
    }
}

// MARK: - Helper Views

struct ProviderRow: View {
    let provider: ProviderConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.body)

                Text(provider.providerType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if provider.enabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }

                Button("编辑") {
                    onEdit()
                }
                .buttonStyle(.borderless)

                Button("删除") {
                    onDelete()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                StatusBadge(status: status)

                switch status {
                case .notDetermined:
                    Button("申请") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                case .denied, .restricted:
                    Button("去设置") {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .authorized:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .notDetermined:
            return .orange.opacity(0.2)
        case .denied, .restricted:
            return .red.opacity(0.2)
        case .authorized:
            return .green.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .notDetermined:
            return .orange
        case .denied, .restricted:
            return .red
        case .authorized:
            return .green
        }
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
                .font(.body)

            Spacer()

            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Provider Sheet

struct AddProviderSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var providerType: ProviderType = .ollama
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelId = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("添加 Provider")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("名称", text: $name)

                Picker("类型", selection: $providerType) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("默认模型", text: $modelId)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("添加") {
                    let config = ProviderConfig(
                        name: name,
                        providerType: providerType,
                        baseURL: baseURL,
                        modelId: modelId
                    )
                    Task {
                        await viewModel.addProvider(config)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || baseURL.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
