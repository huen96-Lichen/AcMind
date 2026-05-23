import SwiftUI
import AcMindKit

enum SettingsSuiteSection: String, CaseIterable, Identifiable {
    case general
    case agent
    case processing
    case knowledge
    case tools
    case models
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "基础设置"
        case .agent: return "Agent 设置"
        case .processing: return "信息处理"
        case .knowledge: return "知识库 / Obsidian"
        case .tools: return "工具设置"
        case .models: return "AI 模型"
        case .advanced: return "高级设置"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "主题、语言、启动行为"
        case .agent: return "随身、语音、快捷键与联动"
        case .processing: return "收集、识别、转写与整理"
        case .knowledge: return "Vault、目录与冲突规则"
        case .tools: return "截图、OCR、监听与快捷输入"
        case .models: return "能力分区、默认模型与 Provider"
        case .advanced: return "权限、诊断、导出与系统"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .agent: return "sparkles"
        case .processing: return "tray.and.arrow.down"
        case .knowledge: return "books.vertical"
        case .tools: return "wrench.and.screwdriver"
        case .models: return "brain"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct SettingsSuiteView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsSuiteSection = .general
    @State private var searchText = ""

    init(container: ServiceContainer) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    var body: some View {
        ACSettingsShell(
            header: {
                ACPageHeader(
                    title: "设置中心",
                    subtitle: "统一管理基础偏好、Agent、信息处理、知识库、工具和模型。"
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            ACBadge(selectedSection.title, kind: .neutral)
                            if let message = viewModel.saveStatusMessage {
                                ACBadge(message, kind: .green)
                            }
                            ACButton("保存设置", kind: .primary) {
                                Task { await viewModel.saveSettings() }
                            }
                        }

                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 8) {
                                ACBadge(selectedSection.title, kind: .neutral)
                                if let message = viewModel.saveStatusMessage {
                                    ACBadge(message, kind: .green)
                                }
                            }
                            ACButton("保存设置", kind: .primary) {
                                Task { await viewModel.saveSettings() }
                            }
                        }
                    }
                }
            },
            sidebar: { sidebar },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    sectionOverview
                    sectionContent
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .acmindProvidersDidChange)) { _ in
            Task { await viewModel.loadProviders() }
        }
        .alert("设置错误", isPresented: $viewModel.showError) {
            Button("确定") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ACTypeIcon(
                        "gearshape.2",
                        tint: ACColors.accentBlue,
                        background: ACColors.selectedFill,
                        size: 46
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("设置中心")
                            .font(ACTypography.sectionTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("统一管理基础偏好、Agent、信息处理、知识库、工具和模型。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    ACBadge("本地配置", kind: .blue)
                    ACBadge("即时保存", kind: .neutral)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ACColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ACColors.border.opacity(0.55), lineWidth: 1)
            )

            ACSearchField("搜索设置", text: $searchText, width: nil, height: 36)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredSections) { section in
                        let isSelected = selectedSection == section
                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: 12) {
                                ACTypeIcon(
                                    section.icon,
                                    tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText,
                                    background: isSelected ? ACColors.selectedFill : ACColors.softFill,
                                    size: 34
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title)
                                        .font(ACTypography.itemTitle)
                                        .foregroundStyle(isSelected ? ACColors.primaryText : ACColors.secondaryText)
                                        .lineLimit(1)
                                    Text(section.subtitle)
                                        .font(ACTypography.mini)
                                        .foregroundStyle(ACColors.tertiaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: ACLayout.sidebarNavHeight, alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                    .fill(isSelected ? ACColors.selectedFill : ACColors.softFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                    .stroke(isSelected ? ACColors.accentBlue.opacity(0.24) : ACColors.border.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Divider()
                    .overlay(ACColors.divider)

                HStack(spacing: 8) {
                    Circle()
                        .fill(ACColors.accentGreen)
                        .frame(width: 8, height: 8)
                    Text(appVersionShortDisplay)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                    Spacer(minLength: 0)
                }
                Text("右上角保存会同步到本地持久化。")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.tertiaryText)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            generalSection
        case .agent:
            agentSection
        case .processing:
            processingSection
        case .knowledge:
            knowledgeSection
        case .tools:
            toolsSection
        case .models:
            modelsSection
        case .advanced:
            advancedSection
        }
    }

    private var filteredSections: [SettingsSuiteSection] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return SettingsSuiteSection.allCases
        }

        return SettingsSuiteSection.allCases.filter { section in
            section.title.localizedCaseInsensitiveContains(searchText) ||
            section.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sectionOverview: some View {
        ACCard(padding: 18) {
            HStack(alignment: .top, spacing: 18) {
                ACTypeIcon(selectedSection.icon, tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 50)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(selectedSection.title)
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        ACBadge("设置分区", kind: .blue)
                    }

                    Text(selectedSection.subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(2)

                    Text("这一页会把可见项直接写入本地持久化，修改后需要手动保存。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    ACBadge(filteredSections.contains(selectedSection) ? "当前可见" : "搜索结果外", kind: .neutral)
                    Text("修改后点右上角保存。")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.tertiaryText)
                }
            }
        }
    }

    private var appVersionShortDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.2"
        return "v\(version)"
    }
}
