import SwiftUI

struct DeviceStatusBar: View {
    let model: WorkbenchV2MockData.DeviceStatus
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.md) {
            Text(model.title)
                .font(.system(size: WorkbenchV2Tokens.Typography.sectionTitle, weight: .semibold))
                .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                .lineLimit(1)

            WorkbenchV2DeviceDivider()

            ForEach(visibleItems) { item in
                WorkbenchV2DeviceStatusMetric(item: item)

                if item.id != visibleItems.last?.id {
                    WorkbenchV2DeviceDivider()
                }
            }

            Spacer(minLength: WorkbenchV2Tokens.Spacing.sm)

            Button(action: {}) {
                Label("查看详情", systemImage: "arrow.right.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .semibold))
            }
            .buttonStyle(WorkbenchV2DeviceDetailsButtonStyle())
        }
        .padding(.horizontal, WorkbenchV2Tokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.34), lineWidth: WorkbenchV2Tokens.Border.width)
        )
        .shadow(
            color: Color.black.opacity(WorkbenchV2Tokens.Shadow.opacity),
            radius: WorkbenchV2Tokens.Shadow.radius,
            x: WorkbenchV2Tokens.Shadow.x,
            y: WorkbenchV2Tokens.Shadow.y
        )
    }

    private var visibleItems: [WorkbenchV2MockData.DeviceStatusItem] {
        if layout.mode == .compact {
            return model.items.filter { item in
                ["CPU", "内存", "电源", "权限"].contains(item.title)
            }
        }

        return model.items
    }
}

private struct WorkbenchV2DeviceStatusMetric: View {
    let item: WorkbenchV2MockData.DeviceStatusItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.xs) {
            Circle()
                .fill(item.tint.opacity(0.18))
                .frame(width: WorkbenchV2Tokens.Layout.deviceStatusDotSize, height: WorkbenchV2Tokens.Layout.deviceStatusDotSize)

            Text(item.title)
                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium))
                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                .lineLimit(1)

            Text(item.value)
                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .semibold, design: .monospaced))
                .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                .lineLimit(1)
        }
        .frame(minWidth: 0, alignment: .leading)
    }
}

private struct WorkbenchV2DeviceDivider: View {
    var body: some View {
        Rectangle()
            .fill(WorkbenchV2Tokens.Color.separator.opacity(0.45))
            .frame(width: WorkbenchV2Tokens.Border.width, height: WorkbenchV2Tokens.Layout.deviceStatusDividerHeight)
    }
}

private struct WorkbenchV2DeviceDetailsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
                .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
            .frame(height: WorkbenchV2Tokens.Layout.deviceStatusDetailsButtonHeight)
            .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.control, style: .continuous)
                    .fill(WorkbenchV2Tokens.Color.surfaceSoft.opacity(configuration.isPressed ? 1.0 : 0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.control, style: .continuous)
                    .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.18), lineWidth: WorkbenchV2Tokens.Border.width)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DeviceStatusBar_Previews: PreviewProvider {
    static var previews: some View {
        DeviceStatusBar(
            model: WorkbenchV2MockData.preview().deviceStatus,
            layout: WorkbenchV2Layout.resolve(for: CGSize(width: 1235, height: 68))
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
