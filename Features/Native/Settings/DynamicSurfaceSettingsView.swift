import SwiftUI

struct DynamicSurfaceSettingsView: View {
    var body: some View {
        DynamicSurfaceCommercialView()
    }
}

struct DynamicSurfaceCommercialView: View {
    @State private var selectedMode: SurfaceMode = .continent
    @State private var selectedContinentTabID: UUID = SurfaceContinentTab.mockTabs[0].id
    @State private var continentTabs: [SurfaceContinentTab] = SurfaceContinentTab.mockTabs
    @State private var selectedWidgetIDs: Set<String> = Set(SurfaceWidgetCatalog.capsuleWidgets.map(\.id) + SurfaceWidgetCatalog.continentWidgets.map(\.id))
    @State private var selectedFeatureIDs: Set<String> = Set(SurfaceFeatureCatalog.cards.filter(\.isEnabledByDefault).map(\.id))
    @State private var debugExpanded = false

    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "灵动设置",
                    subtitle: "统一配置桌面入口、大陆、联动和调试。"
                ) {
                    ACSegmentedControl(SurfaceMode.allCases, selection: $selectedMode) { mode, isSelected in
                        Text(mode.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                    }
                    .frame(width: 200)
                }
            },
            content: {
                firstRow
                secondRow
                featureRow
                debugBar
            }
        )
    }

    private var firstRow: some View {
        HStack(alignment: .top, spacing: ACLayout.gapL) {
            SurfaceSectionCard(
                title: "入口形态预览",
                subtitle: "胶囊两态 / 大陆收缩态"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    previewRow(
                        title: "胶囊收缩态",
                        subtitle: "桌面入口",
                        preview: SurfaceCapsuleCompactPreview()
                    )
                    previewRow(
                        title: "胶囊展开态",
                        subtitle: "快捷工具条",
                        preview: SurfaceCapsuleExpandedPreview()
                    )
                    previewRow(
                        title: "大陆收缩态",
                        subtitle: "顶部停靠",
                        preview: SurfaceContinentCompactPreview()
                    )
                }
            }

            SurfaceSectionCard(
                title: "大陆展开预览",
                subtitle: "当前板块与布局切换预览"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(continentTabs) { tab in
                            Button {
                                selectedContinentTabID = tab.id
                            } label: {
                                SurfaceCapsuleTag(title: tab.name, isSelected: selectedContinentTabID == tab.id)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 0)

                        Button {
                            let newTab = SurfaceContinentTab(
                                id: UUID(),
                                name: "自定义\(continentTabs.filter { !$0.isDefault }.count + 1)",
                                icon: "plus",
                                enabledModules: [
                                    SurfaceContinentModule(title: "日程"),
                                    SurfaceContinentModule(title: "快捷入口"),
                                    SurfaceContinentModule(title: "天气")
                                ],
                                isDefault: false
                            )
                            continentTabs.append(newTab)
                            selectedContinentTabID = newTab.id
                        } label: {
                            SurfaceCapsuleTag(title: "+ 新建", isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }

                    ContinentExpandedPreview(tab: selectedContinentTab)
                        .frame(height: 164)

                    HStack(spacing: 8) {
                        ACBadge("展开态", kind: .blue)
                        ACBadge("\(selectedContinentTab.enabledModules.count) 个模块", kind: .neutral)
                        ACBadge(selectedContinentTab.isDefault ? "默认板块" : "自定义板块", kind: .purple)
                        Spacer(minLength: 0)
                    }
                }
            }
            .layoutPriority(1)
        }
    }

    private var secondRow: some View {
        HStack(alignment: .top, spacing: ACLayout.gapL) {
            SurfaceSectionCard(
                title: "联动规则",
                subtitle: "桌面与顶部的四个核心开关"
            ) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    SurfaceRuleCard(
                        title: "启用胶囊",
                        subtitle: "桌面入口",
                        symbol: "capsule",
                        isOn: true
                    )
                    SurfaceRuleCard(
                        title: "启用大陆",
                        subtitle: "顶部入口",
                        symbol: "dock.top",
                        isOn: true
                    )
                    SurfaceRuleCard(
                        title: "拖到顶部切换",
                        subtitle: "胶囊 → 大陆",
                        symbol: "arrow.up.to.line.compact",
                        isOn: true
                    )
                    SurfaceRuleCard(
                        title: "长按回桌面",
                        subtitle: "大陆 → 胶囊",
                        symbol: "arrow.down.to.line.compact",
                        isOn: true
                    )
                }
            }

            SurfaceSectionCard(
                title: "组件选择",
                subtitle: "胶囊组件 / 大陆组件小胶囊选择"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    widgetGroup(
                        title: "胶囊组件",
                        count: SurfaceWidgetCatalog.capsuleWidgets.filter { selectedWidgetIDs.contains($0.id) }.count,
                        items: SurfaceWidgetCatalog.capsuleWidgets
                    )

                    widgetGroup(
                        title: "大陆组件",
                        count: SurfaceWidgetCatalog.continentWidgets.filter { selectedWidgetIDs.contains($0.id) }.count,
                        items: SurfaceWidgetCatalog.continentWidgets
                    )
                }
            }

            SurfaceSectionCard(
                title: "板块管理",
                subtitle: "大陆展开态的板块与内容"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(continentTabs) { tab in
                        Button {
                            selectedContinentTabID = tab.id
                        } label: {
                            SurfaceBlockRow(tab: tab, isSelected: selectedContinentTabID == tab.id)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    ACButton("新建板块", kind: .secondary) {
                        let newTab = SurfaceContinentTab(
                            id: UUID(),
                            name: "专注工作",
                            icon: "target",
                            enabledModules: [
                                SurfaceContinentModule(title: "日程"),
                                SurfaceContinentModule(title: "快捷入口"),
                                SurfaceContinentModule(title: "天气")
                            ],
                            isDefault: false
                        )
                        continentTabs.append(newTab)
                        selectedContinentTabID = newTab.id
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var featureRow: some View {
        SurfaceSectionCard(
            title: "功能模块",
            subtitle: "AcMind 自有能力模块"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("已启用 \(selectedFeatureIDs.count) 个模块")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.secondaryText)
                    Spacer(minLength: 0)
                    ACBadge("商用级", kind: .green)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                    spacing: 12
                ) {
                    ForEach(SurfaceFeatureCatalog.cards) { card in
                        SurfaceFeatureTile(card: card, isEnabled: selectedFeatureIDs.contains(card.id)) {
                            if selectedFeatureIDs.contains(card.id) {
                                selectedFeatureIDs.remove(card.id)
                            } else {
                                selectedFeatureIDs.insert(card.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var debugBar: some View {
        ACCard(padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ACColors.accentBlue)
                    Text("高级调试")
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                }

                Divider()
                    .frame(height: 18)

                Text("当前模式：\(selectedMode.title)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)

                Text("当前板块：\(selectedContinentTab.name)")
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    debugExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(debugExpanded ? "收起" : "展开")
                        Image(systemName: debugExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.accentBlue)

                ACBadge("LIVE", kind: .blue)
            }
        }
        .frame(height: 56)
    }

    private var selectedContinentTab: SurfaceContinentTab {
        continentTabs.first(where: { $0.id == selectedContinentTabID }) ?? continentTabs[0]
    }

    private func previewRow(title: String, subtitle: String, preview: some View) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text(subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            preview
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ACColors.softFill, in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }

    private func widgetGroup(title: String, count: Int, items: [SurfaceWidgetItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                Text("已启用 \(count) 个")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                ForEach(items) { item in
                    Button {
                        if selectedWidgetIDs.contains(item.id) {
                            selectedWidgetIDs.remove(item.id)
                        } else {
                            selectedWidgetIDs.insert(item.id)
                        }
                    } label: {
                        SurfaceWidgetChip(item: item, isSelected: selectedWidgetIDs.contains(item.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SurfaceSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let width: CGFloat?
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.minWidth = minWidth
        self.minHeight = height
        self.content = content()
    }

    var body: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                content

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: width, alignment: .topLeading)
        .frame(minWidth: minWidth, alignment: .topLeading)
        .frame(minHeight: minHeight, alignment: .topLeading)
    }
}

private struct SurfaceCapsuleTag: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(ACTypography.captionMedium)
            .foregroundStyle(isSelected ? .white : ACColors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? ACColors.blackCapsule : Color.white.opacity(0.0), in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? ACColors.blackCapsule : ACColors.border, lineWidth: 1)
            )
    }
}

private struct SurfaceRuleCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ACTypeIcon(symbol, tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)
            }

            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .tint(ACColors.accentBlue)
                .allowsHitTesting(false)

            Text(isOn ? "已启用" : "未启用")
                .font(ACTypography.miniMedium)
                .foregroundStyle(isOn ? ACColors.accentBlue : ACColors.secondaryText)
        }
        .padding(12)
        .frame(minHeight: 118, alignment: .topLeading)
        .background(Color.white.opacity(0.0), in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

private struct SurfaceWidgetChip: View {
    let item: SurfaceWidgetItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(item.title)
                .font(ACTypography.miniMedium)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? .white : ACColors.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(isSelected ? ACColors.blackCapsule : ACColors.softFill, in: Capsule())
        .overlay(
            Capsule().stroke(isSelected ? ACColors.blackCapsule : ACColors.border, lineWidth: 1)
        )
    }
}

private struct SurfaceBlockRow: View {
    let tab: SurfaceContinentTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            ACTypeIcon(tab.icon, tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText, background: isSelected ? ACColors.selectedFill : ACColors.softFill, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.name)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
                Text("\(tab.enabledModules.count) 个模块")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ACColors.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(isSelected ? ACColors.selectedFill.opacity(0.6) : Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

private struct SurfaceFeatureTile: View {
    let card: SurfaceFeatureCard
    let isEnabled: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.primaryText)
                            .lineLimit(1)
                        Text(card.subtitle)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    ACBadge(isEnabled ? "已启用" : "待启用", kind: isEnabled ? .green : .neutral)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(isEnabled ? ACColors.selectedFill.opacity(0.6) : Color.white.opacity(0.0))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(isEnabled ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SurfaceCapsuleCompactPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 8, height: 8)
            Text("AcMind")
                .font(ACTypography.captionMedium)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Circle()
                .fill(ACColors.accentBlue)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 120, height: 34)
        .background(ACColors.blackCapsule, in: Capsule())
    }
}

private struct SurfaceCapsuleExpandedPreview: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "qrcode.viewfinder")
            Image(systemName: "camera")
            Image(systemName: "waveform")
            Image(systemName: "clipboard")
            Image(systemName: "ellipsis")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(ACColors.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 180, height: 40)
        .background(Color.white.opacity(0.0), in: Capsule())
        .overlay(Capsule().stroke(ACColors.border, lineWidth: 1))
    }
}

