import SwiftUI
import AppKit

// MARK: - Schedule Page (Main Layout)

/// AcMind 日程页面 - 个人时间驾驶舱
/// 左侧：分类、总览、今日待办、迷你月历、工作饱和度
/// 右侧：周/月/年视图 + 年度热力图
struct ScheduleNativeView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                ScheduleToolbar(viewModel: viewModel)
                    .frame(height: ACLayout.pageHeaderHeight)

                HStack(spacing: 0) {
                    ScheduleSidebar(viewModel: viewModel)
                        .frame(width: ScheduleLayout.sidebarWidth)

                    Divider()
                        .overlay(ACColors.border)

                    ScrollView(.vertical, showsIndicators: false) {
                        ScheduleMain(viewModel: viewModel)
                            .padding(.horizontal, ACLayout.pagePaddingX)
                            .padding(.vertical, ACLayout.pagePaddingY)
                            .padding(.bottom, ACLayout.pagePaddingBottom)
                            .frame(
                                minWidth: ScheduleLayout.mainMinWidth,
                                maxWidth: ACLayout.secondaryPageContentMaxWidth,
                                alignment: .leading
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ACColors.pageBackground)
        }
        .sheet(isPresented: $viewModel.isCreatingEvent) {
            EventEditorView(viewModel: viewModel)
        }
    }
}

// MARK: - Schedule Main

struct ScheduleMain: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        ScheduleViewSurface(viewModel: viewModel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Schedule View Surface

private struct ScheduleViewSurface: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        Group {
            switch viewModel.viewMode {
            case .day:
                ScheduleDayLogView(viewModel: viewModel)
            case .week:
                ScheduleWeekLogView(viewModel: viewModel)
            }
        }
    }
}
