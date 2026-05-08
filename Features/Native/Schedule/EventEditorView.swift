import SwiftUI

// MARK: - Event Editor View (Sheet)

struct EventEditorView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedCategoryId: String = "acmind"
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var durationMinutes: Int = 60
    @State private var isAllDay: Bool = false
    @State private var validationError: String? = nil

    private let calendar = Calendar.current
    private let durationOptions = [15, 30, 45, 60, 90, 120, 180]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") {
                    viewModel.createError = nil
                    viewModel.closeCreateEvent()
                    dismiss()
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)

                Spacer()

                Text("新建日程")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button("创建") {
                    validateAndCreate()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .cornerRadius(6)
                .disabled(!canCreate)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("标题")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)

                    TextField("输入日程标题", text: $title)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .onAppear {
                            DispatchQueue.main.async {
                                NSTextView.currentFirstResponder()?.becomeFirstResponder()
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("分类")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)

                    HStack(spacing: 6) {
                        ForEach(viewModel.categories) { category in
                            Button {
                                selectedCategoryId = category.id
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 8, height: 8)
                                    Text(category.name)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategoryId == category.id
                                    ? category.color.opacity(0.15)
                                    : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedCategoryId == category.id
                                            ? category.color.opacity(0.3)
                                            : Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Toggle("全天", isOn: $isAllDay)
                    .font(.system(size: 13))
                    .toggleStyle(.switch)

                if !isAllDay {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("开始时间")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)

                            HStack(spacing: 4) {
                                Picker("时", selection: $startHour) {
                                    ForEach(6...23, id: \.self) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 60)

                                Text(":")
                                    .font(.system(size: 14, weight: .medium))

                                Picker("分", selection: $startMinute) {
                                    ForEach([0, 15, 30, 45], id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 60)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("时长")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)

                            Picker("时长", selection: $durationMinutes) {
                                ForEach(durationOptions, id: \.self) { mins in
                                    Text(durationLabel(mins)).tag(mins)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 100)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("结束时间")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)

                            Text(endTimeString)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                    Text(dateString)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }

                if let error = validationError ?? viewModel.createError {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                            .lineLimit(nil)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Spacer()
        }
        .frame(width: 420)
        .onAppear {
            startHour = viewModel.newEventStartHour
            startMinute = viewModel.newEventStartMinute
        }
        .onChange(of: title) { _ in
            validationError = nil
        }
        .onChange(of: startHour) { _ in
            validationError = nil
        }
        .onChange(of: durationMinutes) { _ in
            validationError = nil
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var endTimeString: String {
        let endMinutes = startHour * 60 + startMinute + durationMinutes
        let endHour = endMinutes / 60
        let endMinute = endMinutes % 60
        return String(format: "%02d:%02d", endHour, endMinute)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: viewModel.newEventDate)
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 {
            return "\(h) 小时"
        }
        return "\(h) 小时 \(m) 分钟"
    }

    private func validateAndCreate() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        if trimmedTitle.isEmpty {
            validationError = "标题不能为空"
            return
        }

        if durationMinutes < 15 {
            validationError = "时长不能小于 15 分钟"
            return
        }

        if durationMinutes > 480 {
            validationError = "时长建议不超过 8 小时"
            return
        }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: viewModel.newEventDate)
        guard let startDate = calendar.date(from: DateComponents(
            year: startComponents.year,
            month: startComponents.month,
            day: startComponents.day,
            hour: startHour,
            minute: startMinute
        )) else {
            validationError = "无法解析开始时间"
            return
        }

        let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let nextDayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: viewModel.newEventDate)!)

        if endDate > nextDayStart {
            validationError = "结束时间不能超过当天 24:00"
            return
        }

        viewModel.createEvent(
            title: trimmedTitle,
            categoryId: selectedCategoryId,
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            isAllDay: isAllDay
        )

        if viewModel.createError == nil {
            dismiss()
        }
    }
}

extension NSTextView {
    static func currentFirstResponder() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }
}
