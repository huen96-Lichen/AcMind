import SwiftUI
import AppKit
import AcMindKit

struct CompanionControlCenterView: View {
    @AppStorage("AppSettings.notchPanelEnabled") private var notchPanelEnabled: Bool = true
    @State private var capsuleSettings: DesktopCapsuleSettings = .default
    @ObservedObject private var coordinator = DynamicSurfaceCoordinator.shared
    @State private var selectedHeaderSurface: CompanionLaunchSurface = .capsuleDesktop
    @State private var selectedWidgetIDs: Set<String> = Set(
        CompanionWidgetCatalog.capsuleWidgets.filter(\.isEnabled).map(\.id) +
            CompanionWidgetCatalog.continentWidgets.filter(\.isEnabled).map(\.id)
    )
    @State private var enabledFeatureIDs: Set<String> = Set(
        CompanionFeatureCatalog.cards.filter(\.isEnabledByDefault).map(\.id)
    )
    @State private var continentTabs: [CompanionContinentPreviewTab] = CompanionContinentPreviewCatalog.defaultTabs
    @State private var selectedContinentTabID: UUID = CompanionContinentPreviewCatalog.defaultTabs.first?.id ?? UUID()
    @State private var debugDisclosureExpanded = false
    @State private var linkageCapsuleToContinent = true
    @State private var linkageContinentToCapsule = true
    @State private var topDockHotZoneHeight: CGFloat = 96

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CompanionControlLayout.sectionGap) {
                header
                CompanionPreviewOverviewSection(
                    tabs: $continentTabs,
                    selectedTabID: $selectedContinentTabID
                )
                middleSection
                CompanionFeatureCardSection(enabledFeatureIDs: $enabledFeatureIDs)
                CompanionDebugInfoDisclosure(
                    coordinator: coordinator,
                    capsulePosition: capsulePositionLabel,
                    continentScreen: continentScreenLabel,
                    launchSurface: selectedHeaderSurface.displayTitle,
                    topDockHotZone: String(format: "%.0f px", topDockHotZoneHeight),
                    debugDisclosureExpanded: $debugDisclosureExpanded
                )
            }
            .padding(.horizontal, CompanionControlLayout.pagePadding)
            .padding(.top, CompanionControlLayout.pagePadding)
            .padding(.bottom, CompanionControlLayout.pagePadding)
            .frame(maxWidth: CompanionControlLayout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(CompanionSettingsDesign.pageBackground.ignoresSafeArea())
        .onAppear {
            loadCapsuleSettings()
        }
        .onChange(of: capsuleSettings.isEnabled) { _, _ in
            persistCapsuleSettings()
            reconcileVisibleSurface()
        }
        .onChange(of: notchPanelEnabled) { _, _ in
            persistNotchPanelSetting()
            reconcileVisibleSurface()
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("灵动胶囊 / 大陆")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text("配置桌面入口与顶部大陆，打造你的专属交互体验")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CompanionSettingsDesign.softText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HeaderModeChip(
                    title: "桌面胶囊",
                    icon: "capsule",
                    isSelected: selectedHeaderSurface == .capsuleDesktop
                ) {
                    selectedHeaderSurface = .capsuleDesktop
                }
                HeaderModeChip(
                    title: "顶部大陆",
                    icon: "dock.top",
                    isSelected: selectedHeaderSurface == .continentTopDock
                ) {
                    selectedHeaderSurface = .continentTopDock
                }
                HeaderModeChip(
                    title: "配置中心",
                    icon: "square.grid.2x2",
                    isSelected: false
                ) {
                }
            }
        }
    }

    private var capsulePositionLabel: String {
        if let position = coordinator.capsuleDesktopPosition {
            return String(format: "(%.0f, %.0f)", position.x, position.y)
        }
        return capsuleSettings.position == .zero ? "未记录" : String(format: "(%.0f, %.0f)", capsuleSettings.position.x, capsuleSettings.position.y)
    }

    private var continentScreenLabel: String {
        coordinator.continentTopDockScreenID ?? "默认屏幕"
    }

    private func loadCapsuleSettings() {
        if let data = UserDefaults.standard.data(forKey: "AppSettings.desktopCapsule"),
           let decoded = try? JSONDecoder().decode(DesktopCapsuleSettings.self, from: data) {
            capsuleSettings = decoded
        } else {
            capsuleSettings = .default
        }
    }

    private var middleSection: some View {
        HStack(alignment: .top, spacing: CompanionControlLayout.sectionGap) {
            CompanionLinkageRulesView(
                capsuleEnabled: $capsuleSettings.isEnabled,
                continentEnabled: $notchPanelEnabled,
                capsuleToContinentEnabled: $linkageCapsuleToContinent,
                continentToCapsuleEnabled: $linkageContinentToCapsule
            )
            .frame(width: CompanionControlLayout.linkageWidth)

            CompanionWidgetPickerSection(selectedWidgetIDs: $selectedWidgetIDs)

            ContinentModuleManagerView(
                tabs: $continentTabs,
                selectedTabID: $selectedContinentTabID
            )
            .frame(width: CompanionControlLayout.moduleManagerWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func persistCapsuleSettings() {
        if let data = try? JSONEncoder().encode(capsuleSettings) {
            UserDefaults.standard.set(data, forKey: "AppSettings.desktopCapsule")
        }
    }

    private func persistNotchPanelSetting() {
        UserDefaults.standard.set(notchPanelEnabled, forKey: "AppSettings.notchPanelEnabled")
    }

    private func reconcileVisibleSurface() {
        let coordinator = DynamicSurfaceCoordinator.shared
        let capsuleOn = capsuleSettings.isEnabled
        let continentOn = notchPanelEnabled

        if capsuleOn && continentOn {
            coordinator.restoreLastSurface(fallback: .capsuleCompact)
        } else if capsuleOn {
            (NSApp.delegate as? AppDelegate)?.showDesktopCapsule()
        } else if continentOn {
            (NSApp.delegate as? AppDelegate)?.showNotchPanel()
        } else {
            coordinator.transition(to: .capsuleCompact, reason: .manualCommand)
        }
    }
}

struct CompanionPreviewOverviewSection: View {
    @Binding var tabs: [CompanionContinentPreviewTab]
    @Binding var selectedTabID: UUID

    var body: some View {
        HStack(alignment: .top, spacing: CompanionControlLayout.sectionGap) {
            CompanionEntryPreviewCard()
                .frame(maxWidth: .infinity)
            CompanionContinentExpandedPreviewCard(tabs: $tabs, selectedTabID: $selectedTabID)
                .frame(maxWidth: .infinity)
        }
        .frame(height: CompanionControlLayout.previewSectionHeight)
    }
}

private struct CompanionEntryPreviewCard: View {
    var body: some View {
        AppSurfaceCard(title: "入口形态", subtitle: "胶囊两态 / 大陆收缩态", padding: CompanionControlLayout.previewCardPadding) {
            VStack(alignment: .leading, spacing: 8) {
                previewRow(
                    label: "胶囊收缩",
                    hint: "桌面入口",
                    sample: CapsuleCompactPreview()
                )
                previewRow(
                    label: "胶囊展开",
                    hint: "快捷工具条",
                    sample: CapsuleExpandedToolBar()
                )
                previewRow(
                    label: "大陆收缩",
                    hint: "顶部停靠",
                    sample: ContinentCompactPill()
                )
            }
        }
    }

    private func previewRow<Sample: View>(label: String, hint: String, sample: Sample) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(CompanionSettingsDesign.accentBlue.opacity(0.75))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(hint)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(CompanionSettingsDesign.quietText)
            }
            Spacer(minLength: 0)
            sample
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(CompanionSettingsDesign.subtleBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct CompanionContinentExpandedPreviewCard: View {
    @Binding var tabs: [CompanionContinentPreviewTab]
    @Binding var selectedTabID: UUID

    private var selectedTab: CompanionContinentPreviewTab {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first ?? CompanionContinentPreviewCatalog.defaultTabs[0]
    }

    var body: some View {
        AppSurfaceCard(title: "大陆展开态", subtitle: "可切换板块查看不同内容布局", padding: CompanionControlLayout.previewCardPadding) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        Button {
                            selectedTabID = tab.id
                        } label: {
                            previewTab(tab.name, isSelected: selectedTab.id == tab.id)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        let newTab = CompanionContinentPreviewTab(
                            id: UUID(),
                            name: "自定义\(tabs.count - CompanionContinentPreviewCatalog.defaultTabs.count + 1)",
                            icon: "plus",
                            layout: .custom,
                            enabledModules: [.timeline, .quickActions, .weather],
                            isDefault: false
                        )
                        tabs.append(newTab)
                        selectedTabID = newTab.id
                    } label: {
                        Text("+")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.86), in: Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text("管理板块")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.86), in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                }

                ContinentExpandedMiniPreview(tab: selectedTab)
                    .frame(height: 118)

                HStack(spacing: 8) {
                    Text("当前板块")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CompanionSettingsDesign.quietText)
                    TextField("", text: bindingForSelectedTabName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.86), in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
                        .frame(maxWidth: 128, alignment: .leading)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    ForEach(Array(selectedTab.enabledModules.prefix(5))) { module in
                        modulePill(module.displayTitle)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var bindingForSelectedTabName: Binding<String> {
        Binding(
            get: { tabs.first(where: { $0.id == selectedTabID })?.name ?? "" },
            set: { newValue in
                guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
                tabs[index].name = newValue
            }
        )
    }

    private func previewTab(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(isSelected ? .white : AppSurfaceTokens.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.black : Color.white.opacity(0.86), in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(isSelected ? 0 : 0.05), lineWidth: 1))
    }

    private func modulePill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.78), in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.04), lineWidth: 1))
    }
}

