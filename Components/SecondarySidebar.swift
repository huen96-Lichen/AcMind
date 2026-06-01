import SwiftUI

struct SecondarySidebarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    var badge: String? = nil
    var isDisabled: Bool = false
    var isComingSoon: Bool = false
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
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selectedItem) {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            sidebarRow(item: item)
                                .tag(item.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            if let footerAction = footerAction, let footerTitle = footerTitle {
                Divider()
                Button(action: footerAction) {
                    HStack(spacing: 6) {
                        if let footerIcon = footerIcon {
                            Image(systemName: footerIcon)
                                .font(.caption)
                        }
                        Text(footerTitle)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .background(AppSurfaceTokens.cardBackgroundSoft)
            }
        }
        .background(AppSurfaceTokens.secondarySidebarBackground.ignoresSafeArea())
    }

    private func sidebarRow(item: SecondarySidebarItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 16)
                .foregroundStyle(item.isDisabled ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.secondaryText)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.92)
                    .foregroundStyle(item.isDisabled ? AppSurfaceTokens.tertiaryText : AppSurfaceTokens.primaryText)
            }

            Spacer()

            if let badge = item.badge {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule(style: .continuous))
            }

        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .opacity(item.isDisabled ? 0.6 : 1.0)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .listRowBackground(Color.clear)
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
            .padding(.horizontal, 16)
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
        .background(AppSurfaceTokens.secondarySidebarBackground)
    }
}
