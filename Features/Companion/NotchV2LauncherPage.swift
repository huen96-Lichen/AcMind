import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct NotchV2LauncherPage: View {
    @ObservedObject var viewModel: NotchV2ViewModel
    @StateObject private var launcherStore = NotchV2LauncherStore()
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(0, proxy.size.width - (CompanionLayoutTokens.pageHorizontalPadding * 2))

            VStack(alignment: .leading, spacing: 6) {
                toolbarRow
                quickEntryRow

                compactSectionLabel(title: "常用应用", detail: "拖入置顶，最多 10 个")
                favoriteSection

                CompanionDivider()

                compactSectionLabel(title: "所有应用", detail: launcherStore.appCountText)
                allAppsSection(contentWidth: contentWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, CompanionLayoutTokens.pageHorizontalPadding)
            .padding(.top, CompanionLayoutTokens.pageVerticalPadding)
            .padding(.bottom, CompanionLayoutTokens.pageVerticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(DynamicContinentDesignTokens.containerBackground)
            .onAppear {
                launcherStore.recordContentSize(proxy.size)
                searchIsFocused = true
            }
            .onChange(of: proxy.size) { _, newValue in
                launcherStore.recordContentSize(newValue)
            }
            .onExitCommand {
                launcherStore.clearSearch()
                searchIsFocused = false
            }
            .overlay(alignment: .topLeading) {
                keyboardShortcutLayer
            }
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            searchField

            if let statusMessage = launcherStore.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120, alignment: .trailing)
            }

            moreMenu
        }
        .frame(height: CompanionLayoutTokens.controlHeightSmall)
    }

    private var quickEntryRow: some View {
        HStack(spacing: 8) {
            Text("快速入口")
                .font(.system(size: CompanionLayoutTokens.sectionTitleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)

            Spacer(minLength: 0)

            launcherQuickButton(title: "首页", icon: "house", action: { viewModel.showMainHome() })
            launcherQuickButton(title: "设置", icon: "gearshape", action: { viewModel.showMainSettings() })
            launcherQuickButton(title: "模型", icon: "brain", action: { viewModel.showMainSettings(category: .aiModels) })
            launcherQuickButton(title: "收件箱", icon: "tray.full", action: { viewModel.showInbox() })
            launcherQuickButton(title: "模型管理", icon: "square.grid.2x2", action: { viewModel.showModelManagement() })
        }
        .frame(height: 20)
    }

    private func launcherQuickButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(NotchV2DesignTokens.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(
                Capsule(style: .continuous)
                    .fill(NotchV2DesignTokens.panelBackground.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(NotchV2DesignTokens.separator.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var searchField: some View {
        CompanionSearchField(
            text: $launcherStore.searchQuery,
            placeholder: "搜索应用",
            isFocused: searchIsFocused,
            focusAction: { searchIsFocused = true },
            clearAction: {
                launcherStore.clearSearch()
                searchIsFocused = true
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var moreMenu: some View {
        Menu {
            ForEach(LauncherSortOption.allCases) { option in
                Button(option.displayName) {
                    launcherStore.setSortOption(option)
                }
            }

            Divider()

            Button(launcherStore.isManagingFavorites ? "完成管理" : "管理常用") {
                launcherStore.toggleManagingFavorites()
            }

            Button("清空搜索") {
                launcherStore.clearSearch()
                searchIsFocused = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(launcherStore.sortOption.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(NotchV2DesignTokens.primaryText)
            .frame(width: LauncherTokens.sortButtonWidth + 6, height: LauncherTokens.compactControlHeight)
            .background(
                RoundedRectangle(cornerRadius: LauncherTokens.controlCornerRadius, style: .continuous)
                    .fill(NotchV2DesignTokens.panelBackground.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LauncherTokens.controlCornerRadius, style: .continuous)
                    .stroke(NotchV2DesignTokens.separator.opacity(0.36), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var favoriteSection: some View {
        Group {
            if launcherStore.favoriteApps.isEmpty {
                CompanionEmptyState(
                    title: "拖入置顶",
                    detail: "把最常用的本机应用放到这里，最多 10 个。",
                    icon: "pin"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: LauncherTokens.favoriteItemSpacing) {
                        ForEach(launcherStore.favoriteApps) { app in
                            FavoriteAppTile(
                                app: app,
                                isManagingFavorites: launcherStore.isManagingFavorites,
                                isDropTarget: launcherStore.dropTargetID == app.id,
                                onLaunch: { launcherStore.launch(app) },
                                onRemove: { launcherStore.removeFavorite(id: app.id) }
                            )
                            .onDrop(
                                of: [UTType.text, UTType.fileURL],
                                delegate: LauncherFavoriteDropDelegate(
                                    targetID: app.id,
                                    store: launcherStore
                                )
                            )
                            .contextMenu {
                                Button("取消置顶") {
                                    launcherStore.removeFavorite(id: app.id)
                                }
                            }
                        }

                        if launcherStore.favoriteApps.count < LauncherTokens.favoriteMaximumCount {
                            FavoriteDropZone(
                                isDropTarget: launcherStore.dropTargetID == "favorite-drop-zone",
                                emptyState: launcherStore.favoriteApps.isEmpty,
                                isManagingFavorites: launcherStore.isManagingFavorites
                            )
                            .onDrop(
                                of: [UTType.text, UTType.fileURL],
                                delegate: LauncherFavoriteDropDelegate(
                                    targetID: nil,
                                    store: launcherStore,
                                    isDropZone: true
                                )
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: LauncherTokens.favoriteRowHeight + 2)
            }
        }
        .frame(height: launcherStore.favoriteApps.isEmpty ? 42 : LauncherTokens.favoriteRowHeight + 2)
    }

    private func compactSectionLabel(title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: CompanionLayoutTokens.sectionTitleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Spacer(minLength: 0)
            Text(detail)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
        }
        .frame(height: 16)
    }

    private func allAppsSection(contentWidth: CGFloat) -> some View {
        let columns = launcherColumns(for: contentWidth)

        return VStack(alignment: .leading, spacing: 6) {
            ScrollView(.vertical, showsIndicators: false) {
                if launcherStore.visibleApps.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                } else {
                    LazyVGrid(columns: columns, spacing: LauncherTokens.allAppsRowSpacing) {
                        ForEach(launcherStore.visibleApps) { app in
                            AllAppsTile(
                                app: app,
                                isFavorite: launcherStore.isFavorite(app.id),
                                onLaunch: { launcherStore.launch(app) }
                            )
                            .onDrag {
                                launcherStore.dragPayload(for: app)
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .onDrop(
                of: [UTType.fileURL, UTType.text],
                delegate: LauncherAllAppsDropDelegate(store: launcherStore)
            )
        }
    }

    private var emptyState: some View {
        CompanionEmptyState(
            title: "没有找到匹配的应用",
            detail: "可以搜索应用名称、Bundle 名称或应用标识符。",
            icon: "magnifyingglass"
        )
    }

    private var keyboardShortcutLayer: some View {
        HStack(spacing: 0) {
            Button {
                searchIsFocused = true
            } label: {
                EmptyView()
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button {
                launcherStore.clearSearch()
                searchIsFocused = false
            } label: {
                EmptyView()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .hidden()
    }

    private func launcherColumns(for width: CGFloat) -> [GridItem] {
        let availableWidth = max(0, width)
        let itemWidth = LauncherTokens.allAppsItemWidth
        let spacing = LauncherTokens.allAppsColumnSpacing
        let columns = max(1, Int((availableWidth + spacing) / (itemWidth + spacing)))
        return Array(
            repeating: GridItem(.fixed(itemWidth), spacing: spacing, alignment: .top),
            count: columns
        )
    }
}

private struct FavoriteAppTile: View {
    let app: LauncherApp
    let isManagingFavorites: Bool
    let isDropTarget: Bool
    let onLaunch: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onLaunch()
        } label: {
            VStack(spacing: 5) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: LauncherTokens.favoriteIconSize, height: LauncherTokens.favoriteIconSize)

                Text(app.displayName)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: LauncherTokens.favoriteItemWidth, height: 12)
            }
            .frame(width: LauncherTokens.favoriteItemWidth, height: LauncherTokens.favoriteItemHeight)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius, style: .continuous)
                    .fill(isHovering || isDropTarget ? NotchV2DesignTokens.innerCardActive.opacity(0.64) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius, style: .continuous)
                    .stroke(isDropTarget ? NotchV2DesignTokens.accentBlue.opacity(0.40) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .opacity(isManagingFavorites ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius, style: .continuous))
        .onHover { isHovering = $0 }
        .help(app.displayName)
        .onDrag {
            NSItemProvider(object: NSString(string: "launcher-app:\(app.id)"))
        }
        .overlay(alignment: .topTrailing) {
            if isManagingFavorites {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(NotchV2DesignTokens.rootBackground.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .overlay(alignment: .leading) {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(NotchV2DesignTokens.accentBlue)
                    .frame(width: 2, height: 34)
                    .offset(x: -5)
            }
        }
    }
}

private struct FavoriteDropZone: View {
    let isDropTarget: Bool
    let emptyState: Bool
    let isManagingFavorites: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius, style: .continuous)
                    .fill(isDropTarget ? NotchV2DesignTokens.accentBlue.opacity(0.10) : NotchV2DesignTokens.innerCardBackground.opacity(0.78))
                    .frame(width: LauncherTokens.favoriteItemWidth, height: LauncherTokens.favoriteIconSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius, style: .continuous)
                            .stroke(isDropTarget ? NotchV2DesignTokens.accentBlue.opacity(0.35) : NotchV2DesignTokens.separator.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )

                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isDropTarget ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
            }

            Text(emptyState ? "拖入置顶" : "更多")
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .frame(width: LauncherTokens.favoriteItemWidth, height: 12)
        }
        .frame(width: LauncherTokens.favoriteItemWidth, height: LauncherTokens.favoriteItemHeight)
        .opacity(isManagingFavorites ? 0.95 : 1.0)
        .overlay(alignment: .leading) {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(NotchV2DesignTokens.accentBlue)
                    .frame(width: 2, height: 34)
                    .offset(x: -5)
            }
        }
    }
}

private struct AllAppsTile: View {
    let app: LauncherApp
    let isFavorite: Bool
    let onLaunch: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onLaunch()
        } label: {
            VStack(spacing: 3) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: LauncherTokens.allAppsIconSize, height: LauncherTokens.allAppsIconSize)

                Text(app.displayName)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: LauncherTokens.allAppsItemWidth, height: 10)
            }
            .frame(width: LauncherTokens.allAppsItemWidth, height: LauncherTokens.allAppsItemHeight)
            .background(
                RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius - 1, style: .continuous)
                    .fill(isHovering ? NotchV2DesignTokens.innerCardActive.opacity(0.52) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius - 1, style: .continuous)
                    .stroke(isHovering ? NotchV2DesignTokens.accentBlue.opacity(0.16) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: LauncherTokens.itemCornerRadius - 1, style: .continuous))
        .onHover { isHovering = $0 }
        .help(app.displayName)
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .padding(2)
                    .background(
                        Circle()
                            .fill(NotchV2DesignTokens.accentBlue.opacity(0.90))
                    )
                    .offset(x: 2, y: -2)
            }
        }
    }
}

private struct LauncherFavoriteDropDelegate: DropDelegate {
    let targetID: String?
    let store: NotchV2LauncherStore
    var isDropZone: Bool = false

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier, UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        store.setDropTarget(isDropZone ? "favorite-drop-zone" : targetID)
    }

    func dropExited(info: DropInfo) {
        if store.dropTargetID == (isDropZone ? "favorite-drop-zone" : targetID) {
            store.setDropTarget(nil)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        store.setDropTarget(nil)

        if let provider = info.itemProviders(for: [UTType.text]).first {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let text = LauncherDropPayloadReader.string(from: item)
                Task { @MainActor in
                    if let text {
                        store.handleDroppedString(text, pin: true, targetID: targetID)
                    }
                }
            }
            return true
        }

        if let provider = info.itemProviders(for: [UTType.fileURL]).first {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = LauncherDropPayloadReader.url(from: item)
                Task { @MainActor in
                    if let url {
                        store.handleDroppedFileURL(url, pin: true, targetID: targetID)
                    }
                }
            }
            return true
        }

        return false
    }
}

private struct LauncherAllAppsDropDelegate: DropDelegate {
    let store: NotchV2LauncherStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier, UTType.fileURL.identifier])
    }

    func performDrop(info: DropInfo) -> Bool {
        if let provider = info.itemProviders(for: [UTType.fileURL]).first {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = LauncherDropPayloadReader.url(from: item)
                Task { @MainActor in
                    if let url {
                        store.importApp(from: url, pin: false)
                    }
                }
            }
            return true
        }

        if let provider = info.itemProviders(for: [UTType.text]).first {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let text = LauncherDropPayloadReader.string(from: item)
                Task { @MainActor in
                    if let text, text.contains(".app") {
                        store.handleDroppedString(text, pin: false, targetID: nil)
                    }
                }
            }
            return true
        }

        return false
    }
}

