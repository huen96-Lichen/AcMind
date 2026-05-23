import AppKit
import SwiftUI
import AcMindKit

extension DynamicSurfaceCommercialView {
    var secondRow: some View {
        VStack(alignment: .leading, spacing: ACLayout.gapL) {
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
                .frame(maxWidth: .infinity, alignment: .topLeading)

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
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

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

    var featureRow: some View {
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

    var secondRowCompact: some View {
        VStack(alignment: .leading, spacing: ACLayout.gapL) {
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
                    SurfaceRuleCard(title: "启用胶囊", subtitle: "桌面入口", symbol: "capsule", isOn: true)
                    SurfaceRuleCard(title: "启用大陆", subtitle: "顶部入口", symbol: "dock.top", isOn: true)
                    SurfaceRuleCard(title: "拖到顶部切换", subtitle: "胶囊 → 大陆", symbol: "arrow.up.to.line.compact", isOn: true)
                    SurfaceRuleCard(title: "长按回桌面", subtitle: "大陆 → 胶囊", symbol: "arrow.down.to.line.compact", isOn: true)
                }
            }

            SurfaceSectionCard(
                title: "组件选择",
                subtitle: "胶囊组件 / 大陆组件小胶囊选择"
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    widgetGroup(title: "胶囊组件", count: SurfaceWidgetCatalog.capsuleWidgets.filter { selectedWidgetIDs.contains($0.id) }.count, items: SurfaceWidgetCatalog.capsuleWidgets, columns: 3)
                    widgetGroup(title: "大陆组件", count: SurfaceWidgetCatalog.continentWidgets.filter { selectedWidgetIDs.contains($0.id) }.count, items: SurfaceWidgetCatalog.continentWidgets, columns: 3)
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

    var featureRowCompact: some View {
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
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
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

}
