import SwiftUI

struct QuickActionsCard: View {
    let model: WorkbenchV2DashboardData.QuickActions
    let layout: WorkbenchV2ResolvedLayout
    let actions: WorkbenchV2QuickActionHandlers

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: layout.mode == .compact ? WorkbenchV2Tokens.Spacing.sm : WorkbenchV2Tokens.Spacing.md
        ) {
            HStack(alignment: .firstTextBaseline, spacing: WorkbenchV2Tokens.Spacing.sm) {
                Text(model.title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.cardTitle, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: WorkbenchV2Tokens.Layout.quickActionGridSpacing),
                    GridItem(.flexible(), spacing: WorkbenchV2Tokens.Layout.quickActionGridSpacing),
                    GridItem(.flexible(), spacing: WorkbenchV2Tokens.Layout.quickActionGridSpacing)
                ],
                spacing: WorkbenchV2Tokens.Layout.quickActionGridSpacing
            ) {
                ForEach(Array(model.actions.prefix(6).enumerated()), id: \.offset) { index, action in
                    Button(action: actionHandler(for: index)) {
                        Group {
                            if layout.mode == .compact {
                                VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.xs) {
                                    Circle()
                                        .fill(WorkbenchV2Tokens.Color.separator.opacity(0.10))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Image(systemName: action.systemImage)
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary.opacity(0.9))
                                        )

                                    Text(action.title)
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if action.subtitle.isEmpty == false {
                                        Text(action.subtitle)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary.opacity(0.92))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.sm) {
                                    Circle()
                                        .fill(WorkbenchV2Tokens.Color.separator.opacity(0.10))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Image(systemName: action.systemImage)
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary.opacity(0.9))
                                        )

                                    Text(action.title)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer(minLength: 0)
                                }

                                if action.subtitle.isEmpty == false {
                                    Text(action.subtitle)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary.opacity(0.92))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding(WorkbenchV2Tokens.Spacing.sm)
                        .frame(maxWidth: .infinity, minHeight: layout.mode == .compact ? 60 : 64, alignment: .leading)
                    }
                    .buttonStyle(
                        WorkbenchV2QuickActionButtonStyle(
                            border: WorkbenchV2Tokens.Color.separator.opacity(0.3)
                        )
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

    private func actionHandler(for index: Int) -> () -> Void {
        switch index {
        case 0:
            return actions.screenshot
        case 1:
            return actions.quickRecord
        case 2:
            return actions.createTask
        case 3:
            return actions.openInbox
        case 4:
            return actions.startAgent
        case 5:
            return actions.importFiles
        default:
            return {}
        }
    }
}

private struct WorkbenchV2QuickActionButtonStyle: ButtonStyle {
    let border: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                    .fill(WorkbenchV2Tokens.Color.surfaceSoft.opacity(configuration.isPressed ? 1.0 : 0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                    .stroke(border.opacity(configuration.isPressed ? 0.35 : 0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if DEBUG
struct QuickActionsCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuickActionsCard(model: WorkbenchV2DashboardData.preview().quickActions, layout: WorkbenchV2Layout.resolve(for: CGSize(width: 292, height: 220)), actions: .previewOnly)
            QuickActionsCard(model: .init(state: .empty, title: "快捷动作", actions: []), layout: WorkbenchV2Layout.resolve(for: CGSize(width: 292, height: 220)), actions: .previewOnly)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