private enum LauncherDropPayloadReader {
    static func string(from item: NSSecureCoding?) -> String? {
        if let string = item as? String {
            return string
        }
        if let nsString = item as? NSString {
            return nsString as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let data = item as? Data {
            if let string = String(data: data, encoding: .utf8) {
                return URL(string: string) ?? URL(fileURLWithPath: string.replacingOccurrences(of: "file://", with: ""))
            }
        }
        if let string = item as? String {
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }
        if let nsString = item as? NSString {
            let string = nsString as String
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }
        return nil
    }
}

enum LauncherTokens {
    static let horizontalPadding: CGFloat = 14
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 8

    static let favoriteHeaderHeight: CGFloat = 22
    static let favoriteRowHeight: CGFloat = 54
    static let favoriteIconSize: CGFloat = 38
    static let favoriteItemWidth: CGFloat = 78
    static let favoriteItemHeight: CGFloat = 54
    static let favoriteItemSpacing: CGFloat = 10
    static let favoriteMaximumCount: Int = 10

    static let sectionSpacing: CGFloat = 8
    static let dividerHeight: CGFloat = 1

    static let allAppsHeaderHeight: CGFloat = 18
    static let allAppsIconSize: CGFloat = 36
    static let allAppsItemWidth: CGFloat = 84
    static let allAppsItemHeight: CGFloat = 54
    static let allAppsColumnSpacing: CGFloat = 8
    static let allAppsRowSpacing: CGFloat = 2

