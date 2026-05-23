import AppKit
import SwiftUI

// MARK: - Tool Unavailable Panel

struct ToolUnavailablePanel: View {
    let title: String
    let description: String
    let hint: String

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    hintCard
                }
                .padding(20)
            }
        }
        .frame(width: 700, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("入口已接通", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.green)

            Text("这个卡片现在不会再是死接口了。它已经进入统一工具壳，后续可以继续补上真正的执行逻辑。")
                .font(.body)
                .foregroundStyle(Color.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("下一步")
                .font(.headline)

            Text(hint)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
