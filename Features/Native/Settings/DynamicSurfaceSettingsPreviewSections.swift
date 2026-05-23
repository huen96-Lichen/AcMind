import AppKit
import SwiftUI
import AcMindKit

extension DynamicSurfaceCommercialView {
    var firstRow: some View {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)

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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var monitorRow: some View {
        HStack(alignment: .top, spacing: ACLayout.gapL) {
            SurfaceSectionCard(
                title: "胶囊显示器",
                subtitle: "指定桌面胶囊默认出现的显示器"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SurfaceMonitorHintRow(
                        title: "当前设置",
                        value: preferredScreenLabel(for: coordinator.preferredCapsuleScreenID)
                    )

                    monitorButtons(
                        selectedScreenID: coordinator.preferredCapsuleScreenID,
                        onFollowCurrent: { coordinator.setPreferredCapsuleScreenID(nil) },
                        onSelect: { coordinator.setPreferredCapsuleScreenID($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            SurfaceSectionCard(
                title: "大陆显示器",
                subtitle: "指定顶部大陆默认出现的显示器"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SurfaceMonitorHintRow(
                        title: "当前设置",
                        value: preferredScreenLabel(for: coordinator.preferredContinentScreenID)
                    )

                    monitorButtons(
                        selectedScreenID: coordinator.preferredContinentScreenID,
                        onFollowCurrent: { coordinator.setPreferredContinentScreenID(nil) },
                        onSelect: { coordinator.setPreferredContinentScreenID($0) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var firstRowCompact: some View {
        VStack(alignment: .leading, spacing: ACLayout.gapL) {
            SurfaceSectionCard(
                title: "入口形态预览",
                subtitle: "胶囊两态 / 大陆收缩态"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    previewRow(title: "胶囊收缩态", subtitle: "桌面入口", preview: SurfaceCapsuleCompactPreview())
                    previewRow(title: "胶囊展开态", subtitle: "快捷工具条", preview: SurfaceCapsuleExpandedPreview())
                    previewRow(title: "大陆收缩态", subtitle: "顶部停靠", preview: SurfaceContinentCompactPreview())
                }
            }

            SurfaceSectionCard(
                title: "大陆展开预览",
                subtitle: "当前板块与布局切换预览"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(continentTabs) { tab in
                                Button {
                                    selectedContinentTabID = tab.id
                                } label: {
                                    SurfaceCapsuleTag(title: tab.name, isSelected: selectedContinentTabID == tab.id)
                                }
                                .buttonStyle(.plain)
                            }

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
        }
    }

    var monitorRowCompact: some View {
        VStack(alignment: .leading, spacing: ACLayout.gapL) {
            SurfaceSectionCard(
                title: "胶囊显示器",
                subtitle: "指定桌面胶囊默认出现的显示器"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SurfaceMonitorHintRow(
                        title: "当前设置",
                        value: preferredScreenLabel(for: coordinator.preferredCapsuleScreenID)
                    )

                    monitorButtons(
                        selectedScreenID: coordinator.preferredCapsuleScreenID,
                        onFollowCurrent: { coordinator.setPreferredCapsuleScreenID(nil) },
                        onSelect: { coordinator.setPreferredCapsuleScreenID($0) }
                    )
                }
            }

            SurfaceSectionCard(
                title: "大陆显示器",
                subtitle: "指定顶部大陆默认出现的显示器"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SurfaceMonitorHintRow(
                        title: "当前设置",
                        value: preferredScreenLabel(for: coordinator.preferredContinentScreenID)
                    )

                    monitorButtons(
                        selectedScreenID: coordinator.preferredContinentScreenID,
                        onFollowCurrent: { coordinator.setPreferredContinentScreenID(nil) },
                        onSelect: { coordinator.setPreferredContinentScreenID($0) }
                    )
                }
            }
        }
    }

    var selectedContinentTab: SurfaceContinentTab {
        continentTabs.first(where: { $0.id == selectedContinentTabID }) ?? continentTabs[0]
    }

    func preferredScreenLabel(for screenID: String?) -> String {
        guard let screenID else { return "跟随当前屏幕" }
        return NSScreen.screens.first(where: { $0.displayID == screenID })?.displayName ?? "已保存但当前未连接"
    }

    func monitorButtons(
        selectedScreenID: String?,
        onFollowCurrent: @escaping () -> Void,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onFollowCurrent()
            } label: {
                SurfaceMonitorButtonRow(
                    title: "跟随当前屏幕",
                    subtitle: "由当前显示器或位置决定",
                    isSelected: selectedScreenID == nil
                )
            }
            .buttonStyle(.plain)

            ForEach(NSScreen.screens, id: \.displayID) { screen in
                Button {
                    onSelect(screen.displayID)
                } label: {
                    SurfaceMonitorButtonRow(
                        title: screen.displayName,
                        subtitle: screen.detailLabel,
                        isSelected: selectedScreenID == screen.displayID
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func previewRow(title: String, subtitle: String, preview: some View) -> some View {
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
}