    static let compactControlHeight: CGFloat = 22
    static let searchFieldWidth: CGFloat = 170
    static let sortButtonWidth: CGFloat = 52
    static let manageButtonWidth: CGFloat = 52

    static let itemCornerRadius: CGFloat = 10
    static let controlCornerRadius: CGFloat = 9
    static let hoverOpacity: Double = 0.07
    static let borderOpacity: Double = 0.08
}

enum LauncherSortOption: String, CaseIterable, Identifiable, Codable {
    case name
    case recent
    case frequency

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "名称"
        case .recent: return "最近使用"
        case .frequency: return "使用频率"
        }
    }
}

struct LauncherApp: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let bundleIdentifier: String?
    let bundleName: String?
    let displayName: String
    let bundleURL: URL
    var lastLaunchDate: Date?
    var launchCount: Int

    var icon: NSImage {
        LauncherIconCache.shared.iconImage(for: bundleURL)
    }

    var searchText: String {
        [
            displayName,
            bundleName,
            bundleIdentifier,
            bundleURL.deletingPathExtension().lastPathComponent
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    static func make(from bundleURL: URL) -> LauncherApp? {
        let url = bundleURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard url.pathExtension.lowercased() == "app" else { return nil }

        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary ?? [:]
        let displayName = (
            info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleName = info["CFBundleName"] as? String
        let bundleIdentifier = bundle?.bundleIdentifier ?? info["CFBundleIdentifier"] as? String

        return LauncherApp(
            id: stableID(bundleIdentifier: bundleIdentifier, bundleURL: url),
            bundleIdentifier: bundleIdentifier,
            bundleName: bundleName,
            displayName: displayName.isEmpty ? url.deletingPathExtension().lastPathComponent : displayName,
            bundleURL: url,
            lastLaunchDate: nil,
            launchCount: 0
        )
    }

    static func stableID(bundleIdentifier: String?, bundleURL: URL) -> String {
        if let bundleIdentifier, bundleIdentifier.isEmpty == false {
            return "bundle:\(bundleIdentifier)"
        }
        return "path:\(bundleURL.standardizedFileURL.path.lowercased())"
    }
}

private struct LauncherUsageRecord: Codable, Hashable, Sendable {
    let id: String
    var lastLaunchDate: Date?
    var launchCount: Int
}

private struct LauncherPersistedState: Codable {
    var favoriteIDs: [String]
    var customApps: [LauncherApp]
    var usageRecords: [LauncherUsageRecord]
    var sortOption: LauncherSortOption
}

final class LauncherIconCache: @unchecked Sendable {
    static let shared = LauncherIconCache()

    private let cache = NSCache<NSString, NSImage>()

    func iconImage(for bundleURL: URL) -> NSImage {
        let key = bundleURL.standardizedFileURL.path as NSString
        return cache.object(forKey: key) ?? NSWorkspace.shared.icon(forFile: bundleURL.path)
    }

    func preload(for bundleURL: URL) {
        let key = bundleURL.standardizedFileURL.path as NSString
        if cache.object(forKey: key) != nil {
            return
        }

        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        image.size = NSSize(width: 128, height: 128)
        cache.setObject(image, forKey: key)
    }
}

@MainActor
final class NotchV2LauncherStore: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var sortOption: LauncherSortOption = .name
    @Published var isManagingFavorites: Bool = false
    @Published var statusMessage: String?
    @Published var contentSize: CGSize = .zero
    @Published var dropTargetID: String?
    @Published private(set) var installedApps: [LauncherApp] = []
    @Published private(set) var customApps: [LauncherApp] = []
    @Published private(set) var favoriteIDs: [String] = []

    private var usageRecords: [String: LauncherUsageRecord] = [:]
    private var loadTask: Task<Void, Never>?
    private var statusClearTask: Task<Void, Never>?
    private let storageKey = "launcher.state.v1"

    init() {
        loadPersistedState()
        refreshApplications()
    }

    var favoriteApps: [LauncherApp] {
        favoriteIDs.compactMap { app(for: $0) }
    }

    var visibleApps: [LauncherApp] {
        let query = normalizedSearchQuery
        return sortedApps.filter { app in
            guard query.isEmpty == false else { return true }
            return app.searchText.contains(query)
        }
    }

    var sortedApps: [LauncherApp] {
        let apps = deduplicatedApps
        switch sortOption {
        case .name:
            return apps.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .recent:
            return apps.sorted {
                let leftDate = $0.lastLaunchDate ?? .distantPast
                let rightDate = $1.lastLaunchDate ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .frequency:
            return apps.sorted {
                if $0.launchCount != $1.launchCount { return $0.launchCount > $1.launchCount }
                let leftDate = $0.lastLaunchDate ?? .distantPast
                let rightDate = $1.lastLaunchDate ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    var favoriteCountText: String {
        "\(favoriteApps.count)/\(LauncherTokens.favoriteMaximumCount)"
    }

    var appCountText: String {
        "\(visibleApps.count) 个应用"
    }

    func recordContentSize(_ size: CGSize) {
        guard contentSize != size else { return }
        contentSize = size
        print("[Launcher] content size: \(Int(size.width)) x \(Int(size.height))")
    }

    func setManagingFavorites(_ newValue: Bool) {
        guard isManagingFavorites != newValue else { return }
        isManagingFavorites = newValue
        if newValue == false {
            persistState()
        }
    }

    func toggleManagingFavorites() {
        setManagingFavorites(!isManagingFavorites)
    }

    func setSortOption(_ option: LauncherSortOption) {
        guard sortOption != option else { return }
        sortOption = option
        persistState()
    }

    func clearSearch() {
        searchQuery = ""
    }

    func refreshApplications() {
        loadTask?.cancel()
        let customAppsSnapshot = customApps
        let usageSnapshot = usageRecords
        let favoriteSnapshot = favoriteIDs
        let sortSnapshot = sortOption

#if DEBUG
        if DebugPreviewLaunchCommand.isCompanionSixPagesExport() {
            let scanned = Self.scanInstalledApplications()
            installedApps = Self.merge(scanned, customApps: customAppsSnapshot, usageRecords: usageSnapshot)
            customApps = customAppsSnapshot
            let resolvedFavorites = favoriteSnapshot.filter { self.app(for: $0) != nil }
            if resolvedFavorites.isEmpty, installedApps.isEmpty == false {
                favoriteIDs = Array(installedApps.prefix(6).map(\.id))
            } else {
                favoriteIDs = resolvedFavorites
            }
            sortOption = sortSnapshot
            persistState()
            return
        }
#endif

        loadTask = Task.detached(priority: .utility) {
            let scanned = Self.scanInstalledApplications()
            await MainActor.run {
                self.installedApps = Self.merge(scanned, customApps: customAppsSnapshot, usageRecords: usageSnapshot)
                self.customApps = customAppsSnapshot
                self.favoriteIDs = favoriteSnapshot.filter { self.app(for: $0) != nil }
                self.sortOption = sortSnapshot
                self.persistState()
            }
        }
    }

    func launch(_ app: LauncherApp) {
        NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.presentStatus("打开失败：\(app.displayName)")
                    print("[Launcher] launch failed: \(app.bundleURL.path) error=\(error.localizedDescription)")
                    return
                }
                self.updateUsage(for: app.id)
                self.presentStatus("已打开 \(app.displayName)")
            }
        }
    }

    func addFavorite(_ app: LauncherApp, insertBefore targetID: String? = nil) {
        guard isFavoriteCapacityAvailable(for: app.id) else {
            presentStatus("常用应用已达到 10 个")
            return
        }

        removeFavoriteIfNeeded(app.id)

        let insertIndex: Int
        if let targetID, let targetIndex = favoriteIDs.firstIndex(of: targetID) {
            insertIndex = targetIndex
        } else {
            insertIndex = favoriteIDs.count
        }

        favoriteIDs.insert(app.id, at: min(insertIndex, favoriteIDs.count))
        persistState()
    }

    func moveFavorite(_ sourceID: String, before targetID: String?) {
        guard favoriteIDs.contains(sourceID) else {
            if let app = app(for: sourceID) {
                addFavorite(app, insertBefore: targetID)
            }
            return
        }

        guard let sourceIndex = favoriteIDs.firstIndex(of: sourceID) else { return }
        favoriteIDs.remove(at: sourceIndex)

        let destinationIndex: Int
        if let targetID, let targetIndex = favoriteIDs.firstIndex(of: targetID) {
            destinationIndex = targetIndex
        } else {
            destinationIndex = favoriteIDs.count
        }

        favoriteIDs.insert(sourceID, at: min(destinationIndex, favoriteIDs.count))
        persistState()
    }

    func removeFavorite(id: String) {
        favoriteIDs.removeAll { $0 == id }
        persistState()
    }

    func toggleFavorite(_ app: LauncherApp) {
        if isFavorite(app.id) {
            removeFavorite(id: app.id)
        } else {
            addFavorite(app)
        }
    }

    func setDropTarget(_ id: String?) {
        dropTargetID = id
    }

    func importApp(from bundleURL: URL, pin: Bool) {
        guard let app = LauncherApp.make(from: bundleURL) else {
            presentStatus("无法导入该应用")
            return
        }

        if appIndex(for: app.id) == nil {
            customApps.append(app)
        }

        LauncherIconCache.shared.preload(for: bundleURL)

        rebuildApplications()

        if pin {
            addFavorite(app)
        } else {
            persistState()
        }
    }

    func handleDroppedString(_ value: String, pin: Bool, targetID: String?) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        if trimmed.hasPrefix("launcher-app:") {
            let id = String(trimmed.dropFirst("launcher-app:".count))
            guard let app = app(for: id) else { return }
            if pin {
                moveFavorite(app.id, before: targetID)
            } else {
                launch(app)
            }
            return
        }

        if trimmed.contains(".app") {
            let candidateURL = URL(string: trimmed) ?? URL(fileURLWithPath: trimmed)
            if candidateURL.pathExtension.lowercased() == "app" {
                importApp(from: candidateURL, pin: pin)
            }
        }
    }

    func handleDroppedFileURL(_ url: URL, pin: Bool, targetID: String?) {
        guard url.pathExtension.lowercased() == "app" else { return }
        importApp(from: url, pin: pin)
        if pin, let imported = app(for: LauncherApp.stableID(bundleIdentifier: Bundle(url: url)?.bundleIdentifier, bundleURL: url)) {
            moveFavorite(imported.id, before: targetID)
        }
    }

    func dragPayload(for app: LauncherApp) -> NSItemProvider {
        NSItemProvider(object: NSString(string: "launcher-app:\(app.id)"))
    }

    func isFavorite(_ appID: String) -> Bool {
        favoriteIDs.contains(appID)
    }

    func app(for id: String) -> LauncherApp? {
        deduplicatedApps.first(where: { $0.id == id })
    }

    func appIndex(for id: String) -> Int? {
        deduplicatedApps.firstIndex(where: { $0.id == id })
    }

    func isFavoriteCapacityAvailable(for appID: String) -> Bool {
        isFavorite(appID) || favoriteIDs.count < LauncherTokens.favoriteMaximumCount
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var deduplicatedApps: [LauncherApp] {
        var result: [LauncherApp] = []
        var seen = Set<String>()
        for app in installedApps + customApps {
            guard seen.insert(app.id).inserted else { continue }
            if let usage = usageRecords[app.id] {
                var updated = app
                updated.lastLaunchDate = usage.lastLaunchDate
                updated.launchCount = usage.launchCount
                result.append(updated)
            } else {
                result.append(app)
            }
        }
        return result
    }

    private func updateUsage(for id: String) {
        let now = Date()
        let current = usageRecords[id] ?? LauncherUsageRecord(id: id, lastLaunchDate: nil, launchCount: 0)
        usageRecords[id] = LauncherUsageRecord(
            id: id,
            lastLaunchDate: now,
            launchCount: current.launchCount + 1
        )
        if let index = installedApps.firstIndex(where: { $0.id == id }) {
            installedApps[index].lastLaunchDate = now
            installedApps[index].launchCount += 1
        }
        if let index = customApps.firstIndex(where: { $0.id == id }) {
            customApps[index].lastLaunchDate = now
            customApps[index].launchCount += 1
        }
        persistState()
    }

    private func presentStatus(_ message: String) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            self.statusMessage = nil
        }
    }

    private func removeFavoriteIfNeeded(_ id: String) {
        favoriteIDs.removeAll { $0 == id }
    }

    private func rebuildApplications() {
        let customAppsSnapshot = customApps
        installedApps = Self.merge(Self.scanInstalledApplications(), customApps: customAppsSnapshot, usageRecords: usageRecords)
    }

    private func persistState() {
        let snapshot = LauncherPersistedState(
            favoriteIDs: favoriteIDs,
            customApps: customApps,
            usageRecords: usageRecords.values.sorted { $0.id < $1.id },
            sortOption: sortOption
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(LauncherPersistedState.self, from: data) else {
            customApps = []
            favoriteIDs = []
            usageRecords = [:]
            sortOption = .name
            return
        }

        customApps = snapshot.customApps.filter { FileManager.default.fileExists(atPath: $0.bundleURL.path) }
        favoriteIDs = snapshot.favoriteIDs
        usageRecords = Dictionary(uniqueKeysWithValues: snapshot.usageRecords.map { ($0.id, $0) })
        sortOption = snapshot.sortOption
    }

    nonisolated static func scanInstalledApplications() -> [LauncherApp] {
        let directories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var results: [LauncherApp] = []
        var seen = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]

        for root in directories where FileManager.default.fileExists(atPath: root.path) {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "app" else { continue }
                guard let app = LauncherApp.make(from: url) else { continue }
                LauncherIconCache.shared.preload(for: url)
                guard seen.insert(app.id).inserted else { continue }
                results.append(app)
            }
        }

        return results
    }

    private static func merge(
        _ scanned: [LauncherApp],
        customApps: [LauncherApp],
        usageRecords: [String: LauncherUsageRecord]
    ) -> [LauncherApp] {
        var merged: [LauncherApp] = []
        var seen = Set<String>()

        for app in scanned + customApps {
            guard seen.insert(app.id).inserted else { continue }
            var updated = app
            if let usage = usageRecords[app.id] {
                updated.lastLaunchDate = usage.lastLaunchDate
                updated.launchCount = usage.launchCount
            }
            merged.append(updated)
        }

        return merged
    }
}