private struct CapsuleExpandedToolBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "capsule.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("灵动胶囊展开态")
                .font(.system(size: 11.5, weight: .semibold))
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "camera")
                Image(systemName: "mic")
                Image(systemName: "calendar")
            }
            .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 176, height: 34)
        .background(
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .foregroundStyle(AppSurfaceTokens.primaryText)
    }
}

private struct ContinentCompactPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 10, height: 10)
            Text("灵动大陆收缩态")
                .font(.system(size: 11, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 176, height: 34)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.98), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct CompanionPreviewStageView: View {
    @Binding var mode: CompanionPreviewMode

    var body: some View {
        AppSurfaceCard(title: nil, subtitle: nil, padding: 0) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: CompanionSettingsDesign.previewRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CompanionSettingsDesign.previewGradientStart,
                                CompanionSettingsDesign.previewGradientEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CompanionSettingsDesign.previewRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.86), lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CompanionSettingsDesign.previewRadius, style: .continuous)
                            .stroke(CompanionSettingsDesign.previewBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AcMind Companion Preview")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                            Text("桌面胶囊与顶部大陆的实际展示效果")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(CompanionSettingsDesign.quietText)
                        }

                        Spacer()

                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CompanionSettingsDesign.quietText)
                            .padding(8)
                            .background(Color.white.opacity(0.7), in: Circle())
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.90, green: 0.94, blue: 0.98),
                                        Color(red: 0.96, green: 0.98, blue: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(alignment: .topLeading) {
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.62),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 24,
                                    endRadius: 300
                                )
                                .blendMode(.screen)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                RadialGradient(
                                    colors: [
                                        Color.black.opacity(0.08),
                                        Color.clear
                                    ],
                                    center: .bottomTrailing,
                                    startRadius: 20,
                                    endRadius: 240
                                )
                                .blendMode(.multiply)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

                        VStack(spacing: 10) {
                            HStack {
                                PreviewStatusBadge(label: "当前", value: mode.displayTitle)
                                PreviewStatusBadge(label: "联动", value: "已启用")
                                PreviewStatusBadge(label: "热区", value: "96px")
                                Spacer(minLength: 0)
                            }

                            Spacer(minLength: 0)

                            HStack(alignment: .top) {
                                if mode == .continentCompact || mode == .continentExpanded {
                                    topDockPreview
                                }
                                Spacer(minLength: 0)
                            }

                            HStack(alignment: .bottom, spacing: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("桌面胶囊")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(CompanionSettingsDesign.quietText)
                                        .textCase(.uppercase)
                                        .tracking(1.0)
                                    if mode == .capsuleCompact || mode == .capsuleExpanded {
                                        CapsulePreviewPill(expanded: mode == .capsuleExpanded)
                                    } else {
                                        CapsulePreviewPill(expanded: false)
                                            .opacity(0.65)
                                    }
                                }

                                Spacer(minLength: 0)

                                if mode == .continentExpanded {
                                    continentExpandedCard
                                }
                            }
                        }
                        .padding(16)

                        if mode == .continentExpanded {
                            continentMiniBadge
                                .padding(.trailing, 20)
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                    }
                    .frame(height: 168)

                    HStack {
                        Text("入口预览 · 同屏展示四态")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CompanionSettingsDesign.softText)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, CompanionSettingsDesign.previewPadding)
                .padding(.vertical, 14)
            }
            .frame(height: CompanionSettingsDesign.previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: CompanionSettingsDesign.previewRadius, style: .continuous))
        }
    }

    private var topDockPreview: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.52)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .continentExpanded ? "灵动大陆展开态" : "灵动大陆收缩态")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("顶部停靠")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                }
                Spacer(minLength: 0)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 332, height: 48, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.98),
                    Color.black.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
    }

    private var continentExpandedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日概览")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(CompanionSettingsDesign.accentBlue)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                PreviewMetric(title: "天气", value: "晴 24°")
                PreviewMetric(title: "日程", value: "3 项")
                PreviewMetric(title: "AI", value: "待命")
                PreviewMetric(title: "电量", value: "87%")
            }
        }
        .padding(12)
        .frame(width: 216)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var continentMiniBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(CompanionSettingsDesign.accentBlue)
                .frame(width: 8, height: 8)
            Text("灵动大陆展开态")
                .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.primaryText)
            Text("顶部停靠")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(CompanionSettingsDesign.quietText)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.72), in: Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

