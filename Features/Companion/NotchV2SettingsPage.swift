import Foundation
@preconcurrency import SwiftUI
import AcMindKit

struct NotchV2SettingsPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        CompanionPageTemplate.triple(leftWidth: CompanionLayoutTokens.templateAColumnWidth, rightWidth: CompanionLayoutTokens.templateAColumnWidth, left: {
            behaviorCard
        }, center: {
            layoutCard
        }, right: {
            moduleCard
        })
        .background(DynamicContinentDesignTokens.containerBackground)
    }

    private var behaviorCard: some View {
        CompanionPanel(title: "展开与行为", subtitle: "先开总开关，再调展开节奏", symbol: "arrow.up.left.and.arrow.down.right") {
            VStack(alignment: .leading, spacing: 6) {
                compactToggleRow(
                    title: "启用灵动大陆",
                    isOn: boolBinding(get: { viewModel.displaySettings.isEnabled }, set: viewModel.setDisplayEnabled(_:))
                )

                compactToggleRow(
                    title: "悬停自动展开",
                    isOn: boolBinding(get: { viewModel.displaySettings.autoExpand }, set: viewModel.setAutoExpand(_:))
                )

                sliderRow(
                    title: "展开延迟",
                    valueText: String(format: "%.1f 秒", viewModel.displaySettings.hoverExpandDelay),
                    binding: doubleBinding(get: { viewModel.displaySettings.hoverExpandDelay }, set: viewModel.setHoverExpandDelay(_:)),
                    range: 0.2...4.0,
                    step: 0.1
                )

                compactToggleRow(
                    title: "全屏时隐藏",
                    isOn: boolBinding(get: { viewModel.displaySettings.hideInFullscreen }, set: viewModel.setHideInFullscreen(_:))
                )

                compactToggleRow(
                    title: "录屏时隐藏",
                    isOn: boolBinding(get: { viewModel.displaySettings.hideWhenScreenRecording }, set: viewModel.setHideWhenScreenRecording(_:))
                )
            }
        }
    }

    private var layoutCard: some View {
        CompanionPanel(title: "页面布局", subtitle: "少一点层级，扫起来更快", symbol: "square.grid.2x2") {
            VStack(alignment: .leading, spacing: 6) {
                pickerRow(
                    title: "顶部高度模式",
                    selection: binding(
                        get: { viewModel.displaySettings.notchHeightMode },
                        set: viewModel.setNotchHeightMode(_:)
                    ),
                    options: CompanionCollapsedHeightMode.allCases
                )

                pickerRow(
                    title: "非刘海高度模式",
                    selection: binding(
                        get: { viewModel.displaySettings.nonNotchHeightMode },
                        set: viewModel.setNonNotchHeightMode(_:)
                    ),
                    options: CompanionNonNotchHeightMode.allCases
                )

                sliderRow(
                    title: "收起态宽度",
                    valueText: "\(Int(viewModel.displaySettings.nonNotchCollapsedWidth)) pt",
                    binding: doubleBinding(
                        get: { Double(viewModel.displaySettings.nonNotchCollapsedWidth) },
                        set: { viewModel.setNonNotchCollapsedWidth(CGFloat($0)) }
                    ),
                    range: 160...320,
                    step: 1
                )

                compactToggleRow(
                    title: "显示副标题",
                    isOn: boolBinding(get: { viewModel.displaySettings.showCollapsedSubtitle }, set: viewModel.setCollapsedSubtitleVisible(_:))
                )

                compactToggleRow(
                    title: "显示状态点",
                    isOn: boolBinding(get: { viewModel.displaySettings.showCollapsedStatusDots }, set: viewModel.setCollapsedStatusDotsVisible(_:))
                )
            }
        }
    }

    private var moduleCard: some View {
        CompanionPanel(title: "子模块", subtitle: "拖动排序，次级操作收进菜单", symbol: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.displaySettings.dynamicModuleOrder, id: \.self) { module in
                    moduleRow(module)
                }
            }
        }
    }

    private func moduleRow(_ module: DynamicContinentModuleID) -> some View {
        let isEnabled = viewModel.displaySettings.enabledDynamicModules.contains(module)
        let isOverviewVisible = viewModel.displaySettings.overviewVisibleModules.contains(module)

        return HStack(spacing: 8) {
            NotchV2Glyph(
                symbol: module.icon,
                role: .infoRow,
                tint: isEnabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText,
                isActive: isEnabled
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(NotchV2DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: binding(
                get: { isEnabled },
                set: { viewModel.setModuleEnabled(module, isEnabled: $0) }
            ))
            .labelsHidden()

            Menu {
                Button("上移") { viewModel.moveModule(module, by: -1) }
                    .disabled(canMoveModule(module, offset: -1) == false)
                Button("下移") { viewModel.moveModule(module, by: 1) }
                    .disabled(canMoveModule(module, offset: 1) == false)
                Button(isOverviewVisible ? "隐藏总览" : "显示总览") {
                    viewModel.setModuleOverviewVisible(module, isVisible: isOverviewVisible == false)
                }
                Button(isEnabled ? "停用模块" : "启用模块") {
                    viewModel.setModuleEnabled(module, isEnabled: isEnabled == false)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(NotchV2DesignTokens.panelBackground.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(NotchV2DesignTokens.separator.opacity(0.32), lineWidth: 1)
                    )
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.40), lineWidth: 1)
        )
    }

    private func runtimeContentSection(title: String, scope: NotchRuntimeSurfaceScope) -> some View {
        let scopeSubtitle = runtimeContentSubtitle(scope)

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NotchV2DesignTokens.Typography.caption.weight(.medium))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)

            ForEach(viewModel.orderedRuntimeContents(for: scope), id: \.self) { content in
                reorderableToggleRow(
                    title: content.displayName,
                    subtitle: scopeSubtitle,
                    icon: icon(for: content),
                    isEnabled: visibleContent(content, scope: scope),
                    enabledLabel: "显示",
                    disabledLabel: "隐藏",
                    canMoveUp: canMoveContent(content, scope: scope, offset: -1),
                    canMoveDown: canMoveContent(content, scope: scope, offset: 1),
                    toggle: { viewModel.setContentVisible(content, scope: scope, isVisible: $0) },
                    moveUp: { viewModel.moveContent(content, scope: scope, by: -1) },
                    moveDown: { viewModel.moveContent(content, scope: scope, by: 1) }
                )
            }
        }
    }

    private func visibleContent(_ content: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope) -> Bool {
        switch scope {
        case .collapsed:
            return viewModel.displaySettings.collapsedVisibleContents.contains(content)
        case .primary:
            return viewModel.displaySettings.primarySurfaceContents.contains(content)
        }
    }

    private func canMoveModule(_ module: DynamicContinentModuleID, offset: Int) -> Bool {
        guard let index = viewModel.displaySettings.dynamicModuleOrder.firstIndex(of: module) else { return false }
        let nextIndex = index + offset
        return nextIndex >= 0 && nextIndex < viewModel.displaySettings.dynamicModuleOrder.count
    }

    private func canMoveContent(_ content: CompanionRuntimeContentID, scope: NotchRuntimeSurfaceScope, offset: Int) -> Bool {
        let order = runtimeContentOrder(scope)
        guard let index = order.firstIndex(of: content) else { return false }
        let nextIndex = index + offset
        return nextIndex >= 0 && nextIndex < order.count
    }

    private func runtimeContentOrder(_ scope: NotchRuntimeSurfaceScope) -> [CompanionRuntimeContentID] {
        switch scope {
        case .collapsed:
            return viewModel.displaySettings.collapsedVisibleContentOrder
        case .primary:
            return viewModel.displaySettings.primarySurfaceContentOrder
        }
    }

    private func runtimeContentSubtitle(_ scope: NotchRuntimeSurfaceScope) -> String {
        switch scope {
        case .collapsed:
            return "收起态"
        case .primary:
            return "主内容区"
        }
    }

    private func icon(for content: CompanionRuntimeContentID) -> String {
        switch content {
        case .voice: return "mic.fill"
        case .screenshot: return "camera.viewfinder"
        case .music: return "music.note"
        case .schedule: return "calendar"
        case .agent: return "sparkles"
        case .systemStatus: return "cpu"
        }
    }

    private func icon(for kind: SystemEventKind) -> String {
        switch kind {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .keyboardBacklight: return "keyboard"
        case .microphone: return "mic.fill"
        case .sayInput: return "waveform"
        case .screenshot: return "camera.viewfinder"
        }
    }

    private func systemEventTitle(for kind: SystemEventKind) -> String {
        switch kind {
        case .volume: return "音量"
        case .brightness: return "亮度"
        case .keyboardBacklight: return "键盘背光"
        case .microphone: return "麦克风"
        case .sayInput: return "说入法"
        case .screenshot: return "截图"
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(NotchV2DesignTokens.Typography.caption.weight(.medium))
            .foregroundStyle(NotchV2DesignTokens.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func advancedSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            content()
        }
    }

    private func compactToggleRow(title: String, subtitle: String = "", isOn: Binding<Bool>) -> some View {
        CompanionToggleRow(title: title, subtitle: subtitle.isEmpty ? nil : subtitle, isOn: isOn)
    }

    private func toggleRow(title: String, subtitle: String = "", isOn: Binding<Bool>) -> some View {
        CompanionToggleRow(title: title, subtitle: subtitle.isEmpty ? nil : subtitle, isOn: isOn)
    }

    private func sliderRow(title: String, valueText: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        CompanionSliderRow(title: title, valueText: valueText, range: range, step: step, value: binding)
    }

    private func pickerRow<T: CaseIterable & Hashable & Identifiable & CustomStringConvertible & Sendable>(
        title: String,
        selection: Binding<T>,
        options: T.AllCases
    ) -> some View where T.AllCases: RandomAccessCollection {
        CompanionPickerRow(
            title: title,
            selection: selection,
            options: Array(options)
        )
    }

    private func reorderableToggleRow(
        title: String,
        subtitle: String = "",
        icon: String,
        isEnabled: Bool,
        enabledLabel: String,
        disabledLabel: String,
        canMoveUp: Bool,
        canMoveDown: Bool,
        toggle: @escaping @MainActor (Bool) -> Void,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            NotchV2Glyph(symbol: icon, role: .infoRow, tint: isEnabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText, isActive: isEnabled)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(NotchV2DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText.opacity(0.94))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    moveButton(systemImage: "arrow.up", enabled: canMoveUp, action: moveUp)
                    moveButton(systemImage: "arrow.down", enabled: canMoveDown, action: moveDown)
                }

                Toggle(
                    isEnabled ? enabledLabel : disabledLabel,
                    isOn: boolBinding(get: { isEnabled }, set: toggle)
                )
                .labelsHidden()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.cardBackgroundStrong.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.48), lineWidth: 1)
        )
    }

    private func toggleOnlyRow(
        title: String,
        subtitle: String = "",
        icon: String,
        isEnabled: Bool,
        enabledText: String,
        disabledText: String,
        disabledWhen: Bool,
        toggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            NotchV2Glyph(symbol: icon, role: .infoRow, tint: isEnabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText, isActive: isEnabled)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(NotchV2DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText.opacity(0.94))
            }

            Spacer(minLength: 0)

            Toggle(isEnabled ? enabledText : disabledText, isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    guard disabledWhen == false else { return }
                    toggle(newValue)
                }
            ))
            .labelsHidden()
            .disabled(disabledWhen)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.cardBackgroundStrong.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.48), lineWidth: 1)
        )
    }

    private func moveButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText)
        .disabled(enabled == false)
    }

    private func toggleIconButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.weakText)
        .disabled(enabled == false)
    }

    private func boolBinding(
        get: @escaping @MainActor () -> Bool,
        set: @escaping @MainActor (Bool) -> Void
    ) -> Binding<Bool> {
        actorBinding(get: get, set: set)
    }

    private func doubleBinding(
        get: @escaping @MainActor () -> Double,
        set: @escaping @MainActor (Double) -> Void
    ) -> Binding<Double> {
        actorBinding(get: get, set: set)
    }

    private func binding<Value: Sendable>(
        get: @escaping @MainActor () -> Value,
        set: @escaping @MainActor (Value) -> Void
    ) -> Binding<Value> {
        actorBinding(get: get, set: set)
    }

    private func actorBinding<Value: Sendable>(
        get: @escaping @MainActor () -> Value,
        set: @escaping @MainActor (Value) -> Void
    ) -> Binding<Value> {
        let box = MainActorBindingBox(get: get, set: set)
        return Binding(
            get: { MainActor.assumeIsolated { box.get() } },
            set: { value in MainActor.assumeIsolated { box.set(value) } }
        )
    }
}

private final class MainActorBindingBox<Value: Sendable>: @unchecked Sendable {
    let get: @MainActor () -> Value
    let set: @MainActor (Value) -> Void

    init(
        get: @escaping @MainActor () -> Value,
        set: @escaping @MainActor (Value) -> Void
    ) {
        self.get = get
        self.set = set
    }
}
