import SwiftUI
import AcMindKit

struct TagSelectorView: View {
    let availableTags: [ClipboardTag]
    let selectedTags: [String]
    let onSelect: (String) -> Void
    let onDeselect: (String) -> Void
    let onCreateTag: (String, String) -> Void

    @State private var newTagName = ""
    @State private var showNewTagField = false

    private let presetColors = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#EC4899", "#06B6D4", "#F97316"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)

            FlowLayout(spacing: 4) {
                ForEach(availableTags) { tag in
                    let isSelected = selectedTags.contains(tag.name)
                    Button {
                        if isSelected {
                            onDeselect(tag.name)
                        } else {
                            onSelect(tag.name)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(tag.swiftColor)
                                .frame(width: 6, height: 6)
                            Text(tag.name)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.22) : AppSurfaceTokens.separator.opacity(0.55), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? AppSurfaceTokens.primaryText : AppSurfaceTokens.primaryText)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if showNewTagField {
                    HStack(spacing: 4) {
                        TextField("名称", text: $newTagName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10))
                            .frame(width: 60)

                        Button {
                            let color = presetColors.randomElement() ?? "#3B82F6"
                            onCreateTag(newTagName, color)
                            newTagName = ""
                            showNewTagField = false
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .disabled(newTagName.isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppSurfaceTokens.cardBackgroundSoft)
                    .clipShape(Capsule())
                } else {
                    Button {
                        showNewTagField = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(AppSurfaceTokens.cardBackgroundSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