struct CompanionContinentPreviewTab: Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var layout: ContinentPreviewLayout
    var enabledModules: [ContinentPreviewModule]
    var isDefault: Bool
}

enum ContinentPreviewLayout: String, CaseIterable, Identifiable {
    case overview
    case music
    case agent
    case schedule
    case custom

    var id: String { rawValue }
}

enum ContinentPreviewModule: String, CaseIterable, Identifiable {
    case timeline
    case musicPlayer
    case agentStatus
    case quickActions
    case tasks
    case calendar
    case weather
    case systemStatus
    case notes
    case inbox

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .timeline: return "日程"
        case .musicPlayer: return "音乐"
        case .agentStatus: return "Agent"
        case .quickActions: return "快捷入口"
        case .tasks: return "任务"
        case .calendar: return "日历"
        case .weather: return "天气"
        case .systemStatus: return "系统"
        case .notes: return "笔记"
        case .inbox: return "收集箱"
        }
    }

    var symbolName: String {
        switch self {
        case .timeline: return "calendar"
        case .musicPlayer: return "music.note"
        case .agentStatus: return "sparkles"
        case .quickActions: return "bolt.horizontal.circle"
        case .tasks: return "checklist"
        case .calendar: return "calendar.badge.clock"
        case .weather: return "cloud.sun"
        case .systemStatus: return "slider.horizontal.3"
        case .notes: return "doc.text"
        case .inbox: return "tray.full"
        }
    }
}

