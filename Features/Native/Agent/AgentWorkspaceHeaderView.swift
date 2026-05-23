import SwiftUI

struct AgentWorkspaceHeaderView: View {
    @ObservedObject var viewModel: AgentWorkspaceViewModel
    @Binding var showsQuickAsk: Bool
    @Binding var showsProviderManager: Bool
    @Binding var showsAuxiliaryDrawer: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideHeader
            compactHeader
        }
    }

    private var wideHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            titleBlock

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ACBadge(viewModel.connectionStatusLabel, kind: viewModel.connectionStatusKind)
                ACBadge(viewModel.activeActionMode.displayName, kind: .blue)
                ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)
                actionButtonRow
            }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleBlock

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ACBadge(viewModel.connectionStatusLabel, kind: viewModel.connectionStatusKind)
                    ACBadge(viewModel.activeActionMode.displayName, kind: .blue)
                    ACBadge(viewModel.statusLabel, kind: viewModel.statusKind)
                    actionButtonRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agent")
                .font(ACTypography.pageTitle)
                .foregroundStyle(ACColors.primaryText)
                .lineLimit(1)

            Text("任务输入、执行反馈、工具入口和最近任务")
                .font(ACTypography.pageSubtitle)
                .foregroundStyle(ACColors.secondaryText)
                .lineLimit(2)
        }
    }

    private var actionButtonRow: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    showsQuickAsk.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Quick Ask")
                        .font(ACTypography.mini)
                }
                .foregroundStyle(ACColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(showsQuickAsk ? ACColors.selectedFill.opacity(0.8) : AcMindSurfaceTokens.primarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(showsQuickAsk ? ACColors.accentPurple.opacity(0.35) : AcMindSurfaceTokens.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showsProviderManager = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Provider 管理")
                        .font(ACTypography.mini)
                }
                .foregroundStyle(ACColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(AcMindSurfaceTokens.primarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                showsAuxiliaryDrawer.toggle()
            } label: {
                Image(systemName: showsAuxiliaryDrawer ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ACColors.primaryText)
                    .frame(width: 32, height: 32)
                    .background(AcMindSurfaceTokens.primarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AcMindSurfaceTokens.borderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
