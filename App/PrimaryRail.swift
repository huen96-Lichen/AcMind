import SwiftUI
import AppKit
import AcMindKit

struct PrimaryRail: View {
    @Binding var primaryRailWidth: CGFloat
    @Binding var workspaceMode: WorkspaceMode
    @Binding var selectedItem: SidebarItem

    let onToggleSecondaryInterface: () -> Void
    let forceCompactContent: Bool

    @State private var hoveredItem: SidebarItem?
    @State private var hoveredFooter = false
    @State private var hoverResizeHandle = false
    @State private var dragAnchorWidth: CGFloat?

    init(
        primaryRailWidth: Binding<CGFloat>,
        workspaceMode: Binding<WorkspaceMode>,
        selectedItem: Binding<SidebarItem>,
        onToggleSecondaryInterface: @escaping () -> Void,
        forceCompactContent: Bool = false
    ) {
        self._primaryRailWidth = primaryRailWidth
        self._workspaceMode = workspaceMode
        self._selectedItem = selectedItem
        self.onToggleSecondaryInterface = onToggleSecondaryInterface
        self.forceCompactContent = forceCompactContent
    }

    private var isSecondaryOpen: Bool {
        workspaceMode == .visible
    }

    private enum RailMode {
        case compact
        case expanded

        var shellPadding: CGFloat {
            0
        }

        var sectionSpacing: CGFloat {
            switch self {
            case .compact: return 4
            case .expanded: return 6
            }
        }

        var contentPaddingX: CGFloat {
            switch self {
            case .compact: return 0
            case .expanded: return 2
            }
        }

        var contentPaddingY: CGFloat {
            switch self {
            case .compact: return 4
            case .expanded: return 6
            }
        }

        var brandSpacing: CGFloat {
            switch self {
            case .compact: return 0
            case .expanded: return 10
            }
        }

        var brandGlyphSize: CGFloat {
            switch self {
            case .compact: return 30
            case .expanded: return 36
            }
        }

        var brandGlyphFontSize: CGFloat {
            switch self {
            case .compact: return 16
            case .expanded: return 20
            }
        }

        var brandTitleFontSize: CGFloat {
            15.5
        }

        var brandSubtitleFontSize: CGFloat {
            10.5
        }

        var footerVerticalPadding: CGFloat {
            switch self {
            case .compact: return 2
            case .expanded: return 1
            }
        }

        var footerButtonHeight: CGFloat {
            switch self {
            case .compact: return ACLayout.primaryRailNavItemHeight
            case .expanded: return ACLayout.primaryRailFooterHeight
            }
        }

        var footerButtonAlignment: Alignment {
            switch self {
            case .compact: return .center
            case .expanded: return .leading
            }
        }

        var showFooterMetadata: Bool {
            self == .expanded
        }
    }

    private var railMode: RailMode {
        if forceCompactContent {
            return .compact
        }
        return primaryRailWidth >= ACLayout.primaryRailLabelThreshold ? RailMode.expanded : RailMode.compact
    }

    private var showsLabels: Bool {
        railMode == .expanded
    }

    private var railCornerRadius: CGFloat {
        AcMindSurfaceTokens.workspaceCornerRadius
    }