private enum CompanionContinentPreviewCatalog {
    static let defaultTabs: [CompanionContinentPreviewTab] = [
        .init(
            id: UUID(),
            name: "今日",
            icon: "sun.max",
            layout: .overview,
            enabledModules: [.timeline, .musicPlayer, .quickActions, .tasks, .agentStatus],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "音乐",
            icon: "music.note",
            layout: .music,
            enabledModules: [.musicPlayer, .tasks, .agentStatus, .quickActions],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "AI",
            icon: "sparkles",
            layout: .agent,
            enabledModules: [.agentStatus, .quickActions, .tasks, .systemStatus],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "日程",
            icon: "calendar",
            layout: .schedule,
            enabledModules: [.timeline, .calendar, .tasks, .weather],
            isDefault: true
        )
    ]
}

private struct ContinentExpandedMiniPreview: View {
    let tab: CompanionContinentPreviewTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CompanionControlLayout.featureCardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.98), Color.black.opacity(0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CompanionControlLayout.featureCardRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 10, height: 10)
                        Text(tab.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(CompanionSettingsDesign.accentBlue)
                }

                HStack(spacing: 8) {
                    miniPane(title: "左", value: firstModuleTitle(from: 0))
                    miniPane(title: "中", value: firstModuleTitle(from: 1))
                    miniPane(title: "右", value: firstModuleTitle(from: 2))
                }

                HStack(spacing: 6) {
                    ForEach(Array(tab.enabledModules.prefix(5))) { module in
                        Text(module.displayTitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }

                HStack {
                    Text(statusLine)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
    }

    private func miniPane(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.68))
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func firstModuleTitle(from index: Int) -> String {
        guard tab.enabledModules.indices.contains(index) else { return "—" }
        return tab.enabledModules[index].displayTitle
    }

    private var statusLine: String {
        switch tab.layout {
        case .overview:
            return "今日 · 日程 / 音乐 / 快捷入口"
        case .music:
            return "音乐 · 播放 / 歌词 / Agent"
        case .agent:
            return "AI · 状态 / 任务 / 快捷入口"
        case .schedule:
            return "日程 · 时间线 / 日历 / 提醒"
        case .custom:
            return "自定义 · \(tab.enabledModules.prefix(5).map(\.displayTitle).joined(separator: " / "))"
        }
    }
}

