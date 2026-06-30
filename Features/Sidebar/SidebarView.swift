import SwiftUI
import AcMindKit

// MARK: - Sidebar View

/// 侧边栏导航视图
/// 使用固定宽度的自绘布局，避免 macOS sidebar 样式在窗口变窄时自动折叠成图标栏。
struct SidebarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: ServiceContainer
    @State private var hoveredItem: SidebarItem?
    @State private var isSettingsHovered = false
    @State private var footerStatus: SidebarFooterStatus = .loading
    @State private var capabilityStatuses: [SidebarItem: SidebarCapabilityState] = [:]

    var body: some View {
        sidebarContent(isCollapsed: appState.sidebarCollapsed)
        .frame(
            width: appState.sidebarCollapsed
                ? AppSurfaceTokens.Layout.sidebarCollapsedWidth
                : AppSurfaceTokens.Layout.sidebarWidth,
            alignment: .topLeading
        )
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(sidebarBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主侧边栏")
        .accessibilitySortPriority(100)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppSurfaceTokens.separator.opacity(0.55))
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .onAppear {
            setupKeyboardShortcuts()
            refreshCapabilityStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            Task { await refreshFooterStatus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionConfigurationDidChange)) { _ in
            refreshCapabilityStatuses()
        }
    }

    private var sidebarBackground: some View {
        ZStack {
            AppSurfaceTokens.sidebarBackground
            LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.screen)
        }
    }

    private func sidebarContent(isCollapsed: Bool) -> some View {
        VStack(spacing: 0) {
            sidebarBrandHeader(isCollapsed: isCollapsed)
            Divider().overlay(AppSurfaceTokens.separator.opacity(0.55))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    sidebarSection(title: SidebarItem.Group.coreWorkflow.displayName, items: SidebarItem.coreWorkflow, isCollapsed: isCollapsed)
                    sidebarSection(title: SidebarItem.Group.companionCapabilities.displayName, items: SidebarItem.companionCapabilities, isCollapsed: isCollapsed)
                    sidebarSection(title: SidebarItem.Group.system.displayName, items: SidebarItem.systemItems, isCollapsed: isCollapsed)
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider().overlay(AppSurfaceTokens.separator.opacity(0.55))
            sidebarFooter(isCollapsed: isCollapsed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sidebarBrandHeader(isCollapsed: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: toggleSidebar) {
                SidebarLogoMarkView()
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
            }
            .frame(width: 36, height: 28)
            .buttonStyle(SidebarPressableButtonStyle())
            .help(isCollapsed ? "展开侧边栏" : "AcWork")
            .accessibilityLabel(isCollapsed ? "展开侧边栏" : "AcWork")

            if !isCollapsed {
                Text(AcWorkBrand.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: 0)

            if !isCollapsed {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(SidebarPressableButtonStyle())
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackground.opacity(0.72))
                )
                .help("折叠侧边栏")
                .accessibilityLabel("折叠侧边栏")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func sidebarSection(title: String, items: [SidebarItem], isCollapsed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .opacity(isCollapsed ? 0 : 1)
                .accessibilityHidden(isCollapsed)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    sidebarButton(for: item, isCollapsed: isCollapsed)
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarButton(for item: SidebarItem, isCollapsed: Bool) -> some View {
        Button {
            appState.navigate(to: item)
        } label: {
            if isCollapsed {
                SidebarCompactItemRow(
                    item: item,
                    isSelected: appState.sidebarSelection == item,
                    isHovered: effectiveHoveredItem == item
                )
            } else {
                SidebarItemRow(
                    item: item,
                    isSelected: appState.sidebarSelection == item,
                    isHovered: effectiveHoveredItem == item,
                    capabilityState: capabilityState(for: item)
                )
            }
        }
        .buttonStyle(SidebarPressableButtonStyle())
        .onHover { isHovered in
            withAnimation(hoverAnimation) {
                hoveredItem = isHovered ? item : nil
            }
        }
    }

    private var effectiveHoveredItem: SidebarItem? {
#if DEBUG
        if let forcedItem = DebugSidebarPreviewState.forcedHoverItem {
            return forcedItem
        }
#endif
        return hoveredItem
    }

    private var effectiveSettingsHovered: Bool {
#if DEBUG
        if DebugSidebarPreviewState.isSettingsHovered {
            return true
        }
#endif
        return isSettingsHovered
    }

    private func sidebarFooter(isCollapsed: Bool) -> some View {
        Button {
            appState.navigate(to: .settings)
        } label: {
            SidebarFooterRow(
                status: footerStatus,
                isCompact: isCollapsed,
                isSelected: appState.sidebarSelection == .settings,
                isHovered: effectiveSettingsHovered
            )
        }
        .buttonStyle(SidebarPressableButtonStyle())
        .onHover { isHovered in
            withAnimation(hoverAnimation) {
                isSettingsHovered = isHovered
            }
        }
        .anchorPreference(key: SidebarRailTooltipPreferenceKey.self, value: .bounds) { anchor in
            isCollapsed && effectiveSettingsHovered
                ? SidebarRailTooltipValue(item: .settings, isSelected: appState.sidebarSelection == .settings, anchor: anchor)
                : nil
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .accessibilityLabel("设置")
    }

    private var hoverAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .spring(response: 0.22, dampingFraction: 0.88)
    }

    private func capabilityState(for item: SidebarItem) -> SidebarCapabilityState? {
        capabilityStatuses[item]
    }

    private func toggleSidebar() {
        appState.toggleSidebar()
    }

    private func setupKeyboardShortcuts() {
        // 快捷键已在 AppState 中定义
        Task { await refreshFooterStatus() }
    }

    private func refreshCapabilityStatuses() {
        let displaySettings = CompanionDisplaySettingsStore.load()
        let voiceEnabled = SettingsLocalPreferences.isVoiceInputEnabled()

        capabilityStatuses = [
            .dynamicContinent: SidebarCapabilityState(
                label: displaySettings.isEnabled ? "已开启" : "已关闭",
                isActive: displaySettings.isEnabled
            ),
            .voiceEntry: SidebarCapabilityState(
                label: voiceEnabled ? "已开启" : "已关闭",
                isActive: voiceEnabled
            )
        ]
    }

    @MainActor
    private func refreshFooterStatus() async {
        let serviceState: String
        if container.isInitialized {
            serviceState = "本地服务正常"
        } else {
            serviceState = "本地服务初始化中"
        }

        let modelLabel: String
        let settings = await container.settingsService.getSettings()
        modelLabel = settings.defaultModelId?.isEmpty == false ? settings.defaultModelId! : "自动路由"

        footerStatus = SidebarFooterStatus(
            serviceState: serviceState,
            modelLabel: modelLabel
        )
    }
}

#if DEBUG
@MainActor
enum DebugSidebarPreviewState {
    static var forcedHoverItem: SidebarItem?
    static var isSettingsHovered = false
}
#endif

// MARK: - Sidebar Item Row

private struct SidebarLogoMarkView: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 7, y: 19))
                path.addLine(to: CGPoint(x: 14, y: 6))
                path.addLine(to: CGPoint(x: 21, y: 19))
            }
            .stroke(
                AppSurfaceTokens.primaryText,
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            )

            Circle()
                .fill(AppSurfaceTokens.accentBlue)
                .frame(width: 4.8, height: 4.8)
                .offset(y: 4)
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

