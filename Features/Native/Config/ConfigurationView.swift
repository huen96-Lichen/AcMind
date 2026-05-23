import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AcMindKit

struct ConfigurationView: View {
    @State private var settings: CornerTriggerSettings = CornerTriggerSettingsStore.load()
    @State private var choosingApplicationCorner: ScreenCorner?
    @State private var showResetConfirmation = false
    @State private var focusedCorner: ScreenCorner?
    @State private var screenTopologyToken = UUID()

    var body: some View {
        ACSecondaryPageShell(
            header: {
                ACPageHeader(
                    title: "配置",
                    subtitle: "管理全局触发角、动作和后续扩展能力。"
                ) {
                    HStack(spacing: 10) {
                        ACBadge(settings.isEnabled ? "已启用" : "未启用", kind: settings.isEnabled ? .green : .neutral)
                        ACBadge("全局共用", kind: .blue)
                        ACButton("恢复默认", kind: .ghost, minWidth: 92) {
                            showResetConfirmation = true
                        }
                    }
                }
            },
            content: { width in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            overviewCard
                            desktopHintScreenCard
                            previewCard
                            cornersGrid
                            futureCard
                        }
                        .frame(
                            maxWidth: min(width - ACLayout.pagePaddingX * 2, ACLayout.secondaryPageContentMaxWidth),
                            alignment: .leading
                        )
                        .padding(.vertical, 4)
                    }
                    .onChange(of: focusedCorner) {
                        guard let focusedCorner else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(focusedCorner.id, anchor: .center)
                        }
                    }
                }
            }
        )
        .onAppear {
            settings = CornerTriggerSettingsStore.load()
        }
        .onChange(of: settings) {
            CornerTriggerSettingsStore.save(settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screenTopologyToken = UUID()
        }
        .fileImporter(
            isPresented: Binding(
                get: { choosingApplicationCorner != nil },
                set: { if !$0 { choosingApplicationCorner = nil } }
            ),
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            handleApplicationSelection(result)
        }
        .confirmationDialog(
            "恢复默认配置",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复全部角位默认值", role: .destructive) {
                resetToDefaults()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会关闭全局触发角，并把四个角位恢复到默认绑定。")
        }
    }

    private var overviewCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    ACTypeIcon("square.3.layers.3d", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 46)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("全局触发角")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)

                        Text("把显示器四角变成可配置的触发区域。每个角都能单独开关，并绑定一个内置功能或应用。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    Toggle("", isOn: $settings.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack(spacing: 8) {
                    infoPill(title: "启用角位", value: "\(enabledCornerCount)/4")
                    infoPill(title: "触发模式", value: "鼠标进入角落")
                    infoPill(title: "配置范围", value: settings.desktopHintDisplayIDs.isEmpty ? "未选择显示器" : "\(settings.desktopHintDisplayIDs.count) 台显示器")
                }
            }
        }
    }

    private var desktopHintScreenCard: some View {
        let screens = NSScreen.screens
        let selectedCount = settings.desktopHintDisplayIDs.count
        let connectedSelectedCount = screens.filter { settings.desktopHintDisplayEnabled(on: $0) }.count

        return ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ACTypeIcon("display", tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 46)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("桌面提示屏幕")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)

                        Text("选择哪些显示器会显示黑色圆角提示。保存的是显示器 ID，所以重启后会记住你的选择。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ACBadge("\(selectedCount) 台已选", kind: .blue)
                        ACBadge("\(connectedSelectedCount) 台在线", kind: .neutral)
                    }
                }

                HStack(spacing: 8) {
                    ACButton("全选", kind: .secondary, minWidth: 72) {
                        selectAllHintScreens()
                    }

                    ACButton("清空", kind: .ghost, minWidth: 72) {
                        clearHintScreens()
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(screens, id: \.displayID) { screen in
                        hintScreenRow(for: screen)
                    }
                }

                let missingSelectedScreens = settings.desktopHintDisplayIDs.subtracting(Set(screens.map(\.displayID)))
                if missingSelectedScreens.isEmpty == false {
                    Text("已保存但当前未连接：\(missingSelectedScreens.sorted().joined(separator: "、"))")
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }
        }
        .id(screenTopologyToken)
    }

    private var previewCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("预览")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("圆角只是提示和热区装饰，不会改变系统桌面的真实边界。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ACBadge("热区圆角", kind: .neutral)
                        ACBadge(focusedCorner?.shortName ?? "点击角标定位", kind: .blue)
                    }
                }

                GeometryReader { proxy in
                    let width = max(0, proxy.size.width)
                    let height = max(0, proxy.size.height)

                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ACColors.selectedFill.opacity(0.9),
                                        ACColors.softFill.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(ACColors.border.opacity(0.7), lineWidth: 1)
                            )

                        previewBadge(corner: .topLeft)
                            .position(x: 52, y: 28)
                        previewBadge(corner: .topRight)
                            .position(x: max(width - 52, 52), y: 28)
                        previewBadge(corner: .bottomLeft)
                            .position(x: 52, y: max(height - 28, 28))
                        previewBadge(corner: .bottomRight)
                            .position(x: max(width - 52, 52), y: max(height - 28, 28))

                        VStack(spacing: 4) {
                            Text("全局热角")
                                .font(ACTypography.sectionTitle)
                                .foregroundStyle(ACColors.primaryText)
                            Text(settings.isEnabled ? "已开启" : "未开启")
                                .font(ACTypography.caption)
                                .foregroundStyle(ACColors.secondaryText)
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var cornersGrid: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("四角配置")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("每个触发角都可以单独启用，并绑定一个内置功能或具体应用。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(ScreenCorner.allCases) { corner in
                        cornerCard(for: corner)
                            .id(corner.id)
                    }
                }
            }
        }
    }

    private func hintScreenRow(for screen: NSScreen) -> some View {
        let isSelected = settings.desktopHintDisplayEnabled(on: screen)

        return HStack(spacing: 12) {
            ACTypeIcon(
                "display",
                tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText,
                background: isSelected ? ACColors.selectedFill : ACColors.softFill,
                size: 34
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(screen.displayName)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
                Text(screen.detailLabel)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: hintScreenBinding(for: screen))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, minHeight: ACLayout.sidebarNavHeight, alignment: .leading)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .fill(isSelected ? ACColors.selectedFill : ACColors.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.24) : ACColors.border.opacity(0.32), lineWidth: 1)
        )
    }

    private var futureCard: some View {
        ACCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ACTypeIcon("plus.viewfinder", tint: ACColors.accentPurple, background: ACColors.selectedFill, size: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("后续扩展")
                            .font(ACTypography.cardTitle)
                            .foregroundStyle(ACColors.primaryText)
                        Text("新的灵动大陆相关能力会继续放进这个页面，不再分散到别的设置入口。")
                            .font(ACTypography.caption)
                            .foregroundStyle(ACColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    ACBadge("动作扩展", kind: .purple)
                    ACBadge("更多角区策略", kind: .neutral)
                    ACBadge("每屏独立配置", kind: .neutral)
                }
            }
        }
    }

    private func cornerCard(for corner: ScreenCorner) -> some View {
        let assignment = settings[corner]
        let isFocused = focusedCorner == corner

        return VStack(spacing: 0) {
            ACCard(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(corner.displayName)
                                .font(ACTypography.itemTitle)
                                .foregroundStyle(ACColors.primaryText)
                            Text(corner.shortName)
                                .font(ACTypography.mini)
                                .foregroundStyle(ACColors.secondaryText)
                        }

                        Spacer(minLength: 0)

                        ACButton("定位", kind: .ghost, minWidth: 56) {
                            focusCorner(corner)
                        }

                        Toggle("", isOn: cornerEnabledBinding(for: corner))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    HStack(spacing: 6) {
                        ACBadge(assignment.isEnabled ? "已启用" : "已停用", kind: assignment.isEnabled ? .green : .neutral)
                        ACBadge(assignment.target.kind.displayName, kind: .blue)
                    }

                    Picker("动作类型", selection: cornerTargetKindBinding(for: corner)) {
                        ForEach(CornerTriggerTargetKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    switch assignment.target.kind {
                    case .builtInFeature:
                        Picker("内置功能", selection: cornerBuiltInActionBinding(for: corner)) {
                            ForEach(CornerBuiltInAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .pickerStyle(.menu)

                    case .application:
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(assignment.target.displayName)
                                        .font(ACTypography.captionMedium)
                                        .foregroundStyle(ACColors.primaryText)
                                        .lineLimit(1)
                                    Text(assignment.target.applicationBundleIdentifier ?? "未配置 bundle id")
                                        .font(ACTypography.mini)
                                        .foregroundStyle(ACColors.secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 8) {
                                ACButton("选择应用", kind: .secondary, minWidth: 84) {
                                    choosingApplicationCorner = corner
                                }

                                ACButton("清空", kind: .ghost, minWidth: 64) {
                                    clearApplicationSelection(for: corner)
                                }
                            }
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous)
                    .stroke(isFocused ? ACColors.accentBlue.opacity(0.32) : Color.clear, lineWidth: 2)
            )
            .shadow(color: isFocused ? ACColors.accentBlue.opacity(0.10) : .black.opacity(0.05), radius: isFocused ? 28 : 24, x: 0, y: 8)
        }
    }

    private func previewBadge(corner: ScreenCorner) -> some View {
        Button {
            focusCorner(corner)
        } label: {
            CornerPreviewBadge(
                corner: corner,
                assignment: settings[corner],
                isFocused: focusedCorner == corner
            )
        }
        .buttonStyle(.plain)
    }

    private var enabledCornerCount: Int {
        ScreenCorner.allCases.reduce(into: 0) { count, corner in
            if settings[corner].isEnabled { count += 1 }
        }
    }

    private func cornerEnabledBinding(for corner: ScreenCorner) -> Binding<Bool> {
        Binding(
            get: { settings[corner].isEnabled },
            set: { newValue in
                var assignment = settings[corner]
                assignment.isEnabled = newValue
                settings[corner] = assignment
            }
        )
    }

    private func cornerTargetKindBinding(for corner: ScreenCorner) -> Binding<CornerTriggerTargetKind> {
        Binding(
            get: { settings[corner].target.kind },
            set: { newValue in
                updateTargetKind(for: corner, to: newValue)
            }
        )
    }

    private func cornerBuiltInActionBinding(for corner: ScreenCorner) -> Binding<CornerBuiltInAction> {
        Binding(
            get: {
                settings[corner].target.builtInAction ?? .showMainWindow
            },
            set: { newValue in
                var assignment = settings[corner]
                assignment.target = .builtIn(newValue)
                settings[corner] = assignment
            }
        )
    }

    private func updateTargetKind(for corner: ScreenCorner, to newValue: CornerTriggerTargetKind) {
        var assignment = settings[corner]
        switch newValue {
        case .builtInFeature:
            assignment.target = .builtIn(assignment.target.builtInAction ?? .showMainWindow)
        case .application:
            assignment.target = CornerTriggerTarget.application(
                name: assignment.target.applicationName ?? "未选择应用",
                bundleIdentifier: assignment.target.applicationBundleIdentifier,
                url: assignment.target.applicationURL
            )
        }
        settings[corner] = assignment
    }

    private func clearApplicationSelection(for corner: ScreenCorner) {
        var assignment = settings[corner]
        assignment.target = CornerTriggerTarget.application(name: "未选择应用")
        settings[corner] = assignment
    }

    private func hintScreenBinding(for screen: NSScreen) -> Binding<Bool> {
        Binding(
            get: { settings.desktopHintDisplayEnabled(on: screen) },
            set: { newValue in
                var updatedIDs = settings.desktopHintDisplayIDs
                if newValue {
                    updatedIDs.insert(screen.displayID)
                } else {
                    updatedIDs.remove(screen.displayID)
                }
                settings.desktopHintDisplayIDs = updatedIDs
            }
        )
    }

    private func selectAllHintScreens() {
        settings.desktopHintDisplayIDs = Set(NSScreen.screens.map(\.displayID))
    }

    private func clearHintScreens() {
        settings.desktopHintDisplayIDs = []
    }

    private func focusCorner(_ corner: ScreenCorner) {
        focusedCorner = corner
    }

    private func resetToDefaults() {
        settings = .default
    }

    private func handleApplicationSelection(_ result: Result<[URL], Error>) {
        guard let corner = choosingApplicationCorner else { return }
        defer { choosingApplicationCorner = nil }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let bundle = Bundle(url: url)
            let displayName = applicationDisplayName(for: url, bundle: bundle)
            var assignment = settings[corner]
            assignment.target = CornerTriggerTarget.application(
                name: displayName,
                bundleIdentifier: bundle?.bundleIdentifier,
                url: url
            )
            settings[corner] = assignment

        case .failure:
            break
        }
    }

    private func applicationDisplayName(for url: URL, bundle: Bundle?) -> String {
        if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, displayName.isEmpty == false {
            return displayName
        }
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String, name.isEmpty == false {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }
}

private struct CornerPreviewBadge: View {
    let corner: ScreenCorner
    let assignment: CornerTriggerAssignment
    let isFocused: Bool

    var body: some View {
        VStack(alignment: corner.isLeftEdge ? .leading : .trailing, spacing: 4) {
            Text(corner.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(assignment.isEnabled ? .white : ACColors.primaryText)

            Text(assignment.target.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(assignment.isEnabled ? Color.white.opacity(0.82) : ACColors.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(assignment.isEnabled ? ACColors.accentBlue.opacity(0.92) : (isFocused ? ACColors.selectedFill : ACColors.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? ACColors.accentBlue.opacity(0.5) : (assignment.isEnabled ? ACColors.accentBlue.opacity(0.25) : ACColors.border), lineWidth: 1)
        )
    }
}

private func infoPill(title: String, value: String) -> some View {
    HStack(spacing: 6) {
        Text(title)
            .font(ACTypography.mini)
            .foregroundStyle(ACColors.secondaryText)
        Text(value)
            .font(ACTypography.miniMedium)
            .foregroundStyle(ACColors.primaryText)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(ACColors.softFill, in: Capsule())
    .overlay(
        Capsule().stroke(ACColors.border, lineWidth: 1)
    )
}