private struct SurfaceContinentCompactPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("AcMind")
                    .font(ACTypography.captionMedium)
                Text("正在运行")
                    .font(ACTypography.mini)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            Spacer(minLength: 0)
            Circle()
                .fill(ACColors.accentGreen)
                .frame(width: 7, height: 7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 150, height: 38)
        .background(ACColors.blackCapsule, in: Capsule())
    }
}

private struct ContinentExpandedPreview: View {
    let tab: SurfaceContinentTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ACColors.blackCapsule, ACColors.darkCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 10, height: 10)
                        Text(tab.name)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    ACBadge("LIVE", kind: .blue)
                }

                HStack(spacing: 8) {
                    miniPane(title: "左", value: tab.enabledModules.first?.title ?? "—")
                    miniPane(title: "中", value: tab.enabledModules.dropFirst().first?.title ?? "—")
                    miniPane(title: "右", value: tab.enabledModules.dropFirst(2).first?.title ?? "—")
                }

                HStack(spacing: 6) {
                    ForEach(tab.enabledModules.prefix(5)) { module in
                        Text(module.title)
                            .font(ACTypography.miniMedium)
                            .foregroundStyle(Color.white.opacity(0.90))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Text(tab.summary)
                        .font(ACTypography.mini)
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func miniPane(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ACTypography.mini)
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

private enum SurfaceMode: String, CaseIterable, Identifiable {
    case capsuleDesktop = "桌面胶囊"
    case continent = "顶部大陆"
    case config = "配置中心"

    var id: String { rawValue }
    var title: String { rawValue }
}

private struct SurfaceWidgetItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
}

private struct SurfaceFeatureCard: Identifiable {
    enum Tier {
        case free, pro, beta

        var tint: Color {
            switch self {
            case .free: return ACColors.accentGreen
            case .pro: return ACColors.accentBlue
            case .beta: return ACColors.accentOrange
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let isEnabledByDefault: Bool
}

private struct SurfaceWidgetCatalog {
    static let capsuleWidgets: [SurfaceWidgetItem] = [
        .init(id: "capsule-status", title: "状态", symbol: "sparkles"),
        .init(id: "capsule-sound", title: "语音", symbol: "waveform"),
        .init(id: "capsule-capture", title: "捕获", symbol: "camera"),
        .init(id: "capsule-note", title: "笔记", symbol: "doc.text"),
        .init(id: "capsule-sync", title: "同步", symbol: "arrow.triangle.2.circlepath"),
        .init(id: "capsule-focus", title: "专注", symbol: "moon.stars")
    ]

    static let continentWidgets: [SurfaceWidgetItem] = [
        .init(id: "continent-timeline", title: "日程", symbol: "calendar"),
        .init(id: "continent-agent", title: "Agent", symbol: "bubble.left.and.bubble.right"),
        .init(id: "continent-task", title: "任务", symbol: "checklist"),
        .init(id: "continent-weather", title: "天气", symbol: "cloud.sun"),
        .init(id: "continent-notes", title: "知识", symbol: "books.vertical"),
        .init(id: "continent-media", title: "媒体", symbol: "music.note")
    ]
}

private struct SurfaceFeatureCatalog {
    static let cards: [SurfaceFeatureCard] = [
        .init(id: "feature-agent", title: "Agent", subtitle: "任务与响应", symbol: "sparkles", tint: ACColors.accentBlue, isEnabledByDefault: true),
        .init(id: "feature-voice", title: "语音", subtitle: "快捷转写", symbol: "waveform", tint: ACColors.accentPurple, isEnabledByDefault: true),
        .init(id: "feature-capture", title: "捕获", subtitle: "截图 / 剪贴板", symbol: "camera", tint: ACColors.accentOrange, isEnabledByDefault: true),
        .init(id: "feature-schedule", title: "日程", subtitle: "时间线联动", symbol: "calendar", tint: ACColors.accentGreen, isEnabledByDefault: true),
        .init(id: "feature-notes", title: "知识", subtitle: "Markdown / Obsidian", symbol: "books.vertical", tint: ACColors.accentTeal, isEnabledByDefault: true)
    ]
}

private struct SurfaceContinentModule: Identifiable {
    let id = UUID()
    let title: String
}

private struct SurfaceContinentTab: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var enabledModules: [SurfaceContinentModule]
    var isDefault: Bool

    var summary: String {
        "今日 · " + enabledModules.prefix(3).map(\.title).joined(separator: " / ")
    }

    static let mockTabs: [SurfaceContinentTab] = [
        .init(
            id: UUID(),
            name: "今日",
            icon: "sun.max",
            enabledModules: [
                SurfaceContinentModule(title: "日程"),
                SurfaceContinentModule(title: "天气"),
                SurfaceContinentModule(title: "任务"),
                SurfaceContinentModule(title: "消息")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "音乐",
            icon: "music.note",
            enabledModules: [
                SurfaceContinentModule(title: "播放"),
                SurfaceContinentModule(title: "歌单"),
                SurfaceContinentModule(title: "歌词")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "AI",
            icon: "sparkles",
            enabledModules: [
                SurfaceContinentModule(title: "状态"),
                SurfaceContinentModule(title: "任务"),
                SurfaceContinentModule(title: "快捷入口"),
                SurfaceContinentModule(title: "参考")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "日程",
            icon: "calendar",
            enabledModules: [
                SurfaceContinentModule(title: "日历"),
                SurfaceContinentModule(title: "时间线"),
                SurfaceContinentModule(title: "提醒")
            ],
            isDefault: true
        )
    ]
}
