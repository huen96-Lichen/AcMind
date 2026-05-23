import AppKit
import SwiftUI
import AcMindKit

struct SurfaceSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let width: CGFloat?
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.minWidth = minWidth
        self.minHeight = height
        self.content = content()
    }

    var body: some View {
        ACCard(padding: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(ACTypography.cardTitle)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: width, alignment: .topLeading)
        .frame(minWidth: minWidth, alignment: .topLeading)
        .frame(minHeight: minHeight, alignment: .topLeading)
    }
}

struct SurfaceMonitorHintRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(ACTypography.caption)
                .foregroundStyle(ACColors.secondaryText)
            Spacer(minLength: 0)
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(ACColors.primaryText)
        }
        .padding(.horizontal, 2)
    }
}

struct SurfaceMonitorButtonRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                Text(subtitle)
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.tertiaryText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(isSelected ? ACColors.selectedFill : ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.28) : ACColors.border, lineWidth: 1)
        )
    }
}

struct SurfaceCapsuleTag: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(ACTypography.captionMedium)
            .foregroundStyle(isSelected ? .white : ACColors.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? ACColors.blackCapsule : Color.white.opacity(0.0), in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? ACColors.blackCapsule : ACColors.border, lineWidth: 1)
            )
    }
}

struct SurfaceRuleCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ACTypeIcon(symbol, tint: ACColors.accentBlue, background: ACColors.selectedFill, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ACTypography.captionMedium)
                        .foregroundStyle(ACColors.primaryText)
                    Text(subtitle)
                        .font(ACTypography.mini)
                        .foregroundStyle(ACColors.secondaryText)
                }

                Spacer(minLength: 0)
            }

            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .tint(ACColors.accentBlue)
                .allowsHitTesting(false)

            Text(isOn ? "已启用" : "未启用")
                .font(ACTypography.miniMedium)
                .foregroundStyle(isOn ? ACColors.accentBlue : ACColors.secondaryText)
        }
        .padding(12)
        .frame(minHeight: 118, alignment: .topLeading)
        .background(Color.white.opacity(0.0), in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}

struct SurfaceWidgetChip: View {
    let item: SurfaceWidgetItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(item.title)
                .font(ACTypography.miniMedium)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? .white : ACColors.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(isSelected ? ACColors.blackCapsule : ACColors.softFill, in: Capsule())
        .overlay(
            Capsule().stroke(isSelected ? ACColors.blackCapsule : ACColors.border, lineWidth: 1)
        )
    }
}

struct SurfaceBlockRow: View {
    let tab: SurfaceContinentTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            ACTypeIcon(tab.icon, tint: isSelected ? ACColors.accentBlue : ACColors.secondaryText, background: isSelected ? ACColors.selectedFill : ACColors.softFill, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.name)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.primaryText)
                    .lineLimit(1)
                Text("\(tab.enabledModules.count) 个模块")
                    .font(ACTypography.mini)
                    .foregroundStyle(ACColors.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ACColors.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(isSelected ? ACColors.selectedFill.opacity(0.6) : Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isSelected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

struct SurfaceFeatureTile: View {
    let card: SurfaceFeatureCard
    let isEnabled: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(ACColors.primaryText)
                            .lineLimit(1)
                        Text(card.subtitle)
                            .font(ACTypography.mini)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    ACBadge(isEnabled ? "已启用" : "待启用", kind: isEnabled ? .green : .neutral)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(isEnabled ? ACColors.selectedFill.opacity(0.6) : Color.white.opacity(0.0))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(isEnabled ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SurfaceCapsuleCompactPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 8, height: 8)
            Text("AcMind")
                .font(ACTypography.captionMedium)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Circle()
                .fill(ACColors.accentBlue)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 120, height: 34)
        .background(ACColors.blackCapsule, in: Capsule())
    }
}

struct SurfaceCapsuleExpandedPreview: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "qrcode.viewfinder")
            Image(systemName: "camera")
            Image(systemName: "waveform")
            Image(systemName: "clipboard")
            Image(systemName: "ellipsis")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(ACColors.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 180, height: 40)
        .background(Color.white.opacity(0.0), in: Capsule())
        .overlay(Capsule().stroke(ACColors.border, lineWidth: 1))
    }
}

