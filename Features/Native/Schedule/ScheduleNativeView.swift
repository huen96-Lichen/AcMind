import SwiftUI

struct ScheduleNativeView: View {
    @State private var newEventText: String = ""

    private let today = Date()

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: today)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题区
                VStack(alignment: .leading, spacing: 4) {
                    Text("日程表")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(todayString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 快速添加
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                    TextField("快速添加日程…", text: $newEventText)
                        .textFieldStyle(.plain)
                        .onSubmit { addEvent() }
                    Button("添加") { addEvent() }
                        .buttonStyle(.bordered)
                        .disabled(newEventText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // 时间轴
                VStack(spacing: 0) {
                    ForEach(scheduleBlocks, id: \.title) { block in
                        ScheduleBlockRow(block: block)
                        if block != scheduleBlocks.last {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Spacer(minLength: 40)
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - 示例数据

    private var scheduleBlocks: [ScheduleBlock] {
        [
            ScheduleBlock(time: "09:00", duration: "1h", title: "晨间回顾", subtitle: "检查昨日收集的内容", icon: "sunrise.fill", color: .orange),
            ScheduleBlock(time: "10:30", duration: "30min", title: "整理笔记", subtitle: "处理收集箱中的待整理内容", icon: "doc.text.fill", color: .blue),
            ScheduleBlock(time: "14:00", duration: "2h", title: "深度工作", subtitle: "专注于核心项目任务", icon: "brain.head.profile", color: .purple),
        ]
    }

    // MARK: - Actions

    private func addEvent() {
        let text = newEventText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 占位：暂不持久化
        newEventText = ""
    }
}

// MARK: - ScheduleBlock

private struct ScheduleBlock: Equatable {
    let time: String
    let duration: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private struct ScheduleBlockRow: View {
    let block: ScheduleBlock

    var body: some View {
        HStack(spacing: 16) {
            // 时间
            VStack(spacing: 2) {
                Text(block.time)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                Text(block.duration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52, alignment: .leading)

            // 图标
            Image(systemName: block.icon)
                .font(.system(size: 20))
                .foregroundStyle(block.color)
                .frame(width: 36, height: 36)
                .background(block.color.opacity(0.1))
                .cornerRadius(8)

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(block.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}