private struct SidebarItemGlyphView: View {
    enum Presentation {
        case card
        case rail
    }

    let item: SidebarItem
    let isSelected: Bool
    let presentation: Presentation

    var body: some View {
        Group {
            switch presentation {
            case .card:
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.14) : AppSurfaceTokens.cardBackground.opacity(0.76))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.20) : Color.clear, lineWidth: 1)
                        )

                    glyph
                        .padding(4.5)
                }
            case .rail:
                glyph
                    .padding(1.5)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        switch item {
        case .home:
            HomeGlyph(isSelected: isSelected)
        case .agent:
            AgentGlyph(isSelected: isSelected)
        case .inbox:
            InboxGlyph(isSelected: isSelected)
        case .screenshot:
            ScreenshotGlyph(isSelected: isSelected)
        case .screenshotHistory:
            ScreenshotHistoryGlyph(isSelected: isSelected)
        case .clipboard:
            ClipboardGlyph(isSelected: isSelected)
        case .schedule:
            ScheduleGlyph(isSelected: isSelected)
        case .workbench:
            WorkbenchGlyph(isSelected: isSelected)
        case .dynamicContinent:
            DynamicContinentGlyph(isSelected: isSelected)
        case .systemStatus:
            SystemGlyph(isSelected: isSelected)
        case .voiceEntry:
            VoiceGlyph(isSelected: isSelected)
        case .modelManagement:
            ModelGlyph(isSelected: isSelected)
        case .settings:
            SettingsGlyph(isSelected: isSelected)
        }
    }
}

