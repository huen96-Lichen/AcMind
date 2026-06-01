import SwiftUI
import AppKit
import EventKit
import UniformTypeIdentifiers
import AcMindKit

struct DynamicContinentConfigView: View {
    @StateObject private var viewModel = DynamicContinentConfigViewModel()
    @StateObject private var hotCornerViewModel = HotCornerConfigViewModel()
    @StateObject private var permissionManager = PermissionManager()
    @State private var selectedSection: ConfigSection
    @State private var editingHotCorner: HotCornerPosition?
    @State private var draftHotCornerBinding = HotCornerBinding()

    init(initialSection: ConfigSection = .overviewAppearance) {
        _selectedSection = State(initialValue: initialSection)
    }

    enum ConfigSection: String, CaseIterable, Identifiable {
        case overviewAppearance = "概览与外观"
        case behavior = "行为"
        case permissionsDebug = "权限与调试"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overviewAppearance: return "square.grid.2x2"
            case .behavior: return "arrow.up.left.and.arrow.down.right"
            case .permissionsDebug: return "lock.shield"
            }
        }
    }

    private enum LocalTokens {
        static let pageMaxWidth: CGFloat = 1360
        static let pagePadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 12
        static let cardSpacing: CGFloat = 10
        static let mainCardRadius: CGFloat = 18
        static let secondaryCardRadius: CGFloat = 14
        static let inlineBlockRadius: CGFloat = 10
        static let pageTitleSize: CGFloat = 28
        static let pageSubtitleSize: CGFloat = 13
        static let sectionTitleSize: CGFloat = 16
        static let sectionDescSize: CGFloat = 12
        static let cardTitleSize: CGFloat = 14
        static let bodySize: CGFloat = 13
        static let captionSize: CGFloat = 11
        static let tabHeight: CGFloat = 40
        static let tabMinWidth: CGFloat = 132
        static let tabSpacing: CGFloat = 10
        static let tabCornerRadius: CGFloat = 12
        static let tabPaddingH: CGFloat = 12
        static let tabPaddingV: CGFloat = 8
        static let tabIconSize: CGFloat = 12
        static let tabTextSize: CGFloat = 13
        static let statusCardHeight: CGFloat = 80
        static let notchPreviewHeight: CGFloat = 130
        static let moduleCardHeight: CGFloat = 116
        static let permissionRowHeight: CGFloat = 48
        static let summaryWidth: CGFloat = 260
        static let summaryBlockGap: CGFloat = 10
        static let moduleListRowHeight: CGFloat = 42
        static let inlineButtonHeight: CGFloat = 32
        static let toggleRowHeight: CGFloat = 44
        static let keycapHeight: CGFloat = 28
        static let keycapPaddingH: CGFloat = 8
        static let keycapPaddingV: CGFloat = 4
        static let headerTabGap: CGFloat = 10
        static let contentRowGap: CGFloat = 8
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LocalTokens.sectionSpacing) {
                header
                    .padding(.bottom, LocalTokens.headerTabGap)
                sectionTabs
                sectionContent
            }
            .padding(LocalTokens.pagePadding)
            .frame(maxWidth: LocalTokens.pageMaxWidth, alignment: .leading)
        }
        .background(AppSurfaceTokens.background)
        .onChange(of: viewModel.isEnabled) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.autoExpand) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.hoverExpandDelay) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.showOnAllDisplays) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.autoSwitchDisplays) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.hideInFullscreen) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.hideWhenScreenRecording) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.nonNotchCollapsedWidth) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.showCollapsedSubtitle) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.showCollapsedStatusDots) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.showSystemEventHUD) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .onChange(of: viewModel.systemEventSettings) { _, _ in
            viewModel.persistDisplaySettings()
        }
        .task {
            await permissionManager.refreshAll()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("灵动大陆 & 配置")
                .font(.system(size: LocalTokens.pageTitleSize, weight: .bold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Text("伴随能力的配置中心。")
                .font(.system(size: LocalTokens.pageSubtitleSize))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LocalTokens.tabSpacing) {
                ForEach(ConfigSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: LocalTokens.tabIconSize, weight: .semibold))
                            Text(section.rawValue)
                                .font(.system(size: LocalTokens.tabTextSize, weight: .semibold))
                        }
                        .padding(.horizontal, LocalTokens.tabPaddingH)
                        .padding(.vertical, LocalTokens.tabPaddingV)
                        .frame(minWidth: LocalTokens.tabMinWidth, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: LocalTokens.tabCornerRadius, style: .continuous)
                                .fill(selectedSection == section ? AppSurfaceTokens.cardBackground : AppSurfaceTokens.cardBackgroundSoft.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LocalTokens.tabCornerRadius, style: .continuous)
                                .stroke(selectedSection == section ? AppSurfaceTokens.separator : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedSection == section ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: LocalTokens.tabHeight)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overviewAppearance:
            overviewAppearancePage
        case .behavior:
            behaviorPage
        case .permissionsDebug:
            permissionsDebugPage
        }
    }

    private var overviewAppearancePage: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                NotchPreviewCard()
                    .frame(height: 150)

                HStack(spacing: 12) {
                    statusCard(title: "状态", value: viewModel.currentStateText, icon: "power", color: viewModel.currentStateColor)
                    statusCard(title: "模块数", value: "\(viewModel.activeModuleCount)", icon: "puzzlepiece.extension", color: .purple)
                    statusCard(title: "展示密度", value: "\(viewModel.overviewVisibleModules.count)/\(viewModel.modules.count)", icon: "square.grid.2x2", color: .orange)
                }
                .frame(height: 92)

                moduleManagementSection
                runtimeContentSection

                VStack(alignment: .leading, spacing: 0) {
                    infoRow(icon: "checkmark.seal", title: "视觉原则", desc: "展开时只保留一层信息密度。")
                    Divider()
                    infoRow(icon: "rectangle.expand.vertical", title: "展开态", desc: "状态条 + 主模块 + HUD。")
                    Divider()
                    infoRow(icon: "arrow.up.left.and.arrow.down.right", title: "收起态", desc: "只保留最低存在感。")
                }
                .padding(.vertical, 4)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                summaryBlock(title: "采样通道", icon: "waveform.path.ecg", color: .blue) {
                    VStack(alignment: .leading, spacing: 8) {
                        samplingItem("CPU 采样", value: "实时", color: .blue)
                        samplingItem("内存采样", value: "5s", color: .purple)
                        samplingItem("电池采样", value: "30s", color: .green)
                        samplingItem("网络采样", value: "3s", color: .orange)
                    }
                }

                summaryBlock(title: "权限状态", icon: "checkmark.shield", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        permissionStatusItem(
                            "辅助功能",
                            status: permissionManager.statuses[.accessibility] ?? .unknown,
                            color: permissionColor(for: permissionManager.statuses[.accessibility] ?? .unknown)
                        )
                        permissionStatusItem(
                            "屏幕录制",
                            status: permissionManager.statuses[.screenRecording] ?? .unknown,
                            color: permissionColor(for: permissionManager.statuses[.screenRecording] ?? .unknown)
                        )
                        permissionStatusItem(
                            "麦克风",
                            status: permissionManager.statuses[.microphone] ?? .unknown,
                            color: permissionColor(for: permissionManager.statuses[.microphone] ?? .unknown)
                        )
                    }
                }

                summaryBlock(title: "反馈", icon: "bubble.left.and.bubble.right", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("HUD 时长")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Text("1.2 - 1.8s")
                                .font(.system(size: 11, weight: .medium))
                        }
                        HStack {
                            Text("反馈策略")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Text("异常优先")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }

                summaryBlock(title: "系统事件", icon: "sparkles", color: .purple) {
                    VStack(alignment: .leading, spacing: 0) {
                        Toggle(isOn: $viewModel.showSystemEventHUD) {
                            Text("启用 HUD")
                                .font(.system(size: 11))
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .padding(.vertical, 6)
                        ForEach(viewModel.systemEventSettings.indices, id: \.self) { index in
                            Divider()
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.systemEventSettings[index].kind.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(viewModel.systemEventSettings[index].kind.accent)
                                    .frame(width: 14)
                                Text(viewModel.systemEventSettings[index].kind.displayName)
                                    .font(.system(size: 11))
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { viewModel.systemEventSettings[index].isEnabled },
                                    set: { viewModel.systemEventSettings[index].isEnabled = $0 }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private func infoRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
    }

    private func statusCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: LocalTokens.captionSize))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Text(value)
                .font(.system(size: LocalTokens.sectionTitleSize, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(LocalTokens.secondaryCardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: LocalTokens.secondaryCardRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private var moduleManagementSection: some View {
        VStack(alignment: .leading, spacing: LocalTokens.contentRowGap) {
            Text("展示模块")
                .font(.system(size: LocalTokens.sectionTitleSize, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            ForEach(viewModel.modules) { module in
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: module.id.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(module.id.displayName)
                                .font(.system(size: LocalTokens.cardTitleSize, weight: .medium))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text(moduleSummary(for: module.id.displayName))
                                .font(.system(size: LocalTokens.captionSize))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isModuleEnabled(module.id) },
                            set: { viewModel.setModuleEnabled(module.id, isEnabled: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }

                    HStack(spacing: 12) {
                        Text("参与总览")
                            .font(.system(size: LocalTokens.captionSize))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isOverviewModuleVisible(module.id) },
                            set: { viewModel.setOverviewModuleVisible(module.id, isVisible: $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(viewModel.isModuleEnabled(module.id) == false)
                    }
                    .padding(.leading, 36)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(AppSurfaceTokens.cardBackground)
                .cornerRadius(LocalTokens.inlineBlockRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: LocalTokens.inlineBlockRadius)
                        .stroke(AppSurfaceTokens.separator.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(LocalTokens.secondaryCardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: LocalTokens.secondaryCardRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private var runtimeContentSection: some View {
        VStack(alignment: .leading, spacing: LocalTokens.contentRowGap) {
            Text("运行时编排")
                .font(.system(size: LocalTokens.sectionTitleSize, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            ForEach(CompanionRuntimeContentID.allCases) { content in
                let iconName = runtimeContentIcon(for: content)
                let summary = runtimeContentSummary(for: content)

                RuntimeContentRow(
                    iconName: iconName,
                    title: content.displayName,
                    summary: summary,
                    collapsedIsOn: Binding(
                        get: { viewModel.isRuntimeContentVisible(content, scope: .collapsed) },
                        set: { viewModel.setRuntimeContentVisible(content, scope: .collapsed, isVisible: $0) }
                    ),
                    primaryIsOn: Binding(
                        get: { viewModel.isRuntimeContentVisible(content, scope: .primary) },
                        set: { viewModel.setRuntimeContentVisible(content, scope: .primary, isVisible: $0) }
                    )
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppSurfaceTokens.cardBackground)
                .cornerRadius(LocalTokens.inlineBlockRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: LocalTokens.inlineBlockRadius)
                        .stroke(AppSurfaceTokens.separator.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(LocalTokens.secondaryCardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: LocalTokens.secondaryCardRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private struct RuntimeContentRow: View {
        let iconName: String
        let title: String
        let summary: String
        let collapsedIsOn: Binding<Bool>
        let primaryIsOn: Binding<Bool>

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: title)
                            .font(.system(size: LocalTokens.cardTitleSize, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                        Text(verbatim: summary)
                            .font(.system(size: LocalTokens.captionSize))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                RuntimeToggleRow(title: "收起态", isOn: collapsedIsOn)
                RuntimeToggleRow(title: "主内容", isOn: primaryIsOn)
            }
        }
    }

    private struct RuntimeToggleRow: View {
        let title: String
        let isOn: Binding<Bool>

        var body: some View {
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .font(.system(size: 12, weight: .medium))
        }
    }

    private var behaviorPage: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    statusCard(title: "当前状态", value: viewModel.currentStateText, icon: "rectangle.expand.vertical", color: viewModel.currentStateColor)
                    statusCard(title: "热区", value: hotCornerViewModel.settings.isEnabled ? "已启用" : "已关闭", icon: "hand.tap", color: hotCornerViewModel.settings.isEnabled ? .green : .gray)
                }
                .frame(height: 92)

                VStack(alignment: .leading, spacing: 0) {
                    compactToggleRow("启用灵动大陆", isOn: $viewModel.isEnabled)
                    Divider()
                    compactToggleRow("自动展开", isOn: $viewModel.autoExpand)
                    Divider()
                    compactToggleRow("所有显示器显示", isOn: $viewModel.showOnAllDisplays)
                    Divider()
                    compactToggleRow("自动切换显示器", isOn: $viewModel.autoSwitchDisplays)
                    Divider()
                    compactToggleRow("全屏时隐藏", isOn: $viewModel.hideInFullscreen)
                    Divider()
                    compactToggleRow("屏幕录制时隐藏", isOn: $viewModel.hideWhenScreenRecording)
                }
                .padding(.vertical, 4)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("悬停展开延迟")
                            .font(.system(size: 14))
                        Spacer()
                        Text("\(viewModel.hoverExpandDelay, specifier: "%.1f") 秒")
                            .font(.system(size: 14))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    Slider(value: $viewModel.hoverExpandDelay, in: 0.5...3.0, step: 0.1)
                        .frame(height: 24)
                }
                .padding(14)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("非刘海屏收起宽度")
                            .font(.system(size: 14))
                        Spacer()
                        Text("\(Int(viewModel.nonNotchCollapsedWidth.rounded())) pt")
                            .font(.system(size: 14))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    Slider(value: $viewModel.nonNotchCollapsedWidth, in: 185...240, step: 1)
                        .frame(height: 24)

                    Divider()

                    compactToggleRow("显示收起副标题", isOn: $viewModel.showCollapsedSubtitle)
                    Divider()
                    compactToggleRow("显示状态小点", isOn: $viewModel.showCollapsedStatusDots)
                }
                .padding(14)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )

                hotZoneSection
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                summaryBlock(title: "触发方式", icon: "hand.tap", color: .blue) {
                    VStack(alignment: .leading, spacing: 8) {
                        triggerItem("悬停展开", desc: String(format: "%.1f", viewModel.hoverExpandDelay) + "s 延迟")
                        triggerItem("热区触发", desc: "四角停留 1.5s")
                    }
                }

                summaryBlock(title: "隐藏条件", icon: "eye.slash", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        triggerItem("全屏应用", desc: viewModel.hideInFullscreen ? "已启用" : "已关闭")
                        triggerItem("屏幕录制", desc: viewModel.hideWhenScreenRecording ? "已启用" : "已关闭")
                    }
                }

                summaryBlock(title: "反馈策略", icon: "exclamationmark.triangle", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("策略")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Text("异常优先")
                                .font(.system(size: 11, weight: .medium))
                        }
                        HStack {
                            Text("HUD 时长")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Text("1.2 - 1.8s")
                                .font(.system(size: 11, weight: .medium))
                        }
                        HStack {
                            Text("空间占用")
                                .font(.system(size: 11))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Text("短时状态层")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }

                summaryBlock(title: "系统事件", icon: "checkmark.circle", color: .green) {
                    VStack(alignment: .leading, spacing: 6) {
                        let enabledCount = viewModel.systemEventSettings.filter(\.isEnabled).count
                        Text("\(enabledCount) / \(viewModel.systemEventSettings.count)")
                            .font(.system(size: 18, weight: .bold))
                        Text("事件类型已启用")
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private func compactToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: LocalTokens.cardTitleSize))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .frame(height: LocalTokens.toggleRowHeight)
    }

    private func runtimeToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: LocalTokens.captionSize))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.leading, 36)
    }

    private func triggerItem(_ title: String, desc: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: LocalTokens.captionSize))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            Spacer()
            Text(desc)
                .font(.system(size: LocalTokens.captionSize))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var permissionsDebugPage: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    permissionRow(.accessibility)
                    Divider()
                    permissionRow(.microphone)
                    Divider()
                    permissionRow(.screenRecording)
                    Divider()
                    permissionTextRow(
                        title: "日历",
                        detail: calendarPermissionText,
                        accent: .blue
                    )
                    Divider()
                    permissionTextRow(
                        title: "提醒事项",
                        detail: remindersPermissionText,
                        accent: .green
                    )
                }
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )

                HStack {
                    Button("打开系统设置") {
                        permissionManager.openPrivacySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Spacer()

                    Text("权限异常时查看这里。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }

                VStack(alignment: .leading, spacing: 0) {
                    compactToggleRow("调试模式", isOn: $viewModel.debugMode)
                    Divider()
                    compactToggleRow("显示性能指标", isOn: $viewModel.showPerformanceMetrics)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: 520)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )

                Text("修改可能影响稳定性。")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                summaryBlock(title: "权限概览", icon: "lock.shield", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        let allAuthorized = checkAllPermissions()
                        HStack {
                            Image(systemName: allAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(allAuthorized ? .green : .orange)
                            Text(allAuthorized ? "全部正常" : "部分异常")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }

                summaryBlock(title: "需要操作", icon: "hand.raised", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        permissionStatusItem("辅助功能", status: permissionManager.statuses[.accessibility] ?? .unknown, color: .blue)
                        permissionStatusItem("屏幕录制", status: permissionManager.statuses[.screenRecording] ?? .unknown, color: .purple)
                    }
                }
            }
            .frame(width: 280)
        }
    }

    private func checkAllPermissions() -> Bool {
        let statuses = [
            permissionManager.statuses[.accessibility] ?? .unknown,
            permissionManager.statuses[.microphone] ?? .unknown,
            permissionManager.statuses[.screenRecording] ?? .unknown
        ]
        return statuses.allSatisfy { $0 == .authorized }
    }

    private var hotZoneSection: some View {
        VStack(alignment: .leading, spacing: LocalTokens.contentRowGap) {
            Text("热区配置")
                .font(.system(size: LocalTokens.sectionTitleSize, weight: .semibold))

            if hotCornerViewModel.isLoading {
                ProgressView("正在加载热区设置")
            } else {
                VStack(spacing: 0) {
                    compactToggleRow("启用桌面四角热区", isOn: $hotCornerViewModel.settings.isEnabled)

                    if hotCornerViewModel.settings.isEnabled {
                        Divider()

                        VStack(alignment: .leading, spacing: LocalTokens.contentRowGap) {
                            HStack {
                                Text("热区大小")
                                    .font(.system(size: LocalTokens.cardTitleSize))
                                Spacer()
                                Text("\(Int(hotCornerViewModel.settings.cornerSize)) px")
                                    .font(.system(size: LocalTokens.cardTitleSize))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }
                            Slider(
                                value: cornerSizeBinding,
                                in: 0...100,
                                step: 1
                            )
                            .frame(height: 24)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider()

                        ForEach(HotCornerPosition.allCases) { position in
                            hotZoneRow(
                                position: position.displayName,
                                binding: hotCornerViewModel.binding(for: position),
                                actionText: hotCornerViewModel.actionSummary(for: position),
                                onEdit: {
                                    draftHotCornerBinding = hotCornerViewModel.binding(for: position)
                                    editingHotCorner = position
                                },
                                onReset: {
                                    hotCornerViewModel.resetBinding(for: position)
                                }
                            )
                            if position != HotCornerPosition.allCases.last {
                                Divider()
                            }
                        }

                        Divider()

                        HStack {
                            Text("恢复默认")
                                .font(.system(size: LocalTokens.captionSize))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                            Spacer()
                            Button("保存") {
                                Task {
                                    await hotCornerViewModel.save()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(LocalTokens.secondaryCardRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: LocalTokens.secondaryCardRadius)
                        .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
                )
            }
        }
        .sheet(item: $editingHotCorner) { position in
            HotCornerBindingEditorSheet(
                position: position,
                binding: $draftHotCornerBinding,
                onCancel: {
                    editingHotCorner = nil
                },
                onSave: { updatedBinding in
                    hotCornerViewModel.updateBinding(updatedBinding, for: position)
                    Task {
                        await hotCornerViewModel.save()
                    }
                    editingHotCorner = nil
                }
            )
        }
    }

    private func hotZoneRow(
        position: String,
        binding: HotCornerBinding,
        actionText: String,
        onEdit: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(position)
                    .font(.system(size: LocalTokens.cardTitleSize))
                Text(binding.isEnabled ? "已启用 · 停留 \(binding.hoverDelay, specifier: "%.1f")s" : "已关闭")
                    .font(.system(size: LocalTokens.captionSize))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(actionText)
                    .font(.system(size: LocalTokens.captionSize))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                HStack(spacing: 6) {
                    Button("编辑") { onEdit() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("重置") { onReset() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func moduleSummary(for name: String) -> String {
        switch name {
        case "音乐模块":
            return "播放摘要与基础控制"
        case "Agent 模块":
            return "对话与工具入口"
        case "日程模块":
            return "今日最近事项"
        case "系统状态模块":
            return "设备概览与采样"
        default:
            return "灵动大陆内容"
        }
    }

    private func runtimeContentIcon(for content: CompanionRuntimeContentID) -> String {
        switch content {
        case .voice: return "waveform"
        case .screenshot: return "camera.viewfinder"
        case .music: return "music.note"
        case .schedule: return "calendar.badge.clock"
        case .agent: return "sparkles"
        case .systemStatus: return "waveform.path.ecg"
        }
    }

    private func runtimeContentSummary(for content: CompanionRuntimeContentID) -> String {
        switch content {
        case .voice:
            return "录音、转写与投递反馈。"
        case .screenshot:
            return "截图处理中与完成反馈。"
        case .music:
            return "播放中时接管收起态或主内容。"
        case .schedule:
            return "今日日程摘要与下一步提示。"
        case .agent:
            return "默认空闲态与最近任务摘要。"
        case .systemStatus:
            return "权限异常、电量异常与系统提醒。"
        }
    }

    private func permissionRow(_ kind: AppPermissionKind) -> some View {
        let status = permissionManager.statuses[kind] ?? .unknown
        let color = permissionColor(for: status)

        return HStack(spacing: 12) {
            Image(systemName: kind.iconName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(color)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.system(size: LocalTokens.cardTitleSize))
                Text(status.displayName)
                    .font(.system(size: LocalTokens.captionSize))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()

            Button("检查") {
                Task {
                    await permissionManager.refresh(kind)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if status == .needsSystemSettings || status == .denied {
                Button("系统设置") {
                    permissionManager.openSettingsFor(kind)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: LocalTokens.permissionRowHeight)
    }

    private func permissionColor(for status: AppPermissionStatus) -> Color {
        switch status {
        case .authorized:
            return .green
        case .needsSystemSettings, .denied, .restricted:
            return .orange
        case .failed:
            return .red
        case .requesting:
            return .blue
        case .notDetermined, .unknown:
            return .secondary
        }
    }

    private func permissionTextRow(title: String, detail: String, accent: Color) -> some View {
        let isWarning = detail != "已授权"

        return HStack(spacing: 12) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(isWarning ? .orange : accent)
                .background((isWarning ? Color.orange : accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: LocalTokens.cardTitleSize))
                Text(detail)
                    .font(.system(size: LocalTokens.captionSize))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: LocalTokens.permissionRowHeight)
    }

    private var calendarPermissionText: String {
        Self.formatCalendarStatus(EKEventStore.authorizationStatus(for: .event))
    }

    private var remindersPermissionText: String {
        Self.formatCalendarStatus(EKEventStore.authorizationStatus(for: .reminder))
    }

    private static func formatCalendarStatus(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "已授权"
        case .fullAccess:
            return "已授权"
        case .writeOnly:
            return "已授权"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限"
        case .notDetermined:
            return "未确定"
        @unknown default:
            return "未知"
        }
    }

    private func summaryBlock<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: LocalTokens.cardTitleSize, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(LocalTokens.inlineBlockRadius)
        .overlay(
            RoundedRectangle(cornerRadius: LocalTokens.inlineBlockRadius)
                .stroke(AppSurfaceTokens.separator.opacity(0.6), lineWidth: 1)
        )
    }

    private func samplingItem(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: LocalTokens.captionSize))
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: LocalTokens.captionSize))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private func permissionStatusItem(_ title: String, status: AppPermissionStatus, color: Color) -> some View {
        let isGood = status == .authorized
        return HStack(spacing: 6) {
            Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(isGood ? .green : .orange)
            Text(title)
                .font(.system(size: LocalTokens.captionSize))
            Spacer(minLength: 0)
            Text(status.displayName)
                .font(.system(size: LocalTokens.captionSize))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
    }

    private var cornerSizeBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(hotCornerViewModel.settings.cornerSize) },
            set: { hotCornerViewModel.settings.cornerSize = CGFloat($0) }
        )
    }
}

struct NotchPreviewCard: View {
    private enum LocalTokens {
        static let previewHeight: CGFloat = 120
        static let cardRadius: CGFloat = 14
        static let contentPadding: CGFloat = 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notch 预览")
                .font(.system(size: 14, weight: .semibold))

            ZStack {
                RoundedRectangle(cornerRadius: LocalTokens.cardRadius)
                    .fill(Color.black)
                    .frame(height: LocalTokens.previewHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: LocalTokens.cardRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    Spacer()

                    Text("灵动大陆")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(LocalTokens.contentPadding)
        .background(AppSurfaceTokens.cardBackground)
        .cornerRadius(LocalTokens.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: LocalTokens.cardRadius)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
    }
}

@MainActor
final class HotCornerConfigViewModel: ObservableObject {
    @Published var settings: HotCornerSettings = .defaultSettings
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let settingsService: HotCornerSettingsStore?

    init(settingsService: HotCornerSettingsStore? = nil) {
        if let settingsService {
            self.settingsService = settingsService
        } else if ServiceContainer.isInitialized() {
            self.settingsService = ServiceContainer.shared.hotCornerSettingsStore
        } else {
            self.settingsService = nil
        }

        Task {
            await load()
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let settingsService else {
            settings = .defaultSettings
            return
        }

        settings = await settingsService.getHotCornerSettings()
        normalizeBindings()
    }

    func binding(for position: HotCornerPosition) -> HotCornerBinding {
        settings.bindings[position] ?? HotCornerBinding()
    }

    func actionSummary(for position: HotCornerPosition) -> String {
        binding(for: position).action.displayName
    }

    func updateBinding(_ binding: HotCornerBinding, for position: HotCornerPosition) {
        settings.bindings[position] = binding
    }

    func resetBinding(for position: HotCornerPosition) {
        settings.bindings[position] = HotCornerBinding()
    }

    func resetAllBindings() {
        settings = .defaultSettings
    }

    func save() async {
        guard let settingsService else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            normalizeBindings()
            try await settingsService.updateHotCornerSettings(settings)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func normalizeBindings() {
        for position in HotCornerPosition.allCases {
            if settings.bindings[position] == nil {
                settings.bindings[position] = HotCornerBinding()
            }
        }
    }
}

enum HotCornerActionKind: String, CaseIterable, Identifiable {
    case none
    case openApp
    case openURL
    case toggleFeature
    case openInternalRoute
    case showPanel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无动作"
        case .openApp: return "打开应用"
        case .openURL: return "打开链接"
        case .toggleFeature: return "切换功能"
        case .openInternalRoute: return "打开页面"
        case .showPanel: return "显示面板"
        }
    }
}

extension HotCornerAction {
    var displayName: String {
        switch self {
        case .none:
            return "无动作"
        case let .openApp(bundleIdentifier):
            return "打开应用 · \(bundleIdentifier)"
        case let .openURL(urlString):
            return "打开链接 · \(urlString)"
        case let .toggleFeature(featureIdentifier):
            return "切换功能 · \(HotCornerFeaturePreset.displayName(for: featureIdentifier))"
        case let .openInternalRoute(routeIdentifier):
            return "打开页面 · \(HotCornerRoutePreset.displayName(for: routeIdentifier))"
        case let .showPanel(panelIdentifier):
            return "显示面板 · \(HotCornerPanelPreset.displayName(for: panelIdentifier))"
        }
    }
}

enum HotCornerFeaturePreset: String, CaseIterable, Identifiable {
    case dynamicContinent
    case systemStatus
    case voiceEntry
    case notchPanel
    case desktopCapsule
    case mainWindow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dynamicContinent: return "灵动大陆 & 配置"
        case .systemStatus: return "本地状态"
        case .voiceEntry: return "说入法"
        case .notchPanel: return "灵动岛"
        case .desktopCapsule: return "灵动胶囊"
        case .mainWindow: return "主窗口"
        }
    }

    static func displayName(for identifier: String) -> String {
        Self(rawValue: identifier)?.displayName ?? identifier
    }
}

enum HotCornerRoutePreset {
    static func displayName(for identifier: String) -> String {
        SidebarItem(rawValue: identifier)?.displayName ?? identifier
    }
}

enum HotCornerPanelPreset {
    static func displayName(for identifier: String) -> String {
        switch identifier {
        case "notchPanel": return "灵动岛"
        case "desktopCapsule": return "灵动胶囊"
        default: return identifier
        }
    }
}

struct HotCornerBindingEditorSheet: View {
    let position: HotCornerPosition
    @Binding var binding: HotCornerBinding
    let onCancel: () -> Void
    let onSave: (HotCornerBinding) -> Void

    @State private var actionKind: HotCornerActionKind = .none
    @State private var bundleIdentifier = ""
    @State private var urlString = ""
    @State private var featureIdentifier = HotCornerFeaturePreset.dynamicContinent.rawValue
    @State private var routeIdentifier = SidebarItem.dynamicContinent.rawValue
    @State private var panelIdentifier = "notchPanel"
    @State private var isLoadingBinding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(position.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("停留 1.5 秒后触发。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用这个角", isOn: $binding.isEnabled)

                HStack {
                    Text("停留时间")
                    Spacer()
                    Stepper(value: $binding.hoverDelay, in: 0.5...5.0, step: 0.1) {
                        Text("\(binding.hoverDelay, specifier: "%.1f") 秒")
                    }
                    .labelsHidden()
                }

                Picker("动作类型", selection: $actionKind) {
                    ForEach(HotCornerActionKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }

            Group {
                switch actionKind {
                case .none:
                    Text("当前不会触发任何动作。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .openApp:
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Bundle Identifier", text: $bundleIdentifier)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("选择应用") {
                                chooseApplication()
                            }
                            .buttonStyle(.bordered)
                            Text(bundleIdentifier.isEmpty ? "请选择一个 .app" : bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                case .openURL:
                    TextField("https://example.com", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                case .toggleFeature:
                    Picker("功能", selection: $featureIdentifier) {
                        ForEach(HotCornerFeaturePreset.allCases) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                case .openInternalRoute:
                    Picker("页面", selection: $routeIdentifier) {
                        ForEach(SidebarItem.mainItems, id: \.rawValue) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                case .showPanel:
                    Picker("面板", selection: $panelIdentifier) {
                        Text("灵动岛").tag("notchPanel")
                        Text("灵动胶囊").tag("desktopCapsule")
                    }
                    .pickerStyle(.menu)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("保存") {
                    onSave(updatedBinding())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460, height: 420)
        .onAppear {
            loadBinding()
        }
        .onChange(of: actionKind, initial: false) { _, _ in
            guard !isLoadingBinding else { return }
            syncBindingAction()
        }
    }

    private func loadBinding() {
        isLoadingBinding = true
        defer { isLoadingBinding = false }

        actionKind = kind(for: binding.action)
        switch binding.action {
        case .none:
            break
        case let .openApp(bundleIdentifier):
            self.bundleIdentifier = bundleIdentifier
        case let .openURL(urlString):
            self.urlString = urlString
        case let .toggleFeature(featureIdentifier):
            self.featureIdentifier = featureIdentifier
        case let .openInternalRoute(routeIdentifier):
            self.routeIdentifier = routeIdentifier
        case let .showPanel(panelIdentifier):
            self.panelIdentifier = panelIdentifier
        }
    }

    private func kind(for action: HotCornerAction) -> HotCornerActionKind {
        switch action {
        case .none: return .none
        case .openApp: return .openApp
        case .openURL: return .openURL
        case .toggleFeature: return .toggleFeature
        case .openInternalRoute: return .openInternalRoute
        case .showPanel: return .showPanel
        }
    }

    private func syncBindingAction() {
        binding.action = currentAction()
    }

    private func currentAction() -> HotCornerAction {
        switch actionKind {
        case .none:
            return .none
        case .openApp:
            return .openApp(bundleIdentifier: bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))
        case .openURL:
            return .openURL(urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        case .toggleFeature:
            return .toggleFeature(featureIdentifier: featureIdentifier)
        case .openInternalRoute:
            return .openInternalRoute(routeIdentifier: routeIdentifier)
        case .showPanel:
            return .showPanel(panelIdentifier: panelIdentifier)
        }
    }

    private func updatedBinding() -> HotCornerBinding {
        var updated = binding
        updated.action = currentAction()
        return updated
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.title = "选择应用"
        panel.message = "选择一个 .app 应用包作为热区动作"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier {
            bundleIdentifier = identifier
            actionKind = .openApp
        }
    }
}

@MainActor
class DynamicContinentConfigViewModel: ObservableObject {
    @Published var isEnabled = true
    @Published var autoExpand = false
    @Published var hoverExpandDelay: Double = 1.5
    @Published var showOnAllDisplays = false
    @Published var autoSwitchDisplays = true
    @Published var hideInFullscreen = true
    @Published var hideWhenScreenRecording = true
    @Published var nonNotchCollapsedWidth: CGFloat = 220
    @Published var showCollapsedSubtitle = true
    @Published var showCollapsedStatusDots = true
    @Published var showSystemEventHUD = true
    @Published var debugMode = false
    @Published var showPerformanceMetrics = false

    var currentStateText: String {
        if !isEnabled {
            return "已关闭"
        }
        if autoExpand {
            return "自动展开"
        }
        return "收起"
    }

    var currentStateColor: Color {
        if !isEnabled {
            return .gray
        }
        if autoExpand {
            return .blue
        }
        return .green
    }

    var activeModuleCount: Int {
        modules.filter(\.isEnabled).count
    }

    var overviewVisibleModules: Set<DynamicContinentModuleID> {
        moduleOverviewVisibility
    }

    struct Module: Identifiable {
        let id: DynamicContinentModuleID
        var isEnabled: Bool
    }

    @Published var modules = DynamicContinentModuleID.allCases.map { Module(id: $0, isEnabled: true) }
    @Published var moduleOverviewVisibility: Set<DynamicContinentModuleID> = Set(DynamicContinentModuleID.allCases)
    @Published var collapsedVisibleContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases)
    @Published var primarySurfaceContents: Set<CompanionRuntimeContentID> = Set(CompanionRuntimeContentID.allCases)

    struct SystemEventSetting: Identifiable, Equatable {
        let kind: SystemEventKind
        var isEnabled: Bool

        var id: SystemEventKind { kind }
    }

    @Published var systemEventSettings: [SystemEventSetting] = [
        .init(kind: .volume, isEnabled: true),
        .init(kind: .brightness, isEnabled: true),
        .init(kind: .keyboardBacklight, isEnabled: true),
        .init(kind: .microphone, isEnabled: true),
        .init(kind: .sayInput, isEnabled: true),
        .init(kind: .screenshot, isEnabled: true)
    ]

    init() {
        let settings = CompanionDisplaySettingsStore.load()
        isEnabled = settings.isEnabled
        autoExpand = settings.autoExpand
        hoverExpandDelay = settings.hoverExpandDelay
        showOnAllDisplays = settings.showOnAllDisplays
        autoSwitchDisplays = settings.autoSwitchDisplays
        hideInFullscreen = settings.hideInFullscreen
        hideWhenScreenRecording = settings.hideWhenScreenRecording
        nonNotchCollapsedWidth = settings.nonNotchCollapsedWidth
        showCollapsedSubtitle = settings.showCollapsedSubtitle
        showCollapsedStatusDots = settings.showCollapsedStatusDots
        showSystemEventHUD = settings.showSystemEventHUD
        modules = DynamicContinentModuleID.allCases.map { module in
            .init(id: module, isEnabled: settings.enabledDynamicModules.contains(module))
        }
        moduleOverviewVisibility = settings.overviewVisibleModules
        collapsedVisibleContents = settings.collapsedVisibleContents
        primarySurfaceContents = settings.primarySurfaceContents
        systemEventSettings = SystemEventKind.allCases.map { kind in
            .init(kind: kind, isEnabled: settings.enabledSystemEventKinds.contains(kind))
        }
    }

    func persistDisplaySettings() {
        CompanionDisplaySettingsStore.save(currentDisplaySettings())
    }

    private func currentDisplaySettings() -> CompanionDisplaySettings {
        CompanionDisplaySettings(
            isEnabled: isEnabled,
            autoExpand: autoExpand,
            hoverExpandDelay: hoverExpandDelay,
            showOnAllDisplays: showOnAllDisplays,
            autoSwitchDisplays: autoSwitchDisplays,
            hideInFullscreen: hideInFullscreen,
            hideWhenScreenRecording: hideWhenScreenRecording,
            enabledDynamicModules: Set(modules.filter(\.isEnabled).map(\.id)),
            overviewVisibleModules: moduleOverviewVisibility.intersection(Set(modules.filter(\.isEnabled).map(\.id))),
            collapsedVisibleContents: collapsedVisibleContents,
            primarySurfaceContents: primarySurfaceContents,
            nonNotchCollapsedWidth: nonNotchCollapsedWidth,
            showCollapsedSubtitle: showCollapsedSubtitle,
            showCollapsedStatusDots: showCollapsedStatusDots,
            showSystemEventHUD: showSystemEventHUD,
            enabledSystemEventKinds: Set(systemEventSettings.filter(\.isEnabled).map(\.kind))
        )
    }

    func isModuleEnabled(_ id: DynamicContinentModuleID) -> Bool {
        modules.first(where: { $0.id == id })?.isEnabled ?? false
    }

    func setModuleEnabled(_ id: DynamicContinentModuleID, isEnabled: Bool) {
        guard let index = modules.firstIndex(where: { $0.id == id }) else { return }
        modules[index].isEnabled = isEnabled
        if isEnabled == false {
            moduleOverviewVisibility.remove(id)
        }
        persistDisplaySettings()
    }

    func isOverviewModuleVisible(_ id: DynamicContinentModuleID) -> Bool {
        moduleOverviewVisibility.contains(id)
    }

    func setOverviewModuleVisible(_ id: DynamicContinentModuleID, isVisible: Bool) {
        if isVisible {
            moduleOverviewVisibility.insert(id)
        } else {
            moduleOverviewVisibility.remove(id)
        }
        persistDisplaySettings()
    }

    func isRuntimeContentVisible(_ id: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope) -> Bool {
        switch scope {
        case .collapsed:
            return collapsedVisibleContents.contains(id)
        case .primary:
            return primarySurfaceContents.contains(id)
        }
    }

    func setRuntimeContentVisible(_ id: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope, isVisible: Bool) {
        switch scope {
        case .collapsed:
            if isVisible {
                collapsedVisibleContents.insert(id)
            } else {
                collapsedVisibleContents.remove(id)
            }
        case .primary:
            if isVisible {
                primarySurfaceContents.insert(id)
            } else {
                primarySurfaceContents.remove(id)
            }
        }
        persistDisplaySettings()
    }
}
