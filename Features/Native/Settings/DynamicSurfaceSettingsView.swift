import AppKit
import SwiftUI
import AcMindKit

struct DynamicSurfaceSettingsView: View {
    var body: some View {
        DynamicSurfaceCommercialView()
    }
}

struct DynamicSurfaceCommercialView: View {
    @ObservedObject var coordinator = DynamicSurfaceCoordinator.shared
    @State var selectedMode: SurfaceMode = .continent
    @State var selectedContinentTabID: UUID = DynamicSurfaceSettingsStorage.loadSelectedContinentTabID(default: SurfaceContinentTab.mockTabs[0].id)
    @State var continentTabs: [SurfaceContinentTab] = DynamicSurfaceSettingsStorage.loadContinentTabs(default: SurfaceContinentTab.mockTabs)
    @State var selectedWidgetIDs: Set<String> = DynamicSurfaceSettingsStorage.loadSelectedWidgetIDs(default: Set(SurfaceWidgetCatalog.capsuleWidgets.map(\.id) + SurfaceWidgetCatalog.continentWidgets.map(\.id)))
    @State var selectedFeatureIDs: Set<String> = DynamicSurfaceSettingsStorage.loadSelectedFeatureIDs(default: Set(SurfaceFeatureCatalog.cards.filter(\.isEnabledByDefault).map(\.id)))
    @State var debugExpanded = false
    @State private var didBootstrapSelection = false

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
                    .frame(width: 256)
                }
            },
            content: { width in
                let isCompact = width < ACLayout.Breakpoint.compact

                VStack(alignment: .leading, spacing: ACLayout.gapL) {
                    if isCompact {
                        firstRowCompact
                        monitorRowCompact
                        secondRowCompact
                        featureRowCompact
                    } else {
                        firstRow
                        monitorRow
                        secondRow
                        featureRow
                    }

                    debugBar
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        )
        .onAppear {
            guard !didBootstrapSelection else { return }
            didBootstrapSelection = true

            if !continentTabs.contains(where: { $0.id == selectedContinentTabID }),
               let first = continentTabs.first {
                selectedContinentTabID = first.id
            }
        }
        .onChange(of: continentTabs) {
            DynamicSurfaceSettingsStorage.saveContinentTabs(continentTabs)
            if !continentTabs.contains(where: { $0.id == selectedContinentTabID }),
               let first = continentTabs.first {
                selectedContinentTabID = first.id
            }
        }
        .onChange(of: selectedContinentTabID) {
            DynamicSurfaceSettingsStorage.saveSelectedContinentTabID(selectedContinentTabID)
        }
        .onChange(of: selectedWidgetIDs) {
            DynamicSurfaceSettingsStorage.saveSelectedWidgetIDs(selectedWidgetIDs)
        }
        .onChange(of: selectedFeatureIDs) {
            DynamicSurfaceSettingsStorage.saveSelectedFeatureIDs(selectedFeatureIDs)
        }
    }
}