private struct HomeGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path { path in
                path.move(to: CGPoint(x: size * 0.14, y: size * 0.50))
                path.addLine(to: CGPoint(x: size * 0.50, y: size * 0.18))
                path.addLine(to: CGPoint(x: size * 0.86, y: size * 0.50))
                path.addLine(to: CGPoint(x: size * 0.86, y: size * 0.82))
                path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.82))
                path.addLine(to: CGPoint(x: size * 0.62, y: size * 0.60))
                path.addLine(to: CGPoint(x: size * 0.38, y: size * 0.60))
                path.addLine(to: CGPoint(x: size * 0.38, y: size * 0.82))
                path.addLine(to: CGPoint(x: size * 0.14, y: size * 0.82))
                path.closeSubpath()
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            Path(roundedRect: CGRect(x: size * 0.45, y: size * 0.62, width: size * 0.10, height: size * 0.16), cornerRadius: 1.2)
                .fill(color)
        }
    }
}

private struct AgentGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.15, y: size * 0.20, width: size * 0.60, height: size * 0.44), cornerRadius: size * 0.14)
                .stroke(color, lineWidth: 1.5)
            Path { path in
                path.move(to: CGPoint(x: size * 0.30, y: size * 0.64))
                path.addLine(to: CGPoint(x: size * 0.26, y: size * 0.82))
                path.addLine(to: CGPoint(x: size * 0.42, y: size * 0.69))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(color)
                .frame(width: size * 0.11, height: size * 0.11)
                .position(x: size * 0.63, y: size * 0.39)
        }
    }
}

private struct InboxGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path { path in
                path.move(to: CGPoint(x: size * 0.16, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.84, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.70, y: size * 0.66))
                path.addLine(to: CGPoint(x: size * 0.30, y: size * 0.66))
                path.closeSubpath()
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            Path(roundedRect: CGRect(x: size * 0.30, y: size * 0.58, width: size * 0.40, height: size * 0.12), cornerRadius: 1.4)
                .fill(color)
        }
    }
}

private struct ScreenshotGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText

            Path(roundedRect: CGRect(x: size * 0.16, y: size * 0.22, width: size * 0.68, height: size * 0.52), cornerRadius: size * 0.09)
                .stroke(color, lineWidth: 1.5)

            Path { path in
                path.move(to: CGPoint(x: size * 0.30, y: size * 0.40))
                path.addLine(to: CGPoint(x: size * 0.70, y: size * 0.40))
                path.move(to: CGPoint(x: size * 0.30, y: size * 0.52))
                path.addLine(to: CGPoint(x: size * 0.54, y: size * 0.52))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

            Circle()
                .fill(color)
                .frame(width: size * 0.08, height: size * 0.08)
                .position(x: size * 0.72, y: size * 0.58)
        }
    }
}

private struct ScreenshotHistoryGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.18, y: size * 0.30, width: size * 0.64, height: size * 0.42), cornerRadius: size * 0.08)
                .stroke(color, lineWidth: 1.4)
            Path(roundedRect: CGRect(x: size * 0.30, y: size * 0.22, width: size * 0.20, height: size * 0.12), cornerRadius: size * 0.03)
                .fill(color.opacity(0.86))
            Circle()
                .stroke(color, lineWidth: 1.35)
                .frame(width: size * 0.20, height: size * 0.20)
                .position(x: size * 0.50, y: size * 0.51)
            Path { path in
                path.move(to: CGPoint(x: size * 0.68, y: size * 0.40))
                path.addLine(to: CGPoint(x: size * 0.72, y: size * 0.40))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }
}

private struct ClipboardGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.24, y: size * 0.22, width: size * 0.52, height: size * 0.58), cornerRadius: 2.4)
                .stroke(color, lineWidth: 1.4)
            Path(roundedRect: CGRect(x: size * 0.38, y: size * 0.10, width: size * 0.24, height: size * 0.14), cornerRadius: 1.2)
                .fill(color)
            Path { path in
                path.move(to: CGPoint(x: size * 0.34, y: size * 0.40))
                path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.40))
                path.move(to: CGPoint(x: size * 0.34, y: size * 0.52))
                path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.52))
            }
            .stroke(color.opacity(0.86), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }
}

private struct ScheduleGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.16, y: size * 0.20, width: size * 0.68, height: size * 0.64), cornerRadius: 2.4)
                .stroke(color, lineWidth: 1.4)
            Path { path in
                path.move(to: CGPoint(x: size * 0.16, y: size * 0.36))
                path.addLine(to: CGPoint(x: size * 0.84, y: size * 0.36))
            }
            .stroke(color, lineWidth: 1.1)
            Circle().fill(color).frame(width: size * 0.08, height: size * 0.08).position(x: size * 0.36, y: size * 0.58)
            Circle().fill(color.opacity(0.82)).frame(width: size * 0.08, height: size * 0.08).position(x: size * 0.60, y: size * 0.58)
        }
    }
}