struct SurfaceContinentCompactPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("AcMind")
                    .font(ACTypography.captionMedium)
                Text("正在运行")
                    .font(ACTypography.mini)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            Spacer(minLength: 0)
            Circle()
                .fill(ACColors.accentGreen)
                .frame(width: 7, height: 7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 150, height: 38)
        .background(ACColors.blackCapsule, in: Capsule())
    }
}

struct ContinentExpandedPreview: View {
    let tab: SurfaceContinentTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ACColors.blackCapsule, ACColors.darkCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 10, height: 10)
                        Text(tab.name)
                            .font(ACTypography.captionMedium)
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    ACBadge("LIVE", kind: .blue)
                }

                HStack(spacing: 8) {
                    miniPane(title: "左", value: tab.enabledModules.first?.title ?? "—")
                    miniPane(title: "中", value: tab.enabledModules.dropFirst().first?.title ?? "—")
                    miniPane(title: "右", value: tab.enabledModules.dropFirst(2).first?.title ?? "—")
                }

                HStack(spacing: 6) {
                    ForEach(tab.enabledModules.prefix(5)) { module in
                        Text(module.title)
                            .font(ACTypography.miniMedium)
                            .foregroundStyle(Color.white.opacity(0.90))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Text(tab.summary)
                        .font(ACTypography.mini)
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func miniPane(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ACTypography.mini)
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(ACTypography.captionMedium)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
    }
}

enum SurfaceMode: String, CaseIterable, Identifiable {
    case capsuleDesktop = "桌面胶囊"
    case continent = "顶部大陆"
    case config = "配置中心"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct SurfaceWidgetItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
}

struct SurfaceFeatureCard: Identifiable {
    enum Tier {
        case free, pro, beta

