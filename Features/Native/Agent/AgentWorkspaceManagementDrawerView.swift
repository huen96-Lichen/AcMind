import AppKit
import SwiftUI
import AcMindKit

struct AgentWorkspaceManagementDrawerView: View {
    @ObservedObject var viewModel: AgentWorkspaceViewModel
    @Binding var managementRailWidth: Double
    @Binding var managementRailCollapsed: Bool
    @Binding var railDragBaseWidth: Double?
    @Binding var folderRenameTarget: AgentProjectFolder?
    @Binding var showsAuxiliaryDrawer: Bool

    let width: CGFloat
    let isCompact: Bool

    var body: some View {
        managementRailShell
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: AcMindSurfaceTokens.panelCornerRadius, style: .continuous)
                    .fill(AcMindSurfaceTokens.secondarySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AcMindSurfaceTokens.panelCornerRadius, style: .continuous)
                    .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
            )
            .shadow(color: AcMindSurfaceTokens.shadowColor, radius: AcMindSurfaceTokens.shadowRadius, x: 0, y: AcMindSurfaceTokens.shadowYOffset)
    }
}