private struct WorkbenchGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            let cell = size * 0.18
            let gap = size * 0.09
            ForEach(0..<2, id: \.self) { row in
                ForEach(0..<2, id: \.self) { column in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: cell, height: cell)
                        .position(
                            x: size * 0.32 + CGFloat(column) * (cell + gap),
                            y: size * 0.32 + CGFloat(row) * (cell + gap)
                        )
                }
            }
        }
    }
}

private struct DynamicContinentGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.34, y: size * 0.18, width: size * 0.32, height: size * 0.62), cornerRadius: size * 0.16)
                .stroke(color, lineWidth: 1.4)
            Circle()
                .fill(color)
                .frame(width: size * 0.11, height: size * 0.11)
                .position(x: size * 0.72, y: size * 0.28)
        }
    }
}

private struct SystemGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Path(roundedRect: CGRect(x: size * 0.24, y: size * 0.24, width: size * 0.52, height: size * 0.52), cornerRadius: 2)
                .stroke(color, lineWidth: 1.4)
            ForEach(0..<4, id: \.self) { index in
                let row = CGFloat(index / 2)
                let column = CGFloat(index % 2)
                Path { path in
                    let x = size * (0.24 + column * 0.52)
                    let y = size * (0.24 + row * 0.52)
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + size * 0.10))
                }
                .stroke(color.opacity(0.86), lineWidth: 1.0)
            }
        }
    }
}

private struct VoiceGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Capsule(style: .continuous)
                .stroke(color, lineWidth: 1.4)
                .frame(width: size * 0.30, height: size * 0.54)
                .position(x: size * 0.50, y: size * 0.40)
            Path { path in
                path.move(to: CGPoint(x: size * 0.50, y: size * 0.64))
                path.addLine(to: CGPoint(x: size * 0.50, y: size * 0.82))
            }
            .stroke(color, lineWidth: 1.2)
        }
    }
}

private struct ModelGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: size * 0.18, height: size * 0.18)
                .position(x: size * 0.28, y: size * 0.30)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.92))
                .frame(width: size * 0.18, height: size * 0.18)
                .position(x: size * 0.66, y: size * 0.42)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.82))
                .frame(width: size * 0.18, height: size * 0.18)
                .position(x: size * 0.46, y: size * 0.68)
            Path { path in
                path.move(to: CGPoint(x: size * 0.36, y: size * 0.34))
                path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.46))
                path.move(to: CGPoint(x: size * 0.52, y: size * 0.60))
                path.addLine(to: CGPoint(x: size * 0.66, y: size * 0.46))
            }
            .stroke(color.opacity(0.75), lineWidth: 1.0)
        }
    }
}

private struct SettingsGlyph: View {
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let color = isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText
            Circle()
                .stroke(color, lineWidth: 1.4)
                .frame(width: size * 0.46, height: size * 0.46)
                .position(x: size * 0.50, y: size * 0.50)
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6.0 * .pi * 2.0
                let dx = cos(angle) * size * 0.16
                let dy = sin(angle) * size * 0.16
                Path { path in
                    path.move(to: CGPoint(x: size * 0.50, y: size * 0.50))
                    path.addLine(to: CGPoint(x: size * 0.50 + dx, y: size * 0.50 + dy))
                }
                .stroke(color.opacity(0.70), lineWidth: 1.0)
            }
        }
    }
}

struct SidebarItemRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool
    let capabilityState: SidebarCapabilityState?

    init(
        item: SidebarItem,
        isSelected: Bool,
        isHovered: Bool = false,
        capabilityState: SidebarCapabilityState? = nil
    ) {
        self.item = item
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.capabilityState = capabilityState
    }

    var body: some View {
        HStack(spacing: 10) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.8, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if item.group == .companionCapabilities {
                    Text(item.group.displayName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            if let capabilityState {
                capabilityPill(state: capabilityState)
            } else if (isHovered || isSelected), let shortcut = item.shortcut {
                shortcutPill(shortcutDisplay(for: shortcut))
            }
        }
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: AppSurfaceTokens.Layout.rowMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackground.opacity(0.64) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 0)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)\(isSelected ? "，当前页面" : "")")
    }

    private var iconTile: some View {
        SidebarItemGlyphView(item: item, isSelected: isSelected, presentation: .card)
            .frame(width: 26, height: 26)
            .frame(width: 36, alignment: .center)
    }

    private func capabilityPill(state: SidebarCapabilityState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.isActive ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.secondaryText.opacity(0.5))
                .frame(width: 5, height: 5)
            Text(state.isActive ? "已开" : "已关")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(state.isActive ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.secondaryText)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(state.isActive ? AppSurfaceTokens.accentGreen.opacity(0.10) : AppSurfaceTokens.cardBackground.opacity(0.82))
        )
    }

    private func shortcutPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.12) : AppSurfaceTokens.cardBackground.opacity(0.88))
            )
    }

    private func shortcutDisplay(for shortcut: AcMindKeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.command) { parts.append("⌘") }
        if shortcut.modifiers.contains(.option) { parts.append("⌥") }
        if shortcut.modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(shortcut.key.uppercased())
        return parts.joined()
    }
}