struct ContinentModuleManagerView: View {
    @Binding var tabs: [CompanionContinentPreviewTab]
    @Binding var selectedTabID: UUID

    var body: some View {
        AppSurfaceCard(title: "板块管理", subtitle: "管理大陆展开态的板块与内容") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(tabs) { tab in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tab.isDefault ? CompanionSettingsDesign.accentBlue.opacity(0.16) : Color.black.opacity(0.10))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(tab.isDefault ? CompanionSettingsDesign.accentBlue : AppSurfaceTokens.secondaryText)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tab.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.primaryText)
                                .lineLimit(1)
                            Text("\(tab.enabledModules.count) 个内容")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(CompanionSettingsDesign.softText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(CompanionSettingsDesign.quietText)
                        if !tab.isDefault {
                            Button {
                                remove(tab)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(CompanionSettingsDesign.quietText)
                                    .frame(width: 16, height: 16)
                                    .background(Color.white.opacity(0.82), in: Circle())
                                    .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedTabID == tab.id ? Color.black.opacity(0.04) : Color.white.opacity(0.82))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
                    .frame(minHeight: CompanionControlLayout.moduleRowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTabID = tab.id
                    }
                }

                Button {
                    let nextIndex = tabs.filter { !$0.isDefault }.count + 1
                    let newTab = CompanionContinentPreviewTab(
                        id: UUID(),
                        name: "专注\(nextIndex)",
                        icon: "plus",
                        layout: .custom,
                        enabledModules: [.timeline, .quickActions, .weather],
                        isDefault: false
                    )
                    tabs.append(newTab)
                    selectedTabID = newTab.id
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("新建板块")
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
                    .frame(minHeight: CompanionControlLayout.moduleRowHeight)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func remove(_ tab: CompanionContinentPreviewTab) {
        guard !tab.isDefault else { return }
        tabs.removeAll { $0.id == tab.id }
        if selectedTabID == tab.id {
            selectedTabID = tabs.first?.id ?? UUID()
        }
    }
}

private struct HeaderModeChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? CompanionSettingsDesign.accentBlue : AppSurfaceTokens.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.78), in: Capsule())
            .overlay(
                Capsule().stroke(Color.black.opacity(isSelected ? 0.03 : 0.04), lineWidth: 1)
            )
            .shadow(color: isSelected ? .black.opacity(0.05) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewStatusBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CompanionSettingsDesign.quietText)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.72), in: Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

struct CompanionLinkageRulesView: View {
    @Binding var capsuleEnabled: Bool
    @Binding var continentEnabled: Bool
    @Binding var capsuleToContinentEnabled: Bool
    @Binding var continentToCapsuleEnabled: Bool

    var body: some View {
        AppSurfaceCard(title: "联动规则", subtitle: "四个核心开关，保持桌面与顶部的联动关系") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                alignment: .leading,
                spacing: 10
            ) {
                LinkageToggleCard(
                    title: "启用胶囊",
                    subtitle: "桌面入口",
                    symbolName: "capsule",
                    isOn: $capsuleEnabled
                )
                LinkageToggleCard(
                    title: "启用大陆",
                    subtitle: "顶部入口",
                    symbolName: "dock.top",
                    isOn: $continentEnabled
                )
                LinkageToggleCard(
                    title: "拖到顶部",
                    subtitle: "胶囊 → 大陆",
                    symbolName: "arrow.up.to.line.compact",
                    isOn: $capsuleToContinentEnabled
                )
                LinkageToggleCard(
                    title: "长按回桌面",
                    subtitle: "大陆 → 胶囊",
                    symbolName: "arrow.down.to.line.compact",
                    isOn: $continentToCapsuleEnabled
                )
            }
        }
    }
}

