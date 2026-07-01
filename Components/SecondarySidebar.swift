import SwiftUI

struct SecondarySidebarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    var badge: String? = nil
    var isDisabled: Bool = false
}

struct SecondarySidebarSection: Identifiable {
    let id: String
    let title: String
    let items: [SecondarySidebarItem]
}

struct SecondarySidebar: View {
    let sections: [SecondarySidebarSection]
    @Binding var selectedItem: String?
    var footerAction: (() -> Void)? = nil
    var footerTitle: String? = nil
    var footerIcon: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sections) { section in
                    AppSurfaceCard(
                        title: section.title,
                        subtitle: "\(section.items.count) 个入口",
                        padding: 12
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(section.items) { item in
                                Button {
                                    guard item.isDisabled == false else { return }
                                    selectedItem = item.id
                                } label: {
                                    sidebarRow(
                                        item: item,
                                        isSelected: selectedItem == item.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(item.isDisabled)
                            }
                        }
                    }
                }

                if let footerAction = footerAction, let footerTitle = footerTitle {
                    AppSurfaceCard(title: "快捷操作", subtitle: nil, padding: 12) {
                        Button(action: footerAction) {
                            HStack(spacing: 8) {
                                if let footerIcon = footerIcon {
                                    Image(systemName: footerIcon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                                        .frame(width: 22, height: 22)
                                        .background(AppSurfaceTokens.accentBlue.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(footerTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppSurfaceTokens.primaryText)
                                    Text("打开全局导航")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(AppSurfaceTokens.cardBackground.opacity(0.94).ignoresSafeArea())
    }

    private func sidebarRow(item: SecondarySidebarItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.14) : AppSurfaceTokens.cardBackground.opacity(0.92))
                    .frame(width: 26, height: 26)

                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13.2, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(item.isDisabled ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.primaryText)

            }

            Spacer(minLength: 6)

            if let badge = item.badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.12) : AppSurfaceTokens.cardBackground.opacity(0.92))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .opacity(item.isDisabled ? 0.55 : 1.0)
    }
}

struct SecondarySidebarWithHeader: View {
    let title: String
    let subtitle: String?
    let sections: [SecondarySidebarSection]
    @Binding var selectedItem: String?
    var footerAction: (() -> Void)? = nil
    var footerTitle: String? = nil
    var footerIcon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Divider()

            SecondarySidebar(
                sections: sections,
                selectedItem: $selectedItem,
                footerAction: footerAction,
                footerTitle: footerTitle,
                footerIcon: footerIcon
            )
        }
        .background(AppSurfaceTokens.cardBackground.opacity(0.94))
    }
}
