import SwiftUI

struct TodayOverviewPanel: View {
    let model: WorkbenchV2MockData.TodayStatus
    let layout: WorkbenchV2ResolvedLayout

    @State private var islandEnabled = true
    @State private var speechEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header
            summaryBar

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: WorkbenchV2Tokens.Layout.overviewTileSpacing),
                    GridItem(.flexible(), spacing: WorkbenchV2Tokens.Layout.overviewTileSpacing)
                ],
                spacing: WorkbenchV2Tokens.Layout.overviewTileSpacing
            ) {
                ForEach(Array(model.items.prefix(4))) { item in
                    WorkbenchV2OverviewMetricTile(item: item, layout: layout)
                }
            }

            VStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
                WorkbenchV2OverviewToggleRow(
                    item: model.toggle(at: 0) ?? .init(title: "灵动大陆", subtitle: "已开启", isOn: true, systemImage: "circle"),
                    isOn: $islandEnabled,
                    isCompact: layout.mode == .compact
                )

                WorkbenchV2OverviewToggleRow(
                    item: model.toggle(at: 1) ?? .init(title: "说人法", subtitle: "已开启", isOn: true, systemImage: "music.note"),
                    isOn: $speechEnabled,
                    isCompact: layout.mode == .compact
                )
            }

            HStack(spacing: WorkbenchV2Tokens.Layout.overviewTileSpacing) {
                ForEach(model.statusBlocks) { block in
                    WorkbenchV2OverviewStatusBlock(
                        block: block,
                        isCompact: layout.mode == .compact
                    )
                }
            }
        }
        .padding(layout.mode == .compact ? WorkbenchV2Tokens.Spacing.md : WorkbenchV2Tokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surface)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.36), lineWidth: WorkbenchV2Tokens.Border.width)
        )
        .shadow(
            color: Color.black.opacity(WorkbenchV2Tokens.Shadow.opacity),
            radius: WorkbenchV2Tokens.Shadow.radius,
            x: WorkbenchV2Tokens.Shadow.x,
            y: WorkbenchV2Tokens.Shadow.y
        )
    }

    private var sectionSpacing: CGFloat {
        layout.mode == .compact ? WorkbenchV2Tokens.Spacing.sm : WorkbenchV2Tokens.Spacing.md
    }

    private var header: some View {
        HStack(alignment: .top, spacing: WorkbenchV2Tokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.cardTitle + 2, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)

                Text(model.subtitle)
                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var summaryBar: some View {
        HStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
            WorkbenchV2SummaryPill(
                title: "状态",
                value: model.state.rawValue.uppercased(),
                tint: tint(for: model.state)
            )

            WorkbenchV2SummaryPill(
                title: "总览",
                value: "\(model.items.count) 项",
                tint: WorkbenchV2Tokens.Color.accent
            )

            WorkbenchV2SummaryPill(
                title: "开关",
                value: "\(model.toggles.filter(\.isOn).count)/\(model.toggles.count)",
                tint: WorkbenchV2Tokens.Color.textSecondary
            )
        }
    }

    private func tint(for state: WorkbenchV2State) -> Color {
        switch state {
        case .empty:
            return WorkbenchV2Tokens.Color.textTertiary
        case .normal:
            return WorkbenchV2Tokens.Color.accent
        case .warning:
            return WorkbenchV2Tokens.Color.accentOrange
        }
    }
}

private struct WorkbenchV2SummaryPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
        .padding(.vertical, WorkbenchV2Tokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct WorkbenchV2OverviewMetricTile: View {
    let item: WorkbenchV2MockData.TodayStatusItem
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        Group {
            if layout.mode == .compact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.xs) {
                        Circle()
                            .fill(item.tint.opacity(0.16))
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.xs) {
                        Text(item.value)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)

                        if item.unit.isEmpty == false {
                            Text(item.unit)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                            .lineLimit(1)
                        }
                    }

                    Text(item.meta)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.sm) {
                    HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.xs) {
                        Circle()
                            .fill(item.tint.opacity(0.16))
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.xs) {
                        Text(item.value)
                            .font(.system(size: WorkbenchV2Tokens.Typography.value, weight: .semibold))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        if item.unit.isEmpty == false {
                            Text(item.unit)
                                .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium))
                                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        Text(item.meta)
                            .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .medium, design: .monospaced))
                            .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(WorkbenchV2Tokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: layout.mode == .compact ? 58 : WorkbenchV2Tokens.Layout.overviewTileHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct WorkbenchV2OverviewToggleRow: View {
    let item: WorkbenchV2MockData.TodayStatusToggle
    @Binding var isOn: Bool
    let isCompact: Bool

    var body: some View {
        HStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
            Circle()
                .fill(WorkbenchV2Tokens.Color.separator.opacity(0.16))
                .frame(width: isCompact ? 24 : 28, height: isCompact ? 24 : 28)
                .overlay(
                    Image(systemName: item.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkbenchV2Tokens.Color.textTertiary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                    .lineLimit(1)
                Text(isOn ? "已开启" : "已关闭")
                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : WorkbenchV2Tokens.Layout.overviewToggleHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct WorkbenchV2OverviewStatusBlock: View {
    let block: WorkbenchV2MockData.TodayStatusBlock
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.sm) {
            Circle()
                .fill(block.tint.opacity(0.18))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.caption))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
                    .lineLimit(1)
                Text(block.value)
                    .font(.system(size: WorkbenchV2Tokens.Typography.body, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
        .padding(.vertical, isCompact ? WorkbenchV2Tokens.Spacing.xs : WorkbenchV2Tokens.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 48 : WorkbenchV2Tokens.Layout.overviewStatusHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.separator.opacity(0.16), lineWidth: 1)
        )
    }
}

private extension WorkbenchV2MockData.TodayStatus {
    func toggle(at index: Int) -> WorkbenchV2MockData.TodayStatusToggle? {
        guard toggles.indices.contains(index) else { return nil }
        return toggles[index]
    }
}

struct TodayOverviewPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodayOverviewPanel(model: WorkbenchV2MockData.preview().todayStatus, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 330, height: 260)))
            TodayOverviewPanel(model: .init(state: .empty, title: "今日总览", subtitle: "暂无内容", items: [], toggles: [], statusBlocks: []), layout: WorkbenchV2Layout.resolve(for: CGSize(width: 330, height: 260)))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
