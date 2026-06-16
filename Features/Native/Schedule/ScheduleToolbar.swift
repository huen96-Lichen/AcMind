import SwiftUI
import AppKit

// MARK: - Schedule Toolbar

struct ScheduleToolbar: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var isSearching = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：标题
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.viewTitle)
                    .font(.system(size: 17, weight: .semibold))
                Text(viewModel.viewSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧：操作按钮
            HStack(spacing: 8) {
                // 今天按钮
                Button {
                    viewModel.goToToday()
                } label: {
                    Text("今天")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(AppSurfaceTokens.cardBackgroundSoft)
                        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .stroke(AppSurfaceTokens.separator, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                // 前进后退
                HStack(spacing: 0) {
                    Button { viewModel.goToPrevious() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.goToNext() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
                .background(AppSurfaceTokens.cardBackgroundSoft)
                .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                        .stroke(AppSurfaceTokens.separator, lineWidth: 0.5)
                )

                // 分段控件：周 / 月 / 年
                ScheduleSegmentedControl(selection: $viewModel.viewMode)

                if isSearching {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)

                            TextField("搜索日程", text: $viewModel.searchText)
                                .textFieldStyle(.plain)
                                .focused($searchFieldFocused)
                                .frame(minWidth: 180)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppSurfaceTokens.cardBackgroundSoft)
                        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .stroke(AppSurfaceTokens.separator, lineWidth: 0.5)
                        )

                        Button {
                            viewModel.searchText = ""
                            isSearching = false
                            searchFieldFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("清除搜索")
                    }
                } else {
                    Button {
                        isSearching = true
                        DispatchQueue.main.async {
                            searchFieldFocused = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("搜索日程")
                }

                // 添加日程按钮
                Button {
                    viewModel.openCreateEvent()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("添加日程")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: ScheduleLayout.toolbarHeight)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .overlay(
            Rectangle()
                .fill(AppSurfaceTokens.separator.opacity(0.35))
                .frame(height: 1),
            alignment: .bottom
        )
        .onAppear {
            isSearching = !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isSearching = true
            }
        }
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
                        .font(.system(size: 12, weight: selection == mode ? .medium : .regular))
                        .foregroundStyle(selection == mode ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                .fill(selection == mode ? AppSurfaceTokens.cardBackgroundSoft : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(AppSurfaceTokens.inlineBlockRadius)
    }
}
