import SwiftUI
import AcMindKit

struct ContinentConfigCenterView: View {
    @AppStorage("AppSettings.notchPanelEnabled") private var notchPanelEnabled: Bool = true
    @State private var capsuleSettings: DesktopCapsuleSettings = .default
    @ObservedObject private var coordinator = DynamicSurfaceCoordinator.shared
    @State private var selectedHeaderSurface: String = "capsule"
    @State private var selectedWidgetIDs: Set<String> = Set(
        CompanionWidgetCatalog.capsuleWidgets.filter(\.isEnabled).map(\.id) +
            CompanionWidgetCatalog.continentWidgets.filter(\.isEnabled).map(\.id)
    )
    @State private var enabledFeatureIDs: Set<String> = Set(
        CompanionFeatureCatalog.cards.filter(\.isEnabledByDefault).map(\.id)
    )
    @State private var continentTabs: [CompanionContinentPreviewTab] = Self.defaultContinentTabs
    @State private var selectedContinentTabID: UUID = Self.defaultContinentTabs.first?.id ?? UUID()
    @State private var debugDisclosureExpanded = false
    @State private var linkageCapsuleToContinent = true
    @State private var linkageContinentToCapsule = true
    
    private static let defaultContinentTabs: [CompanionContinentPreviewTab] = [
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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ContinentConfigLayout.gridGap) {
                ContinentConfigHeaderView(
                    selectedSurface: $selectedHeaderSurface
                )
                .frame(height: ContinentConfigLayout.headerHeight)
                
                HStack(alignment: .top, spacing: ContinentConfigLayout.gridGap) {
                    CapsuleShapePreviewCard()
                        .frame(width: ContinentConfigLayout.previewLeftWidth, height: ContinentConfigLayout.firstRowHeight)
                    ContinentExpandedPreviewCard(
                        tabs: $continentTabs,
                        selectedTabID: $selectedContinentTabID
                    )
                    .frame(minWidth: 660, maxWidth: .infinity)
                    .frame(height: ContinentConfigLayout.firstRowHeight)
                }
                
                HStack(alignment: .top, spacing: ContinentConfigLayout.gridGap) {
                    LinkRulesCard(
                        capsuleEnabled: $capsuleSettings.isEnabled,
                        continentEnabled: $notchPanelEnabled,
                        capsuleToContinentEnabled: $linkageCapsuleToContinent,
                        continentToCapsuleEnabled: $linkageContinentToCapsule
                    )
                    .frame(width: ContinentConfigLayout.linkRulesWidth, height: ContinentConfigLayout.secondRowHeight)
                    
                    ComponentSelectionCard(selectedWidgetIDs: $selectedWidgetIDs)
                        .frame(width: ContinentConfigLayout.componentSelectionWidth, height: ContinentConfigLayout.secondRowHeight)
                    
                    BlockManagementCard(
                        tabs: $continentTabs,
                        selectedTabID: $selectedContinentTabID
                    )
                    .frame(width: ContinentConfigLayout.blockManagerWidth, height: ContinentConfigLayout.secondRowHeight)
                }
                
                FunctionModulesCard(enabledFeatureIDs: $enabledFeatureIDs)
                    .frame(height: ContinentConfigLayout.functionModuleHeight)
                
                AdvancedDebugBar(
                    coordinator: coordinator,
                    capsulePosition: capsulePositionLabel,
                    continentScreen: continentScreenLabel,
                    launchSurface: selectedHeaderSurface,
                    debugDisclosureExpanded: $debugDisclosureExpanded
                )
                .frame(height: ContinentConfigLayout.debugBarHeight)
            }
            .padding(.leading, ContinentConfigLayout.mainPaddingX)
            .padding(.trailing, ContinentConfigLayout.mainPaddingX)
            .padding(.top, ContinentConfigLayout.mainPaddingTop)
            .padding(.bottom, ContinentConfigLayout.mainPaddingBottom)
        }
        .background(ContinentConfigTokens.pageBackground)
        .onAppear {
            loadCapsuleSettings()
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
}