struct SidebarCompactItemRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            SidebarItemGlyphView(item: item, isSelected: isSelected, presentation: .card)
                .frame(width: 26, height: 26)
        }
        .frame(maxWidth: .infinity, minHeight: AppSurfaceTokens.Layout.rowMinHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackground.opacity(0.64) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 0)
            }
        }
        .anchorPreference(key: SidebarRailTooltipPreferenceKey.self, value: .bounds) { anchor in
            isHovered ? SidebarRailTooltipValue(item: item, isSelected: isSelected, anchor: anchor) : nil
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.10)
                : .spring(response: 0.24, dampingFraction: 0.92),
            value: isHovered
        )
        .zIndex(isHovered ? 10 : 0)
        .contentShape(Rectangle())
        .help(item.displayName)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)\(isSelected ? "，当前页面" : "")")
    }
}

struct SidebarRailTooltip: View {
    let item: SidebarItem
    let isSelected: Bool

    var body: some View {
        Text(item.displayName)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 82, alignment: .leading)
            .background(tooltipBackground)
            .overlay(tooltipBorder)
            .shadow(color: Color.black.opacity(0.11), radius: 5, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            .shadow(color: isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : Color.clear, radius: 10, x: 0, y: 0)
            .fixedSize(horizontal: true, vertical: false)
            .allowsHitTesting(false)
    }

    private var tooltipBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppSurfaceTokens.cardBackgroundStrong)
    }

    private var tooltipBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isSelected ? AppSurfaceTokens.accentBlue.opacity(0.24) : AppSurfaceTokens.separator.opacity(0.72),
                lineWidth: 1
            )
    }
}

struct SidebarRailTooltipValue {
    let item: SidebarItem
    let isSelected: Bool
    let anchor: Anchor<CGRect>
}

struct SidebarRailTooltipPreferenceKey: PreferenceKey {
    static let defaultValue: SidebarRailTooltipValue? = nil

    static func reduce(value: inout SidebarRailTooltipValue?, nextValue: () -> SidebarRailTooltipValue?) {
        value = nextValue() ?? value
    }
}

enum SidebarRailTooltipLayout {
    static func yOffset(for frame: CGRect, viewportHeight: CGFloat) -> CGFloat {
        let tooltipHalfHeight: CGFloat = 16
        let viewportInset: CGFloat = 28
        let projectedBottom = frame.midY + tooltipHalfHeight + viewportInset
        return -max(0, projectedBottom - viewportHeight)
    }
}

struct SidebarCapabilityState: Sendable, Equatable {
    let label: String
    let isActive: Bool
}

private struct SidebarFooterStatus: Sendable, Equatable {
    var serviceState: String
    var modelLabel: String

    static let loading = SidebarFooterStatus(serviceState: "本地服务加载中", modelLabel: "自动路由")
}

private struct SidebarFooterRow: View {
    let status: SidebarFooterStatus
    let isCompact: Bool
    var isSelected: Bool = false
    var isHovered: Bool = false

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                expandedBody
            }
        }
    }

    private var compactBody: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.12))

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                    .accessibilityHidden(true)
            }
            .frame(width: 26, height: 26)
        }
        .frame(maxWidth: .infinity, minHeight: AppSurfaceTokens.Layout.rowMinHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackground.opacity(0.64) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 0)
            }
        }
        .overlay(alignment: .trailing) {
            Circle()
                .fill(AppSurfaceTokens.accentGreen.opacity(0.92))
                .frame(width: 4.5, height: 4.5)
                .padding(.trailing, 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.serviceState)，模型：\(status.modelLabel)")
    }

    private var expandedBody: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppSurfaceTokens.accentBlue.opacity(0.12))

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                    .accessibilityHidden(true)
            }
            .frame(width: 30, height: 30)
            .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.system(size: 12.6, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text("\(status.serviceState) · \(status.modelLabel)")
                    .font(.system(size: 10.2, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.7), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.serviceState)，模型：\(status.modelLabel)")
    }
}

private struct SidebarPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Sidebar Item Badge

struct SidebarItemBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule(style: .continuous))
        }
    }
}
