import SwiftUI

// MARK: - Environment Key for Theme

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ISTheme.dark
}

extension EnvironmentValues {
    var theme: ISTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func iStatTheme(_ theme: ISTheme) -> some View {
        environment(\.theme, theme)
    }
}

// MARK: - Menu Section Header

struct ISSectionHeader: View {
    let title: String
    var value: String?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(ISTypography.sectionHeader)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            if let value {
                Text(value)
                    .font(ISTypography.sectionBody)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
        .padding(.vertical, 5)
    }
}

// MARK: - Menu Row (Label + Value)

struct ISMenuRow: View {
    let label: String
    let value: String
    var valueColor: Color?
    var icon: String?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 14)
            }
            Text(label)
                .font(ISTypography.sectionBody)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .font(ISTypography.dataValue)
                .foregroundStyle(valueColor ?? theme.textSecondary)
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
        .padding(.vertical, 2)
    }
}

// MARK: - Process Row

struct ISProcessRow: View {
    let name: String
    let value: String
    var color: Color?
    var showBar: Bool = false
    var barValue: CGFloat = 0

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(name)
                    .font(ISTypography.dataLabel)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(value)
                    .font(ISTypography.dataValue)
                    .foregroundStyle(color ?? theme.textSecondary)
            }
            if showBar {
                ISSpaceBar(used: barValue, color: color ?? theme.graphPrimary, height: ISLayout.barHeightThin)
            }
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
        .padding(.vertical, 2)
    }
}

// MARK: - Graph Section Container

struct ISGraphSection<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionInternalGap) {
            HStack {
                Text(title)
                    .font(ISTypography.sectionHeader)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(ISTypography.sectionCaption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            content()
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
    }
}

// MARK: - Divider

struct ISDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.divider)
            .frame(height: 0.5)
            .padding(.horizontal, ISLayout.menuPaddingH)
            .padding(.vertical, ISLayout.dividerPadding)
    }
}

// MARK: - Menu Container

struct ISMenuContainer<Content: View>: View {
    var theme: ISTheme = .dark
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ISLayout.sectionGap) {
            content()
        }
        .padding(.vertical, ISLayout.menuPaddingV)
        .frame(width: ISLayout.menuWidth)
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: ISLayout.cornerRadius))
        .iStatTheme(theme)
    }
}

// MARK: - Button Item

struct ISButtonMenuItem: View {
    let title: String
    var icon: String?
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(ISTypography.sectionBody)
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: ISLayout.cornerRadius)
                    .fill(isPressed ? theme.surfacePressed : isHovered ? theme.surfaceElevated : theme.surface)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
    }
}

// MARK: - Toggle Row

struct ISToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(label)
                .font(ISTypography.sectionBody)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.7)
        }
        .padding(.horizontal, ISLayout.menuPaddingH)
        .padding(.vertical, 2)
    }
}

// MARK: - Status Badge

struct ISStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(ISTypography.statusBadge)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Press Events Modifier

private struct PressEventModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventModifier(onPress: onPress, onRelease: onRelease))
    }
}
