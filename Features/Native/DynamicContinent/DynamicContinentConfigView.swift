import SwiftUI
import AcMindKit

struct DynamicContinentConfigView: View {
    @StateObject private var viewModel = DynamicContinentConfigViewModel()
    @State private var selectedSection: ConfigSection = .overview

    enum ConfigSection: String, CaseIterable, Identifiable {
        case overview = "总览"
        case expand = "展开 / 收缩"
        case moduleManagement = "模块管理"
        case musicModule = "音乐模块"
        case agentModule = "Agent 模块"
        case scheduleModule = "日程模块"
        case systemStatusModule = "系统状态模块"
        case hotZone = "热区配置"
        case advanced = "高级参数"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .expand: return "arrow.up.left.and.arrow.down.right"
            case .moduleManagement: return "puzzlepiece.extension"
            case .musicModule: return "music.note"
            case .agentModule: return "bubble.left"
            case .scheduleModule: return "calendar"
            case .systemStatusModule: return "cpu"
            case .hotZone: return "hand.tap"
            case .advanced: return "gearshape.2"
            }
        }
    }

    var body: some View {
        HSplitView {
            secondarySidebar
                .frame(width: 220)

            mainContent
        }
        .background(AppSurfaceTokens.background)
    }

    private var secondarySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("灵动大陆 & 配置")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            List(ConfigSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
        }
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader
                sectionContent
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: selectedSection.icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(selectedSection.rawValue)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewSection
        case .expand:
            expandSection
        case .moduleManagement:
            moduleManagementSection
        case .musicModule:
            modulePlaceholder("音乐模块", icon: "music.note")
        case .agentModule:
            modulePlaceholder("Agent 模块", icon: "bubble.left")
        case .scheduleModule:
            modulePlaceholder("日程模块", icon: "calendar")
        case .systemStatusModule:
            modulePlaceholder("系统状态模块", icon: "cpu")
        case .hotZone:
            hotZoneSection
        case .advanced:
            advancedSection
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("灵动大陆是 AcMind 的伴随式桌面能力，提供快捷访问和实时信息展示。")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                statusCard(title: "状态", value: viewModel.isEnabled ? "已启用" : "未启用", icon: "power", color: viewModel.isEnabled ? .green : .gray)
                statusCard(title: "模式", value: viewModel.currentMode, icon: "rectangle.expand.vertical", color: .blue)
                statusCard(title: "模块数", value: "\(viewModel.activeModuleCount)", icon: "puzzlepiece.extension", color: .purple)
            }

            NotchPreviewCard()
        }
    }

    private func statusCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private var expandSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("启用灵动大陆", isOn: $viewModel.isEnabled)
            Toggle("自动展开", isOn: $viewModel.autoExpand)
            Slider(value: $viewModel.expandSpeed, in: 0.1...1.0) {
                Text("展开速度")
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private var moduleManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模块管理")
                .font(.headline)

            Text("配置灵动大陆中显示的模块及其顺序")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.modules) { module in
                HStack {
                    Image(systemName: module.icon)
                        .frame(width: 24)
                    Text(module.name)
                    Spacer()
                    Toggle("", isOn: .constant(module.isEnabled))
                        .labelsHidden()
                }
                .padding(12)
                .background(AppSurfaceTokens.secondarySidebarBackground)
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private func modulePlaceholder(_ name: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("\(name) 配置")
                .font(.headline)
            Text("此模块当前仅展示基础配置骨架")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("规划中", systemImage: "clock")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private var hotZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("热区配置")
                .font(.headline)

            Text("配置桌面热区触发灵动大陆的行为")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                hotZoneRow(position: "左上角", action: "无动作")
                hotZoneRow(position: "右上角", action: "展开灵动大陆")
                hotZoneRow(position: "左下角", action: "无动作")
                hotZoneRow(position: "右下角", action: "无动作")
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }

    private func hotZoneRow(position: String, action: String) -> some View {
        HStack {
            Text(position)
                .font(.body)
            Spacer()
            Text(action)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(AppSurfaceTokens.secondarySidebarBackground)
        .cornerRadius(8)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("高级参数")
                .font(.headline)

            Text("以下参数修改可能影响灵动大陆的稳定性")
                .font(.caption)
                .foregroundStyle(.orange)

            Toggle("调试模式", isOn: $viewModel.debugMode)
            Toggle("显示性能指标", isOn: $viewModel.showPerformanceMetrics)
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(12)
    }
}

struct NotchPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notch 预览")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Spacer()

                    Text("灵动大陆")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
    }
}

@MainActor
class DynamicContinentConfigViewModel: ObservableObject {
    @Published var isEnabled = true
    @Published var autoExpand = false
    @Published var expandSpeed: Double = 0.3
    @Published var debugMode = false
    @Published var showPerformanceMetrics = false

    let currentMode = "收缩"
    let activeModuleCount = 4

    struct Module: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let isEnabled: Bool
    }

    let modules = [
        Module(name: "音乐模块", icon: "music.note", isEnabled: true),
        Module(name: "Agent 模块", icon: "bubble.left", isEnabled: true),
        Module(name: "日程模块", icon: "calendar", isEnabled: true),
        Module(name: "系统状态模块", icon: "cpu", isEnabled: false)
    ]
}