    private var railShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: railCornerRadius, style: .continuous)
    }

    private var appVersionShortDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.2"
        return "v\(version)"
    }

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) · build \(build)"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            railSurface
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var railSurface: some View {
        VStack(spacing: 0) {
            railTopChrome
            Divider()
                .overlay(AcMindSurfaceTokens.borderColor)

            railMiddleSurface

            railFooter
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, railMode.shellPadding)
        .padding(.horizontal, railMode.shellPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var railMiddleSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ACColors.pageBackground)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: railMode.sectionSpacing) {
                    navItemsColumn
                }
                .padding(.horizontal, railMode.contentPaddingX)
                .padding(.vertical, railMode.contentPaddingY)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var railTopChrome: some View {
        VStack(spacing: 0) {
            railBrandCard
                .padding(.top, railMode == .compact ? 2 : 3)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var railBrandCard: some View {
        HStack(alignment: .center, spacing: railMode.brandSpacing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ACColors.accentBlue.opacity(0.16),
                            ACColors.accentBlue.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: railMode.brandGlyphSize, height: railMode.brandGlyphSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ACColors.accentBlue.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: railMode.brandGlyphFontSize, weight: .semibold))
                        .foregroundStyle(ACColors.accentBlue)
                )

            if showsLabels {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AcMind")
                        .font(.system(size: railMode.brandTitleFontSize, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)

                    Text("灵动设置")
                        .font(.system(size: railMode.brandSubtitleFontSize, weight: .medium))
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(height: ACLayout.primaryRailBrandHeight)
        .padding(.horizontal, showsLabels ? 10 : 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(showsLabels ? 0.84 : 0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AcMindSurfaceTokens.borderColor.opacity(showsLabels ? 0.9 : 0.7), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }

    private var navItemsColumn: some View {
        VStack(spacing: 1) {
            ForEach(SidebarItem.primaryNavItems) { item in
                PrimaryNavItem(
                    item: item,
                    isSelected: selectedItem == item,
                    showsLabels: showsLabels,
                    isHovered: hoveredItem == item,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedItem = item
                        }
                    }
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredItem = hovering ? item : nil
                    }
                }
            }
        }
        .frame(width: AcMindSurfaceTokens.sidebarInnerRailWidth, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var railFooter: some View {
        SidebarFooterPanel(
            isSecondaryOpen: isSecondaryOpen,
            showsLabels: showsLabels,
            appVersionShortDisplay: appVersionShortDisplay,
            appVersionDisplay: appVersionDisplay,
            onToggleSecondaryInterface: onToggleSecondaryInterface,
            primaryRailWidth: $primaryRailWidth,
            hoverResizeHandle: $hoverResizeHandle,
            dragAnchorWidth: $dragAnchorWidth
        )
        .frame(width: AcMindSurfaceTokens.sidebarInnerRailWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SidebarFooterPanel: View {
    let isSecondaryOpen: Bool
    let showsLabels: Bool
    let appVersionShortDisplay: String
    let appVersionDisplay: String
    let onToggleSecondaryInterface: () -> Void
    @Binding var primaryRailWidth: CGFloat
    @Binding var hoverResizeHandle: Bool
    @Binding var dragAnchorWidth: CGFloat?

    private var footerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSecondaryOpen ? ACColors.accentGreen : ACColors.accentYellow)
                    .frame(width: 6, height: 6)

                if showsLabels {
                    Text(isSecondaryOpen ? "二级界面打开" : "二级界面关闭")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ACColors.tertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(appVersionDisplay)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                } else {
                    Text(appVersionShortDisplay)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.black.opacity(0.06))

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onToggleSecondaryInterface()
                }
            }) {
                HStack(spacing: showsLabels ? 8 : 0) {
                    Image(systemName: isSecondaryOpen ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ACColors.secondaryText)
                        .frame(width: 18, height: 18)

                    if showsLabels {
                        Text(isSecondaryOpen ? "二级界面关闭" : "二级界面打开")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(ACColors.quaternaryText)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 32)
                .frame(maxWidth: .infinity, alignment: showsLabels ? .leading : .center)
                .padding(.horizontal, showsLabels ? 8 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            footerResizeHandle
        }
        .padding(8)
        .frame(width: AcMindSurfaceTokens.sidebarInnerRailWidth)
        .background(
            footerShape
                .fill(Color.black.opacity(0.025))
        )
        .overlay(
            footerShape
                .stroke(Color.black.opacity(0.055), lineWidth: 1)
        )
        .clipShape(footerShape)
        .padding(.bottom, 10)
    }

    private var footerResizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragAnchorWidth == nil {
                            dragAnchorWidth = primaryRailWidth
                        }
                        guard let dragAnchorWidth else { return }
                        let nextWidth = dragAnchorWidth + value.translation.width
                        primaryRailWidth = min(max(nextWidth, ACLayout.primaryRailCompact), ACLayout.primaryRailMaxWidth)
                    }
                    .onEnded { _ in
                        dragAnchorWidth = nil
                    }
            )
            .onHover { hovering in
                hoverResizeHandle = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(alignment: .center) {
                Capsule()
                    .fill(hoverResizeHandle ? ACColors.accentBlue.opacity(0.28) : ACColors.border.opacity(0.42))
                    .frame(width: 18, height: 3)
            }
    }
}
