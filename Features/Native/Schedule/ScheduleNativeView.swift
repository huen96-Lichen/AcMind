import SwiftUI
import AppKit

// MARK: - Schedule Page (Main Layout)

/// AcMind 日程页面 - 个人时间驾驶舱
/// 左侧：分类、总览、今日待办、迷你月历、工作饱和度
/// 右侧：周/月/年视图 + 年度热力图
struct ScheduleNativeView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // 左侧信息面板
            ScheduleSidebar(viewModel: viewModel)

            Divider()

            // 右侧主日历区域
            ScheduleMain(viewModel: viewModel)
        }
        .background(AppSurfaceTokens.background)
        .sheet(isPresented: $viewModel.isCreatingEvent) {
            ScheduleEventEditorView(viewModel: viewModel)
        }
    }
}

// MARK: - Schedule Main

struct ScheduleMain: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            ScheduleToolbar(viewModel: viewModel)

            Divider()

            // 视图主体
            ScheduleViewSurface(viewModel: viewModel)
        }
        .frame(minWidth: ScheduleLayout.mainMinWidth)
        .background(AppSurfaceTokens.background)
    }
}

// MARK: - Schedule View Surface

private struct ScheduleViewSurface: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        switch viewModel.viewMode {
        case .week:
            WeekCalendarView(viewModel: viewModel)
        case .month:
            MonthCalendarView(viewModel: viewModel)
        case .year:
            YearCalendarView(viewModel: viewModel)
        }
    }
}

// MARK: - Event Editor Sheet

private struct ScheduleEventEditorView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedCategoryId: String = "personal"
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var durationMinutes: Int = 60
    @State private var isAllDay: Bool = false

    private let durationOptions = [15, 30, 45, 60, 90, 120, 180]
    private var isEditing: Bool { viewModel.editingEvent != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") {
                    viewModel.closeCreateEvent()
                    dismiss()
                }
                .foregroundStyle(Color.secondary)

                Spacer()

                Text(isEditing ? "编辑日程" : "新建日程")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button(isEditing ? "更新" : "保存") {
                    guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                    viewModel.createEvent(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        categoryId: selectedCategoryId,
                        startHour: startHour,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        isAllDay: isAllDay
                    )
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                TextField("输入日程标题", text: $title)
                    .textFieldStyle(.roundedBorder)

                Picker("分类", selection: $selectedCategoryId) {
                    ForEach(viewModel.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }

                Toggle("全天", isOn: $isAllDay)

                HStack {
                    Picker("开始", selection: $startHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .frame(width: 120)

                    Picker("分钟", selection: $startMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 100)
                }

                Picker("时长", selection: $durationMinutes) {
                    ForEach(durationOptions, id: \.self) { duration in
                        Text("\(duration) 分钟").tag(duration)
                    }
                }
            }
            .padding()
            .onAppear {
                if let editingEvent = viewModel.editingEvent {
                    title = editingEvent.title
                    selectedCategoryId = editingEvent.categoryId
                    startHour = Calendar.current.component(.hour, from: editingEvent.startAt)
                    startMinute = Calendar.current.component(.minute, from: editingEvent.startAt)
                    durationMinutes = max(15, editingEvent.durationMinutes)
                    isAllDay = editingEvent.isAllDay
                } else {
                    title = ""
                }
            }
        }
        .frame(width: 420, height: 320)
    }
}
