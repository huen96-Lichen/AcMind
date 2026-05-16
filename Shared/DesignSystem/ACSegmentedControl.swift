import SwiftUI

struct ACSegmentedControl<Option: Hashable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option, Bool) -> Label

    init(
        _ options: [Option],
        selection: Binding<Option>,
        @ViewBuilder label: @escaping (Option, Bool) -> Label
    ) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option == selection

                Button {
                    selection = option
                } label: {
                    label(option, isSelected)
                        .frame(minHeight: ACLayout.buttonHeightL)
                        .padding(.horizontal, 12)
                        .foregroundStyle(isSelected ? ACColors.accentBlue : ACColors.primaryText)
                        .background(isSelected ? ACColors.cardBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}
