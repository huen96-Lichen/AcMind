import SwiftUI
import AppKit

// MARK: - Schedule Toolbar

struct ScheduleToolbar: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        ACPageHeader(title: viewModel.viewTitle, subtitle: viewModel.viewSubtitle) {
            HStack(spacing: ACLayout.gapM) {
                Button {
                    viewModel.goToToday()
                } label: {
                    Text("今天")
                        .font(ACTypography.button)
                        .foregroundStyle(ACColors.primaryText)
                        .frame(height: ACLayout.buttonHeightL)
                        .padding(.horizontal, 12)
                        .background(ACColors.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                .stroke(ACColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    navigationButton(systemName: "chevron.left") {
                        viewModel.goToPrevious()
                    }

                    Divider()
                        .frame(height: 20)

                    navigationButton(systemName: "chevron.right") {
                        viewModel.goToNext()
                    }
                }
                .frame(height: ACLayout.buttonHeightL)
                .background(ACColors.softFill)
                .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                        .stroke(ACColors.border, lineWidth: 1)
                )

                ScheduleSegmentedControl(selection: $viewModel.viewMode)

                Button {} label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)
                        .frame(width: ACLayout.buttonHeightL, height: ACLayout.buttonHeightL)
                        .background(ACColors.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                .stroke(ACColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.35)
                .help("搜索暂未实现")

                Button {
                    viewModel.openCreateEvent()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ACColors.primaryText)
                        .frame(width: ACLayout.buttonHeightL, height: ACLayout.buttonHeightL)
                        .background(ACColors.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                                .stroke(ACColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("添加记录")
            }
        }
    }

    private func navigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ACColors.primaryText)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segmented Control

struct ScheduleSegmentedControl: View {
    @Binding var selection: ScheduleViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.displayName)
                        .font(ACTypography.miniMedium)
                        .foregroundStyle(selection == mode ? ACColors.primaryText : ACColors.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            selection == mode
                                ? ACColors.cardBackground
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ACLayout.tinyRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(ACColors.softFill)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
    }
}
