import SwiftUI

struct WorkbenchHeader: View {
    let model: WorkbenchV2MockData.Header
    let layout: WorkbenchV2ResolvedLayout

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.xs) {
                Text(model.title)
                    .font(.system(size: WorkbenchV2Tokens.Typography.pageTitle, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textPrimary)
                Text(model.subtitle)
                    .font(.system(size: WorkbenchV2Tokens.Typography.headerKicker, weight: .medium))
                    .foregroundStyle(WorkbenchV2Tokens.Color.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
                ForEach(model.badges) { badge in
                    Label(badge.text, systemImage: badge.systemImage)
                        .font(.system(size: WorkbenchV2Tokens.Typography.caption, weight: .semibold))
                        .foregroundStyle(badge.tint)
                        .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.chip, style: .continuous)
                                .fill(badge.tint.opacity(0.12))
                        )
                }
            }
        }
        .padding(.horizontal, 0)
        .frame(height: layout.headerHeight, alignment: .center)
        .layoutDebugRegion("WorkbenchHeader")
    }
}

struct WorkbenchHeader_Previews: PreviewProvider {
    static var previews: some View {
        WorkbenchHeader(
            model: WorkbenchV2MockData.preview().header,
            layout: WorkbenchV2Layout.resolve(for: CGSize(width: 1235, height: 888))
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