struct CompanionWidgetPickerSection: View {
    @Binding var selectedWidgetIDs: Set<String>

    var body: some View {
        AppSurfaceCard(title: "组件选择", subtitle: "胶囊组件 / 大陆组件紧凑网格") {
            VStack(alignment: .leading, spacing: CompanionControlLayout.widgetGroupGap) {
                widgetGroup(
                    title: "胶囊组件",
                    countLabel: "已启用 \(CompanionWidgetCatalog.capsuleWidgets.filter { selectedWidgetIDs.contains($0.id) }.count) 个",
                    items: CompanionWidgetCatalog.capsuleWidgets
                )
                widgetGroup(
                    title: "大陆组件",
                    countLabel: "已启用 \(CompanionWidgetCatalog.continentWidgets.filter { selectedWidgetIDs.contains($0.id) }.count) 个",
                    items: CompanionWidgetCatalog.continentWidgets
                )
            }
        }
    }

    private func widgetGroup(title: String, countLabel: String, items: [CompanionWidgetDefinition]) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: CompanionSettingsDesign.sectionTitleFontSize, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(countLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(CompanionSettingsDesign.softText)
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: CompanionControlLayout.widgetColumnGap), count: CompanionControlLayout.widgetColumns),
                alignment: .center,
                spacing: CompanionControlLayout.widgetRowGap
            ) {
                ForEach(items) { item in
                    CompanionWidgetPillPreview(
                        item: item,
                        isSelected: selectedWidgetIDs.contains(item.id)
                    ) {
                        toggleWidget(item.id)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleWidget(_ id: String) {
        if selectedWidgetIDs.contains(id) {
            selectedWidgetIDs.remove(id)
        } else {
            selectedWidgetIDs.insert(id)
        }
    }
}

struct CompanionWidgetPillPreview: View {
    let item: CompanionWidgetDefinition
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: CompanionSettingsDesign.widgetPillRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black,
                                    Color.black.opacity(0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CompanionControlLayout.widgetPillWidth, height: CompanionControlLayout.widgetPillHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: CompanionSettingsDesign.widgetPillRadius, style: .continuous)
                                .stroke(
                                    isSelected ? CompanionSettingsDesign.accentBlue.opacity(0.42) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isSelected ? CompanionSettingsDesign.accentBlue.opacity(0.07) : .black.opacity(0.10), radius: 4, x: 0, y: 2)

                    VStack(spacing: 2) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(item.valueText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)

                    if isSelected {
                        Circle()
                            .fill(CompanionSettingsDesign.accentBlue)
                            .frame(width: 5, height: 5)
                            .offset(x: CompanionControlLayout.widgetPillWidth * 0.34, y: -CompanionControlLayout.widgetPillHeight * 0.30)
                    }
                }
                Text(item.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }
            .frame(width: CompanionControlLayout.widgetItemWidth, height: CompanionControlLayout.widgetItemHeight)
            .opacity(item.isEnabled ? 1.0 : 0.42)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct CompanionFeatureCardSection: View {
    @Binding var enabledFeatureIDs: Set<String>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: CompanionControlLayout.featureCardGap), count: 5)

    var body: some View {
        AppSurfaceCard(title: "功能模块", subtitle: "AcMind 自有能力模块") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("已启用 \(enabledFeatureIDs.count) 个")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CompanionSettingsDesign.softText)
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: CompanionControlLayout.featureCardGap) {
                    ForEach(CompanionFeatureCatalog.cards) { card in
                        CompanionFeatureCard(
                            card: card,
                            isEnabled: enabledFeatureIDs.contains(card.id)
                        ) {
                            toggleFeature(card.id)
                        }
                    }
                }
            }
        }
    }

    private func toggleFeature(_ id: String) {
        if enabledFeatureIDs.contains(id) {
            enabledFeatureIDs.remove(id)
        } else {
            enabledFeatureIDs.insert(id)
        }
    }
}

