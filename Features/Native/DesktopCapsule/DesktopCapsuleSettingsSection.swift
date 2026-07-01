import SwiftUI
import AcMindKit

// MARK: - Desktop Capsule Settings Section

struct DesktopCapsuleSettingsSection: View {
    @State private var settings: DesktopCapsuleSettings = .default
    @State private var showingAddAction = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("桌面小胶囊")
                .font(.title2)
                .fontWeight(.semibold)

            Text("桌面小胶囊是一个悬浮在桌面上的快捷入口，可以快速调用应用功能")
                .font(.caption)
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            // 启用开关
            VStack(alignment: .leading, spacing: 8) {
                Toggle("启用桌面小胶囊", isOn: $settings.isEnabled)
                    .onChange(of: settings.isEnabled) { _, newValue in
                        saveSettings()
                        if newValue {
                            // 显示胶囊
                            (NSApp.delegate as? AppDelegate)?.showDesktopCapsule()
                        } else {
                            // 隐藏胶囊
                            (NSApp.delegate as? AppDelegate)?.hideDesktopCapsule()
                        }
                    }

                Toggle("启动时自动显示", isOn: $settings.showOnLaunch)
                    .onChange(of: settings.showOnLaunch) { _, _ in saveSettings() }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("快速入口")
                        .font(.headline)

                    Spacer()
                }

                HStack(spacing: 8) {
                    quickEntryButton(title: "设置首页", category: nil)
                    quickEntryButton(title: "随身能力", category: .companion)
                    quickEntryButton(title: "智能与模型", category: .aiModels)
                    quickEntryButton(title: "捕获与输入", category: .captureInput)
                }
            }

            Divider()

            // 功能列表
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("快捷功能")
                        .font(.headline)

                    Spacer()

                    Button("添加功能") {
                        showingAddAction = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if settings.actions.isEmpty {
                    Text("尚未添加功能，请点击上方按钮添加")
                        .font(.caption)
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
                        )
                } else {
                    List {
                        ForEach(settings.actions.sorted { $0.order < $1.order }) { action in
                            CapsuleActionRow(
                                action: action,
                                onToggle: { toggleAction(action) },
                                onDelete: { removeAction(action) }
                            )
                        }
                        .onMove { source, destination in
                            reorderActions(from: source, to: destination)
                        }
                        .onDelete { indexSet in
                            deleteActions(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 150, maxHeight: 300)
                }
            }

            Divider()

            // 可用功能
            VStack(alignment: .leading, spacing: 8) {
                Text("可用功能")
                    .font(.headline)

                ForEach(CapsuleActionType.allCases) { type in
                    HStack(spacing: 12) {
                        Image(systemName: type.defaultIcon)
                            .font(.system(size: 14))
                            .foregroundStyle(type.defaultColor)
                            .frame(width: 24)

                        Text(type.defaultTitle)
                            .font(.body)

                        Spacer()

                        Text(actionDescription(for: type))
                            .font(.caption)
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
            )
        }
        .onAppear {
            loadSettings()
        }
        .sheet(isPresented: $showingAddAction) {
            AddActionSheet(settings: $settings, onSave: saveSettings)
        }
    }

    // MARK: - Actions

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let decoded = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            settings = decoded
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "AppSettings.desktopCapsule")
            NotificationCenter.default.post(name: .desktopCapsuleSettingsDidChange, object: nil)
        }
    }

    private func quickEntryButton(title: String, category: SettingsCategory?) -> some View {
        Button(title) {
            (NSApp.delegate as? AppDelegate)?.openSettingsWindow(category: category)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func toggleAction(_ action: CapsuleActionConfig) {
        if let index = settings.actions.firstIndex(where: { $0.id == action.id }) {
            settings.actions[index].isEnabled.toggle()
            saveSettings()
        }
    }

    private func removeAction(_ action: CapsuleActionConfig) {
        settings.actions.removeAll { $0.id == action.id }
        // 重新排序
        for (index, _) in settings.actions.enumerated() {
            settings.actions[index].order = index
        }
        saveSettings()
    }

    private func reorderActions(from source: IndexSet, to destination: Int) {
        var sortedActions = settings.actions.sorted { $0.order < $1.order }
        sortedActions.move(fromOffsets: source, toOffset: destination)
        // 重新排序
        for (index, _) in sortedActions.enumerated() {
            sortedActions[index].order = index
        }
        settings.actions = sortedActions
        saveSettings()
    }

    private func deleteActions(at offsets: IndexSet) {
        var sortedActions = settings.actions.sorted { $0.order < $1.order }
        sortedActions.remove(atOffsets: offsets)
        // 重新排序
        for (index, _) in sortedActions.enumerated() {
            sortedActions[index].order = index
        }
        settings.actions = sortedActions
        saveSettings()
    }

    private func actionDescription(for type: CapsuleActionType) -> String {
        switch type {
        case .screenshot: return "截取屏幕内容"
        case .scrollScreenshot: return "自动滚动拼接当前页面"
        case .voiceNote: return "录音并转文字"
        case .urlToText: return "提取网页文字"
        case .scheduleAnalysis: return "分析日程安排"
        case .clipboard: return "保存剪贴板内容"
        case .quickText: return "快速输入文本"
        case .fileCapture: return "导入文件内容"
        }
    }
}

// MARK: - Capsule Action Row

struct CapsuleActionRow: View {
    let action: CapsuleActionConfig
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 拖拽手柄
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            // 图标
            Image(systemName: action.type.defaultIcon)
                .font(.system(size: 16))
                .foregroundStyle(action.type.defaultColor)
                .frame(width: 28)

            // 标题
            Text(action.type.defaultTitle)
                .font(.body)

            Spacer()

            // 启用开关
            Toggle("", isOn: Binding(
                get: { action.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Action Sheet

struct AddActionSheet: View {
    @Binding var settings: DesktopCapsuleSettings
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CapsuleActionType?

    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("添加快捷功能")
                .font(.title2)
                .fontWeight(.semibold)

            // 已添加的类型
            let existingTypes = Set(settings.actions.map { $0.type })

            // 可添加的功能
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(CapsuleActionType.allCases) { type in
                    let isAdded = existingTypes.contains(type)

                    Button(action: {
                        if !isAdded {
                            selectedType = type
                        }
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                            Circle()
                                    .fill(isAdded ? AppSurfaceTokens.cardBackground.opacity(0.94) : type.defaultColor.opacity(0.1))
                                    .frame(width: 48, height: 48)

                                Image(systemName: type.defaultIcon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(isAdded ? .secondary : type.defaultColor)

                                if isAdded {
                                    Circle()
                                        .stroke(AppSurfaceTokens.secondaryText, lineWidth: 2)
                                }
                            }

                            Text(type.defaultTitle)
                                .font(.caption)
                                .foregroundStyle(isAdded ? .secondary : .primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAdded)
                }
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("添加") {
                    if let type = selectedType {
                        let newAction = CapsuleActionConfig(
                            type: type,
                            isEnabled: true,
                            order: settings.actions.count
                        )
                        settings.actions.append(newAction)
                        onSave()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedType == nil)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