        var tint: Color {
            switch self {
            case .free: return ACColors.accentGreen
            case .pro: return ACColors.accentBlue
            case .beta: return ACColors.accentOrange
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let isEnabledByDefault: Bool
}

struct SurfaceWidgetCatalog {
    static let capsuleWidgets: [SurfaceWidgetItem] = [
        .init(id: "capsule-status", title: "状态", symbol: "sparkles"),
        .init(id: "capsule-sound", title: "语音", symbol: "waveform"),
        .init(id: "capsule-capture", title: "捕获", symbol: "camera"),
        .init(id: "capsule-note", title: "笔记", symbol: "doc.text"),
        .init(id: "capsule-sync", title: "同步", symbol: "arrow.triangle.2.circlepath"),
        .init(id: "capsule-focus", title: "专注", symbol: "moon.stars")
    ]

    static let continentWidgets: [SurfaceWidgetItem] = [
        .init(id: "continent-timeline", title: "日程", symbol: "calendar"),
        .init(id: "continent-agent", title: "Agent", symbol: "bubble.left.and.bubble.right"),
        .init(id: "continent-task", title: "任务", symbol: "checklist"),
        .init(id: "continent-weather", title: "天气", symbol: "cloud.sun"),
        .init(id: "continent-notes", title: "知识", symbol: "books.vertical"),
        .init(id: "continent-media", title: "媒体", symbol: "music.note")
    ]
}

struct SurfaceFeatureCatalog {
    static let cards: [SurfaceFeatureCard] = [
        .init(id: "feature-agent", title: "Agent", subtitle: "任务与响应", symbol: "sparkles", tint: ACColors.accentBlue, isEnabledByDefault: true),
        .init(id: "feature-voice", title: "语音", subtitle: "快捷转写", symbol: "waveform", tint: ACColors.accentPurple, isEnabledByDefault: true),
        .init(id: "feature-capture", title: "捕获", subtitle: "截图 / 剪贴板", symbol: "camera", tint: ACColors.accentOrange, isEnabledByDefault: true),
        .init(id: "feature-schedule", title: "日程", subtitle: "时间线联动", symbol: "calendar", tint: ACColors.accentGreen, isEnabledByDefault: true),
        .init(id: "feature-notes", title: "知识", subtitle: "Markdown / Obsidian", symbol: "books.vertical", tint: ACColors.accentTeal, isEnabledByDefault: true)
    ]
}

struct SurfaceContinentModule: Identifiable, Codable, Hashable {
    var id: UUID
    let title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

struct SurfaceContinentTab: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var enabledModules: [SurfaceContinentModule]
    var isDefault: Bool

    var summary: String {
        "今日 · " + enabledModules.prefix(3).map(\.title).joined(separator: " / ")
    }

    static let mockTabs: [SurfaceContinentTab] = [
        .init(
            id: UUID(),
            name: "今日",
            icon: "sun.max",
            enabledModules: [
                SurfaceContinentModule(title: "日程"),
                SurfaceContinentModule(title: "天气"),
                SurfaceContinentModule(title: "任务"),
                SurfaceContinentModule(title: "消息")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "音乐",
            icon: "music.note",
            enabledModules: [
                SurfaceContinentModule(title: "播放"),
                SurfaceContinentModule(title: "歌单"),
                SurfaceContinentModule(title: "歌词")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "AI",
            icon: "sparkles",
            enabledModules: [
                SurfaceContinentModule(title: "状态"),
                SurfaceContinentModule(title: "任务"),
                SurfaceContinentModule(title: "快捷入口"),
                SurfaceContinentModule(title: "参考")
            ],
            isDefault: true
        ),
        .init(
            id: UUID(),
            name: "日程",
            icon: "calendar",
            enabledModules: [
                SurfaceContinentModule(title: "日历"),
                SurfaceContinentModule(title: "时间线"),
                SurfaceContinentModule(title: "提醒")
            ],
            isDefault: true
        )
    ]
}

enum DynamicSurfaceSettingsStorage {
    private static let continentTabsKey = "DynamicSurfaceSettings.continentTabs"
    private static let selectedContinentTabIDKey = "DynamicSurfaceSettings.selectedContinentTabID"
    private static let selectedWidgetIDsKey = "DynamicSurfaceSettings.selectedWidgetIDs"
    private static let selectedFeatureIDsKey = "DynamicSurfaceSettings.selectedFeatureIDs"

    static func loadContinentTabs(default defaultValue: [SurfaceContinentTab]) -> [SurfaceContinentTab] {
        guard let data = UserDefaults.standard.data(forKey: continentTabsKey),
              let decoded = try? JSONDecoder().decode([SurfaceContinentTab].self, from: data),
              !decoded.isEmpty else {
            return defaultValue
        }
        return decoded
    }

    static func saveContinentTabs(_ tabs: [SurfaceContinentTab]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        UserDefaults.standard.set(data, forKey: continentTabsKey)
        NotificationCenter.default.post(name: DynamicSurfacePreferencesStore.preferencesDidChange, object: nil)
    }

    static func loadSelectedContinentTabID(default defaultValue: UUID) -> UUID {
        guard let raw = UserDefaults.standard.string(forKey: selectedContinentTabIDKey),
              let id = UUID(uuidString: raw) else {
            return defaultValue
        }
        return id
    }

    static func saveSelectedContinentTabID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: selectedContinentTabIDKey)
        NotificationCenter.default.post(name: DynamicSurfacePreferencesStore.preferencesDidChange, object: nil)
    }

    static func loadSelectedWidgetIDs(default defaultValue: Set<String>) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: selectedWidgetIDsKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    static func saveSelectedWidgetIDs(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: selectedWidgetIDsKey)
        NotificationCenter.default.post(name: DynamicSurfacePreferencesStore.preferencesDidChange, object: nil)
    }

    static func loadSelectedFeatureIDs(default defaultValue: Set<String>) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: selectedFeatureIDsKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    static func saveSelectedFeatureIDs(_ ids: Set<String>) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: selectedFeatureIDsKey)
        NotificationCenter.default.post(name: DynamicSurfacePreferencesStore.preferencesDidChange, object: nil)
    }
}

extension NSScreen {
    var displayID: String {
        if let raw = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return raw.stringValue
        }
        return localizedName
    }

    var displayName: String {
        let width = Int(frame.width.rounded())
        let height = Int(frame.height.rounded())
        return "\(localizedName) · \(width)×\(height)"
    }

    var detailLabel: String {
        if let raw = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "ID \(raw.stringValue)"
        }
        return "当前显示器"
    }
}