struct CompanionFeatureCard: View {
    let card: CompanionFeatureDefinition
    let isEnabled: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(card.tier.accentColor.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: card.tier.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(card.tier.accentColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                    Text(card.subtitle)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(isEnabled ? "ON" : "OFF")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isEnabled ? Color.green : CompanionSettingsDesign.softText)
                    .frame(width: 28, alignment: .leading)

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if newValue != isEnabled {
                            toggle()
                        }
                    }
                ))
                .labelsHidden()
                .tint(CompanionSettingsDesign.accentBlue)
                .frame(width: 42)

                Spacer(minLength: 0)

                Button("设置") { }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(CompanionSettingsDesign.softText)
            }
        }
        .padding(CompanionControlLayout.featureCardPadding)
        .frame(maxWidth: .infinity, minHeight: CompanionControlLayout.featureCardHeight, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CompanionControlLayout.featureCardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionControlLayout.featureCardRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct CompanionDebugInfoDisclosure: View {
    @ObservedObject var coordinator: DynamicSurfaceCoordinator
    let capsulePosition: String
    let continentScreen: String
    let launchSurface: String
    let topDockHotZone: String
    @Binding var debugDisclosureExpanded: Bool

    var body: some View {
        AppSurfaceCard(title: nil, subtitle: nil) {
            DisclosureGroup(isExpanded: $debugDisclosureExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    DebugRow(label: "可见形态", value: coordinator.visibilityState.displayName)
                    DebugRow(label: "拖拽阶段", value: coordinator.dragPhase.displayName)
                    DebugRow(label: "胶囊位置记忆", value: capsulePosition)
                    DebugRow(label: "大陆停靠记忆", value: continentScreen)
                    DebugRow(label: "默认启动形态", value: launchSurface)
                    DebugRow(label: "顶部热区", value: topDockHotZone)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("高级调试信息")
                        .font(.system(size: CompanionSettingsDesign.sectionTitleFontSize, weight: .semibold))
                    Spacer()
                    Text("仅开发时展开")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CompanionSettingsDesign.quietText)
                }
            }
            .accentColor(CompanionSettingsDesign.accentBlue)
        }
    }
}

private struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: CompanionSettingsDesign.bodyFontSize, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: CompanionSettingsDesign.bodyFontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
    }
}

private struct TagChip: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(AppSurfaceTokens.primaryText)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.82), in: Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct MiniSummaryChip: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(CompanionSettingsDesign.quietText)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 176, alignment: .leading)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct StatusPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(CompanionSettingsDesign.quietText)
                .textCase(.uppercase)
                .tracking(1.0)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 0)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private extension CompanionFeatureTier {
    var accentColor: Color {
        switch self {
        case .pro:
            return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .free:
            return Color(red: 0.22, green: 0.68, blue: 0.38)
        case .beta:
            return Color(red: 0.83, green: 0.45, blue: 0.18)
        }
    }

    var symbolName: String {
        switch self {
        case .pro:
            return "crown.fill"
        case .free:
            return "checkmark.seal.fill"
        case .beta:
            return "flask.fill"
        }
    }
}

private struct LinkageToggleCard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CompanionSettingsDesign.accentBlue)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(CompanionSettingsDesign.softText)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(CompanionSettingsDesign.accentBlue)
            }
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isOn ? CompanionSettingsDesign.accentBlue : CompanionSettingsDesign.quietText)
                Text(isOn ? "已启用" : "未启用")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CompanionSettingsDesign.softText)
            }
        }
        .padding(CompanionSettingsDesign.linkageCardPadding)
        .frame(maxWidth: .infinity, minHeight: CompanionSettingsDesign.linkageCardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CompanionSettingsDesign.linkageCardRadius, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionSettingsDesign.linkageCardRadius, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

private struct CapsulePreviewPill: View {
    let expanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: expanded ? "waveform.circle.fill" : "capsule.fill")
                .font(.system(size: expanded ? 18 : 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(expanded ? "灵动胶囊展开态" : "灵动胶囊收缩态")
                    .font(.system(size: 13, weight: .semibold))
                Text(expanded ? "显示更多快捷动作" : "支持拖拽与联动")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
            }
            if expanded {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                    Image(systemName: "mic")
                    Image(systemName: "calendar")
                }
                .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(width: expanded ? 208 : 184, height: expanded ? 68 : 60, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: expanded ? 32 : 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: expanded ? 32 : 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CapsuleCompactPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text("灵动胶囊收缩态")
                    .font(.system(size: 11.5, weight: .semibold))
                Text("桌面入口")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))
            }
            Spacer(minLength: 0)
            Text("0:12")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 176, height: 38, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.98),
                    Color.black.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct PreviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CompanionSettingsDesign.quietText)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
